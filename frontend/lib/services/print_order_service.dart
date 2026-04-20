import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/print_order_models.dart';

class PrintOrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('print_orders');

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  static const String _shopOpenKey = 'shopOpen';
  static const String _shopClosedMessageKey = 'shopClosedMessage';
  static const String _outOfStockKey = 'outOfStock';

  // Out-of-stock map keys (match UI options)
  static const String oosColor = 'color';
  static const String oosLamination = 'lamination';
  static const String oosGlossy = 'glossy';
  static const String oosSpiralBinding = 'spiralBinding';
  static const String oosTapeBinding = 'tapeBinding';

  // Supabase Storage config (public bucket + anon uploads).
  // NOTE: this is NOT the service role key.
  static const String _supabaseUrl = 'https://bkfwujraxqpotoehpunz.supabase.co';
  static const String _supabaseAnonKey =
      'sb_publishable_4lDqq4TNfNi7LR4lWJ1VcQ_RRcdc1f0';
  static const String _supabaseBucket = 'print-files';

  Future<Map<String, dynamic>> _getDefaultOwner() async {
    final query = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'owner')
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('No owner account found. Please add a shop owner first.');
    }

    final doc = query.docs.first;
    final data = doc.data();
    return {
      'ownerId': doc.id,
      'ownerName': (data['ownerName'] ?? 'Owner').toString(),
      'shopName': (data['shopName'] ?? 'Print Shop').toString(),
    };
  }

  Stream<Map<String, dynamic>?> watchOwnerShopSettings(String ownerId) {
    return _users.doc(ownerId).snapshots().map((snap) => snap.data());
  }

  Stream<Map<String, dynamic>?> watchDefaultOwnerShopSettings() {
    // Uses the first owner as the "default shop" in this app.
    return _users
        .where('role', isEqualTo: 'owner')
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty ? null : snap.docs.first.data());
  }

  bool _isShopOpen(Map<String, dynamic>? ownerDoc) {
    if (ownerDoc == null) return true;
    final v = ownerDoc[_shopOpenKey];
    if (v is bool) return v;
    return true; // default open
  }

  Map<String, bool> _readOutOfStock(Map<String, dynamic>? ownerDoc) {
    final raw = ownerDoc?[_outOfStockKey];
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v == true));
    }
    return const {};
  }

  String _closedMessage(Map<String, dynamic>? ownerDoc) {
    final raw = ownerDoc?[_shopClosedMessageKey];
    final msg = (raw ?? '').toString().trim();
    return msg.isEmpty ? 'Shop is temporarily closed.' : msg;
  }

  void _enforceShopAvailability({
    required Map<String, dynamic>? ownerDoc,
    required PrintOrderSummary summary,
  }) {
    if (!_isShopOpen(ownerDoc)) {
      throw Exception(_closedMessage(ownerDoc));
    }

    final oos = _readOutOfStock(ownerDoc);

    final isColor = summary.printType == 'Color';
    if (isColor && (oos[oosColor] == true)) {
      throw Exception('Color printing is currently out of stock.');
    }
    if (summary.lamination && (oos[oosLamination] == true)) {
      throw Exception('Lamination is currently out of stock.');
    }
    if (summary.glossy && (oos[oosGlossy] == true)) {
      throw Exception('Glossy paper is currently out of stock.');
    }
    if (summary.spiralBinding && (oos[oosSpiralBinding] == true)) {
      throw Exception('Spiral binding is currently out of stock.');
    }
    if (summary.tapeBinding && (oos[oosTapeBinding] == true)) {
      throw Exception('Tape binding is currently out of stock.');
    }
  }

  Future<Map<String, String>> uploadOrderFile({
    required String userId,
    required String localFilePath,
    required String fileName,
  }) async {
    final file = File(localFilePath);
    if (!await file.exists()) {
      throw Exception('Selected file is no longer available on the device.');
    }

    final sanitizedName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath =
        'print_orders/$userId/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';

    final encodedPath = storagePath
        .split('/')
        .map((s) => Uri.encodeComponent(s))
        .join('/');

    // Upload to Supabase Storage (public bucket write via anon).
    final uploadUrl =
        '$_supabaseUrl/storage/v1/object/$_supabaseBucket/$encodedPath';

    final bytes = await file.readAsBytes();
    final contentType = _guessContentType(sanitizedName);

    final resp = await http.post(
      Uri.parse(uploadUrl),
      headers: {
        // Supabase Storage API expects `apikey` header.
        'apikey': _supabaseAnonKey,
        'Content-Type': contentType,
      },
      body: bytes,
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
        'Supabase upload failed (${resp.statusCode}): ${resp.body}',
      );
    }

    // Public objects can be accessed via the conventional public URL format.
    final downloadUrl =
        '$_supabaseUrl/storage/v1/object/public/$_supabaseBucket/$encodedPath';

    // Supabase returns a JSON like: {"Key":"bucket/path",...} on success.
    // We rely on our known `storagePath` and computed public URL.
    final decoded = jsonDecode(resp.body.isEmpty ? '{}' : resp.body);
    final keyFromServer = (decoded is Map && decoded['Key'] != null)
        ? decoded['Key'].toString()
        : storagePath;

    return {
      'storagePath': keyFromServer,
      'downloadUrl': downloadUrl,
    };
  }

  Future<String> createOrder({
    required PrintOrderSummary summary,
    required int pageCount,
    required double printCost,
    required double extrasCost,
    required double totalAmount,
    required String paymentId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to place an order.');
    }

    final owner = await _getDefaultOwner();
    final ownerDoc = await _users.doc(owner['ownerId'].toString()).get();
    _enforceShopAvailability(ownerDoc: ownerDoc.data(), summary: summary);

    final upload = await uploadOrderFile(
      userId: user.uid,
      localFilePath: summary.filePath,
      fileName: summary.fileName,
    );

    final doc = await _orders.add({
      'userId': user.uid,
      'userName': (user.displayName ?? 'Customer').trim().isEmpty
          ? 'Customer'
          : user.displayName!.trim(),
      'userEmail': user.email ?? '',
      'ownerId': owner['ownerId'],
      'ownerName': owner['ownerName'],
      'shopName': owner['shopName'],
      'fileName': summary.fileName,
      'storagePath': upload['storagePath'],
      'downloadUrl': upload['downloadUrl'],
      'fileType': summary.fileName.split('.').last.toLowerCase(),
      'fileSize': summary.fileSize,
      'pageCount': pageCount,
      'copies': summary.copies,
      'pages': summary.pages,
      'printType': summary.printType,
      'doubleSide': summary.doubleSide,
      'layout': summary.layout,
      'paperSize': summary.paperSize,
      'perSheet': summary.perSheet,
      'margins': summary.margins,
      'scale': summary.scale,
      'quality': summary.quality,
      'staple': summary.staple,
      'lamination': summary.lamination,
      'glossy': summary.glossy,
      'spiralBinding': summary.spiralBinding,
      'tapeBinding': summary.tapeBinding,
      'printCost': printCost,
      'extrasCost': extrasCost,
      'totalAmount': totalAmount,
      'paymentId': paymentId,
      'status': PrintOrderStatus.pending,
      'createdAt': FieldValue.serverTimestamp(),
      'statusUpdatedAt': FieldValue.serverTimestamp(),
      'completedAt': null,
    });

    return doc.id;
  }

  Stream<List<PrintOrderRecord>> watchOwnerQueue(String ownerId) {
    // NOTE: We intentionally avoid compound Firestore queries here to prevent
    // `[cloud_firestore/failed-precondition] The query requires an index`.
    //
    // Also: some environments create orders with an ownerId that doesn't match
    // the currently signed-in owner's UID. To ensure the queue is never empty,
    // we fetch the active queue statuses and filter/sort locally.
    return _orders.snapshots().map((snap) {
      final records = _mapRecords(snap)
          .where((o) =>
              o.status == PrintOrderStatus.pending ||
              o.status == PrintOrderStatus.processing)
          .toList();

      records.sort((a, b) {
        final at = a.createdAt;
        final bt = b.createdAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1; // nulls last
        if (bt == null) return -1;
        return at.compareTo(bt); // oldest first
      });
      return records;
    });
  }

  Stream<List<PrintOrderRecord>> watchOwnerHistory(
    String ownerId, {
    String? status,
  }) {
    // Avoid compound Firestore queries (they require composite indexes).
    // We filter/sort locally so the screen works immediately.
    return _orders.snapshots().map((snap) {
      final all = _mapRecords(snap);

      final filtered = all.where((o) {
        if (status != null && status.isNotEmpty && o.status != status) {
          return false;
        }
        return true;
      }).toList();

      filtered.sort((a, b) {
        final at = a.createdAt;
        final bt = b.createdAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1; // nulls last
        if (bt == null) return -1;
        return bt.compareTo(at); // newest first
      });
      return filtered;
    });
  }

  Stream<List<PrintOrderRecord>> watchOwnerCompletedOrders({
    required String ownerId,
    String? shopName,
  }) {
    // Avoid compound Firestore queries (they require composite indexes).
    // Filter/sort locally so earnings can load immediately.
    return _orders.snapshots().map((snap) {
      final records = _mapRecords(snap)
          .where((o) {
            if (o.status != PrintOrderStatus.completed) return false;
            if (o.ownerId == ownerId) return true;
            final sn = shopName?.trim();
            if (sn != null && sn.isNotEmpty && o.shopName == sn) return true;
            return false;
          })
          .toList();

      records.sort((a, b) {
        final at = a.completedAt ?? a.statusUpdatedAt ?? a.createdAt;
        final bt = b.completedAt ?? b.statusUpdatedAt ?? b.createdAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1; // nulls last
        if (bt == null) return -1;
        return bt.compareTo(at); // newest first
      });
      return records;
    });
  }

  Stream<List<PrintOrderRecord>> watchUserOrders(String userId) {
    // Avoid compound Firestore queries (they require composite indexes).
    // We filter/sort locally so status updates reflect immediately.
    return _orders.where('userId', isEqualTo: userId).snapshots().map((snap) {
      final records = _mapRecords(snap).toList();
      records.sort((a, b) {
        final at = a.createdAt;
        final bt = b.createdAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1; // nulls last
        if (bt == null) return -1;
        return bt.compareTo(at); // newest first
      });
      return records;
    });
  }

  Stream<List<PrintOrderRecord>> watchActiveQueueForShop({
    required String ownerId,
    required String shopName,
  }) {
    // No compound query: filter/sort locally.
    return _orders.snapshots().map((snap) {
      final records = _mapRecords(snap).where((o) {
        final matchShop = (o.ownerId == ownerId) || (o.shopName == shopName);
        if (!matchShop) return false;
        return o.status == PrintOrderStatus.pending ||
            o.status == PrintOrderStatus.processing;
      }).toList();

      records.sort((a, b) {
        final at = a.createdAt;
        final bt = b.createdAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return at.compareTo(bt); // oldest first for queue
      });
      return records;
    });
  }

  Stream<PrintOrderRecord> watchOrder(String orderId) {
    return _orders.doc(orderId).snapshots().map((snapshot) {
      return PrintOrderRecord.fromSnapshot(snapshot);
    });
  }

  Future<void> markProcessing(String orderId) async {
    await _orders.doc(orderId).update({
      'status': PrintOrderStatus.processing,
      'statusUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markCompleted(String orderId) async {
    final doc = await _orders.doc(orderId).get();
    final data = doc.data();
    final ownerId = (data?['ownerId'] ?? '').toString();

    await _orders.doc(orderId).update({
      'status': PrintOrderStatus.completed,
      'statusUpdatedAt': FieldValue.serverTimestamp(),
      'completedAt': FieldValue.serverTimestamp(),
    });

    if (ownerId.isNotEmpty) {
      final ownerRef = _firestore.collection('users').doc(ownerId);
      await _firestore.runTransaction((transaction) async {
        final ownerSnap = await transaction.get(ownerRef);
        final currentRevenue =
            (ownerSnap.data()?['totalRevenue'] as num?)?.toDouble() ?? 0;
        final orderTotal = (data?['totalAmount'] as num?)?.toDouble() ?? 0;
        transaction.update(ownerRef, {
          'totalRevenue': currentRevenue + orderTotal,
        });
      });
    }
  }

  Future<Uint8List> downloadPdfBytes(String url) async {
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
        'Could not download file. (${resp.statusCode})',
      );
    }
    return resp.bodyBytes;
  }

  List<PrintOrderRecord> _mapRecords(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs.map(PrintOrderRecord.fromSnapshot).toList();
  }

  User? get currentUser => _auth.currentUser;

  String _guessContentType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }
}
