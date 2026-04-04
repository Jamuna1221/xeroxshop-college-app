import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'email_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _generateOTP() {
    final rand = Random.secure();
    return (100000 + rand.nextInt(900000)).toString();
  }

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
        DateTime.now()
            .add(const Duration(minutes: 5))
            .millisecondsSinceEpoch,
      );

      await EmailService.sendOTP(email: email, otp: otp);
      onCodeSent();
    } catch (e) {
      onError('Failed to send OTP: ${e.toString()}');
    }
  }

  Future<bool> verifyEmailOTP({
    required String enteredOTP,
    required Function(String error) onError,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOTP = prefs.getString('otp_code');
      final expiry = prefs.getInt('otp_expiry') ?? 0;
      final email = prefs.getString('otp_email') ?? '';

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

      // Clear OTP
      await prefs.remove('otp_code');
      await prefs.remove('otp_expiry');

      // Sign in to Firebase
      await _signInWithEmail(email);
      return true;
    } catch (e) {
      onError('Verification failed: ${e.toString()}');
      return false;
    }
  }

  // ✅ Fixed: no fetchSignInMethodsForEmail
  Future<void> _signInWithEmail(String email) async {
    final password = 'SmartPrint@${email.hashCode}';
    try {
      // First try sign in
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'INVALID_LOGIN_CREDENTIALS') {
        // User doesn't exist → create account
        try {
          await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        } on FirebaseAuthException catch (createError) {
          // If account exists with wrong password, reset it
          if (createError.code == 'email-already-in-use') {
            await _auth.sendPasswordResetEmail(email: email);
          }
          // Silently continue — OTP already verified
        }
      }
      // Any other error → silently continue
    }
  }

  User? get currentUser => _auth.currentUser;
  Future<void> signOut() => _auth.signOut();
}