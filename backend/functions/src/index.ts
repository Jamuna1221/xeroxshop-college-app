import cors from "cors";
import express, { Request, Response, NextFunction } from "express";
import { onRequest } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2";
import * as admin from "firebase-admin";

setGlobalOptions({ region: "asia-south1" });

admin.initializeApp();

type AuthedRequest = Request & { user?: admin.auth.DecodedIdToken };

function requireAuth(req: AuthedRequest, res: Response, next: NextFunction) {
  // Allow CORS preflight to pass through without auth.
  if (req.method === "OPTIONS") return next();

  const header = req.header("authorization") ?? "";
  const match = header.match(/^Bearer (.+)$/i);
  if (!match) return res.status(401).json({ error: "missing_auth" });

  admin
    .auth()
    .verifyIdToken(match[1])
    .then((decoded) => {
      req.user = decoded;
      next();
    })
    .catch(() => res.status(401).json({ error: "invalid_auth" }));
}

async function requireAdmin(req: AuthedRequest, res: Response, next: NextFunction) {
  // Allow CORS preflight to pass through without role check.
  if (req.method === "OPTIONS") return next();

  if (!req.user?.uid) return res.status(401).json({ error: "missing_auth" });

  const snap = await admin.firestore().collection("users").doc(req.user.uid).get();
  const role = snap.data()?.role;
  if (role !== "admin") return res.status(403).json({ error: "not_admin" });

  next();
}

function safeUser(doc: admin.firestore.DocumentSnapshot) {
  const d = doc.data() ?? {};
  return {
    uid: d.uid ?? doc.id,
    email: d.email ?? null,
    role: d.role ?? null,
    createdAt: d.createdAt?.toDate?.()?.toISOString?.() ?? null,
    disabled: d.disabled ?? false,
    // owner fields (nullable for regular users)
    ownerName: d.ownerName ?? null,
    shopName: d.shopName ?? null,
    phone: d.phone ?? null,
    mustChangePassword: d.mustChangePassword ?? false,
    accountSetupStatus: d.accountSetupStatus ?? null,
    totalRevenue: d.totalRevenue ?? 0
  };
}

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

// All routes below require admin auth
app.use(requireAuth);
app.use(requireAdmin);

// GET /users?role=user|owner|admin
app.get("/users", async (req: AuthedRequest, res: Response) => {
  const role = typeof req.query.role === "string" ? req.query.role : undefined;
  let q: admin.firestore.Query = admin.firestore().collection("users");
  if (role) q = q.where("role", "==", role);

  const snap = await q.limit(250).get();
  res.json({ users: snap.docs.map(safeUser) });
});

// GET /owners
app.get("/owners", async (_req: AuthedRequest, res: Response) => {
  const snap = await admin
    .firestore()
    .collection("users")
    .where("role", "==", "owner")
    .limit(250)
    .get();

  res.json({ owners: snap.docs.map(safeUser) });
});

// GET /auth-users
// Lists Firebase Auth users (so regular users appear even without Firestore docs).
app.get("/auth-users", async (_req: AuthedRequest, res: Response) => {
  const db = admin.firestore();

  const out: Array<Record<string, unknown>> = [];
  let nextPageToken: string | undefined;

  do {
    const page = await admin.auth().listUsers(250, nextPageToken);
    nextPageToken = page.pageToken;

    // Join with Firestore roles (best-effort)
    const joins = await Promise.all(
      page.users.map(async (u) => {
        const snap = await db.collection("users").doc(u.uid).get();
        const d = snap.data() ?? {};
        return {
          uid: u.uid,
          email: u.email ?? null,
          disabled: u.disabled ?? false,
          createdAt: u.metadata?.creationTime ?? null,
          role: d.role ?? null
        };
      })
    );

    out.push(...joins);
  } while (nextPageToken && out.length < 1000);

  res.json({ users: out });
});

// PATCH /auth-users/:uid  { disabled?: boolean }
app.patch("/auth-users/:uid", async (req: AuthedRequest, res: Response) => {
  const uidParam = req.params.uid;
  const uid = Array.isArray(uidParam) ? uidParam[0] : uidParam;
  const { disabled } = req.body ?? {};

  if (typeof disabled !== "boolean") {
    return res.status(400).json({ error: "missing_disabled" });
  }

  await admin.auth().updateUser(uid, { disabled });
  res.json({ ok: true });
});

// DELETE /auth-users/:uid
// Deletes Firebase Auth account and associated Firestore profile doc if present.
app.delete("/auth-users/:uid", async (req: AuthedRequest, res: Response) => {
  const uidParam = req.params.uid;
  const uid = Array.isArray(uidParam) ? uidParam[0] : uidParam;

  await admin.auth().deleteUser(uid);
  await admin.firestore().collection("users").doc(uid).delete().catch(() => {});

  res.json({ ok: true });
});

// POST /owners  { email, ownerName, shopName, phone }
app.post("/owners", async (req: AuthedRequest, res: Response) => {
  const { email, ownerName, shopName, phone } = req.body ?? {};
  if (!email || !ownerName || !shopName || !phone) {
    return res.status(400).json({ error: "missing_fields" });
  }

  // Generate temp password: "Print@4821"
  const digits = "0123456789";
  const word = "print";
  const rand = () => digits[Math.floor(Math.random() * digits.length)];
  const tempPassword = `${word[0].toUpperCase()}${word.slice(1)}@${rand()}${rand()}${rand()}${rand()}`;

  // Create Auth user
  const userRecord = await admin.auth().createUser({ email, password: tempPassword });

  // Create Firestore profile
  await admin.firestore().collection("users").doc(userRecord.uid).set(
    {
      uid: userRecord.uid,
      email,
      ownerName,
      shopName,
      phone,
      role: "owner",
      mustChangePassword: true,
      accountSetupStatus: "pending",
      totalRevenue: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    },
    { merge: true }
  );

  // NOTE: email sending should happen server-side; keeping it out for now
  // because this repo currently sends email from the client.

  res.json({ uid: userRecord.uid, tempPassword });
});

// PATCH /owners/:uid  { accountSetupStatus?, totalRevenue? }
app.patch("/owners/:uid", async (req: AuthedRequest, res: Response) => {
  const uidParam = req.params.uid;
  const uid = Array.isArray(uidParam) ? uidParam[0] : uidParam;
  const { accountSetupStatus, totalRevenue } = req.body ?? {};

  const patch: Record<string, unknown> = {};
  if (typeof accountSetupStatus === "string") patch.accountSetupStatus = accountSetupStatus;
  if (typeof totalRevenue === "number") patch.totalRevenue = totalRevenue;

  if (Object.keys(patch).length === 0) return res.status(400).json({ error: "no_updates" });

  await admin.firestore().collection("users").doc(uid).set(patch, { merge: true });
  res.json({ ok: true });
});

export const adminApi = onRequest(app);

