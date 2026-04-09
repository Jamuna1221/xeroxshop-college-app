import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailService {
  // ─── Replace with your EmailJS credentials ───────────────────────────────
  static const _serviceId  = 'service_ph8p8uj';
  static const _publicKey  = '__MxvWSCabqgsRSC9';

  // Template IDs — create these two templates in your EmailJS dashboard
  static const _otpTemplateId   = 'template_vajmq3c';   // existing OTP template
  static const _ownerTemplateId = 'template_sggm63u'; // new template (see note below)
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> _send({
    required String templateId,
    required Map<String, dynamic> params,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
      headers: {
        'Content-Type': 'application/json',
        'origin': 'http://localhost',
      },
      body: jsonEncode({
        'service_id':  _serviceId,
        'template_id': templateId,
        'user_id':     _publicKey,
        'template_params': params,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('EmailJS error: ${response.body}');
    }
  }

  // ─── Send OTP (Sign Up) ───────────────────────────────────────────────────
  static Future<void> sendOTP({
    required String email,
    required String otp,
  }) =>
      _send(
        templateId: _otpTemplateId,
        params: {
          'to_email': email,
          'otp_code': otp,
          'app_name': 'Smart Print System',
          'expiry':   '5 minutes',
        },
      );

  // ─── Send Shop Owner Credentials ─────────────────────────────────────────
  /// Sends a welcome email to a newly created shop owner with their
  /// temporary login credentials.
  ///
  /// EmailJS template variables used:
  ///   {{to_email}}, {{owner_name}}, {{shop_name}},
  ///   {{temp_password}}, {{app_name}}
  static Future<void> sendShopOwnerCredentials({
    required String email,
    required String ownerName,
    required String shopName,
    required String tempPassword,
  }) =>
      _send(
        templateId: _ownerTemplateId,
        params: {
          'to_email':      email,
          'owner_name':    ownerName,
          'shop_name':     shopName,
          'temp_password': tempPassword,
          'app_name':      'Smart Print System',
        },
      );
}