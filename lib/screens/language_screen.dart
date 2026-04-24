import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../core/app_theme.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  static const List<Map<String, String>> _languages = [
    {'id': 'en', 'name': 'English', 'native': 'English'},
    {'id': 'hi', 'name': 'Hindi', 'native': 'हिन्दी'},
    {'id': 'bn', 'name': 'Bangla', 'native': 'বাংলা'},
    {'id': 'ta', 'name': 'Tamil', 'native': 'தமிழ்'},
    {'id': 'mr', 'name': 'Marathi', 'native': 'मराठी'},
    {'id': 'gu', 'name': 'Gujarati', 'native': 'ગુજરાતી'},
    {'id': 'te', 'name': 'Telugu', 'native': 'తెలుగు'},
    {'id': 'pa', 'name': 'Punjabi', 'native': 'ਪੰਜਾਬੀ'},
  ];

  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = context.read<LanguageProvider>().language;
  }

  Future<void> _handleSave() async {
    await context.read<LanguageProvider>().setLanguage(_selected);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final lang = context.watch<LanguageProvider>();

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
                      lang.t('language'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1),
                    ),
                  ),
                  GestureDetector(
                    onTap: _handleSave,
                    child: Text(lang.t('save'), style: TextStyle(color: theme.accent, fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 12),
                      child: Text(
                        lang.t('select_preference').toUpperCase(),
                        style: TextStyle(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                      ),
                      child: Column(
                        children: List.generate(_languages.length, (i) {
                          final l = _languages[i];
                          final isSelected = _selected == l['id'];
                          return Column(
                            children: [
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => setState(() => _selected = l['id']!),
                                  borderRadius: BorderRadius.circular(i == 0 ? 20 : i == _languages.length - 1 ? 20 : 0),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(l['name']!, style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                                              const SizedBox(height: 4),
                                              Text(l['native']!, style: TextStyle(color: theme.textSecondary, fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected ? theme.accent : theme.border,
                                              width: 2,
                                            ),
                                          ),
                                          child: isSelected
                                              ? Center(
                                                  child: Container(
                                                    width: 12,
                                                    height: 12,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: theme.accent,
                                                    ),
                                                  ),
                                                )
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (i < _languages.length - 1)
                                Divider(color: theme.border, height: 1),
                            ],
                          );
                        }),
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
}
