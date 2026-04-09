import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/admin_auth_service.dart';
import '../widgets/custom_button.dart';

class AddShopOwnerSheet extends StatefulWidget {
  const AddShopOwnerSheet({super.key});

  @override
  State<AddShopOwnerSheet> createState() => _AddShopOwnerSheetState();
}

class _AddShopOwnerSheetState extends State<AddShopOwnerSheet> {
  final _service       = AdminAuthService();
  final _ownerNameCtrl = TextEditingController();
  final _shopNameCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _phoneCtrl     = TextEditingController();

  bool    _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _ownerNameCtrl.dispose();
    _shopNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String e) =>
      RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(e);

  Future<void> _submit() async {
    final ownerName = _ownerNameCtrl.text.trim();
    final shopName  = _shopNameCtrl.text.trim();
    final email     = _emailCtrl.text.trim();
    final phone     = _phoneCtrl.text.trim();

    if (ownerName.isEmpty || shopName.isEmpty || email.isEmpty || phone.isEmpty) {
      setState(() => _errorMsg = 'Please fill in all fields.');
      return;
    }
    if (!_isValidEmail(email)) {
      setState(() => _errorMsg = 'Enter a valid email address.');
      return;
    }
    if (phone.length < 10) {
      setState(() => _errorMsg = 'Enter a valid phone number.');
      return;
    }

    setState(() { _isLoading = true; _errorMsg = null; });

    await _service.createShopOwner(
      email:     email,
      ownerName: ownerName,
      shopName:  shopName,
      phone:     phone,
      onError: (e) => setState(() { _errorMsg = e; _isLoading = false; }),
      onSuccess: () {
        if (mounted) {
          Navigator.pop(context); // close sheet
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Shop owner created! Credentials sent to $email',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              backgroundColor: Colors.green[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Push sheet up when keyboard appears
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.store_rounded, color: Color(0xFFE53935), size: 20),
                ),
                const SizedBox(width: 12),
                Text('Add Shop Owner',
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E1E1E))),
              ]),
              const SizedBox(height: 6),
              Text(
                'A temporary password will be generated and emailed to the owner.',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),

              // Form fields
              _Field(
                hint: 'Owner Full Name',
                icon: Icons.person_outline_rounded,
                controller: _ownerNameCtrl,
              ),
              const SizedBox(height: 14),
              _Field(
                hint: 'Shop Name',
                icon: Icons.storefront_outlined,
                controller: _shopNameCtrl,
              ),
              const SizedBox(height: 14),
              _Field(
                hint: 'Owner Email',
                icon: Icons.email_outlined,
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              _Field(
                hint: 'Phone Number',
                icon: Icons.phone_outlined,
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 10,
              ),

              // Error
              if (_errorMsg != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: Color(0xFFE53935), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_errorMsg!,
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: const Color(0xFFE53935))),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 24),
              CustomButton(
                label: 'Create & Send Credentials',
                onPressed: _submit,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Reusable inline field widget ─────────────────────────────────────────────
class _Field extends StatelessWidget {
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;

  const _Field({
    required this.hint,
    required this.icon,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400]),
          prefixIcon: Icon(icon, color: const Color(0xFFE53935), size: 20),
          border: InputBorder.none,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
