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

    test('Chip theme has visible high-contrast labelStyle in light and dark modes', () {
      final lightChip = AppTheme.light.chipTheme;
      final darkChip = AppTheme.dark.chipTheme;

      final lightStyle = lightChip.labelStyle as WidgetStateTextStyle;
      final darkStyle = darkChip.labelStyle as WidgetStateTextStyle;

      // Unselected light chip has visible dark blue label color (not white)
      final lightUnselectedStyle = lightStyle.resolve({});
      expect(lightUnselectedStyle.color, AppColors.textDarkBlue);
      expect(lightUnselectedStyle.color, isNot(Colors.white));

      // Selected light chip has white label color
      final lightSelectedStyle = lightStyle.resolve({WidgetState.selected});
      expect(lightSelectedStyle.color, Colors.white);

      // Unselected dark chip has light text color
      final darkUnselectedStyle = darkStyle.resolve({});
      expect(darkUnselectedStyle.color, const Color(0xFFE0E7FF));

      // Selected dark chip has white text color
      final darkSelectedStyle = darkStyle.resolve({WidgetState.selected});
      expect(darkSelectedStyle.color, Colors.white);
    });
  });
}
