import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminOverviewPage extends StatelessWidget {
  final VoidCallback onAddOwner;
  final VoidCallback onManageUsers;
  final VoidCallback onManageOwners;

  const AdminOverviewPage({
    super.key,
    required this.onAddOwner,
    required this.onManageUsers,
    required this.onManageOwners,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(
            'Quick Actions',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.15,
            children: [
              _AdminCard(
                icon: Icons.store_rounded,
                label: 'Add Shop Owner',
                color: const Color(0xFF43A047),
                onTap: onAddOwner,
              ),
              _AdminCard(
                icon: Icons.people_rounded,
                label: 'Manage Users',
                color: const Color(0xFF5C6BC0),
                onTap: onManageUsers,
              ),
              _AdminCard(
                icon: Icons.supervisor_account_rounded,
                label: 'Manage Owners',
                color: const Color(0xFF00897B),
                onTap: onManageOwners,
              ),
              _AdminCard(
                icon: Icons.bar_chart_rounded,
                label: 'Reports',
                color: const Color(0xFFF57C00),
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AdminCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E1E1E),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

