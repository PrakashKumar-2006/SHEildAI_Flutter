import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../core/app_theme.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isLoading = false;

  void _handleAction(String successMessage) async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1)); // Mock network request
    setState(() => _isLoading = false);
    
    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Success!'),
          content: Text(successMessage),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // dismiss dialog
                Navigator.of(context).pop(); // dismiss screen
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Unlock Peace of Mind',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.textPrimary, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose the ultimate safety plan that fits your needs.',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 32),

              // FREE TRIAL BANNER
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.accent.withOpacity(0.1),
                  border: Border.all(color: theme.accent),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text('New User? Get 30 Days Free!', style: TextStyle(color: theme.accent, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      'Experience all premium features entirely free for your first month.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _handleAction('Your 30-day Free Trial is now active!'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accent,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Start Free Trial', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              // FREE PLAN
              _buildPlanCard(
                theme: theme,
                name: 'Basic Protection (Free)',
                price: '₹0 / month',
                features: ['View risk zones and core maps', 'Manual SOS & basic messages'],
                buttonText: null,
              ),

              // PLAN 1
              _buildPlanCard(
                theme: theme,
                name: 'Proactive Guard (Plan 1)',
                price: '₹99 / month',
                priceColor: theme.accent,
                features: ['Everything in Free', 'Local Incident Feed (Alerts)', 'Background video evidence'],
                buttonText: 'Select Plan',
                onTap: () => _handleAction('Successfully upgraded to Proactive Guard!'),
              ),

              // PLAN 2
              _buildPlanCard(
                theme: theme,
                name: 'Premium Sentinel (Plan 2)',
                price: '₹169 / month',
                priceColor: theme.accent,
                borderColor: theme.accent,
                bgColor: theme.accent.withOpacity(0.05),
                features: ['Everything in Plan 1', '3-Hour Risk Forecasting (ML v4.0)', 'Safest Travel Time Analysis', '5km Community Helper Network'],
                buttonText: 'Select Plan',
                onTap: () => _handleAction('Successfully upgraded to Premium Sentinel!'),
              ),

              // Not Now Button
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Not Now', style: TextStyle(color: theme.accent, fontWeight: FontWeight.w600, fontSize: 16)),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required ThemeProvider theme,
    required String name,
    required String price,
    Color? priceColor,
    Color? borderColor,
    Color? bgColor,
    required List<String> features,
    String? buttonText,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor ?? theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? Colors.transparent, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(price, style: TextStyle(color: priceColor ?? theme.textSecondary, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: theme.accent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(f, style: TextStyle(color: theme.textPrimary, fontSize: 15))),
                  ],
                ),
              )),
          if (buttonText != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(buttonText, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
