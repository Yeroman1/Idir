import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// Exposes the current app [Locale] and lets the user switch languages.
final localeProvider =
    StateNotifierProvider<LocaleNotifier, Locale>((ref) => LocaleNotifier());

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en')) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(AppConstants.prefLocale) ?? 'en';
      if (['en', 'am', 'om'].contains(code)) {
        state = Locale(code);
      }
    } catch (e) {
      debugPrint('Notice loading locale: $e');
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.prefLocale, locale.languageCode);
    } catch (e) {
      debugPrint('Notice saving locale: $e');
    }
  }

  static const supportedLocales = [
    Locale('en'),
    Locale('am'),
    Locale('om'),
  ];

  static String localeName(String code) {
    switch (code) {
      case 'am':
        return 'አማርኛ';
      case 'om':
        return 'Afaan Oromoo';
      default:
        return 'English';
    }
  }
}
