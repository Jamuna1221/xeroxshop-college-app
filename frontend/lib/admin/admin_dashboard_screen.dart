import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../screens/signin_screen.dart';
import 'add_shop_owner_sheet.dart';
import 'pages/admin_overview_page.dart';
import 'pages/manage_owners_page.dart';
import 'pages/manage_users_page.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selected = 0;

  void _openAddOwnerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddShopOwnerSheet(),
    );
  }

  void _goTo(int idx) => setState(() => _selected = idx);

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final isWide = MediaQuery.of(context).size.width >= 900;

    final pages = <Widget>[
      AdminOverviewPage(
        onAddOwner: _openAddOwnerSheet,
        onManageUsers: () => _goTo(1),
        onManageOwners: () => _goTo(2),
      ),
      const ManageUsersPage(),
      const ManageOwnersPage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE53935),
        title: Text('Admin Dashboard',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const SignInScreen()));
              }
            },
          ),
        ],
      ),
      drawer: isWide ? null : _AdminDrawer(
        selected: _selected,
        email: user?.email ?? '',
        onSelect: (i) {
          Navigator.pop(context);
          _goTo(i);
        },
      ),
      body: Row(
        children: [
          if (isWide)
            _AdminSidebar(
              selected: _selected,
              email: user?.email ?? '',
              onSelect: _goTo,
            ),
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: _WelcomeBanner(email: user?.email ?? ''),
                ),
                const SizedBox(height: 8),
                Expanded(child: pages[_selected]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  final String email;
  const _WelcomeBanner({required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFFEF5350)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE53935).withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, Admin',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  final int selected;
  final String email;
  final ValueChanged<int> onSelect;

  const _AdminSidebar({
    required this.selected,
    required this.email,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: _AdminNav(
        selected: selected,
        email: email,
        onSelect: onSelect,
      ),
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  final int selected;
  final String email;
  final ValueChanged<int> onSelect;

  const _AdminDrawer({
    required this.selected,
    required this.email,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: _AdminNav(selected: selected, email: email, onSelect: onSelect),
      ),
    );
  }
}

class _AdminNav extends StatelessWidget {
  final int selected;
  final String email;
  final ValueChanged<int> onSelect;

  const _AdminNav({
    required this.selected,
    required this.email,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE53935).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded,
                  color: Color(0xFFE53935)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Admin',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  if (email.isNotEmpty)
                    Text(email,
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 10),
        _NavTile(
          selected: selected == 0,
          icon: Icons.dashboard_rounded,
          label: 'Overview',
          onTap: () => onSelect(0),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 8, bottom: 6),
          child: Text(
            'Overview',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ),
        _NavTile(
          selected: selected == 1,
          icon: Icons.people_rounded,
          label: 'Manage Users',
          onTap: () => onSelect(1),
          dense: true,
        ),
        _NavTile(
          selected: selected == 2,
          icon: Icons.supervisor_account_rounded,
          label: 'Manage Owners',
          onTap: () => onSelect(2),
          dense: true,
        ),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool dense;

  const _NavTile({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFFE53935).withValues(alpha: 0.10) : null;
    final fg = selected ? const Color(0xFFE53935) : const Color(0xFF424242);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: dense ? 10 : 12,
          ),
          child: Row(
            children: [
              Icon(icon, color: fg, size: dense ? 18 : 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: dense ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
