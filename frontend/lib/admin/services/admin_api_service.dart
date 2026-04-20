import 'dart:convert';
import 'package:flutter/foundation.dart'
    show kDebugMode, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AdminApiService {
  static const String _projectId = 'xeroxshop-college-app-e4182';
  static const String _region = 'asia-south1';

  // Deployed Cloud Function base:
  // https://asia-south1-xeroxshop-college-app-e4182.cloudfunctions.net/adminApi
  static const String _deployedBaseUrl =
      'https://asia-south1-xeroxshop-college-app-e4182.cloudfunctions.net/adminApi';

  // Local emulator base:
  // http://127.0.0.1:5002/xeroxshop-college-app-e4182/asia-south1/adminApi
  static const String _emulatorHost = '127.0.0.1';
  static const int _emulatorPort = 5002;

  String get _baseUrl {
    // IMPORTANT:
    // - On a physical device, 127.0.0.1 points to the device itself, so the emulator URL will fail.
    // - We only auto-use the emulator for web/desktop.
    // - For Android Emulator, the host machine is reachable at 10.0.2.2 (optional).
    if (kDebugMode) {
      if (kIsWeb) {
        return 'http://$_emulatorHost:$_emulatorPort/$_projectId/$_region/adminApi';
      }
      switch (defaultTargetPlatform) {
        case TargetPlatform.windows:
        case TargetPlatform.macOS:
        case TargetPlatform.linux:
          return 'http://$_emulatorHost:$_emulatorPort/$_projectId/$_region/adminApi';
        case TargetPlatform.android:
        case TargetPlatform.iOS:
        case TargetPlatform.fuchsia:
          // Use deployed function on mobile devices.
          return _deployedBaseUrl;
      }
    }
    return _deployedBaseUrl;
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, String>> _headers() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    final token = await user.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> listUsers({String? role}) async {
    final uri = Uri.parse('$_baseUrl/users').replace(
      queryParameters: role == null ? null : {'role': role},
    );
    final resp = await http.get(uri, headers: await _headers());
    if (resp.statusCode != 200) {
      throw Exception('Failed to load users (${resp.statusCode})');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final list = (json['users'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return list;
  }

  Future<List<Map<String, dynamic>>> listAuthUsers() async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/auth-users'),
      headers: await _headers(),
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to load auth users (${resp.statusCode})');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final list = (json['users'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return list;
  }

  Future<void> setUserDisabled({
    required String uid,
    required bool disabled,
  }) async {
    final resp = await http.patch(
      Uri.parse('$_baseUrl/auth-users/$uid'),
      headers: await _headers(),
      body: jsonEncode({'disabled': disabled}),
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to update user (${resp.statusCode})');
    }
  }

  Future<void> deleteUser({required String uid}) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/auth-users/$uid'),
      headers: await _headers(),
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to delete user (${resp.statusCode})');
    }
  }

  Future<List<Map<String, dynamic>>> listOwners() async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/owners'),
      headers: await _headers(),
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to load owners (${resp.statusCode})');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final list = (json['owners'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return list;
  }

  Future<Map<String, dynamic>> createOwner({
    required String email,
    required String ownerName,
    required String shopName,
    required String phone,
  }) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/owners'),
      headers: await _headers(),
      body: jsonEncode({
        'email': email,
        'ownerName': ownerName,
        'shopName': shopName,
        'phone': phone,
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to create owner (${resp.statusCode})');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<void> patchOwner({
    required String uid,
    String? accountSetupStatus,
    num? totalRevenue,
  }) async {
    final body = <String, dynamic>{};
    if (accountSetupStatus != null) body['accountSetupStatus'] = accountSetupStatus;
    if (totalRevenue != null) body['totalRevenue'] = totalRevenue;

    final resp = await http.patch(
      Uri.parse('$_baseUrl/owners/$uid'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to update owner (${resp.statusCode})');
    }
  }
}

