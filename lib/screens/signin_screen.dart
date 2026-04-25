import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../core/app_theme.dart';
import '../features/auth/presentation/providers/auth_provider.dart';

class SigninScreen extends StatefulWidget {
  const SigninScreen({super.key});

  @override
  State<SigninScreen> createState() => _SigninScreenState();
}

class _SigninScreenState extends State<SigninScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final lang = context.read<LanguageProvider>();

    if (email.isEmpty || password.isEmpty || (!_isLogin && name.isEmpty)) {
      _showAlert(lang.t('missing_fields'), lang.t('missing_fields_msg'));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      bool success = _isLogin 
        ? await auth.signIn(email, password) 
        : await auth.signUp(email, password, name);
      
      if (success && mounted) {
        final safety = context.read<SafetyProvider>();
        // Get name from Firebase if login, otherwise use input field
        String displayName = name;
        if (_isLogin) {
          displayName = auth.user?.displayName ?? 
                        auth.user?.email?.split('@')[0] ?? 
                        'User';
        }
        
        await safety.updateUserProfile(UserProfile(
          name: displayName,
          isComplete: true,
          isSetupComplete: false,
        ));
      }
    } catch (e) {
      _showAlert(lang.t('error'), e.toString());
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
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.15),
                      ),
                      child: const Icon(Icons.shield_rounded, color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'SHEild AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
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
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Login/Signup Toggle
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.surface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              _buildToggleButton('Sign In', _isLogin, () => setState(() => _isLogin = true), theme),
                              _buildToggleButton('Sign Up', !_isLogin, () => setState(() => _isLogin = false), theme),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        if (!_isLogin) ...[
                          _buildLabel('Full Name', theme),
                          _buildTextField(
                            controller: _nameController,
                            hint: 'Enter your name',
                            icon: Icons.person_outline_rounded,
                            theme: theme,
                          ),
                          const SizedBox(height: 16),
                        ],

                        _buildLabel('Email Address', theme),
                        _buildTextField(
                          controller: _emailController,
                          hint: 'your@email.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          theme: theme,
                        ),
                        const SizedBox(height: 16),

                        _buildLabel('Password', theme),
                        _buildTextField(
                          controller: _passwordController,
                          hint: '••••••••',
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          theme: theme,
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        
                        if (!_isLogin) ...[
                          const SizedBox(height: 16),
                          _buildLabel('Confirm Password', theme),
                          _buildTextField(
                            controller: _confirmPasswordController,
                            hint: '••••••••',
                            icon: Icons.lock_reset_rounded,
                            obscureText: true,
                            theme: theme,
                          ),
                        ],

                        const SizedBox(height: 32),

                        // Submit button
                        GestureDetector(
                          onTap: _isLoading ? null : _handleSubmit,
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0D1B6E), Color(0xFF1976D2)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFF0D1B6E).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: _isLoading
                                ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                                : Center(
                                    child: Text(
                                      _isLogin ? 'Sign In' : 'Create Account',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                                    ),
                                  ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text('OR', style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Google Sign-In
                        OutlinedButton(
                          onPressed: _isLoading ? null : () async {
                            setState(() => _isLoading = true);
                            try {
                              final auth = context.read<AuthProvider>();
                              bool success = await auth.signInWithGoogle();
                              if (success && mounted) {
                                final safety = context.read<SafetyProvider>();
                                final displayName = auth.user?.displayName ?? 
                                                  auth.user?.email?.split('@')[0] ?? 
                                                  'Google User';
                                                  
                                await safety.updateUserProfile(UserProfile(
                                  name: displayName,
                                  isComplete: true,
                                  isSetupComplete: false,
                                ));
                              }
                            } catch (e) {
                              _showAlert('Google Error', e.toString());
                            } finally {
                              if (mounted) setState(() => _isLoading = false);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            side: BorderSide(color: theme.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.g_mobiledata, size: 30, color: Color(0xFF1976D2)),
                              const SizedBox(width: 8),
                              Text('Continue with Google', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
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

  Widget _buildToggleButton(String text, bool active, VoidCallback onTap, ThemeProvider theme) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF0D1B6E) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(color: active ? Colors.white : theme.textSecondary, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required ThemeProvider theme,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(color: theme.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: theme.textSecondary.withOpacity(0.5)),
          prefixIcon: Icon(icon, color: theme.textSecondary, size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
