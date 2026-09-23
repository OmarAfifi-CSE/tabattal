import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabattal/features/quran_reader/data/models/tafsir_model.dart';
import 'package:tabattal/features/quran_reader/presentation/bloc/quran_state.dart';
import 'package:tabattal/features/quran_reader/presentation/widgets/shared/tafsir_selector_menu.dart';
import 'package:tabattal/l10n/app_localizations.dart';

void main() {
  group('TafsirLoaded Resource Tracking', () {
    test('effectiveDownloadingResourceId returns downloadingResourceId when set', () {
      final model = TafsirModel(
        id: 1,
        tafsirId: 16,
        text: 'Tafsir text',
      );
      final state = TafsirLoaded(
        model,
        isDownloading: true,
        downloadProgress: 0.45,
        downloadingResourceId: 14,
      );

      expect(state.effectiveDownloadingResourceId, 14);
      expect(state.isDownloading, isTrue);
      expect(state.downloadProgress, 0.45);
    });

    test('effectiveDownloadingResourceId falls back to tafsirId when not specified', () {
      final model = TafsirModel(
        id: 1,
        tafsirId: 16,
        text: 'Tafsir text',
      );
      final state = TafsirLoaded(
        model,
        isDownloading: false,
        downloadProgress: 1.0,
      );

      expect(state.effectiveDownloadingResourceId, 16);
      expect(state.isDownloading, isFalse);
    });
  });

  group('TafsirOption and Localization Display Test', () {
    testWidgets('TafsirOption.getTafsirName and downloadingTafsirBackground render correctly in Arabic', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ar'),
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              final nameIbnKathir = TafsirOption.getTafsirName(context, 14);
              final nameSaadi = TafsirOption.getTafsirName(context, 91);
              final nameMuyassar = TafsirOption.getTafsirName(context, 16);

              expect(nameIbnKathir, 'ابن كثير');
              expect(nameSaadi, 'السعدي');
              expect(nameMuyassar, 'الميسر');

              final bannerText = l10n.downloadingTafsirBackground(nameIbnKathir);
              expect(bannerText, 'جاري تحميل باقي تفسير ابن كثير في الخلفية...');

              return Text(bannerText);
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('جاري تحميل باقي تفسير ابن كثير في الخلفية...'), findsOneWidget);
    });

    testWidgets('downloadingTafsirBackground renders correctly in English', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              final name = TafsirOption.getTafsirName(context, 169);
              final bannerText = l10n.downloadingTafsirBackground(name);

              return Text(bannerText);
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Downloading remaining Ibn Kathir (Abridged) Tafsir in background...'), findsOneWidget);
    });

    testWidgets('TafsirOption renders Indonesian Kemenag (ID 33) correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('id'),
          home: Builder(
            builder: (context) {
              final name = TafsirOption.getTafsirName(context, 33);
              return Text(name);
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Terjemahan Kemenag (RI)'), findsOneWidget);
    });

    testWidgets('TafsirSelectorMenu updates percentage in real-time while open', (tester) async {
      final progressNotifier = ValueNotifier<double>(0.20);
      Map<int, double> progressMap = {14: 0.20};

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          minTextAdapt: true,
          splitScreenMode: false,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ar'),
            home: Scaffold(
              body: Center(
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return TafsirSelectorMenu(
                      selectedId: 16,
                      options: TafsirOption.getLocalizedOptions(
                        context,
                        downloadedIds: const {},
                        progressMap: progressMap,
                        activeDownloadingId: 14,
                        activeDownloadProgress: progressNotifier.value,
                      ),
                      downloadedIds: const {},
                      progressMap: progressMap,
                      activeDownloadingId: 14,
                      activeDownloadProgress: progressNotifier.value,
                      progressListenable: progressNotifier,
                      onSelected: (_) {},
                      trigger: const Text('Open Menu'),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap trigger to open the popup menu
      await tester.tap(find.text('Open Menu'));
      await tester.pumpAndSettle();

      // Menu is open, should show 20%
      expect(find.text('20%'), findsOneWidget);

      // Simulate real-time progress update while menu is still open
      progressMap[14] = 0.68;
      progressNotifier.value = 0.68;
      await tester.pump();

      // Should now show 68% without closing/reopening the menu!
      expect(find.text('68%'), findsOneWidget);
      expect(find.text('20%'), findsNothing);

      // Simulate completion (reaches 100% or finishes)
      progressMap[14] = 1.0;
      progressNotifier.value = 1.0;
      await tester.pump();

      // Percentage should disappear and 99% / 68% should NOT be displayed!
      expect(find.text('68%'), findsNothing);
      expect(find.text('99%'), findsNothing);
      expect(find.text('100%'), findsNothing);
    });

    testWidgets('TafsirOption recognizes cached downloaded IDs even when empty set is passed', (tester) async {
      TafsirOption.markDownloaded(14);
      TafsirOption.markDownloaded(91);

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ar'),
            home: Builder(
              builder: (context) {
                // Pass completely empty downloadedIds set
                final options = TafsirOption.getLocalizedOptions(
                  context,
                  downloadedIds: const {},
                );

                final ibnKathir = options.firstWhere((o) => o.id == 14);
                final saadi = options.firstWhere((o) => o.id == 91);
                final tabari = options.firstWhere((o) => o.id == 15);

                expect(ibnKathir.isDownloaded, isTrue);
                expect(saadi.isDownloaded, isTrue);
                // 15 was never marked downloaded
                expect(tabari.isDownloaded, isFalse);

                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
    });

    testWidgets('TafsirOption treats >= 99.5% progress as completed (no 99% freeze)', (tester) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ar'),
            home: Builder(
              builder: (context) {
                final options = TafsirOption.getLocalizedOptions(
                  context,
                  downloadedIds: const {},
                  progressMap: {90: 0.996}, // 113.5/114 or 99.6%
                );

                final qurtubi = options.firstWhere((o) => o.id == 90);
                expect(qurtubi.isDownloaded, isTrue);
                expect(qurtubi.isDownloading, isFalse);

                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
    });
  });
}
