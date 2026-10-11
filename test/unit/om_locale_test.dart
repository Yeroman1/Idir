import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idir_app/core/localization/fallback_localizations_delegate.dart';
import 'package:idir_app/l10n/app_localizations.dart';

void main() {
  group('Afaan Oromoo (om) Localization & Fallback Tests', () {
    test('Fallback delegates support om locale', () {
      const mat = FallbackMaterialLocalizationsDelegate();
      const cup = FallbackCupertinoLocalizationsDelegate();

      expect(mat.isSupported(const Locale('om')), isTrue);
      expect(cup.isSupported(const Locale('om')), isTrue);
    });

    testWidgets('MaterialApp loads and renders cleanly with Locale(om)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('om'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            FallbackMaterialLocalizationsDelegate(),
            FallbackCupertinoLocalizationsDelegate(),
          ],
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              final mat = MaterialLocalizations.of(context);
              return Scaffold(
                appBar: AppBar(title: Text(l10n.appName)),
                body: Center(
                  child: Column(
                    children: [
                      Text(l10n.idirName),
                      Text(l10n.dashboardTitle),
                      Text(mat.okButtonLabel),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Afaan Oromoo translations render without throwing
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Idir'), findsWidgets);
    });
  });
}
