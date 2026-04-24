import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../core/app_theme.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  bool _isEditing = false;
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    final safety = context.read<SafetyProvider>();
    _nameController = TextEditingController(text: safety.userProfile.name);
    _phoneController = TextEditingController(text: safety.userProfile.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isEditing) {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your name.')));
        return;
      }
      if (phone.length != 10) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid 10-digit number.')));
        return;
      }
      final safety = context.read<SafetyProvider>();
      await safety.updateUserProfile(safety.userProfile.copyWith(name: name, phone: phone));
    }
    setState(() => _isEditing = !_isEditing);
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
                    child: Container(
                      width: 40, height: 40, alignment: Alignment.centerLeft,
                      child: Icon(Icons.arrow_back_rounded, color: theme.textPrimary, size: 24),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      lang.t('personal_info'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  GestureDetector(
                    onTap: _handleSave,
                    child: Text(
                      _isEditing ? lang.t('save') : lang.t('edit'),
                      style: TextStyle(color: theme.accent, fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  children: [
                    // Avatar
                    Column(
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [Color(0xFF0D1B6E), Color(0xFF1976D2)]),
                          ),
                          child: const Icon(Icons.person_rounded, color: Colors.white, size: 40),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          safety.userProfile.name,
                          style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Form
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                      ),
                      child: Column(
                        children: [
                          _buildInputGroup(
                            label: lang.t('full_name_label'),
                            controller: _nameController,
                            icon: Icons.person_outline_rounded,
                            isEditing: _isEditing,
                            theme: theme,
                          ),
                          const SizedBox(height: 20),
                          _buildInputGroup(
                            label: lang.t('mobile_label'),
                            controller: _phoneController,
                            icon: Icons.phone_outlined,
                            isEditing: _isEditing,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            theme: theme,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputGroup({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool isEditing,
    required ThemeProvider theme,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isEditing ? (theme.isDarkMode ? Colors.transparent : const Color(0xFFF9FAFC)) : theme.surface,
            borderRadius: isEditing ? BorderRadius.circular(12) : null,
            border: isEditing ? Border.all(color: theme.border) : Border(bottom: BorderSide(color: theme.border)),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(icon, color: theme.textSecondary, size: 20),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: isEditing,
                  keyboardType: keyboardType,
                  maxLength: maxLength,
                  style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    counterText: '',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
