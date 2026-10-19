import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idir_app/core/theme/app_theme.dart';
import 'package:idir_app/l10n/app_localizations.dart';

void main() {
  group('Theme tests', () {
    test('Light and dark themes build with valid properties', () {
      final light = AppTheme.light;
      final dark = AppTheme.dark;

      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.colorScheme.primary, AppColors.primary);
      expect(dark.colorScheme.primary, AppColors.primary);
    });

    test('Supported locales include en, am, om', () {
      const locales = AppLocalizations.supportedLocales;
      final languageCodes = locales.map((l) => l.languageCode).toList();

      expect(languageCodes, containsAll(['en', 'am', 'om']));
    });
  });
}
