import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../core/app_theme.dart';

class SigninScreen extends StatefulWidget {
  const SigninScreen({super.key});

  @override
  State<SigninScreen> createState() => _SigninScreenState();
}

class _SigninScreenState extends State<SigninScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final List<TextEditingController> _contactControllers = [TextEditingController()];
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    for (final c in _contactControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _handleGetStarted() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final contacts = _contactControllers
        .map((c) => c.text.trim())
        .where((v) => v.isNotEmpty)
        .toList();
    final lang = context.read<LanguageProvider>();

    if (name.isEmpty || phone.isEmpty || contacts.isEmpty) {
      _showAlert(lang.t('missing_fields'), lang.t('missing_fields_msg'));
      return;
    }
    if (phone.length != 10) {
      _showAlert(lang.t('invalid_phone'), lang.t('invalid_phone_msg'));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final safety = context.read<SafetyProvider>();
      await safety.updateUserProfile(UserProfile(
        name: name,
        phone: phone,
        trustedContacts: contacts,
        isComplete: true,
        isSetupComplete: false,
      ));
    } catch (e) {
      final lang = context.read<LanguageProvider>();
      _showAlert(lang.t('error'), lang.t('error_msg'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  void _addContact() {
    if (_contactControllers.length < 5) {
      setState(() => _contactControllers.add(TextEditingController()));
    }
  }

  void _removeContact(int index) {
    if (_contactControllers.length > 1) {
      _contactControllers[index].dispose();
      setState(() => _contactControllers.removeAt(index));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1B6E), Color(0xFF1565C0), Color(0xFF1976D2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header branding
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.15),
                      ),
                      child: const Icon(Icons.shield_rounded, color: Colors.white, size: 44),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'SHEild AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lang.t('your_companion'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Form card
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.background,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang.t('create_profile'),
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lang.t('enter_details'),
                          style: TextStyle(color: theme.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 24),

                        // Name
                        _buildLabel(lang.t('full_name'), theme),
                        _buildTextField(
                          controller: _nameController,
                          hint: lang.t('enter_name'),
                          icon: Icons.person_outline_rounded,
                          theme: theme,
                        ),
                        const SizedBox(height: 16),

                        // Phone
                        _buildLabel(lang.t('mobile_number'), theme),
                        _buildTextField(
                          controller: _phoneController,
                          hint: lang.t('ten_digit'),
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          theme: theme,
                        ),
                        const SizedBox(height: 16),

                        // Contacts
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              lang.t('trusted_contacts'),
                              style: TextStyle(
                                color: theme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (_contactControllers.length < 5)
                              GestureDetector(
                                onTap: _addContact,
                                child: Icon(Icons.add_circle_rounded, color: theme.accent, size: 24),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...List.generate(_contactControllers.length, (i) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _contactControllers[i],
                                    hint: '${lang.t('contact_n')} ${i + 1} ${lang.t('ten_digits')}',
                                    icon: Icons.call_outlined,
                                    keyboardType: TextInputType.phone,
                                    maxLength: 10,
                                    theme: theme,
                                  ),
                                ),
                                if (_contactControllers.length > 1) ...[
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => _removeContact(i),
                                    child: const Icon(Icons.remove_circle_rounded, color: Color(0xFFFF4D4D), size: 24),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 8),

                        // Location info text
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.surface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.location_on_outlined, color: theme.textSecondary, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  lang.t('location_info'),
                                  style: TextStyle(color: theme.textSecondary, fontSize: 12, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Submit button
                        GestureDetector(
                          onTap: _isLoading ? null : _handleGetStarted,
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0D1B6E), Color(0xFF1976D2)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFF0D1B6E).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: _isLoading
                                ? const Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        lang.t('activate_protection'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: theme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required ThemeProvider theme,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: theme.textSecondary),
          prefixIcon: Icon(icon, color: theme.textSecondary, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          counterText: '',
        ),
      ),
    );
  }
}
