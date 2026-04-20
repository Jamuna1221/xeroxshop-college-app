// payment_screen.dart
//
// Dependencies to add in pubspec.yaml:
// ─────────────────────────────────────
//   syncfusion_flutter_pdf: ^25.1.35      # PDF page count
//   razorpay_flutter: ^1.3.6              # Payment gateway
//   cloud_firestore: ^4.17.0             # Firestore order save
//   firebase_storage: ^11.7.0            # (already used in upload)
//   google_fonts: ^6.2.1                 # (already in your project)
//   intl: ^0.19.0                        # Currency formatting
//
// AndroidManifest.xml — add inside <application>:
//   <activity android:name="com.razorpay.CheckoutActivity"
//             android:theme="@style/Theme.AppCompat.Light.NoActionBar"
//             android:configChanges="keyboard|keyboardHidden|orientation|screenSize"/>
//
// iOS Info.plist — add:
//   <key>LSApplicationQueriesSchemes</key>
//   <array><string>upi</string><string>phonepe</string><string>gpay</string></array>

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:intl/intl.dart';
import '../models/print_order_models.dart';
import '../services/print_order_service.dart';

// ── Pricing constants (₹) ─────────────────────────────────────────────────────
const double kPricePerPageBW    = 1.0;
const double kPricePerPageColor = 3.0;
const double kLaminationFee     = 10.0;
const double kGlossyFee         = 5.0;
const double kSpiralBindingFee  = 30.0;
const double kTapeBindingFee    = 30.0;

// ── Screen ────────────────────────────────────────────────────────────────────
class PaymentScreen extends StatefulWidget {
  final PrintOrderSummary order;
  const PaymentScreen({super.key, required this.order});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const _red      = Color(0xFFE53935);
  static const _redLight = Color(0xFFFFEBEE);
  static const _bg       = Color(0xFFF6F7FB);
  static const _text     = Color(0xFF1A1A2E);
  static const _green    = Color(0xFF43A047);

  // State
  bool _analyzingPDF  = true;
  int  _pageCount     = 0;
  String? _error;

  // Bill breakdown
  double _printCost    = 0;
  double _extrasCost   = 0;
  double _total        = 0;

  late Razorpay _razorpay;
  bool _paymentLoading = false;
  bool _paymentSuccess = false;
  String? _orderId;
  final _orderService = PrintOrderService();

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  void initState() {
    super.initState();
    _initRazorpay();
    _analyzePDF();
  }

  // ── Razorpay ────────────────────────────────────────────────────────────────
  void _initRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,   _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final orderId = await _orderService.createOrder(
        summary: widget.order,
        pageCount: _pageCount,
        printCost: _printCost,
        extrasCost: _extrasCost,
        totalAmount: _total,
        paymentId: response.paymentId ?? 'N/A',
      );
      if (!mounted) return;
      setState(() {
        _paymentLoading = false;
        _paymentSuccess = true;
        _orderId = orderId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _paymentLoading = false);
      _showBanner('Could not save order: $e', _red);
      return;
    }

