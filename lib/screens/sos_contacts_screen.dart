import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';

class SOSContactsScreen extends StatefulWidget {
  const SOSContactsScreen({super.key});

  @override
  State<SOSContactsScreen> createState() => _SOSContactsScreenState();
}

class _SOSContactsScreenState extends State<SOSContactsScreen> {
  bool _isEditing = false;
  bool _isLoadingContacts = true;
  final List<ContactControllerGroup> _controllers = [];

  @override
  void initState() {
    super.initState();
    // Defer to post-frame so context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadContactsFromDB();
    });
  }

  /// Fetches latest contacts from MongoDB then rebuilds controllers
  Future<void> _loadContactsFromDB() async {
    final safety = context.read<SafetyProvider>();
    await safety.refreshProfile(); // pulls fresh data from MongoDB
    if (!mounted) return;
    setState(() {
      _controllers.clear();
      final contacts = safety.trustedContacts;
      for (var contact in contacts) {
        _controllers.add(ContactControllerGroup(
          name: contact.name,
          phone: contact.phone,
        ));
      }
      if (_controllers.isEmpty) {
        _controllers.add(ContactControllerGroup());
      }
      _isLoadingContacts = false;
    });
  }

  @override
  void dispose() {
    for (final group in _controllers) {
      group.dispose();
    }
    super.dispose();
  }

  void _addContact() {
    if (_controllers.length < 5) {
      setState(() => _controllers.add(ContactControllerGroup()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 trusted contacts allowed.')),
      );
    }
  }

  Future<void> _removeContact(int index) async {
    // Minimum 1 contact must remain
    if (_controllers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least 1 trusted contact is required for your safety.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final contactName = _controllers[index].nameController.text.trim();
    final displayName = contactName.isNotEmpty ? contactName : 'this contact';

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text('Remove Contact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "$displayName" from your trusted contacts?',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _controllers[index].dispose();
      setState(() => _controllers.removeAt(index));
    }
  }

  bool _isSaving = false;

  Future<void> _handleSave() async {
    // Validate at least 1 valid contact
    final validCount = _controllers.where((g) => g.phoneController.text.trim().length >= 10).length;
    if (validCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least 1 valid phone number (10 digits).'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final safety = context.read<SafetyProvider>();
      final List<GuardianContact> newContacts = _controllers.map((group) => GuardianContact(
        name: group.nameController.text.trim(),
        phone: group.phoneController.text.trim(),
      )).toList();
      
      safety.setInputContacts(newContacts);
      await safety.saveTrustedContacts();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Contacts saved successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        setState(() => _isEditing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving contacts: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final lang = context.watch<LanguageProvider>();
    final safety = context.watch<SafetyProvider>();
    final isDark = theme.isDarkMode;

    return Scaffold(
      backgroundColor: theme.background,
      body: _isLoadingContacts
          ? SafeArea(
              child: Column(
                children: [
                  // Header still visible while loading
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
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: theme.accent),
                          const SizedBox(height: 16),
                          Text('Loading contacts...', style: TextStyle(color: theme.textSecondary, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          : SafeArea(
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
                    onTap: () {
                      if (_isEditing) {
                        // Reset controllers to original (DB) values
                        setState(() {
                          for (var group in _controllers) group.dispose();
                          _controllers.clear();
                          final contacts = safety.trustedContacts;
                          for (var c in contacts) {
                            _controllers.add(ContactControllerGroup(name: c.name, phone: c.phone));
                          }
                          if (_controllers.isEmpty) _controllers.add(ContactControllerGroup());
                          _isEditing = false;
                        });
                      } else {
                        setState(() => _isEditing = true);
                      }
                    },
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
                                      e.value.name.toUpperCase(),
                                      style: TextStyle(color: theme.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(e.value.phone, style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                        const SizedBox(height: 10),
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
                              margin: const EdgeInsets.only(bottom: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Contact ${e.key + 1}', style: TextStyle(color: theme.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                                      GestureDetector(
                                        onTap: () => _removeContact(e.key),
                                        child: Icon(
                                          _controllers.length <= 1
                                              ? Icons.lock_outline_rounded
                                              : Icons.remove_circle_rounded,
                                          color: _controllers.length <= 1
                                              ? Colors.orange
                                              : const Color(0xFFFF4D4D),
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Name Field
                                  _buildTextField(
                                    controller: e.value.nameController,
                                    hint: 'Guardian Name',
                                    icon: Icons.person_outline,
                                    isDark: isDark,
                                    theme: theme,
                                  ),
                                  const SizedBox(height: 12),
                                  // Phone Field
                                  _buildTextField(
                                    controller: e.value.phoneController,
                                    hint: 'Phone Number (10 digits)',
                                    icon: Icons.call_outlined,
                                    isDark: isDark,
                                    theme: theme,
                                    keyboardType: TextInputType.phone,
                                    maxLength: 10,
                                  ),
                                ],
                              ),
                            )),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: _isSaving ? null : _handleSave,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                decoration: BoxDecoration(
                                  color: _isSaving
                                      ? theme.accent.withOpacity(0.6)
                                      : theme.accent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 22, height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2.5),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.check_circle_outline,
                                              color: Colors.white, size: 20),
                                          const SizedBox(width: 8),
                                          Text(lang.t('verify_save'),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800)),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 30),
                    // Safety Protocol
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang.t('safety_protocol'),
                          style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 16),
                        _buildProtocolItem(
                          icon: Icons.check_circle_outline_rounded,
                          text: lang.t('protocol_sms'),
                          theme: theme,
                        ),
                        const SizedBox(height: 12),
                        _buildProtocolItem(
                          icon: Icons.lock_outline_rounded,
                          text: lang.t('protocol_encryption'),
                          theme: theme,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    required ThemeProvider theme,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.transparent : const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
        border: isDark ? Border.all(color: theme.border) : null,
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.textSecondary, size: 20),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLength: maxLength,
              style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: theme.textSecondary, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                counterText: '',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtocolItem({required IconData icon, required String text, required ThemeProvider theme}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.green, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: theme.textSecondary, fontSize: 13, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class ContactControllerGroup {
  final TextEditingController nameController;
  final TextEditingController phoneController;

  ContactControllerGroup({String name = '', String phone = ''})
      : nameController = TextEditingController(text: name),
        phoneController = TextEditingController(text: phone);

  void dispose() {
    nameController.dispose();
    phoneController.dispose();
  }
}
