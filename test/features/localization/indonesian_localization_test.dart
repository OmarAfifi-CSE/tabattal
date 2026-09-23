import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabattal/core/constants/quran_constants.dart';
import 'package:tabattal/features/quran_reader/presentation/widgets/shared/tafsir_selector_menu.dart';
import 'package:tabattal/l10n/app_localizations.dart';

void main() {
  group('Indonesian Localization & Resource Routing Tests', () {
    test('AppLocalizations.supportedLocales contains Indonesian (id)', () {
      expect(
        AppLocalizations.supportedLocales.any((loc) => loc.languageCode == 'id'),
        isTrue,
      );
    });

    test('QuranConstants maps Indonesian to Kemenag translation (ID 33)', () {
      expect(QuranConstants.defaultTranslationIdForLocale('id'), 33);
      expect(QuranConstants.defaultTranslationIdForLocale('en'), 20);
      expect(QuranConstants.defaultTranslationIdForLocale('ar'), 20);
    });

    testWidgets('AppLocalizations renders Indonesian strings correctly',
        (tester) async {
      late AppLocalizations localizations;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('id'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              localizations = AppLocalizations.of(context)!;
              return Container();
            },
          ),
        ),
      );

      expect(localizations.appName, 'Tabattal');
      expect(localizations.drawerSearch, 'Pencarian Lanjutan');
      expect(localizations.drawerIndex, 'Indeks');
      expect(localizations.videoStudioShowTranslation, 'Tampilkan Terjemahan (Bahasa Indonesia)');
      expect(localizations.videoStudioShowTafsir, 'Tampilkan Tafsir (Al-Muyassar)');
      expect(localizations.verseCardTafsirBadge, 'Tafsir Al-Muyassar');
      expect(localizations.verseCardTranslationBadge, 'Terjemahan Bahasa Indonesia');
      expect(localizations.drawerLanguageSubtitle, 'العربية / English / Indonesia');
      expect(localizations.languageIndonesian, 'Bahasa Indonesia');
      expect(localizations.hifzEnableMode, 'Uji Hafalan');
      expect(localizations.hifzDisableMode, 'Hentikan Tes');
      expect(localizations.hifzMaskFull, 'Sembunyikan Ayat');
      expect(localizations.hifzMaskWord, 'Sembunyikan Kata');
    });

    testWidgets('AppLocalizations drawer subtitles include Indonesia in Arabic and English',
        (tester) async {
      late AppLocalizations arLoc;
      late AppLocalizations enLoc;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              arLoc = AppLocalizations.of(context)!;
              return Container();
            },
          ),
        ),
      );

      expect(arLoc.drawerLanguageSubtitle, 'العربية / English / Indonesia');
      expect(arLoc.drawerThemeAndLanguageSubtitle,
          'تخصيص المصحف والوضع الداكن • العربية / English / Indonesia');

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              enLoc = AppLocalizations.of(context)!;
              return Container();
            },
          ),
        ),
      );

      expect(enLoc.drawerLanguageSubtitle, 'العربية / English / Indonesia');
      expect(enLoc.drawerThemeAndLanguageSubtitle,
          'Customize Mushaf & Dark Mode • العربية / English / Indonesia');
    });

    testWidgets('TafsirOption.getLocalizedOptions returns combined AR and EN tafsirs with badges for id locale',
        (tester) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('id'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return Container();
            },
          ),
        ),
      );

      final options = TafsirOption.getLocalizedOptions(
        capturedContext,
        downloadedIds: {},
      );

      // Should have 7 Arabic + 3 English = 10 total options
      expect(options.length, 10);

      // Verify Arabic tafsir with AR badge
      final muyassarOpt = options.firstWhere((opt) => opt.id == 16);
      expect(muyassarOpt.isDownloaded, isTrue);
      expect(muyassarOpt.langBadge, 'AR');

      // Verify English tafsir with EN badge
      final ibnKathirEnOpt = options.firstWhere((opt) => opt.id == 169);
      expect(ibnKathirEnOpt.langBadge, 'EN');

      // Verify translation ID 33 is NOT in tafsir options
      expect(options.any((opt) => opt.id == 33), isFalse);
    });

    test('QuranConstants maps Indonesian to default Arabic tafsir (ID 16)', () {
      expect(QuranConstants.defaultTafsirIdForLocale('id'), 16);
      expect(QuranConstants.defaultTafsirIdForLocale('en'), 169);
      expect(QuranConstants.defaultTafsirIdForLocale('ar'), 16);
    });
  });
}
