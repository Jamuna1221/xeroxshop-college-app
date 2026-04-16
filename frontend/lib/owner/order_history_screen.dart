import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/print_order_models.dart';
import '../services/print_order_service.dart';
import 'order_detail_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  final String ownerId;

  const OrderHistoryScreen({super.key, required this.ownerId});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final service = PrintOrderService();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'Orders',
          style: GoogleFonts.poppins(
            color: const Color(0xFF1A1A2E),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _statusFilter == null,
                  onTap: () => setState(() => _statusFilter = null),
                ),
                _FilterChip(
                  label: 'Pending',
                  selected: _statusFilter == PrintOrderStatus.pending,
                  onTap: () =>
                      setState(() => _statusFilter = PrintOrderStatus.pending),
                ),
                _FilterChip(
                  label: 'Processing',
                  selected: _statusFilter == PrintOrderStatus.processing,
                  onTap: () => setState(
                    () => _statusFilter = PrintOrderStatus.processing,
                  ),
                ),
                _FilterChip(
                  label: 'Completed',
                  selected: _statusFilter == PrintOrderStatus.completed,
                  onTap: () => setState(
                    () => _statusFilter = PrintOrderStatus.completed,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<PrintOrderRecord>>(
              stream: service.watchOwnerHistory(
                widget.ownerId,
                status: _statusFilter,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _HistoryState(message: snapshot.error.toString());
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final orders = snapshot.data!;
                if (orders.isEmpty) {
                  return const _HistoryState(message: 'No orders found.');
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: orders.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return ListTile(
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(
                        order.fileName,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1A2E),
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${order.userName} • ${order.statusLabel} • ${order.totalAmount.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrderDetailScreen(orderId: order.id),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _HistoryState extends StatelessWidget {
  final String message;

  const _HistoryState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
      ),
    );
  }
}
