import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabattal/features/quran_reader/data/models/verse_model.dart';
import 'package:tabattal/features/quran_verse_card/presentation/widgets/desktop/verse_card_generator_sheet_desktop.dart';
import 'package:tabattal/features/quran_verse_card/presentation/widgets/mobile/verse_card_generator_sheet_mobile.dart';
import 'package:tabattal/features/quran_verse_card/presentation/widgets/shared/widgets/verse_card_options_bar.dart';
import 'package:tabattal/features/quran_verse_card/presentation/widgets/tablet/verse_card_generator_sheet_tablet.dart';
import 'package:tabattal/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
  });

  Widget buildTestableWidget(Widget child, {Size size = const Size(375, 812)}) {
    return ScreenUtilInit(
      designSize: size,
      minTextAdapt: true,
      splitScreenMode: false,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ar', 'SA'),
          Locale('en', 'US'),
        ],
        locale: const Locale('ar', 'SA'),
        home: Scaffold(body: child),
      ),
    );
  }

  final sampleVerse = VerseModel(
    id: 1,
    verseNumber: 1,
    verseKey: '1:1',
    textUthmani: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
    juzNumber: 1,
    words: const [],
  );

  group('Tafsir Decoupling & Default Closed Verification', () {
    testWidgets('Mobile: Tafsir is ALWAYS closed by default even if tafsirText was provided', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          VerseCardGeneratorSheetMobile(
            verse: sampleVerse,
            initialFormat: ShareFormat.image,
            tafsirText: 'تفسير ابن كثير أو غير ميسر',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final optionsBar = tester.widget<VerseCardOptionsBar>(
        find.byType(VerseCardOptionsBar).first,
      );

      // Verify Tafsir is strictly OFF by default
      expect(optionsBar.includeTafsir, isFalse);
    });

    testWidgets('Tablet: Tafsir is ALWAYS closed by default even if tafsirText was provided', (tester) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          VerseCardGeneratorSheetTablet(
            verse: sampleVerse,
            initialFormat: ShareFormat.image,
            tafsirText: 'تفسير الطبري أو غير ميسر',
          ),
          size: const Size(800, 1024),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final optionsBar = tester.widget<VerseCardOptionsBar>(
        find.byType(VerseCardOptionsBar).first,
      );

      // Verify Tafsir is strictly OFF by default
      expect(optionsBar.includeTafsir, isFalse);
    });

    testWidgets('Desktop & Web: Tafsir is ALWAYS closed by default even if foreign tafsir was provided', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          VerseCardGeneratorSheetDesktop(
            verse: sampleVerse,
            initialFormat: ShareFormat.image,
            tafsirText: 'تفسير القرطبي أو غير ميسر',
          ),
          size: const Size(1200, 900),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Desktop uses _VerseCardOptionsBarDesktop
      final optionsBarDesktop = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_VerseCardOptionsBarDesktop',
      );
      expect(optionsBarDesktop, findsOneWidget);
      final dynamic bar = tester.widget(optionsBarDesktop);
      expect(bar.includeTafsir, isFalse);
    });
  });
}
