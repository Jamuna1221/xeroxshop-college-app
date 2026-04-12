import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/admin_api_service.dart';

class ManageOwnersPage extends StatefulWidget {
  const ManageOwnersPage({super.key});

  @override
  State<ManageOwnersPage> createState() => _ManageOwnersPageState();
}

class _ManageOwnersPageState extends State<ManageOwnersPage> {
  final _api = AdminApiService();
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _all = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.listOwners();
      if (!mounted) return;
      setState(() {
        _all = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((o) {
      final email = (o['email'] ?? '').toString().toLowerCase();
      final shop = (o['shopName'] ?? '').toString().toLowerCase();
      final owner = (o['ownerName'] ?? '').toString().toLowerCase();
      return email.contains(q) || shop.contains(q) || owner.contains(q);
    }).toList();
  }

  Future<void> _toggleSuspend(Map<String, dynamic> o) async {
    final uid = (o['uid'] ?? '').toString();
    if (uid.isEmpty) return;
    final disabledNow = o['disabled'] == true;
    final targetDisabled = !disabledNow;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(targetDisabled ? 'Suspend owner?' : 'Unsuspend owner?'),
        content: Text(
          targetDisabled
              ? 'This owner will not be able to sign in.'
              : 'This owner will be able to sign in again.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(targetDisabled ? 'Suspend' : 'Unsuspend'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _api.setUserDisabled(uid: uid, disabled: targetDisabled);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(targetDisabled ? 'Owner suspended' : 'Owner unsuspended')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteOwner(Map<String, dynamic> o) async {
    final uid = (o['uid'] ?? '').toString();
    if (uid.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete owner?'),
        content: const Text('This will permanently delete the owner account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _api.deleteUser(uid: uid);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Owner deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Manage Owners',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Search by owner / shop / email',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorState(message: _error!, onRetry: _load)
                    : _OwnersTable(
                        rows: _filtered,
                        onSuspendToggle: _toggleSuspend,
                        onDelete: _deleteOwner,
                      ),
          ),
        ],
      ),
    );
  }
}

class _OwnersTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final ValueChanged<Map<String, dynamic>> onSuspendToggle;
  final ValueChanged<Map<String, dynamic>> onDelete;

  const _OwnersTable({
    required this.rows,
    required this.onSuspendToggle,
    required this.onDelete,
  });

  String _setupLabel(Map<String, dynamic> o) {
    final raw = o['accountSetupStatus'];
    if (raw != null && raw.toString().trim().isNotEmpty) return raw.toString();
    final mustChange = o['mustChangePassword'] == true;
    if (mustChange) return 'Password change pending';
    return '—';
  }

  Color _setupColor(String label) {
    final l = label.toLowerCase();
    if (l.contains('complete') || l.contains('active') || l.contains('done')) {
      return const Color(0xFF2E7D32);
    }
    if (l.contains('pending') || l.contains('progress')) {
      return const Color(0xFFF57C00);
    }
    return const Color(0xFF616161);
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Center(
        child: Text(
          'No owners found.',
          style: GoogleFonts.poppins(color: Colors.grey[600]),
        ),
      );
    }

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 40),
          child: SingleChildScrollView(
            child: DataTable(
              columnSpacing: 22,
              columns: const [
                DataColumn(label: Text('Owner')),
                DataColumn(label: Text('Shop')),
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('Setup Status')),
                DataColumn(label: Text('Total Revenue')),
                DataColumn(label: Text('Actions')),
              ],
              rows: rows.map((o) {
                final label = _setupLabel(o);
                final color = _setupColor(label);
                return DataRow(cells: [
                  DataCell(Text((o['ownerName'] ?? '').toString())),
                  DataCell(Text((o['shopName'] ?? '').toString())),
                  DataCell(Text((o['email'] ?? '').toString())),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: color.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  DataCell(Text((o['totalRevenue'] ?? 0).toString())),
                  DataCell(
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'toggle') onSuspendToggle(o);
                        if (v == 'delete') onDelete(o);
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(o['disabled'] == true ? 'Unsuspend' : 'Suspend'),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40, color: Colors.redAccent),
            const SizedBox(height: 10),
            Text(
              'Failed to load owners',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

