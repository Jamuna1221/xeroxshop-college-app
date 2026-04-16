import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:file_picker/file_picker.dart';  // ← MISSING IMPORT
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/print_order_models.dart';
import 'payment_screen.dart';

// ── Model ─────────────────────────────────────────────────────────────────────
class UploadedFile {
  final String name;
  final String size;
  final String ext;
  final String path;
  UploadedFile({
    required this.name,
    required this.size,
    required this.ext,
    required this.path,
  });
}

class UploadPrintScreen extends StatefulWidget {
  const UploadPrintScreen({super.key});

  @override
  State<UploadPrintScreen> createState() => _UploadPrintScreenState();
}

class _UploadPrintScreenState extends State<UploadPrintScreen>
    with TickerProviderStateMixin {
  static const _red = Color(0xFFE53935);
  static const _redLight = Color(0xFFFFEBEE);
  static const _bg = Color(0xFFF6F7FB);
  static const _text = Color(0xFF1A1A2E);

  // Upload state
  UploadedFile? _file;
  bool _isPickingFile = false;
  late AnimationController _revealCtrl;
  late Animation<double> _revealAnim;

  // Print side
  bool _doubleSide = false;

  // Print settings
  String _pages = 'All';
  String _layout = 'Portrait';
  String _paperSize = 'A4';
  String _perSheet = '1';
  String _margins = 'Default';
  String _scale = 'Fit to Page';
  String _quality = 'Standard';
  String _printType = 'Black & White';

  // Extra options
  bool _staple = false;
  bool _lamination = false;
  bool _glossy = false;

  // Binding
  bool _spiralBinding = false;
  bool _tapeBinding = false;

  // Copies
  int _copies = 1;

  // Card expand states
  bool _settingsExpanded = true;
  bool _extraExpanded = true;
  bool _bindingExpanded = true;

  // Submit state
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _revealAnim = CurvedAnimation(
      parent: _revealCtrl,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _revealCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
  if (_isPickingFile) return;
  setState(() => _isPickingFile = true);

  try {
    // Only run permission logic on Android
    if (!kIsWeb && Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 33) {
        final photos = await Permission.photos.request();
        if (photos.isPermanentlyDenied) {
          _showError('Permission denied. Open App Settings → allow Files & Media.');
          await openAppSettings();
          return;
        }
      } else {
        final status = await Permission.storage.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          _showError('Storage permission denied. Open App Settings → allow Storage.');
          if (status.isPermanentlyDenied) await openAppSettings();
          return;
        }
      }
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'png', 'jpg', 'jpeg'],
      withData: kIsWeb, // On web, we need bytes; on mobile, path is enough
      withReadStream: false,
    );

    if (!mounted) return;

    if (result != null && result.files.isNotEmpty) {
      final picked = result.files.single;

      final bytes = picked.size;
      final sizeStr = bytes < 1024
          ? '$bytes B'
          : bytes < 1024 * 1024
              ? '${(bytes / 1024).toStringAsFixed(1)} KB'
              : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

      setState(() {
        _file = UploadedFile(
          name: picked.name,
          size: sizeStr,
          ext: (picked.extension ?? 'file').toLowerCase(),
          path: picked.path ?? '',
        );
      });
      _revealCtrl.forward();
    }
  } on PlatformException catch (e) {
    if (!mounted) return;
    _showError(_resolvePlatformError(e.code));
  } catch (e) {
    if (!mounted) return;
    final msg = e.toString();
    if (msg.contains('MissingPluginException')) {
      _showError('Plugin not linked. Run: flutter clean → flutter pub get → rebuild.');
    } else if (!msg.contains('already_active')) {
      _showError('Could not open file picker.\n$msg');
    }
  } finally {
    if (mounted) setState(() => _isPickingFile = false);
  }
}

  String _resolvePlatformError(String code) {
    switch (code) {
      case 'read_external_storage_denied':
      case 'photo_access_denied':
      case 'PERMISSION_DENIED':
        return 'Storage permission denied.\n'
            'Open App Settings → Permissions → allow Storage / Files.';
      case 'already_active':
        return 'File picker is already open. Please wait.';
      case 'unknown_path':
        return 'Could not read the selected file path. Try a different file.';
      default:
        return 'File picker error: $code\nPlease try again.';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child:
                  Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: GoogleFonts.poppins(fontSize: 12)),
            ),
          ],
        ),
        backgroundColor: _red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
    );
  }

  void _removeFile() {
    _revealCtrl.reverse().then((_) {
      if (mounted) setState(() => _file = null);
    });
  }

  Future<void> _submitOrder() async {
    if (_file == null) return;

    final order = PrintOrderSummary(
      filePath      : _file!.path,
      fileName      : _file!.name,
      fileSize      : _file!.size,
      pages         : _pages,
      layout        : _layout,
      paperSize     : _paperSize,
      perSheet      : _perSheet,
      margins       : _margins,
      scale         : _scale,
      quality       : _quality,
      printType     : _printType,
      doubleSide    : _doubleSide,
      staple        : _staple,
      lamination    : _lamination,
      glossy        : _glossy,
      spiralBinding : _spiralBinding,
      tapeBinding   : _tapeBinding,
      copies        : _copies,
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PaymentScreen(order: order)),
    );
  }
  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUploadSection(),
            FadeTransition(
              opacity: _revealAnim,
              child: SizeTransition(
                sizeFactor: _revealAnim,
                child: _file != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPrintSideCard(),
                          _buildSettingsCard(),
                          _buildExtraOptionsCard(),
                          _buildBindingCard(),
                          _buildCopiesCard(),
                          _buildUploadButton(),
                          const SizedBox(height: 10),
                          Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                'Your document is sent securely.\nOrder confirmation via email.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: Colors.grey[500]),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 2,
      shadowColor: Colors.black.withOpacity(0.08),
      automaticallyImplyLeading: true,
      iconTheme: const IconThemeData(color: _text),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Upload Document',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _text)),
          Text('Customize and submit your print job',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }

  // ── Upload Section ────────────────────────────────────────────────────────────
  Widget _buildUploadSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: _buildCard(
        padding: const EdgeInsets.all(16),
        child: _file == null ? _buildDropZone() : _buildFilePreviewCard(),
      ),
    );
  }

  Widget _buildDropZone() {
    return GestureDetector(
      onTap: _isPickingFile ? null : _pickFile,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E0E0), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                  color: _redLight, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.folder_open_rounded, color: _red, size: 28),
            ),
            const SizedBox(height: 14),
            Text('Tap to Browse Files',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _text)),
            const SizedBox(height: 4),
            Text('PDF, DOCX, PPTX, PNG, JPG',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 16),
            _isPickingFile
                ? const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: _red),
                  )
                : ElevatedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: Text('Browse Files',
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePreviewCard() {
    final ext = _file!.ext.toUpperCase();
    const extIcons = <String, IconData>{
      'PDF': Icons.picture_as_pdf_rounded,
      'DOC': Icons.article_rounded,
      'DOCX': Icons.article_rounded,
      'PPT': Icons.slideshow_rounded,
      'PPTX': Icons.slideshow_rounded,
      'PNG': Icons.image_rounded,
      'JPG': Icons.image_rounded,
      'JPEG': Icons.image_rounded,
    };
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFCDD2)),
          ),
          child: Icon(extIcons[ext] ?? Icons.insert_drive_file_rounded,
              color: _red, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_file!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _text)),
              const SizedBox(height: 2),
              Text(_file!.size,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey[500])),
            ],
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: _removeFile,
          style: OutlinedButton.styleFrom(
            foregroundColor: _red,
            side: const BorderSide(color: Color(0xFFEF5350)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text('Remove',
              style: GoogleFonts.poppins(
                  fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  // ── Print Side ────────────────────────────────────────────────────────────────
  Widget _buildPrintSideCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardHeader(
                icon: Icons.print_rounded,
                title: 'Print Side',
                subtitle: 'Choose single or double sided'),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                    child: _sideOption(
                        icon: Icons.article_outlined,
                        label: 'Single Side',
                        sub: 'One page per sheet',
                        selected: !_doubleSide,
                        onTap: () => setState(() => _doubleSide = false))),
                const SizedBox(width: 12),
                Expanded(
                    child: _sideOption(
                        icon: Icons.menu_book_rounded,
                        label: 'Double Side',
                        sub: 'Print both sides',
                        selected: _doubleSide,
                        onTap: () => setState(() => _doubleSide = true))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sideOption({
    required IconData icon,
    required String label,
    required String sub,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? _redLight : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? _red : const Color(0xFFE0E0E0),
              width: selected ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? _red : Colors.grey[400], size: 26),
            const SizedBox(height: 6),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? _red : _text)),
            Text(sub,
                style:
                    GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  // ── Print Settings ────────────────────────────────────────────────────────────
  Widget _buildSettingsCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _expandableHeader(
              icon: Icons.settings_rounded,
              title: 'Print Settings',
              subtitle: 'Customize your print job',
              expanded: _settingsExpanded,
              onTap: () =>
                  setState(() => _settingsExpanded = !_settingsExpanded),
            ),
            if (_settingsExpanded) ...[
              const Divider(height: 20),
              _formGrid([
                _dropdownRow(
                    'Pages',
                    Icons.menu_book_outlined,
                    _pages,
                    ['All', 'Odd Pages Only', 'Even Pages Only', 'Custom Range'],
                    (v) => setState(() => _pages = v!)),
                _dropdownRow(
                    'Layout',
                    Icons.rotate_90_degrees_ccw_rounded,
                    _layout,
                    ['Portrait', 'Landscape'],
                    (v) => setState(() => _layout = v!)),
                _dropdownRow(
                    'Paper Size',
                    Icons.crop_square_rounded,
                    _paperSize,
                    ['A4', 'A3', 'A5', 'Letter', 'Legal'],
                    (v) => setState(() => _paperSize = v!)),
                _dropdownRow(
                    'Per Sheet',
                    Icons.grid_view_rounded,
                    _perSheet,
                    ['1', '2', '4', '6', '8'],
                    (v) => setState(() => _perSheet = v!)),
                _dropdownRow(
                    'Margins',
                    Icons.border_outer_rounded,
                    _margins,
                    ['Default', 'None', 'Narrow', 'Wide'],
                    (v) => setState(() => _margins = v!)),
                _dropdownRow(
                    'Scale',
                    Icons.search_rounded,
                    _scale,
                    ['Fit to Page', 'Custom %'],
                    (v) => setState(() => _scale = v!)),
                _dropdownRow(
                    'Quality',
                    Icons.star_outline_rounded,
                    _quality,
                    ['Draft', 'Standard', 'High'],
                    (v) => setState(() => _quality = v!)),
                _dropdownRow(
                    'Print Type',
                    Icons.palette_outlined,
                    _printType,
                    ['Black & White', 'Color'],
                    (v) => setState(() => _printType = v!)),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  // ── Extra Options ─────────────────────────────────────────────────────────────
  Widget _buildExtraOptionsCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _expandableHeader(
              icon: Icons.auto_awesome_rounded,
              title: 'Extra Print Options',
              subtitle: 'Special finishes and features',
              expanded: _extraExpanded,
              onTap: () => setState(() => _extraExpanded = !_extraExpanded),
            ),
            if (_extraExpanded) ...[
              const Divider(height: 20),
              _checkRow(Icons.push_pin_rounded, 'Staple Pages', _staple,
                  (v) => setState(() => _staple = v ?? false)),
              _checkRow(Icons.layers_rounded, 'Lamination', _lamination,
                  (v) => setState(() => _lamination = v ?? false)),
              _checkRow(
                  Icons.brightness_high_rounded, 'Glossy Paper', _glossy,
                  (v) => setState(() => _glossy = v ?? false),
                  last: true),
            ],
          ],
        ),
      ),
    );
  }

  // ── Binding ───────────────────────────────────────────────────────────────────
  Widget _buildBindingCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _expandableHeader(
              icon: Icons.book_rounded,
              title: 'Binding',
              subtitle: 'Choose binding type',
              expanded: _bindingExpanded,
              onTap: () =>
                  setState(() => _bindingExpanded = !_bindingExpanded),
            ),
            if (_bindingExpanded) ...[
              const Divider(height: 20),
              _checkRow(Icons.loop_rounded, 'Spiral Binding', _spiralBinding,
                  (v) => setState(() => _spiralBinding = v ?? false)),
              _checkRow(
                  Icons.straighten_rounded, 'Tape Binding', _tapeBinding,
                  (v) => setState(() => _tapeBinding = v ?? false),
                  last: true),
            ],
          ],
        ),
      ),
    );
  }

  // ── Copies ────────────────────────────────────────────────────────────────────
  Widget _buildCopiesCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: _buildCard(
        child: Column(
          children: [
            _cardHeader(
                icon: Icons.copy_rounded,
                title: 'Number of Copies',
                subtitle: 'How many copies do you need?'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _stepBtn(
                    icon: Icons.remove_rounded,
                    onTap: () {
                      if (_copies > 1) setState(() => _copies--);
                    }),
                const SizedBox(width: 28),
                Text('$_copies',
                    style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: _text)),
                const SizedBox(width: 28),
                _stepBtn(
                    icon: Icons.add_rounded,
                    onTap: () {
                      if (_copies < 99) setState(() => _copies++);
                    }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Icon(icon, color: _text, size: 20),
      ),
    );
  }

  // ── Upload Button ─────────────────────────────────────────────────────────────
  Widget _buildUploadButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _submitted
                ? [const Color(0xFF43A047), const Color(0xFF66BB6A)]
                : [_red, const Color(0xFFEF5350)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (_submitted ? const Color(0xFF43A047) : _red)
                  .withOpacity(0.4),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: TextButton(
          onPressed: _submitted ? null : _submitOrder,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 17),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: _submitted
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Text('Uploading…',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: .4)),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_upload_rounded,
                        size: 20, color: Colors.white),
                    const SizedBox(width: 10),
                    Text('UPLOAD',
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: .6)),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Reusable Widgets ──────────────────────────────────────────────────────────

  Widget _buildCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _cardHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: _redLight, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: _red, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _text)),
            Text(subtitle,
                style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ],
    );
  }

  Widget _expandableHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool expanded,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: _redLight, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: _red, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _text)),
                Text(subtitle,
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.grey[400], size: 22),
          ),
        ],
      ),
    );
  }

  Widget _formGrid(List<Widget> children) {
    final List<Widget> rows = [];
    for (int i = 0; i < children.length; i += 2) {
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: children[i]),
          const SizedBox(width: 10),
          if (i + 1 < children.length)
            Expanded(child: children[i + 1])
          else
            const Expanded(child: SizedBox()),
        ],
      ));
      if (i + 2 < children.length) rows.add(const SizedBox(height: 10));
    }
    return Column(children: rows);
  }

  Widget _dropdownRow(
    String label,
    IconData icon,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey[500])),
            ),
          ],
        ),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          isExpanded: true,
          style: GoogleFonts.poppins(fontSize: 12, color: _text),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _red)),
            filled: true,
            fillColor: Colors.white,
          ),
          items: options
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 12, color: _text)),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _checkRow(
    IconData icon,
    String label,
    bool value,
    ValueChanged<bool?> onChanged, {
    bool last = false,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(9)),
                  child: Icon(icon, color: Colors.grey[600], size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(label,
                        style:
                            GoogleFonts.poppins(fontSize: 13, color: _text))),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: value ? _red : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: value ? _red : const Color(0xFFBDBDBD),
                        width: 1.5),
                  ),
                  child: value
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 14)
                      : null,
                ),
              ],
            ),
          ),
        ),
        if (!last) Divider(height: 1, color: Colors.grey.withOpacity(0.12)),
      ],
    );
  }
}