    if (!mounted) return;
    _showBanner(
      '✅ Payment successful! Order placed.',
      _green,
    );
  }

  void _onPaymentError(PaymentFailureResponse response) {
    setState(() => _paymentLoading = false);
    _showBanner(
      'Payment failed: ${response.message ?? 'Unknown error'}',
      _red,
    );
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    _showBanner('External wallet: ${response.walletName}', Colors.orange);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  // ── PDF Analysis ─────────────────────────────────────────────────────────────
  Future<void> _analyzePDF() async {
    try {
      int pages = 0;
      final ext = widget.order.filePath.split('.').last.toLowerCase();

      if (ext == 'pdf') {
        final bytes = await File(widget.order.filePath).readAsBytes();
        final doc = PdfDocument(inputBytes: bytes);
        pages = doc.pages.count;
        doc.dispose();
      } else {
        // For images / DOCX / PPTX — treat as 1 page per file
        // In production, convert to PDF first via a Cloud Function or
        // use a server-side solution to get the real page count.
        pages = 1;
      }

      // Adjust for "per sheet" setting
      final perSheet = int.tryParse(widget.order.perSheet) ?? 1;
      final physicalPages = (pages / perSheet).ceil();

      // Adjust for page selection
      int printablePages = physicalPages;
      if (widget.order.pages == 'Odd Pages Only' ||
          widget.order.pages == 'Even Pages Only') {
        printablePages = (physicalPages / 2).ceil();
      }

      // Double side halves physical sheets
      int sheets = printablePages;
      if (widget.order.doubleSide) {
        sheets = (printablePages / 2).ceil();
      }

      final pricePerPage = widget.order.printType == 'Color'
          ? kPricePerPageColor
          : kPricePerPageBW;

      final printCost = sheets * pricePerPage * widget.order.copies;

      double extras = 0;
      if (widget.order.lamination)    extras += kLaminationFee;
      if (widget.order.glossy)        extras += kGlossyFee;
      if (widget.order.spiralBinding) extras += kSpiralBindingFee;
      if (widget.order.tapeBinding)   extras += kTapeBindingFee;

      setState(() {
        _pageCount   = pages;
        _printCost   = printCost;
        _extrasCost  = extras;
        _total       = printCost + extras;
        _analyzingPDF = false;
      });
    } catch (e) {
      setState(() {
        _error        = 'Could not read file: $e';
        _analyzingPDF = false;
      });
    }
  }

  // ── Razorpay Checkout ────────────────────────────────────────────────────────
  void _startPayment() {
    setState(() => _paymentLoading = true);

    // Razorpay amount is in paise (₹1 = 100 paise)
    final amountInPaise = (_total * 100).toInt();

    final options = <String, dynamic>{
      'key'         : 'rzp_test_RHXfjs5k6Sq6ua', // ← Replace with your Razorpay key
      'amount'      : amountInPaise,
      'name'        : 'XeroxShop',
      'description' : 'Print Job — ${widget.order.fileName}',
      'currency'    : 'INR',
      'prefill'     : {
        'contact': '', // pre-fill from user profile if available
        'email'  : _orderService.currentUser?.email ?? '',
      },
      'theme'       : {'color': '#E53935'},
    };

    try {
      _razorpay.open(options);
    } on PlatformException catch (e) {
      setState(() => _paymentLoading = false);
      _showBanner('Error: ${e.message}', _red);
    }
  }

  void _showBanner(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: _analyzingPDF
          ? _buildLoading()
          : _error != null
          ? _buildError()
          : _paymentSuccess
          ? _buildSuccessView()
          : _buildContent(),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    scrolledUnderElevation: 2,
    shadowColor: Colors.black.withValues(alpha: 0.08),
    automaticallyImplyLeading: true,
    iconTheme: const IconThemeData(color: _text),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Order Summary',
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w700, color: _text)),
        Text('Review and pay for your print job',
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
      ],
    ),
  );

  Widget _buildLoading() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: _red, strokeWidth: 3),
        const SizedBox(height: 20),
        Text('Analyzing document…',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
        const SizedBox(height: 6),
        Text('Counting pages and calculating cost',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400])),
      ],
    ),
  );

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text('Failed to analyze file',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _text)),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600])),
        ],
      ),
    ),
  );

  Widget _buildSuccessView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(Icons.check_circle_rounded, color: _green, size: 48),
          ),
          const SizedBox(height: 24),
          Text('Order Placed! 🎉',
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.w700, color: _text)),
          const SizedBox(height: 8),
          Text('Your print job has been submitted successfully.\nYou will receive a confirmation email shortly.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 18),
          if (_orderId != null)
            _QueuePositionCard(orderId: _orderId!, service: _orderService),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text('Back to Home',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFileCard(),
          const SizedBox(height: 12),
          _buildPrintDetailsCard(),
          const SizedBox(height: 12),
          _buildBillCard(),
          const SizedBox(height:20),
          _buildPayButton(),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Powered by Razorpay  •  Secure 256-bit SSL',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }

  // ── File Info Card ────────────────────────────────────────────────────────────
  Widget _buildFileCard() => _card(
    child: Row(
      children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
              color: _redLight, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.picture_as_pdf_rounded, color: _red, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.order.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600, color: _text)),
              Text('${widget.order.fileSize}  •  $_pageCount pages detected',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
        ),
      ],
    ),
  );

  // ── Print Details Card ────────────────────────────────────────────────────────
  Widget _buildPrintDetailsCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.settings_rounded, 'Print Details'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(widget.order.printType),
            _chip(widget.order.doubleSide ? 'Double Side' : 'Single Side'),
            _chip(widget.order.paperSize),
            _chip(widget.order.layout),
            _chip('${widget.order.copies} ${widget.order.copies == 1 ? 'Copy' : 'Copies'}'),
            _chip('${widget.order.perSheet}/Sheet'),
            _chip(widget.order.quality),
            if (widget.order.staple)        _chip('Staple', accent: true),
            if (widget.order.lamination)    _chip('Lamination', accent: true),
            if (widget.order.glossy)        _chip('Glossy Paper', accent: true),
            if (widget.order.spiralBinding) _chip('Spiral Binding', accent: true),
            if (widget.order.tapeBinding)   _chip('Tape Binding', accent: true),
          ],
        ),
      ],
    ),
  );

  // ── Bill Card ─────────────────────────────────────────────────────────────────
  Widget _buildBillCard() {
    final pricePerPage = widget.order.printType == 'Color'
        ? kPricePerPageColor
        : kPricePerPageBW;

    final perSheet   = int.tryParse(widget.order.perSheet) ?? 1;
    final adjustedPages = (widget.order.pages == 'Odd Pages Only' ||
        widget.order.pages == 'Even Pages Only')
        ? (_pageCount / 2).ceil()
        : _pageCount;
    final physicalSheets = widget.order.doubleSide
        ? ((adjustedPages / perSheet) / 2).ceil()
        : (adjustedPages / perSheet).ceil();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.receipt_long_rounded, 'Bill Breakdown'),
          const SizedBox(height: 14),

          // Print cost
          _billRow(
            label:
            'Print Cost  ($physicalSheets sheets × ${widget.order.copies} ${widget.order.copies == 1 ? "copy" : "copies"} × ₹${pricePerPage.toStringAsFixed(0)}/sheet)',
            amount: _printCost,
          ),

          // Extras
          if (widget.order.lamination)
            _billRow(label: 'Lamination', amount: kLaminationFee),
          if (widget.order.glossy)
            _billRow(label: 'Glossy Paper', amount: kGlossyFee),
          if (widget.order.spiralBinding)
            _billRow(label: 'Spiral Binding', amount: kSpiralBindingFee),
          if (widget.order.tapeBinding)
            _billRow(label: 'Tape Binding', amount: kTapeBindingFee),

          const SizedBox(height: 8),
          const Divider(thickness: 1.5),
          const SizedBox(height: 8),

          // Total
          Row(
            children: [
              Text('TOTAL AMOUNT',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w800, color: _text)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_red, Color(0xFFEF5350)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _currency.format(_total),
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _billRow({required String label, required double amount}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
          ),
          Text(_currency.format(amount),
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _text)),
        ],
      ),
    );
  }

  // ── Pay Button ────────────────────────────────────────────────────────────────
  Widget _buildPayButton() => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [_red, Color(0xFFEF5350)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
            color: _red.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 8)),
      ],
    ),
    child: TextButton(
      onPressed: _paymentLoading ? null : _startPayment,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 17),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
      ),
      child: _paymentLoading
          ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: Colors.white)),
        const SizedBox(width: 10),
        Text('Processing…',
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
      ])
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.lock_rounded, size: 18, color: Colors.white),
        const SizedBox(width: 10),
        Text('PAY  ${_currency.format(_total)}',
            style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: .6)),
      ]),
    ),
  );

  // ── Helpers ───────────────────────────────────────────────────────────────────
  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4)),
      ],
    ),
    padding: const EdgeInsets.all(16),
    child: child,
  );

  Widget _sectionTitle(IconData icon, String title) => Row(
    children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
            color: _redLight, borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, color: _red, size: 17),
      ),
      const SizedBox(width: 10),
      Text(title,
          style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w700, color: _text)),
    ],
  );

  Widget _chip(String label, {bool accent = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: accent ? _redLight : const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
          color: accent ? const Color(0xFFFFCDD2) : const Color(0xFFE0E0E0)),
    ),
    child: Text(label,
        style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: accent ? _red : Colors.grey[700])),
  );
}

