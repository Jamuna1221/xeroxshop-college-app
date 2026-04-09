import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OwnerAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── First-Login Check ────────────────────────────────────────────────────
  /// Returns true if the owner still has the temp password (must change it).
  Future<bool> isFirstLogin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      final doc = await _db.collection('users').doc(user.uid).get();
      return doc.data()?['mustChangePassword'] == true;
    } catch (_) {
      return false;
    }
  }

  // ─── Update Password & Clear Flag ────────────────────────────────────────
  /// Updates the Firebase Auth password and flips mustChangePassword → false.
  Future<bool> updatePasswordAndClearFlag({
    required String newPassword,
    required Function(String error) onError,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        onError('No user is signed in.');
        return false;
      }
      await user.updatePassword(newPassword);
      await _db.collection('users').doc(user.uid).update({
        'mustChangePassword': false,
      });
      return true;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'weak-password':
          onError('Password is too weak. Use at least 6 characters.');
          break;
        case 'requires-recent-login':
          onError('Session expired. Please sign in again.');
          break;
        default:
          onError('Failed to update password: ${e.message ?? e.code}');
      }
      return false;
    } catch (e) {
      onError('Failed to update password: ${e.toString()}');
      return false;
    }
  }

  // ─── Get Owner Profile ────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getOwnerProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      final doc = await _db.collection('users').doc(user.uid).get();
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  User? get currentUser => _auth.currentUser;
  Future<void> signOut() => _auth.signOut();
}