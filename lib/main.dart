import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/providers.dart';
import 'core/app_theme.dart';
import 'screens/main_screen.dart';
import 'screens/signin_screen.dart';
import 'screens/setup_permissions_screen.dart';

void main() {
  runApp(const ShieldAIApp());
}

class ShieldAIApp extends StatelessWidget {
  const ShieldAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => SafetyProvider()),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, langProvider, child) {
          return MaterialApp(
            title: 'SHEild AI',
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const AppBootstrap(),
          );
        },
      ),
    );
  }
}

class AppBootstrap extends StatelessWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    final safety = context.watch<SafetyProvider>();

    if (!safety.isAppReady) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF0D1B6E)),
              SizedBox(height: 16),
              Text('SHEild AI', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0D1B6E))),
            ],
          ),
        ),
      );
    }

    if (!safety.userProfile.isComplete) {
      return const SigninScreen();
    }

    if (!safety.userProfile.isSetupComplete) {
      return const SetupPermissionsScreen();
    }

    return const MainScreen();
  }
}
