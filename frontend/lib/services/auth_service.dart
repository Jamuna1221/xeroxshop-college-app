import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'email_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─── Sign In with Email & Password ───────────────────────────────────────
  Future<bool> signInWithEmailPassword({
    required String email,
    required String password,
    required Function(String error) onError,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return true;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          onError('No account found with this email. Please sign up.');
          break;
        case 'wrong-password':
        case 'INVALID_LOGIN_CREDENTIALS':
        case 'invalid-credential':
          onError('Incorrect password. Please try again.');
          break;
        case 'invalid-email':
          onError('Invalid email address.');
          break;
        case 'user-disabled':
          onError('This account has been disabled.');
          break;
        case 'too-many-requests':
          onError('Too many attempts. Please try again later.');
          break;
        default:
          onError('Sign in failed: ${e.message ?? e.code}');
      }
      return false;
    } catch (e) {
      onError('Sign in failed: ${e.toString()}');
      return false;
    }
  }

  // ─── OTP: Send (used in Sign Up) ─────────────────────────────────────────
  Future<void> sendEmailOTP({
    required String email,
    required Function(String error) onError,
    required VoidCallback onCodeSent,
  }) async {
    try {
      final otp = _generateOTP();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('otp_code', otp);
      await prefs.setString('otp_email', email);
      await prefs.setInt(
        'otp_expiry',
        DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch,
      );
      await EmailService.sendOTP(email: email, otp: otp);
      onCodeSent();
    } catch (e) {
      onError('Failed to send OTP: ${e.toString()}');
    }
  }

  // ─── OTP: Verify (used in Sign Up) ───────────────────────────────────────
  Future<bool> verifyEmailOTP({
    required String enteredOTP,
    required Function(String error) onError,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOTP = prefs.getString('otp_code');
      final expiry = prefs.getInt('otp_expiry') ?? 0;

      if (savedOTP == null) {
        onError('No OTP found. Please resend.');
        return false;
      }
      if (DateTime.now().millisecondsSinceEpoch > expiry) {
        onError('OTP expired. Please resend.');
        return false;
      }
      if (enteredOTP.trim() != savedOTP) {
        onError('Invalid OTP. Please try again.');
        return false;
      }

      // Clear OTP after success
      await prefs.remove('otp_code');
      await prefs.remove('otp_expiry');
      await prefs.remove('otp_email');

      return true;
    } catch (e) {
      onError('Verification failed: ${e.toString()}');
      return false;
    }
  }

  // ─── Sign Up with Email + Password (called after OTP verified) ───────────
  Future<bool> signUpWithEmailPassword({
    required String email,
    required String password,
    required String username,
    required String rollNumber,
    required String year,
    required String department,
    required Function(String error) onError,
  }) async {
    try {
      final UserCredential credential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Save display name to Firebase profile
      await credential.user?.updateDisplayName(username);

      // Optional: save extra fields to Firestore
      // await FirebaseFirestore.instance
      //     .collection('users')
      //     .doc(credential.user!.uid)
      //     .set({
      //   'username': username,
      //   'rollNumber': rollNumber,
      //   'year': year,
      //   'department': department,
      //   'email': email,
      // });

      return true;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          onError('An account already exists with this email. Please sign in.');
          break;
        case 'invalid-email':
          onError('Invalid email address.');
          break;
        case 'weak-password':
          onError('Password is too weak. Use at least 6 characters.');
          break;
        default:
          onError('Sign up failed: ${e.message ?? e.code}');
      }
      return false;
    } catch (e) {
      onError('Sign up failed: ${e.toString()}');
      return false;
    }
  }

  // ─── Check Admin Role ─────────────────────────────────────────────────────
  /// Returns true if the currently signed-in user has role == 'admin'
  /// in Firestore (collection: 'users', doc: uid).
  Future<bool> checkIfAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!doc.exists) return false;
      return doc.data()?['role'] == 'admin';
    } catch (_) {
      return false;
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  String _generateOTP() {
    final rand = Random.secure();
    return (100000 + rand.nextInt(900000)).toString();
  }

  User? get currentUser => _auth.currentUser;
  Future<void> signOut() => _auth.signOut();
}
