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
    return _orders
        .where('ownerId', isEqualTo: ownerId)
        .where('status', whereIn: [
          PrintOrderStatus.pending,
          PrintOrderStatus.processing,
        ])
        .orderBy('createdAt')
        .snapshots()
        .map(_mapRecords);
  }

  Stream<List<PrintOrderRecord>> watchOwnerHistory(
    String ownerId, {
    String? status,
  }) {
    Query<Map<String, dynamic>> query =
        _orders.where('ownerId', isEqualTo: ownerId);

    if (status != null && status.isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapRecords);
  }

  Stream<List<PrintOrderRecord>> watchUserOrders(String userId) {
    return _orders
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapRecords);
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
