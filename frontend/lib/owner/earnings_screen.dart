import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/print_order_models.dart';
import '../services/print_order_service.dart';
import 'order_detail_screen.dart';

class EarningsScreen extends StatelessWidget {
  final String ownerId;

  const EarningsScreen({super.key, required this.ownerId});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ');
    final service = PrintOrderService();
    final ownerRef = FirebaseFirestore.instance.collection('users').doc(ownerId);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'Earnings',
          style: GoogleFonts.poppins(
            color: const Color(0xFF1A1A2E),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ownerRef.snapshots(),
        builder: (context, ownerSnap) {
          final ownerData = ownerSnap.data?.data();
          final shopName = (ownerData?['shopName'] ?? '').toString().trim();
          final storedTotalRevenue =
              (ownerData?['totalRevenue'] as num?)?.toDouble() ?? 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              StreamBuilder<List<PrintOrderRecord>>(
                stream: service.watchOwnerCompletedOrders(
                  ownerId: ownerId,
                  shopName: shopName.isEmpty ? null : shopName,
                ),
                builder: (context, completedSnap) {
                  final completed = completedSnap.data ?? const <PrintOrderRecord>[];
                  final computedTotal = completed.fold<double>(
                    0,
                    (acc, o) => acc + o.totalAmount,
                  );

                  final showTotal =
                      computedTotal > 0 ? computedTotal : storedTotalRevenue;

                  return _RevenueCard(
                    totalRevenue: showTotal,
                    currency: currency,
                    loading: (ownerSnap.connectionState == ConnectionState.waiting &&
                            !ownerSnap.hasData) ||
                        (completedSnap.connectionState == ConnectionState.waiting &&
                            !completedSnap.hasData),
                    helper: computedTotal > 0 &&
                            storedTotalRevenue > 0 &&
                            (computedTotal - storedTotalRevenue).abs() > 0.01
                        ? 'Showing computed total (data mismatch)'
                        : null,
                  );
                },
              ),
              const SizedBox(height: 14),
              Text(
                'Completed Orders',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 10),
              StreamBuilder<List<PrintOrderRecord>>(
                stream: service.watchOwnerCompletedOrders(
                  ownerId: ownerId,
                  shopName: shopName.isEmpty ? null : shopName,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _StateCard(message: snapshot.error.toString());
                  }
                  if (!snapshot.hasData) {
                    return const _StateCard(message: 'Loading completed orders...');
                  }

                  final orders = snapshot.data!;
                  if (orders.isEmpty) {
                    return const _StateCard(
                      message: 'No completed orders yet.',
                    );
                  }

                  return Column(
                    children: orders.map((o) {
                      final when = o.completedAt ?? o.statusUpdatedAt ?? o.createdAt;
                      final whenLabel = when == null
                          ? '—'
                          : DateFormat('dd MMM yyyy, hh:mm a').format(when);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          tileColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          contentPadding: const EdgeInsets.all(14),
                          title: Text(
                            o.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1A2E),
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${o.userName} • $whenLabel',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                currency.format(o.totalAmount),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2E7D32),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Open',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderDetailScreen(orderId: o.id),
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  final double totalRevenue;
  final NumberFormat currency;
  final bool loading;
  final String? helper;

  const _RevenueCard({
    required this.totalRevenue,
    required this.currency,
    required this.loading,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF57C00).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.payments_rounded,
              color: Color(0xFFF57C00),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Revenue',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  loading ? 'Loading…' : currency.format(totalRevenue),
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A1A2E),
                  ),
                ),
                if (helper != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    helper!,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.trending_up_rounded, color: Color(0xFF2E7D32)),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final String message;
  const _StateCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
      ),
    );
  }
}

