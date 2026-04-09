import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'services/owner_auth_service.dart';
import '../widgets/custom_button.dart';
import 'owner_dashboard_screen.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _service = OwnerAuthService();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _errorMsg;

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final newPass = _newPassCtrl.text;
    final confirmPass = _confirmCtrl.text;

    if (newPass.length < 6) {
      setState(() => _errorMsg = 'Password must be at least 6 characters.');
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _errorMsg = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    final success = await _service.updatePasswordAndClearFlag(
      newPassword: newPass,
      onError: (e) => setState(() {
        _errorMsg = e;
        _isLoading = false;
      }),
    );

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, animation, secondaryAnimation) =>
              const OwnerDashboardScreen(),
          transitionsBuilder: (_, anim, secondaryAnimation, child) =>
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Column(
            children: [
              FadeInDown(
                duration: const Duration(milliseconds: 600),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE53935).withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Set New Password',
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'You must change your temporary\npassword before continuing.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[500],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              FadeInUp(
                duration: const Duration(milliseconds: 600),
                delay: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 24,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildPasswordField(
                        controller: _newPassCtrl,
                        hint: 'New Password',
                        obscure: _obscureNew,
                        onToggle: () =>
                            setState(() => _obscureNew = !_obscureNew),
                      ),
                      const SizedBox(height: 16),
                      _buildPasswordField(
                        controller: _confirmCtrl,
                        hint: 'Confirm New Password',
                        obscure: _obscureConfirm,
                        onToggle: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),

                      if (_errorMsg != null) ...[
                        const SizedBox(height: 14),
                        _buildError(_errorMsg!),
                      ],

                      const SizedBox(height: 24),
                      CustomButton(
                        label: 'Set Password & Continue',
                        onPressed: _submit,
                        isLoading: _isLoading,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400]),
          prefixIcon: const Icon(
            Icons.lock_outline_rounded,
            color: Color(0xFFE53935),
            size: 20,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: Colors.grey[400],
              size: 20,
            ),
            onPressed: onToggle,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildError(String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFE53935), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFFE53935),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
