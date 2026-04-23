import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class AppLocalization {
  static Future<void> initialize() async {
    await EasyLocalization.ensureInitialized();
  }

  static List<Locale> get supportedLocales => const [
    Locale('en'),
    Locale('hi'),
    Locale('es'),
    Locale('fr'),
    Locale('de'),
  ];

  static String translate(String key) {
    return key.tr();
  }
}
