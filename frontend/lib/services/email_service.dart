import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailService {
  // ─── Replace these with your EmailJS credentials ───
  static const _serviceId = 'service_ph8p8uj';    // e.g. service_abc123
  static const _templateId = 'template_vajmq3c';  // e.g. template_xyz456
  static const _publicKey = '__MxvWSCabqgsRSC9';     // e.g. abcDEFghiJKL
  // ────────────────────────────────────────────────────

  static Future<void> sendOTP({
    required String email,
    required String otp,
  }) async {
    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'origin': 'http://localhost',
      },
      body: jsonEncode({
        'service_id': _serviceId,
        'template_id': _templateId,
        'user_id': _publicKey,
        'template_params': {
          'to_email': email,
          'otp_code': otp,
          'app_name': 'Smart Print System',
          'expiry': '5 minutes',
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('EmailJS error: ${response.body}');
    }
  }
}