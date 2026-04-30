import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../app.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/contact_provider.dart';
import '../../../../providers/providers.dart';

class ContactSetupScreen extends StatefulWidget {
  const ContactSetupScreen({super.key});

  @override
  State<ContactSetupScreen> createState() => _ContactSetupScreenState();
}

class _ContactSetupScreenState extends State<ContactSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // User Profile Controllers
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  
  // Trusted Contacts Controllers
  final List<ContactFieldGroup> _contactGroups = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    
    // Initialize user profile fields
    _nameController = TextEditingController(text: auth.userDisplayName);
    _phoneController = TextEditingController(text: auth.userPhone);
    
    // Initialize trusted contacts
    _initializeTrustedContacts();
  }

  void _initializeTrustedContacts() {
    // Add two empty contact fields by default
    _addContactField();
    _addContactField();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    for (var group in _contactGroups) {
      group.dispose();
    }
    super.dispose();
  }

  void _addContactField() {
    if (_contactGroups.length < 5) {
      setState(() {
        _contactGroups.add(ContactFieldGroup());
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 trusted contacts allowed.')),
      );
    }
  }

  void _removeContactField(int index) {
    if (_contactGroups.length > 1) {
      setState(() {
        _contactGroups[index].dispose();
        _contactGroups.removeAt(index);
      });
    }
  }

  String _normalizePhone(String phone) {
    phone = phone.trim();
    if (phone.isEmpty) return '';
    if (!phone.startsWith('+')) {
      if (phone.length == 10 && RegExp(r'^[0-9]+$').hasMatch(phone)) {
        return '+91$phone';
      }
    }
    return phone;
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthProvider>();
      final contactProvider = context.read<ContactProvider>();

      // 1. Save User Profile Updates
      final newName = _nameController.text.trim();
      final newPhone = _phoneController.text.trim();
      
      // Update MongoDB and AuthProvider
      await auth.updateProfile(name: newName, phone: newPhone);

      // 2. Process Trusted Contacts
      final List<String> numbers = [];
      
      // Always include user's own number as a trusted contact for safety
      final userNormalized = _normalizePhone(newPhone);
      numbers.add(userNormalized);
      
      // Save user's own contact to MongoDB for structured access
      await contactProvider.addContact(
        name: 'Me (Self)',
        phone: userNormalized,
        relationship: 'Self',
      );

      // Add other trusted contacts to MongoDB
      for (var group in _contactGroups) {
        final phone = group.phoneController.text.trim();
        final name = group.nameController.text.trim();
        
        if (phone.isNotEmpty) {
          final normalized = _normalizePhone(phone);
          numbers.add(normalized);
          
          // Save to MongoDB via repository
          await contactProvider.addContact(
            name: name.isNotEmpty ? name : 'Trusted Guardian',
            phone: normalized,
            relationship: 'Guardian',
          );
        }
      }

      // 3. Sync trusted contacts list to MongoDB user document
      await auth.updateTrustedContacts(numbers);
      
      // Refresh SafetyProvider to reflect new profile data immediately
      if (mounted) {
        await context.read<SafetyProvider>().refreshProfile();
      }
      
      // 4. Mark setup as complete in local storage (needed for app flow navigation)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('@setup_complete', true);
      await prefs.setBool('@profile_complete', true);
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AppBootstrap()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: AppTheme.spacingXL),
                
                _buildSectionTitle('Your Information', Icons.person_outline),
                _buildProfileCard(),
                
                const SizedBox(height: AppTheme.spacingXL),
                
                _buildSectionTitle('Trusted Contacts', Icons.security_outlined),
                _buildContactsList(),
                
                const SizedBox(height: AppTheme.spacingXL),
                
                CustomButton(
                  text: 'Save & Continue',
                  onPressed: _saveData,
                  isLoading: _isLoading,
                  width: double.infinity,
                  height: 56,
                ),
                const SizedBox(height: AppTheme.spacingXL),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Almost there!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.spacingS),
        Text(
          'Set up your emergency contacts and profile details.',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: AppTheme.spacingS),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      elevation: 0,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        side: BorderSide(color: AppColors.grey200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          children: [
            _buildTextField(
              controller: _nameController,
              label: 'Your Name',
              hint: 'Enter your full name',
              icon: Icons.badge_outlined,
              validator: (v) => v?.isEmpty ?? true ? 'Name is required' : null,
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildTextField(
              controller: _phoneController,
              label: 'Your Phone Number',
              hint: 'e.g. 9876543210',
              icon: Icons.phone_android_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v?.isEmpty ?? true) return 'Phone number is required';
                if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(v!.trim())) {
                  return 'Enter a valid phone number';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsList() {
    return Column(
      children: [
        ...List.generate(_contactGroups.length, (index) {
          return _buildContactCard(index);
        }),
        const SizedBox(height: AppTheme.spacingM),
        OutlinedButton.icon(
          onPressed: _addContactField,
          icon: const Icon(Icons.add),
          label: const Text('Add Another Trusted Contact'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactCard(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: Card(
        elevation: 0,
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          side: BorderSide(color: AppColors.grey200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Contact ${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  if (_contactGroups.length > 1)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      onPressed: () => _removeContactField(index),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingS),
              _buildTextField(
                controller: _contactGroups[index].nameController,
                label: 'Guardian Name',
                hint: 'e.g. Mom, Brother, Friend',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: AppTheme.spacingM),
              _buildTextField(
                controller: _contactGroups[index].phoneController,
                label: 'Phone Number',
                hint: 'e.g. 9876543210',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(v.trim())) {
                    return 'Enter a valid phone number';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: AppColors.grey100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          borderSide: const BorderSide(color: AppColors.primary, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

class ContactFieldGroup {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  void dispose() {
    nameController.dispose();
    phoneController.dispose();
  }
}
