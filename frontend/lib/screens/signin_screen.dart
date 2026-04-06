import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import 'home_screen.dart';
import 'signup_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _authService = AuthService();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);

  Future<void> _signIn() async {
    if (!_isValidEmail(_emailCtrl.text.trim())) {
      setState(() => _errorMsg = 'Enter a valid email address');
      return;
    }
    if (_passwordCtrl.text.length < 6) {
      setState(() => _errorMsg = 'Password must be at least 6 characters');
      return;
    }

    setState(() { _isLoading = true; _errorMsg = null; });

    final success = await _authService.signInWithEmailPassword(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      onError: (e) => setState(() { _errorMsg = e; _isLoading = false; }),
    );

    if (success && mounted) {
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Column(
            children: [
              FadeInDown(
                duration: const Duration(milliseconds: 600),
                child: Column(children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(
                        color: const Color(0xFFE53935).withOpacity(0.35),
                        blurRadius: 20, offset: const Offset(0, 8),
                      )],
                    ),
                    child: const Icon(Icons.print_rounded, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 20),
                  Text('Welcome Back',
                      style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: const Color(0xFF1E1E1E))),
                  const SizedBox(height: 4),
                  Text('Login to continue',
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500])),
                ]),
              ),
              const SizedBox(height: 40),
              FadeInUp(
                duration: const Duration(milliseconds: 600),
                delay: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 24, offset: const Offset(0, 6),
                    )],
                  ),
                  child: Column(children: [
                    CustomTextField(
                      hint: 'College Email',
                      icon: Icons.email_outlined,
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildPasswordField(),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () {
                          // TODO: implement forgot password
                        },
                        child: Text('Forgot Password?',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(0xFFE53935),
                                fontWeight: FontWeight.w500)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    CustomButton(label: 'Sign In', onPressed: _signIn, isLoading: _isLoading),
                    if (_errorMsg != null) ...[
                      const SizedBox(height: 14),
                      _buildMessage(_errorMsg!, isError: true),
                    ],
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const SignUpScreen())),
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                          children: const [
                            TextSpan(text: "Don't have an account? "),
                            TextSpan(text: 'Sign Up',
                                style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w600)),
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

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: TextField(
        controller: _passwordCtrl,
        obscureText: _obscurePassword,
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Password',
          hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400]),
          prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFFE53935), size: 20),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.grey[400], size: 20,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? const Color(0xFFE53935) : Colors.green, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg,
            style: GoogleFonts.poppins(fontSize: 12,
                color: isError ? const Color(0xFFE53935) : Colors.green))),
      ]),
    );
  }
}