import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/admin_api_service.dart';

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({super.key});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
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
      // Load from Firebase Auth so users appear even if Firestore profile missing.
      final data = await _api.listAuthUsers();
      if (!mounted) return;
      setState(() {
        _all = data.where((u) {
          final role = (u['role'] ?? 'user').toString();
          return role != 'owner' && role != 'admin';
        }).toList();
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
    return _all.where((u) {
      final email = (u['email'] ?? '').toString().toLowerCase();
      final uid = (u['uid'] ?? '').toString().toLowerCase();
      return email.contains(q) || uid.contains(q);
    }).toList();
  }

  Future<void> _toggleSuspend(Map<String, dynamic> u) async {
    final uid = (u['uid'] ?? '').toString();
    if (uid.isEmpty) return;
    final disabledNow = u['disabled'] == true;
    final targetDisabled = !disabledNow;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(targetDisabled ? 'Suspend user?' : 'Unsuspend user?'),
        content: Text(
          targetDisabled
              ? 'This user will not be able to sign in.'
              : 'This user will be able to sign in again.',
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
        SnackBar(content: Text(targetDisabled ? 'User suspended' : 'User unsuspended')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> u) async {
    final uid = (u['uid'] ?? '').toString();
    if (uid.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete user?'),
        content: const Text('This will permanently delete the account.'),
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
        const SnackBar(content: Text('User deleted')),
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
                'Manage Users',
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
              hintText: 'Search by email or uid',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorState(message: _error!, onRetry: _load)
                    : _UsersTable(
                        rows: _filtered,
                        onSuspendToggle: _toggleSuspend,
                        onDelete: _deleteUser,
                      ),
          ),
        ],
      ),
    );
  }
}

class _UsersTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final ValueChanged<Map<String, dynamic>> onSuspendToggle;
  final ValueChanged<Map<String, dynamic>> onDelete;

  const _UsersTable({
    required this.rows,
    required this.onSuspendToggle,
    required this.onDelete,
  });

  String _statusLabel(Map<String, dynamic> u) =>
      (u['disabled'] == true) ? 'Suspended' : 'Active';

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Center(
        child: Text(
          'No users found.',
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
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('UID')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Created')),
                DataColumn(label: Text('Actions')),
              ],
              rows: rows.map((u) {
                return DataRow(cells: [
                  DataCell(Text((u['email'] ?? '').toString())),
                  DataCell(SelectableText((u['uid'] ?? '').toString())),
                  DataCell(Text(_statusLabel(u))),
                  DataCell(Text((u['createdAt'] ?? '').toString())),
                  DataCell(
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'toggle') onSuspendToggle(u);
                        if (v == 'delete') onDelete(u);
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(u['disabled'] == true ? 'Unsuspend' : 'Suspend'),
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
              'Failed to load users',
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

