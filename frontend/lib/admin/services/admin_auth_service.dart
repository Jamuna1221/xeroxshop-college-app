import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../services/email_service.dart';

class AdminAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
      final tempPassword = _generateTempPassword();

      // Create Firebase Auth account
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: tempPassword,
      );

      // Save owner profile to Firestore
      await _db.collection('users').doc(credential.user!.uid).set({
        'uid':                credential.user!.uid,
        'email':              email,
        'ownerName':          ownerName,
        'shopName':           shopName,
        'phone':              phone,
        'role':               'owner',
        'mustChangePassword': true,
        'createdAt':          FieldValue.serverTimestamp(),
      });

      // Email credentials to owner
      await EmailService.sendShopOwnerCredentials(
        email:        email,
        ownerName:    ownerName,
        shopName:     shopName,
        tempPassword: tempPassword,
      );

      onSuccess();
      return true;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          onError('An account already exists with this email.');
          break;
        case 'invalid-email':
          onError('Invalid email address.');
          break;
        default:
          onError('Failed to create owner: ${e.message ?? e.code}');
      }
      return false;
    } catch (e) {
      onError('Failed to create owner: ${e.toString()}');
      return false;
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  /// Generates a readable temp password: e.g. "Print@4821"
  String _generateTempPassword() {
    const chars = 'abcdefghjkmnpqrstuvwxyz';
    const digits = '0123456789';
    final rand = Random.secure();
    final word = List.generate(5, (_) => chars[rand.nextInt(chars.length)]).join();
    final num  = List.generate(4, (_) => digits[rand.nextInt(digits.length)]).join();
    // Capitalise first letter + add @ to meet most password policies
    return '${word[0].toUpperCase()}${word.substring(1)}@$num';
  }
}
