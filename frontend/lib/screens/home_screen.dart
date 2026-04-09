import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedTab = 0;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
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
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeSection(),
              _buildUploadCard(),
              _buildQuickOptions(),
              _buildNearbyShops(),
              _buildRecentOrders(),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 2,
      shadowColor: Colors.black.withOpacity(0.08),
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
              icon: const Icon(Icons.notifications_none_rounded,
                  color: Color(0xFF1A1A2E), size: 26),
              onPressed: () {},
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFE53935),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_rounded,
                  color: Color(0xFFE53935), size: 22),
            ),
          ),
        ),
      ],
    );
  }

  // ── Welcome Section ────────────────────────────────────────────────────────
  Widget _buildWelcomeSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E)),
              children: const [
                TextSpan(text: 'Welcome Back, '),
                TextSpan(
                  text: 'Alex 👋',
                  style: TextStyle(color: Color(0xFFE53935)),
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

  // ── Upload Card ────────────────────────────────────────────────────────────
  Widget _buildUploadCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
              color: const Color(0xFFE53935).withOpacity(0.38),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: 30,
              bottom: -30,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  // Left content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.upload_file_rounded,
                              color: Colors.white, size: 28),
                        ),
                        const SizedBox(height: 14),
                        Text('Upload Document',
                            style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('PDF, Image, Word Docs',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8))),
                        const SizedBox(height: 18),
                        GestureDetector(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 11),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              'Upload Now',
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFE53935)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Right illustration
                  Column(
                    children: [
                      const SizedBox(height: 10),
                      Icon(Icons.description_rounded,
                          color: Colors.white.withOpacity(0.3), size: 80),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Quick Options ──────────────────────────────────────────────────────────
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
              Text('Quick Options',
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E))),
              Text('See all',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFFE53935),
                      fontWeight: FontWeight.w500)),
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
                onTap: () {},
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
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
                          color: color.withOpacity(0.1),
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
                              color: const Color(0xFF1A1A2E)),
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

  // ── Nearby Shops ───────────────────────────────────────────────────────────
  Widget _buildNearbyShops() {
    final shops = [
      {'name': 'PrintZone', 'dist': '0.3 km', 'rating': '4.8', 'open': true},
      {'name': 'QuickPrint', 'dist': '0.7 km', 'rating': '4.5', 'open': true},
      {'name': 'XeroxHub', 'dist': '1.2 km', 'rating': '4.2', 'open': false},
      {'name': 'FastCopy', 'dist': '1.8 km', 'rating': '4.6', 'open': true},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Nearby Shops',
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E))),
              Text('View Map',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFFE53935),
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        SizedBox(
          height: 148,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: shops.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final shop = shops[i];
              final isOpen = shop['open'] as bool;
              return Container(
                width: 160,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.store_rounded,
                              color: Color(0xFFE53935), size: 18),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: isOpen
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFFCE4EC),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isOpen ? 'Open' : 'Closed',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: isOpen ? Colors.green : const Color(0xFFE53935),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(shop['name'] as String,
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1A2E))),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            color: Colors.grey[400], size: 12),
                        const SizedBox(width: 2),
                        Text(shop['dist'] as String,
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: Colors.grey[500])),
                        const SizedBox(width: 8),
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFFFC107), size: 12),
                        const SizedBox(width: 2),
                        Text(shop['rating'] as String,
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: isOpen ? () {} : null,
                        style: TextButton.styleFrom(
                          backgroundColor: isOpen
                              ? const Color(0xFFE53935)
                              : Colors.grey[200],
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Select',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isOpen ? Colors.white : Colors.grey[400],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Recent Orders ──────────────────────────────────────────────────────────
  Widget _buildRecentOrders() {
    final orders = [
      {
        'file': 'Assignment_Final.pdf',
        'status': 'Completed',
        'statusColor': const Color(0xFF43A047),
        'bgColor': const Color(0xFFE8F5E9),
        'icon': Icons.check_circle_rounded,
        'time': '2 hrs ago',
        'pages': '12 pages',
      },
      {
        'file': 'Notes_Chapter5.docx',
        'status': 'Printing',
        'statusColor': const Color(0xFFFF6F00),
        'bgColor': const Color(0xFFFFF3E0),
        'icon': Icons.autorenew_rounded,
        'time': '10 min ago',
        'pages': '8 pages',
      },
      {
        'file': 'Lab_Report.pdf',
        'status': 'Pending',
        'statusColor': const Color(0xFFE53935),
        'bgColor': const Color(0xFFFFEBEE),
        'icon': Icons.schedule_rounded,
        'time': 'Just now',
        'pages': '5 pages',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Orders',
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E))),
              Text('View All',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFFE53935),
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final order = orders[i];
            final statusColor = order['statusColor'] as Color;
            final bgColor = order['bgColor'] as Color;
            final icon = order['icon'] as IconData;

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // File icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded,
                        color: Color(0xFFE53935), size: 22),
                  ),
                  const SizedBox(width: 12),
                  // File info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order['file'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1A1A2E))),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(order['pages'] as String,
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: Colors.grey[500])),
                            const SizedBox(width: 8),
                            Text('•',
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 11)),
                            const SizedBox(width: 8),
                            Text(order['time'] as String,
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: Colors.grey[500])),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: statusColor, size: 12),
                        const SizedBox(width: 4),
                        Text(order['status'] as String,
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: statusColor)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────
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
            color: const Color(0xFFE53935).withOpacity(0.45),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  // ── Bottom Nav ─────────────────────────────────────────────────────────────
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
            color: Colors.black.withOpacity(0.08),
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
              // Leave center space for FAB
              if (i == 2) {
                return const Expanded(child: SizedBox());
              }
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
                          color: isSelected
                              ? const Color(0xFFFFEBEE)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          tabs[i]['icon'] as IconData,
                          color: isSelected
                              ? const Color(0xFFE53935)
                              : Colors.grey[400],
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tabs[i]['label'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? const Color(0xFFE53935)
                              : Colors.grey[400],
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