class _QueuePositionCard extends StatelessWidget {
  final String orderId;
  final PrintOrderService service;
  const _QueuePositionCard({required this.orderId, required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PrintOrderRecord>(
      stream: service.watchOrder(orderId),
      builder: (context, snap) {
        if (snap.hasError) {
          return _MiniCard(message: 'Queue: ${snap.error}');
        }
        if (!snap.hasData) {
          return const _MiniCard(message: 'Calculating your position…');
        }

        final order = snap.data!;
        final createdAt = order.createdAt;
        if (createdAt == null) {
          return const _MiniCard(message: 'Calculating your position…');
        }

        return StreamBuilder<List<PrintOrderRecord>>(
          stream: service.watchActiveQueueForShop(
            ownerId: order.ownerId,
            shopName: order.shopName,
          ),
          builder: (context, qSnap) {
            if (qSnap.hasError) {
              return _MiniCard(message: 'Queue: ${qSnap.error}');
            }
            final active = qSnap.data ?? const <PrintOrderRecord>[];
            final ahead = active.where((o) {
              final t = o.createdAt;
              if (t == null) return false;
              return t.isBefore(createdAt);
            }).length;
            return _MiniCard(
              message: ahead == 0
                  ? 'You are next in queue.'
                  : '$ahead pending order(s) before you.',
            );
          },
        );
      },
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String message;
  const _MiniCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF1565C0).withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1A1A2E),
        ),
      ),
    );
  }
}