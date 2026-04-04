import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/otp_input_field.dart';
import 'home_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _authService = AuthService();
  final _usernameCtrl = TextEditingController();
  final _rollCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  String? _selectedYear;
  String? _selectedDept;
  bool _otpSent = false;
  bool _otpVerified = false;
  bool _sendingOtp = false;
  bool _verifyingOtp = false;
  bool _signingUp = false;
  String? _errorMsg;
  String? _successMsg;

  final _years = ['I', 'II', 'III', 'IV'];
  final _departments = ['CSE', 'ECE', 'AIDS', 'IT', 'MECH', 'CIVIL'];

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _rollCtrl.dispose();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);

  Future<void> _sendOTP() async {
    if (!_isValidEmail(_emailCtrl.text.trim())) {
      setState(() => _errorMsg = 'Enter a valid email address');
      return;
    }
    setState(() { _sendingOtp = true; _errorMsg = null; _successMsg = null; });
    await _authService.sendEmailOTP(
      email: _emailCtrl.text.trim(),
      onError: (e) => setState(() { _errorMsg = e; _sendingOtp = false; }),
      onCodeSent: () => setState(() {
        _otpSent = true;
        _sendingOtp = false;
        _successMsg = 'OTP sent to ${_emailCtrl.text.trim()}';
      }),
    );
  }

  Future<void> _verifyOTP() async {
    if (_otpCtrl.text.length < 6) {
      setState(() => _errorMsg = 'Enter the 6-digit OTP');
      return;
    }
    setState(() { _verifyingOtp = true; _errorMsg = null; _successMsg = null; });
    final success = await _authService.verifyEmailOTP(
      enteredOTP: _otpCtrl.text.trim(),
      onError: (e) => setState(() { _errorMsg = e; _verifyingOtp = false; }),
    );
    if (success) {
      setState(() { _otpVerified = true; _verifyingOtp = false; _successMsg = 'Email verified ✓'; });
    }
  }

  Future<void> _signUp() async {
    if (_usernameCtrl.text.isEmpty || _rollCtrl.text.isEmpty ||
        _selectedYear == null || _selectedDept == null) {
      setState(() => _errorMsg = 'Please fill all fields');
      return;
    }
    setState(() { _signingUp = true; _errorMsg = null; });
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            children: [
              FadeInDown(
                duration: const Duration(milliseconds: 600),
                child: Column(children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: const Color(0xFFE53935).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: const Icon(Icons.print_rounded, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text('Create Account', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, color: const Color(0xFF1E1E1E))),
                  Text('Join Smart Print System', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500])),
                ]),
              ),
              const SizedBox(height: 28),
              FadeInUp(
                duration: const Duration(milliseconds: 600),
                delay: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))],
                  ),
                  child: Column(children: [
                    CustomTextField(hint: 'Username', icon: Icons.person_outline_rounded, controller: _usernameCtrl),
                    const SizedBox(height: 14),
                    CustomTextField(hint: 'Roll Number', icon: Icons.badge_outlined, controller: _rollCtrl),
                    const SizedBox(height: 14),
                    _buildDropdown('Select Year', Icons.school_outlined, _years, _selectedYear, (v) => setState(() => _selectedYear = v)),
                    const SizedBox(height: 14),
                    _buildDropdown('Select Department', Icons.apartment_outlined, _departments, _selectedDept, (v) => setState(() => _selectedDept = v)),
                    const SizedBox(height: 14),

                    // Email + Send OTP row
                    Row(children: [
                      Expanded(
                        child: CustomTextField(
                          hint: 'College Email',
                          icon: Icons.email_outlined,
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !_otpSent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      CustomButton(
                        label: _otpSent ? 'Sent ✓' : 'Send\nOTP',
                        onPressed: _otpSent ? null : _sendOTP,
                        isLoading: _sendingOtp,
                        width: 90,
                        color: _otpSent ? Colors.grey[400] : null,
                      ),
                    ]),

                    // OTP field (appears after sending)
                    if (_otpSent) ...[
                      const SizedBox(height: 20),
                      FadeInUp(
                        duration: const Duration(milliseconds: 400),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Enter OTP', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E1E1E))),
                            const SizedBox(height: 4),
                            Text('Check your email inbox', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
                            const SizedBox(height: 12),
                            Center(child: OtpInputField(controller: _otpCtrl)),
                            const SizedBox(height: 14),
                            CustomButton(
                              label: _otpVerified ? '✓ Verified' : 'Verify OTP',
                              onPressed: _otpVerified ? null : _verifyOTP,
                              isLoading: _verifyingOtp,
                              color: _otpVerified ? Colors.green : null,
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_errorMsg != null) ...[const SizedBox(height: 12), _buildMessage(_errorMsg!, isError: true)],
                    if (_successMsg != null) ...[const SizedBox(height: 12), _buildMessage(_successMsg!, isError: false)],

                    const SizedBox(height: 20),
                    CustomButton(label: 'Sign Up', onPressed: _otpVerified ? _signUp : null, isLoading: _signingUp),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                          children: const [
                            TextSpan(text: 'Already have an account? '),
                            TextSpan(text: 'Sign In', style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(String hint, IconData icon, List<String> items, String? value, ValueChanged<String?> onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          hint: Row(children: [
            Icon(icon, color: const Color(0xFFE53935), size: 20),
            const SizedBox(width: 12),
            Text(hint, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400])),
          ]),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFE53935)),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.poppins(fontSize: 14)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildMessage(String msg, {required bool isError}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: isError ? const Color(0xFFE53935) : Colors.green, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: GoogleFonts.poppins(fontSize: 12, color: isError ? const Color(0xFFE53935) : Colors.green))),
      ]),
    );
  }
}