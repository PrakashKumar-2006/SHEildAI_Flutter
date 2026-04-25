import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../core/app_theme.dart';

class SOSContactsScreen extends StatefulWidget {
  const SOSContactsScreen({super.key});

  @override
  State<SOSContactsScreen> createState() => _SOSContactsScreenState();
}

class _SOSContactsScreenState extends State<SOSContactsScreen> {
  bool _isEditing = false;
  List<TextEditingController> _controllers = [];

  @override
  void initState() {
    super.initState();
    final safety = context.read<SafetyProvider>();
    final contacts = safety.inputContacts;
    _controllers = contacts.map((c) => TextEditingController(text: c)).toList();
    if (_controllers.isEmpty) _controllers.add(TextEditingController());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addContact() {
    if (_controllers.length < 5) {
      setState(() => _controllers.add(TextEditingController()));
    }
  }

  void _removeContact(int index) {
    if (_controllers.length > 1) {
      _controllers[index].dispose();
      setState(() => _controllers.removeAt(index));
    }
  }

  Future<void> _handleSave() async {
    final values = _controllers.map((c) => c.text.trim()).toList();
    final safety = context.read<SafetyProvider>();
    safety.setInputContacts(values);
    await safety.saveTrustedContacts();
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final lang = context.watch<LanguageProvider>();
    final safety = context.watch<SafetyProvider>();
    final isDark = theme.isDarkMode;

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: theme.background,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(width: 40, height: 40, alignment: Alignment.centerLeft,
                      child: Icon(Icons.arrow_back_rounded, color: theme.textPrimary, size: 24)),
                  ),
                  Expanded(
                    child: Text(
                      lang.t('sentinel_contacts'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isEditing = !_isEditing),
                    child: Text(
                      _isEditing ? lang.t('cancel') : lang.t('edit'),
                      style: TextStyle(color: theme.accent, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Info box
                    Column(
                      children: [
                        Icon(Icons.shield_rounded, color: theme.accent, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          lang.t('emergency_guardians'),
                          style: TextStyle(color: theme.textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          lang.t('guardians_desc'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.textSecondary, fontSize: 14, height: 1.5),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                    // View / Edit mode
                    if (!_isEditing) ...[
                      if (safety.trustedContacts.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.surface,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                          ),
                          child: Column(
                            children: [
                              Text(lang.t('no_contacts'), style: TextStyle(color: theme.textSecondary, fontSize: 14)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => setState(() => _isEditing = true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.accent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text(lang.t('set_up'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        ...safety.trustedContacts.asMap().entries.map((e) => Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.surface,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 60, height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? const Color(0xFF1e3a8a) : const Color(0xFFE3F2FD),
                                ),
                                child: Icon(Icons.person_rounded, color: theme.accent, size: 24),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'SENTINEL ${e.key + 1}',
                                      style: TextStyle(color: theme.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(e.value, style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                        GestureDetector(
                          onTap: () => setState(() => _isEditing = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D1B6E),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(lang.t('manage_contacts'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ] else ...[
                      // Edit mode
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(lang.t('trusted_contacts_max'), style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                                if (_controllers.length < 5)
                                  GestureDetector(
                                    onTap: _addContact,
                                    child: Icon(Icons.add_circle_rounded, color: theme.accent, size: 24),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ..._controllers.asMap().entries.map((e) => Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.transparent : const Color(0xFFF5F6FA),
                                borderRadius: BorderRadius.circular(12),
                                border: isDark ? Border.all(color: theme.border) : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.call_outlined, color: theme.textSecondary, size: 20),
                                  Expanded(
                                    child: TextField(
                                      controller: e.value,
                                      keyboardType: TextInputType.phone,
                                      maxLength: 10,
                                      style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                                      decoration: InputDecoration(
                                        hintText: 'Contact ${e.key + 1} (10-digits)',
                                        hintStyle: TextStyle(color: theme.textSecondary),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                                        counterText: '',
                                      ),
                                    ),
                                  ),
                                  if (_controllers.length > 1)
                                    GestureDetector(
                                      onTap: () => _removeContact(e.key),
                                      child: const Icon(Icons.remove_circle_rounded, color: Color(0xFFFF4D4D), size: 24),
                                    ),
                                ],
                              ),
                            )),
                            GestureDetector(
                              onTap: _handleSave,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                decoration: BoxDecoration(
                                  color: theme.accent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(lang.t('verify_save'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Safety tips
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lang.t('safety_protocol'), style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.radio_button_on_rounded, color: Color(0xFF43A047), size: 18),
                            const SizedBox(width: 10),
                            Expanded(child: Text(lang.t('tip1'), style: TextStyle(color: theme.textSecondary, fontSize: 13, height: 1.4))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lock_outline_rounded, color: Color(0xFF43A047), size: 18),
                            const SizedBox(width: 10),
                            Expanded(child: Text(lang.t('tip2'), style: TextStyle(color: theme.textSecondary, fontSize: 13, height: 1.4))),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
