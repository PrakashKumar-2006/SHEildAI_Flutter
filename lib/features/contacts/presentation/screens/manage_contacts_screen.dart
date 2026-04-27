import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_button.dart';

class ManageContactsScreen extends StatefulWidget {
  const ManageContactsScreen({super.key});

  @override
  State<ManageContactsScreen> createState() => _ManageContactsScreenState();
}

class _ManageContactsScreenState extends State<ManageContactsScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _controllers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? savedContacts = prefs.getStringList('trusted_contacts');
    
    setState(() {
      if (savedContacts != null && savedContacts.isNotEmpty) {
        for (var contact in savedContacts) {
          _controllers.add(TextEditingController(text: contact));
        }
      } else {
        // Default to 3 empty fields if none found
        for (int i = 0; i < 3; i++) {
          _controllers.add(TextEditingController());
        }
      }
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addContactField() {
    if (_controllers.length < 5) {
      setState(() {
        _controllers.add(TextEditingController());
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 contacts allowed.')),
      );
    }
  }

  void _removeContactField(int index) {
    if (_controllers.length > 1) {
      setState(() {
        _controllers[index].dispose();
        _controllers.removeAt(index);
      });
    }
  }

  String _normalizePhone(String phone) {
    phone = phone.trim();
    if (!phone.startsWith('+')) {
      if (phone.length == 10 && RegExp(r'^[0-9]+$').hasMatch(phone)) {
        return '+91$phone';
      }
    }
    return phone;
  }

  Future<void> _saveContacts() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final List<String> numbers = _controllers
        .map((c) => _normalizePhone(c.text))
        .where((text) => text.isNotEmpty)
        .toList();

    if (numbers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one trusted contact.')),
      );
      return;
    }

    await prefs.setStringList('trusted_contacts', numbers);
    await prefs.setBool('contacts_saved', true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contacts updated successfully.')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Manage Trusted Contacts'),
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.textPrimary,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Manage Trusted Contacts',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    const Text(
                      'Update your emergency contacts below.',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXL),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _controllers.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _controllers[index],
                                    keyboardType: TextInputType.phone,
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return null; // Empty fields are allowed as long as at least one is provided globally
                                      }
                                      final phoneRegex = RegExp(r'^\+?[0-9]{7,15}$');
                                      if (!phoneRegex.hasMatch(value.trim())) {
                                        return 'Enter a valid phone number (e.g. +91 9876543210)';
                                      }
                                      return null;
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'Contact ${index + 1} Phone Number',
                                      prefixIcon: const Icon(Icons.phone),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_controllers.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                                    onPressed: () => _removeContactField(index),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    Center(
                      child: TextButton.icon(
                        onPressed: _addContactField,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Another Contact'),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                    CustomButton(
                      text: 'Update Contacts',
                      onPressed: _saveContacts,
                      width: double.infinity,
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}
