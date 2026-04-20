import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ShopSettingsScreen extends StatefulWidget {
  final String ownerId;
  const ShopSettingsScreen({super.key, required this.ownerId});

  @override
  State<ShopSettingsScreen> createState() => _ShopSettingsScreenState();
}

class _ShopSettingsScreenState extends State<ShopSettingsScreen> {
  static const _bg = Color(0xFFF6F7FB);
  static const _text = Color(0xFF1A1A2E);
  static const _red = Color(0xFFE53935);

  final _closedMsgCtrl = TextEditingController();
  bool _dirtyMsg = false;

  DocumentReference<Map<String, dynamic>> get _ownerRef =>
      FirebaseFirestore.instance.collection('users').doc(widget.ownerId);

  @override
  void dispose() {
    _closedMsgCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveClosedMessage() async {
    final msg = _closedMsgCtrl.text.trim();
    await _ownerRef.set({'shopClosedMessage': msg}, SetOptions(merge: true));
    if (!mounted) return;
    setState(() => _dirtyMsg = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved', style: GoogleFonts.poppins(fontSize: 12))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'Shop Settings',
          style: GoogleFonts.poppins(
            color: _text,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (_dirtyMsg)
            TextButton(
              onPressed: _saveClosedMessage,
              child: Text('Save', style: GoogleFonts.poppins(color: _red)),
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _ownerRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _State(message: snapshot.error.toString());
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() ?? <String, dynamic>{};
          final shopOpen = (data['shopOpen'] as bool?) ?? true;
          final closedMsg = (data['shopClosedMessage'] ?? '').toString();
          final rawOos = data['outOfStock'];
          final oos = (rawOos is Map)
              ? rawOos.map((k, v) => MapEntry(k.toString(), v == true))
              : <String, bool>{};

          if (!_dirtyMsg && _closedMsgCtrl.text != closedMsg) {
            _closedMsgCtrl.text = closedMsg;
          }

          Future<void> setShopOpen(bool v) =>
              _ownerRef.set({'shopOpen': v}, SetOptions(merge: true));
          Future<void> setOos(String key, bool v) => _ownerRef.set(
                {
                  'outOfStock': {key: v},
                },
                SetOptions(merge: true),
              );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Card(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (shopOpen ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        shopOpen ? Icons.storefront_rounded : Icons.storefront_outlined,
                        color: shopOpen ? const Color(0xFF2E7D32) : _red,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shopOpen ? 'Shop is Open' : 'Temporarily Closed',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              color: _text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            shopOpen
                                ? 'Users can place orders now.'
                                : 'Users will see closed status and cannot order.',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: shopOpen,
                      onChanged: (v) => setShopOpen(v),
                      activeColor: const Color(0xFF2E7D32),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Closed message',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _closedMsgCtrl,
                      maxLines: 2,
                      onChanged: (_) => setState(() => _dirtyMsg = true),
                      decoration: InputDecoration(
                        hintText: 'Eg. Closed for maintenance. Try after 4 PM.',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Out of stock',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _oosTile(
                      label: 'Color printing',
                      value: oos['color'] == true,
                      onChanged: (v) => setOos('color', v),
                    ),
                    _oosTile(
                      label: 'Lamination',
                      value: oos['lamination'] == true,
                      onChanged: (v) => setOos('lamination', v),
                    ),
                    _oosTile(
                      label: 'Glossy paper',
                      value: oos['glossy'] == true,
                      onChanged: (v) => setOos('glossy', v),
                    ),
                    _oosTile(
                      label: 'Spiral binding',
                      value: oos['spiralBinding'] == true,
                      onChanged: (v) => setOos('spiralBinding', v),
                    ),
                    _oosTile(
                      label: 'Tape binding',
                      value: oos['tapeBinding'] == true,
                      onChanged: (v) => setOos('tapeBinding', v),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _oosTile({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: GoogleFonts.poppins(fontSize: 13)),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

class _State extends StatelessWidget {
  final String message;
  const _State({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
        ),
      ),
    );
  }
}

