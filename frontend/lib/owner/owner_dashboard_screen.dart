import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'order_history_screen.dart';
import 'earnings_screen.dart';
import 'print_queue_screen.dart';
import 'shop_settings_screen.dart';
import 'services/owner_auth_service.dart';
import '../screens/signin_screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final _service = OwnerAuthService();
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final data = await _service.getOwnerProfile();
    if (mounted) setState(() => _profile = data);
  }

  @override
  Widget build(BuildContext context) {
    final shopName  = _profile?['shopName']  as String? ?? 'Your Shop';
    final ownerName = _profile?['ownerName'] as String? ?? 'Owner';
    final ownerId = _service.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE53935),
        title: Text(shopName,
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await _service.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const SignInScreen()));
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.35),
                    blurRadius: 20, offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.storefront_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome, $ownerName',
                          style: GoogleFonts.poppins(
                              fontSize: 17, fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      Text(shopName,
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.85))),
                    ],
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 28),
            Text('Shop Actions',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E1E1E))),
            const SizedBox(height: 14),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.15,
              children: [
                _OwnerCard(
                  icon: Icons.print_rounded,
                  label: 'Print Queue',
                  color: const Color(0xFFE53935),
                  onTap: () {
                    if (ownerId == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PrintQueueScreen(ownerId: ownerId),
                      ),
                    );
                  },
                ),
                _OwnerCard(
                  icon: Icons.receipt_long_rounded,
                  label: 'Orders',
                  color: const Color(0xFF26A69A),
                  onTap: () {
                    if (ownerId == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderHistoryScreen(ownerId: ownerId),
                      ),
                    );
                  },
                ),
                _OwnerCard(
                  icon: Icons.payments_outlined,
                  label: 'Earnings',
                  color: const Color(0xFFF57C00),
                  onTap: () {
                    if (ownerId == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EarningsScreen(ownerId: ownerId),
                      ),
                    );
                  },
                ),
                _OwnerCard(
                  icon: Icons.settings_rounded,
                  label: 'Shop Settings',
                  color: const Color(0xFF8D6E63),
                  onTap: () {
                    if (ownerId == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ShopSettingsScreen(ownerId: ownerId),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OwnerCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 16, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E1E1E)),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
