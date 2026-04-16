import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/print_order_models.dart';
import '../services/print_order_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  static const _red = Color(0xFFE53935);
  static const _text = Color(0xFF1A1A2E);

  final _service = PrintOrderService();
  bool _busy = false;
  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ');

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showMessage('Could not open the file.');
    }
  }

  Future<void> _printFile(String url) async {
    await _openUrl(url);
  }

  Future<void> _updateStatus(
    Future<void> Function() action,
    String successMessage,
  ) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      _showMessage(successMessage);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Update failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.poppins(fontSize: 12))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'Order Details',
          style: GoogleFonts.poppins(
            color: _text,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<PrintOrderRecord>(
        stream: _service.watchOrder(widget.orderId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _CenteredMessage(message: snapshot.error.toString());
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final order = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryCard(order: order),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'File',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LabelValue(label: 'File Name', value: order.fileName),
                    _LabelValue(label: 'File Type', value: order.fileType.toUpperCase()),
                    _LabelValue(label: 'File Size', value: order.fileSize),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _ActionButton(
                          label: 'Open PDF',
                          icon: Icons.open_in_new_rounded,
                          onTap: () => _openUrl(order.downloadUrl),
                        ),
                        _ActionButton(
                          label: 'Download',
                          icon: Icons.download_rounded,
                          onTap: () => _openUrl(order.downloadUrl),
                        ),
                        _ActionButton(
                          label: 'Print',
                          icon: Icons.print_rounded,
                          onTap: () => _printFile(order.downloadUrl),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Customer',
                child: Column(
                  children: [
                    _LabelValue(label: 'Name', value: order.userName),
                    _LabelValue(
                      label: 'Email',
                      value: order.userEmail.isEmpty ? 'Not available' : order.userEmail,
                    ),
                    _LabelValue(label: 'Shop', value: order.shopName),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Print Details',
                child: Column(
                  children: [
                    _LabelValue(label: 'Pages', value: order.pages),
                    _LabelValue(label: 'Detected Pages', value: '${order.pageCount}'),
                    _LabelValue(label: 'Copies', value: '${order.copies}'),
                    _LabelValue(label: 'Print Type', value: order.printType),
                    _LabelValue(
                      label: 'Print Side',
                      value: order.doubleSide ? 'Double Side' : 'Single Side',
                    ),
                    _LabelValue(label: 'Layout', value: order.layout),
                    _LabelValue(label: 'Paper Size', value: order.paperSize),
                    _LabelValue(label: 'Per Sheet', value: order.perSheet),
                    _LabelValue(label: 'Margins', value: order.margins),
                    _LabelValue(label: 'Scale', value: order.scale),
                    _LabelValue(label: 'Quality', value: order.quality),
                    _LabelValue(
                      label: 'Extras',
                      value: _buildExtras(order),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Payment',
                child: Column(
                  children: [
                    _LabelValue(label: 'Payment ID', value: order.paymentId),
                    _LabelValue(
                      label: 'Print Cost',
                      value: _currency.format(order.printCost),
                    ),
                    _LabelValue(
                      label: 'Extras Cost',
                      value: _currency.format(order.extrasCost),
                    ),
                    _LabelValue(
                      label: 'Total Amount',
                      value: _currency.format(order.totalAmount),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (order.isPending)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _busy
                        ? null
                        : () => _updateStatus(
                              () => _service.markProcessing(order.id),
                              'Order moved to processing.',
                            ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: Text(
                      _busy ? 'Updating...' : 'Accept / Start Processing',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              if (order.isProcessing)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _busy
                        ? null
                        : () => _updateStatus(
                              () => _service.markCompleted(order.id),
                              'Order marked as completed.',
                            ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: Text(
                      _busy ? 'Updating...' : 'Order Completed',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _buildExtras(PrintOrderRecord order) {
    final extras = <String>[];
    if (order.staple) extras.add('Staple');
    if (order.lamination) extras.add('Lamination');
    if (order.glossy) extras.add('Glossy');
    if (order.spiralBinding) extras.add('Spiral Binding');
    if (order.tapeBinding) extras.add('Tape Binding');
    return extras.isEmpty ? 'None' : extras.join(', ');
  }
}

class _SummaryCard extends StatelessWidget {
  final PrintOrderRecord order;

  const _SummaryCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (order.status) {
      PrintOrderStatus.processing => const Color(0xFFEF6C00),
      PrintOrderStatus.completed => const Color(0xFF2E7D32),
      _ => const Color(0xFFE53935),
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.fileName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A2E),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  order.statusLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            order.createdAt == null
                ? 'Waiting for timestamp'
                : 'Placed on ${DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt!)}',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
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
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LabelValue extends StatelessWidget {
  final String label;
  final String value;

  const _LabelValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A2E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final String message;

  const _CenteredMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 13),
        ),
      ),
    );
  }
}
