import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/print_order_models.dart';
import '../services/print_order_service.dart';
import 'upload_print_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedTab = 0;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  final _orderService = PrintOrderService();

  final List<_OrderNotification> _notifications = [];
  final Map<String, String> _knownStatuses = {};
  StreamSubscription<List<PrintOrderRecord>>? _ordersSub;
  bool _didInitialStatusLoad = false;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _startOrderStatusListener();
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _startOrderStatusListener() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    _ordersSub = _orderService.watchUserOrders(userId).listen((orders) {
      final latest = <String, String>{for (final o in orders) o.id: o.status};

      if (!_didInitialStatusLoad) {
        _knownStatuses
          ..clear()
          ..addAll(latest);
        _didInitialStatusLoad = true;
        return;
      }

      for (final order in orders) {
        final prev = _knownStatuses[order.id];
        if (prev == null || prev == order.status) continue;

        if (order.status == PrintOrderStatus.processing ||
            order.status == PrintOrderStatus.completed) {
          _notifications.insert(
            0,
            _OrderNotification(
              title: order.status == PrintOrderStatus.processing
                  ? 'Order started processing'
                  : 'Order completed',
              body: '${order.fileName} is now ${order.statusLabel.toLowerCase()}.',
              createdAt: DateTime.now(),
            ),
          );
        }
      }

      _knownStatuses
        ..clear()
        ..addAll(latest);

      if (mounted) setState(() {});
    });
  }

  int get _unreadCount => _notifications.where((n) => !n.read).length;

  void _openNotificationsSheet() {
    setState(() {
      for (final n in _notifications) {
        n.read = true;
      }
    });

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                child: Row(
                  children: [
                    Text(
                      'Notifications',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A2E),
                      ),
                    ),
                    const Spacer(),
                    if (_notifications.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(_notifications.clear),
                        child: Text(
                          'Clear',
                          style: GoogleFonts.poppins(color: const Color(0xFFE53935)),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _notifications.isEmpty
                    ? Center(
                        child: Text(
                          'No notifications yet.',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notifications.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final n = _notifications[i];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F7FB),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n.title,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1A1A2E),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  n.body,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatRelative(n.createdAt),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _goToUpload() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UploadPrintScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: IndexedStack(
          index: _selectedTab,
          children: [
            _buildHomeTab(),
            _buildOrdersTab(),
            const SizedBox.shrink(),
            _buildProfileTab(),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFE53935),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.print_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Text(
            'Smart Print',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF1A1A2E),
                size: 26,
              ),
              onPressed: _openNotificationsSheet,
            ),
            if (_unreadCount > 0)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE53935),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _unreadCount > 9 ? '9+' : '$_unreadCount',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () => setState(() => _selectedTab = 3),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_rounded, color: Color(0xFFE53935), size: 22),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeSection(),
          _buildUploadCard(),
          _buildQuickOptions(),
          _buildRecentOrdersSection(limit: 5, showHeader: true),
        ],
      ),
    );
  }

  Widget _buildOrdersTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100),
      child: _buildRecentOrdersSection(limit: null, showHeader: false),
    );
  }

  Widget _buildProfileTab() {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;

    if (userId == null) {
      return Center(
        child: Text(
          'Please sign in.',
          style: GoogleFonts.poppins(color: Colors.grey[700]),
        ),
      );
    }
    final safeUser = user!;

    return StreamBuilder<List<PrintOrderRecord>>(
      stream: _orderService.watchUserOrders(userId),
      builder: (context, snapshot) {
        final orders = snapshot.data ?? const <PrintOrderRecord>[];
        final totalSpent = orders.fold<double>(0, (acc, o) => acc + o.totalAmount);
        final completed = orders.where((o) => o.isCompleted).length;
        final processing = orders.where((o) => o.isProcessing).length;
        final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ');
        final displayName = safeUser.displayName?.trim();
        final safeName =
            (displayName == null || displayName.isEmpty) ? 'User' : displayName;
        final safeEmail = safeUser.email ?? 'No email';
        final safeUid = safeUser.uid;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.person_rounded, color: Color(0xFFE53935)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          safeName,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          safeEmail,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _profileCard(
              title: 'Spendings',
              value: currency.format(totalSpent),
              subtitle: 'Total spent on all your print orders',
            ),
            const SizedBox(height: 10),
            _profileCard(
              title: 'Total Orders',
              value: '${orders.length}',
              subtitle: '$completed completed • $processing processing',
            ),
            const SizedBox(height: 10),
            _profileCard(
              title: 'Account ID',
              value: safeUid,
              subtitle: 'Your Firebase account identifier',
            ),
          ],
        );
      },
    );
  }

  Widget _profileCard({
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final userName = FirebaseAuth.instance.currentUser?.displayName?.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A2E),
              ),
              children: [
                const TextSpan(text: 'Welcome Back, '),
                TextSpan(
                  text: '${(userName == null || userName.isEmpty) ? 'User' : userName} 👋',
                  style: const TextStyle(color: Color(0xFFE53935)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'What would you like to print today?',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GestureDetector(
        onTap: _goToUpload,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE53935), Color(0xFFEF5350)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE53935).withValues(alpha: 0.38),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.upload_file_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Upload Document',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PDF, Image, Word Docs',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.description_rounded, color: Colors.white.withValues(alpha: 0.3), size: 78),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickOptions() {
    final options = [
      {'icon': Icons.print_rounded, 'label': 'B&W Print', 'color': const Color(0xFF37474F)},
      {'icon': Icons.color_lens_rounded, 'label': 'Color Print', 'color': const Color(0xFF1E88E5)},
      {'icon': Icons.content_copy_rounded, 'label': 'Multiple Copies', 'color': const Color(0xFF43A047)},
      {'icon': Icons.tune_rounded, 'label': 'Custom Print', 'color': const Color(0xFFE53935)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quick Options',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
              GestureDetector(
                onTap: _goToUpload,
                child: Text(
                  'See all',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFFE53935),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: options.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.55,
            ),
            itemBuilder: (context, i) {
              final opt = options[i];
              final color = opt['color'] as Color;
              return GestureDetector(
                onTap: _goToUpload,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(opt['icon'] as IconData, color: color, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          opt['label'] as String,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentOrdersSection({int? limit, required bool showHeader}) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Orders',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A2E),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _selectedTab = 1),
                  child: Text(
                    'View All',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFFE53935),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text(
              'My Orders',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A2E),
              ),
            ),
          ),
        if (userId == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Sign in to view your orders.',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
            ),
          )
        else
          StreamBuilder<List<PrintOrderRecord>>(
            stream: _orderService.watchUserOrders(userId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    snapshot.error.toString(),
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.red[400]),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final src = snapshot.data!;
              final orders = limit == null ? src : src.take(limit).toList();
              if (orders.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'No orders yet. Upload a file to create your first print request.',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final order = orders[i];
                  final statusColor = _statusColor(order.status);
                  final bgColor = statusColor.withValues(alpha: 0.12);
                  final icon = _statusIcon(order.status);
                  final time = order.createdAt == null
                      ? 'Just now'
                      : _formatRelative(order.createdAt!);

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFE53935), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1A1A2E),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    '${order.pageCount} pages',
                                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('•', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      time,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, color: statusColor, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                order.statusLabel,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case PrintOrderStatus.completed:
        return const Color(0xFF43A047);
      case PrintOrderStatus.processing:
        return const Color(0xFFFF6F00);
      default:
        return const Color(0xFFE53935);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case PrintOrderStatus.completed:
        return Icons.check_circle_rounded;
      case PrintOrderStatus.processing:
        return Icons.autorenew_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  String _formatRelative(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} hrs ago';
    return '${diff.inDays} days ago';
  }

  Widget _buildFAB() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFFEF5350)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE53935).withValues(alpha: 0.45),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: _goToUpload,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildBottomNav() {
    final tabs = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.receipt_long_rounded, 'label': 'Orders'},
      {'icon': Icons.upload_rounded, 'label': 'Upload'},
      {'icon': Icons.person_rounded, 'label': 'Profile'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: List.generate(tabs.length, (i) {
              if (i == 2) return const Expanded(child: SizedBox());
              final isSelected = _selectedTab == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTab = i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFFFEBEE) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          tabs[i]['icon'] as IconData,
                          color: isSelected ? const Color(0xFFE53935) : Colors.grey[400],
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tabs[i]['label'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? const Color(0xFFE53935) : Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _OrderNotification {
  final String title;
  final String body;
  final DateTime createdAt;
  bool read = false;

  _OrderNotification({
    required this.title,
    required this.body,
    required this.createdAt,
  });
}

