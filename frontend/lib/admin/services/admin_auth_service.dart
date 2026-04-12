import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../services/email_service.dart';
import 'admin_api_service.dart';

class AdminAuthService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AdminApiService _api = AdminApiService();

  // ─── Create Shop Owner ────────────────────────────────────────────────────
  /// 1. Creates a Firebase Auth account with a temp password.
  /// 2. Saves the owner doc in Firestore with role='owner' and
  ///    mustChangePassword=true.
  /// 3. Emails the owner their login credentials.
  Future<bool> createShopOwner({
    required String email,
    required String ownerName,
    required String shopName,
    required String phone,
    required Function(String error) onError,
    required VoidCallback onSuccess,
  }) async {
    try {
      final created = await _api.createOwner(
        email: email,
        ownerName: ownerName,
        shopName: shopName,
        phone: phone,
      );
      final tempPassword = (created['tempPassword'] as String?) ?? '';
      final uid = (created['uid'] as String?) ?? '';

      // Backfill any missing fields (safe merge)
      if (uid.isNotEmpty) {
        await _db.collection('users').doc(uid).set({
          'uid': uid,
          'email': email,
          'ownerName': ownerName,
          'shopName': shopName,
          'phone': phone,
          'role': 'owner',
          'mustChangePassword': true,
          'accountSetupStatus': 'pending',
          'totalRevenue': 0,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Email credentials to owner
      await EmailService.sendShopOwnerCredentials(
        email:        email,
        ownerName:    ownerName,
        shopName:     shopName,
        tempPassword: tempPassword,
      );

      onSuccess();
      return true;
    } catch (e) {
      onError('Failed to create owner: ${e.toString()}');
      return false;
    }
  }
}
