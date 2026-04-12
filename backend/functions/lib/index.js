"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.adminApi = void 0;
const cors_1 = __importDefault(require("cors"));
const express_1 = __importDefault(require("express"));
const https_1 = require("firebase-functions/v2/https");
const v2_1 = require("firebase-functions/v2");
const admin = __importStar(require("firebase-admin"));
(0, v2_1.setGlobalOptions)({ region: "asia-south1" });
admin.initializeApp();
function requireAuth(req, res, next) {
    // Allow CORS preflight to pass through without auth.
    if (req.method === "OPTIONS")
        return next();
    const header = req.header("authorization") ?? "";
    const match = header.match(/^Bearer (.+)$/i);
    if (!match)
        return res.status(401).json({ error: "missing_auth" });
    admin
        .auth()
        .verifyIdToken(match[1])
        .then((decoded) => {
        req.user = decoded;
        next();
    })
        .catch(() => res.status(401).json({ error: "invalid_auth" }));
}
async function requireAdmin(req, res, next) {
    // Allow CORS preflight to pass through without role check.
    if (req.method === "OPTIONS")
        return next();
    if (!req.user?.uid)
        return res.status(401).json({ error: "missing_auth" });
    const snap = await admin.firestore().collection("users").doc(req.user.uid).get();
    const role = snap.data()?.role;
    if (role !== "admin")
        return res.status(403).json({ error: "not_admin" });
    next();
}
function safeUser(doc) {
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
const app = (0, express_1.default)();
app.use((0, cors_1.default)({ origin: true }));
app.use(express_1.default.json());
// All routes below require admin auth
app.use(requireAuth);
app.use(requireAdmin);
// GET /users?role=user|owner|admin
app.get("/users", async (req, res) => {
    const role = typeof req.query.role === "string" ? req.query.role : undefined;
    let q = admin.firestore().collection("users");
    if (role)
        q = q.where("role", "==", role);
    const snap = await q.limit(250).get();
    res.json({ users: snap.docs.map(safeUser) });
});
// GET /owners
app.get("/owners", async (_req, res) => {
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
app.get("/auth-users", async (_req, res) => {
    const db = admin.firestore();
    const out = [];
    let nextPageToken;
    do {
        const page = await admin.auth().listUsers(250, nextPageToken);
        nextPageToken = page.pageToken;
        // Join with Firestore roles (best-effort)
        const joins = await Promise.all(page.users.map(async (u) => {
            const snap = await db.collection("users").doc(u.uid).get();
            const d = snap.data() ?? {};
            return {
                uid: u.uid,
                email: u.email ?? null,
                disabled: u.disabled ?? false,
                createdAt: u.metadata?.creationTime ?? null,
                role: d.role ?? null
            };
        }));
        out.push(...joins);
    } while (nextPageToken && out.length < 1000);
    res.json({ users: out });
});
// PATCH /auth-users/:uid  { disabled?: boolean }
app.patch("/auth-users/:uid", async (req, res) => {
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
app.delete("/auth-users/:uid", async (req, res) => {
    const uidParam = req.params.uid;
    const uid = Array.isArray(uidParam) ? uidParam[0] : uidParam;
    await admin.auth().deleteUser(uid);
    await admin.firestore().collection("users").doc(uid).delete().catch(() => { });
    res.json({ ok: true });
});
// POST /owners  { email, ownerName, shopName, phone }
app.post("/owners", async (req, res) => {
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
    await admin.firestore().collection("users").doc(userRecord.uid).set({
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
    }, { merge: true });
    // NOTE: email sending should happen server-side; keeping it out for now
    // because this repo currently sends email from the client.
    res.json({ uid: userRecord.uid, tempPassword });
});
// PATCH /owners/:uid  { accountSetupStatus?, totalRevenue? }
app.patch("/owners/:uid", async (req, res) => {
    const uidParam = req.params.uid;
    const uid = Array.isArray(uidParam) ? uidParam[0] : uidParam;
    const { accountSetupStatus, totalRevenue } = req.body ?? {};
    const patch = {};
    if (typeof accountSetupStatus === "string")
        patch.accountSetupStatus = accountSetupStatus;
    if (typeof totalRevenue === "number")
        patch.totalRevenue = totalRevenue;
    if (Object.keys(patch).length === 0)
        return res.status(400).json({ error: "no_updates" });
    await admin.firestore().collection("users").doc(uid).set(patch, { merge: true });
    res.json({ ok: true });
});
exports.adminApi = (0, https_1.onRequest)(app);
//# sourceMappingURL=index.js.map