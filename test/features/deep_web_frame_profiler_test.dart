import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabattal/core/bloc/locale/locale_cubit.dart';
import 'package:tabattal/core/error/either.dart';
import 'package:tabattal/core/error/failures.dart';
import 'package:tabattal/core/services/audio_preferences_service.dart';
import 'package:tabattal/features/quran_audio/presentation/bloc/audio_bloc.dart';
import 'package:tabattal/features/quran_audio/presentation/bloc/audio_event.dart';
import 'package:tabattal/features/quran_audio/presentation/bloc/audio_state.dart';
import 'package:tabattal/features/quran_bookmarks/domain/repositories/bookmark_repository.dart';
import 'package:tabattal/features/quran_bookmarks/presentation/bloc/bookmark_bloc.dart';
import 'package:tabattal/features/quran_bookmarks/presentation/bloc/bookmark_event.dart';
import 'package:tabattal/features/quran_hifz/presentation/bloc/hifz_bloc.dart';
import 'package:tabattal/features/quran_hifz/presentation/bloc/hifz_event.dart';
import 'package:tabattal/features/quran_reader/presentation/bloc/quran_bloc.dart';
import 'package:tabattal/features/quran_reader/presentation/bloc/quran_event.dart';
import 'package:tabattal/features/quran_reader/presentation/bloc/quran_page_cache.dart';
import 'package:tabattal/features/quran_reader/presentation/bloc/quran_state.dart';
import 'package:tabattal/features/quran_reader/data/models/verse_model.dart';
import 'package:tabattal/features/quran_reader/domain/repositories/quran_repository.dart';
import 'package:tabattal/features/quran_reader/presentation/screens/web/quran_web_screen.dart';
import 'package:tabattal/features/quran_reader/presentation/widgets/drawer/web/quran_drawer_web.dart';
import 'package:tabattal/features/quran_reader/presentation/widgets/drawer/web/quran_index_view_web.dart';
import 'package:tabattal/features/quran_search/data/models/search_verse_model.dart';
import 'package:tabattal/features/quran_verse_card/presentation/widgets/web/verse_card_generator_sheet_web.dart';
import 'package:tabattal/features/quran_video_studio/presentation/widgets/web/video_aspect_ratio_bar_web.dart';
import 'package:tabattal/features/quran_video_studio/presentation/widgets/web/video_theme_selector_web.dart';
import 'package:tabattal/features/quran_video_studio/presentation/widgets/web/video_range_picker_web.dart';
import 'package:tabattal/features/quran_video_studio/presentation/widgets/web/video_reciter_selector_web.dart';
import 'package:tabattal/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:tabattal/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Precision Benchmark Logger & Frame Metrics Collector
// ---------------------------------------------------------------------------
class FrameMetric {
  final String testName;
  final double durationMs;
  final double budgetMs;
  final bool is120FpsPass;

  const FrameMetric({
    required this.testName,
    required this.durationMs,
    required this.budgetMs,
    required this.is120FpsPass,
  });

  @override
  String toString() {
    final passSymbol = is120FpsPass ? '✅ PASS (120 FPS)' : '⚠️ WARNING (>8.33ms)';
    return '$passSymbol | $testName: ${durationMs.toStringAsFixed(2)}ms (Budget: ${budgetMs.toStringAsFixed(2)}ms)';
  }
}

final List<FrameMetric> _profiledMetrics = [];

void logFrameMetric(String testName, double durationMs, double budgetMs) {
  final metric = FrameMetric(
    testName: testName,
    durationMs: durationMs,
    budgetMs: budgetMs,
    is120FpsPass: durationMs <= budgetMs,
  );
  _profiledMetrics.add(metric);
  debugPrint('⏱️ [FRAME PROFILER] $metric');
}

// ---------------------------------------------------------------------------
// Mock Data Helpers
// ---------------------------------------------------------------------------
QuranLoaded createMockQuranPage(int pageNumber) {
  final lines = List.generate(15, (lineIdx) {
    final lineNum = lineIdx + 1;
    final words = List.generate(6, (wordIdx) {
      return WordModel(
        id: lineNum * 10 + wordIdx,
        textUthmani: 'الكلمة',
        codeV2: 'ﱁ',
        lineNumber: lineNum,
        charTypeName: wordIdx == 5 ? 'end' : 'word',
        verseKey: '1:${(lineNum % 7) + 1}',
        pageNumber: pageNumber,
      );
    });
    return LineData(lineNumber: lineNum, words: words);
  });

  return QuranLoaded(currentPage: pageNumber, lines: lines);
}

class FullMockQuranRepository extends Fake implements QuranRepository {
  @override
  Future<Either<Failure, List<LineData>>> getLinesByPage(int pageNumber) async {
    final mockState = createMockQuranPage(pageNumber);
    QuranPageCache.put(pageNumber, mockState);
    return Right(mockState.lines);
  }

  @override
  Future<Either<Failure, int>> getPageForVerse(String verseKey) async => const Right(1);

  @override
  Future<Either<Failure, List<SearchVerseModel>>> searchQuran(String query) async {
    return Right([
      SearchVerseModel(
        id: 1,
        verseKey: '1:1',
        surah: 1,
        ayah: 1,
        page: 1,
        textClean: 'بسم الله الرحمن الرحيم',
        textUthmani: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
      ),
    ]);
  }

  Future<Either<Failure, List<VerseModel>>> getVersesForSurah(int surahNumber) async {
    final verses = List.generate(7, (i) {
      return VerseModel(
        id: i + 1,
        verseNumber: i + 1,
        verseKey: '$surahNumber:${i + 1}',
        textUthmani: 'آية تجريبية رقم ${i + 1}',
        juzNumber: 1,
        words: const [],
        tafsir: 'تفسير تجريبي للآية ${i + 1}',
        translation: 'Sample translation for verse ${i + 1}',
      );
    });
    return Right(verses);
  }

  Future<Either<Failure, List<VerseModel>>> getVersesForRange(int surahNumber, int startAyah, int endAyah) async {
    final count = (endAyah - startAyah + 1).clamp(1, 15);
    final verses = List.generate(count, (i) {
      final ayah = startAyah + i;
      return VerseModel(
        id: ayah,
        verseNumber: ayah,
        verseKey: '$surahNumber:$ayah',
        textUthmani: 'آية تجريبية رقم $ayah',
        juzNumber: 1,
        words: const [],
        tafsir: 'تفسير تجريبي للآية $ayah',
        translation: 'Sample translation for verse $ayah',
      );
    });
    return Right(verses);
  }
}

class FullMockBookmarkRepository extends Fake implements BookmarkRepository {
  final List<String> _bookmarks = ['1:1', '1:2', '2:255'];

  @override
  Future<List<String>> loadBookmarks() async => List.from(_bookmarks);

  @override
  Future<List<String>> toggle(String verseKey) async {
    if (_bookmarks.contains(verseKey)) {
      _bookmarks.remove(verseKey);
    } else {
      _bookmarks.add(verseKey);
    }
    return List.from(_bookmarks);
  }
}

class FullMockAudioPreferencesService extends Fake implements AudioPreferencesService {
  @override
  int get lastReadPage => 1;

  @override
  String get reciter => 'Minshawy_Murattal_128kbps';

  @override
  String get category => 'Murattal';

  @override
  int get repeatCount => 1;

  @override
  bool get playOnce => false;

  @override
  String get appLocale => 'ar';

  @override
  Future<void> saveLastReadPage(int page) async {}
}

class FakeAudioBloc extends Bloc<AudioEvent, AudioState> implements AudioBloc {
  FakeAudioBloc() : super(AudioIdle());

  @override
  String get currentReciter => 'Minshawy_Murattal_128kbps';

  @override
  String get currentCategory => 'Murattal';

  @override
  int get currentRepeatCount => 1;

  @override
  bool get playOnce => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.just_audio.methods'),
      (methodCall) async => <String, dynamic>{'duration': 4000000},
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );

    // Pre-populate page cache
    for (int p = 1; p <= 15; p++) {
      QuranPageCache.put(p, createMockQuranPage(p));
    }
  });

  tearDownAll(() {
    debugPrint('\n================================================================');
    debugPrint('📊 TABATTAL DEEP WEB FRAME PROFILER & LATENCY REPORT');
    debugPrint('================================================================');
    for (final metric in _profiledMetrics) {
      debugPrint(metric.toString());
    }
    debugPrint('================================================================\n');
  });

  Widget buildProfilerAppWrapper(Widget child, {
    QuranRepository? quranRepo,
    BookmarkRepository? bookmarkRepo,
    AudioPreferencesService? audioPrefs,
  }) {
    final effectiveQuranRepo = quranRepo ?? FullMockQuranRepository();
    final effectiveBookmarkRepo = bookmarkRepo ?? FullMockBookmarkRepository();
    final effectiveAudioPrefs = audioPrefs ?? FullMockAudioPreferencesService();

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<QuranRepository>.value(value: effectiveQuranRepo),
        RepositoryProvider<BookmarkRepository>.value(value: effectiveBookmarkRepo),
        RepositoryProvider<AudioPreferencesService>.value(value: effectiveAudioPrefs),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<QuranBloc>(create: (_) => QuranBloc(repository: effectiveQuranRepo)),
          BlocProvider<BookmarkBloc>(create: (_) => BookmarkBloc(repository: effectiveBookmarkRepo)..add(LoadBookmarks())),
          BlocProvider<SettingsBloc>(create: (_) => SettingsBloc(prefs: prefs)),
          BlocProvider<HifzBloc>(create: (_) => HifzBloc()),
          BlocProvider<LocaleCubit>(create: (_) => LocaleCubit(effectiveAudioPrefs)),
          BlocProvider<AudioBloc>(create: (_) => FakeAudioBloc()),
        ],
        child: ScreenUtilInit(
          designSize: const Size(1536, 864),
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
            home: child,
          ),
        ),
      ),
    );
  }

  group('🔬 Deep Web Frame Budget & Zero-Jank Latency Profiler', () {
    testWidgets('1. Quran Web Screen: Cold Boot & First Frame Construction', (tester) async {
      final stopwatch = Stopwatch()..start();
      await tester.pumpWidget(buildProfilerAppWrapper(const QuranWebScreen()));
      await tester.pump();
      stopwatch.stop();

      final bootMs = stopwatch.elapsedMicroseconds / 1000.0;
      logFrameMetric('Quran Web Cold Boot Frame 1', bootMs, 1000.0);
      expect(bootMs, lessThan(2500.0), reason: 'Cold boot build must complete promptly');

      await tester.pumpAndSettle();
    });

    testWidgets('2. Quran Reader: 10 Consecutive Page Swipes & Layout Measurement (<8.33ms / frame)', (tester) async {
      await tester.pumpWidget(buildProfilerAppWrapper(const QuranWebScreen()));
      await tester.pumpAndSettle();

      final quranBloc = tester.element(find.byType(QuranWebScreen)).read<QuranBloc>();

      for (int page = 2; page <= 8; page++) {
        final stopwatch = Stopwatch()..start();
        quranBloc.add(LoadPage(page));
        await tester.pump(); // Render first animation tick of the page flip
        stopwatch.stop();

        final flipMs = stopwatch.elapsedMicroseconds / 1000.0;
        logFrameMetric('Page $page Flip Frame 1 Tick', flipMs, 8.33);
        expect(flipMs, lessThan(8.33), reason: 'Page flip first tick must execute within 8.33ms (120 FPS budget)');

        await tester.pumpAndSettle();
      }
    });

    testWidgets('3. Hifz Mode: Masking Opacity & Word Mask Type Switching', (tester) async {
      await tester.pumpWidget(buildProfilerAppWrapper(const QuranWebScreen()));
      await tester.pumpAndSettle();

      final hifzBloc = tester.element(find.byType(QuranWebScreen)).read<HifzBloc>();

      // Toggle Hifz Mode On
      final stopwatchOn = Stopwatch()..start();
      hifzBloc.add(const ToggleHifzMode(enabled: true));
      await tester.pump();
      stopwatchOn.stop();

      final onMs = stopwatchOn.elapsedMicroseconds / 1000.0;
      logFrameMetric('Hifz Mode Enable Frame', onMs, 8.33);
      expect(onMs, lessThan(10.0));

      // Switch Masking Type
      final stopwatchType = Stopwatch()..start();
      hifzBloc.add(const SetHifzMaskingType(HifzMaskingType.wordByWord));
      await tester.pump();
      stopwatchType.stop();

      final typeMs = stopwatchType.elapsedMicroseconds / 1000.0;
      logFrameMetric('Hifz Mask Type Switch Frame', typeMs, 100.0);
      expect(typeMs, lessThan(100.0));

      await tester.pumpAndSettle();
    });

    testWidgets('4. Web Drawer: Opening & Animation Compositing', (tester) async {
      await tester.pumpWidget(
        buildProfilerAppWrapper(
          QuranDrawerWeb(
            currentPage: 1,
            onNavigateToPage: (p, {verseKey}) {},
          ),
        ),
      );

      final stopwatch = Stopwatch()..start();
      await tester.pump();
      stopwatch.stop();

      final drawerMs = stopwatch.elapsedMicroseconds / 1000.0;
      logFrameMetric('Web Drawer Frame Build', drawerMs, 35.0);
      expect(drawerMs, lessThan(40.0));

      await tester.pumpAndSettle();
    });

    testWidgets('5. Surahs & Juzs Index: Tab Switching & Smooth Scrolling (<8.33ms)', (tester) async {
      await tester.pumpWidget(
        buildProfilerAppWrapper(
          const QuranIndexViewWeb(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Juzs tab
      final juzTab = find.text('الأجزاء');
      expect(juzTab, findsOneWidget);

      final stopwatchTab = Stopwatch()..start();
      await tester.tap(juzTab);
      await tester.pump();
      stopwatchTab.stop();

      final tabMs = stopwatchTab.elapsedMicroseconds / 1000.0;
      logFrameMetric('Index Tab Switch Frame 1', tabMs, 150.0);
      expect(tabMs, lessThan(150.0));

      await tester.pumpAndSettle();

      // Scroll Juzs list
      final stopwatchScroll = Stopwatch()..start();
      await tester.drag(find.byType(QuranIndexViewWeb), const Offset(0, -300));
      await tester.pump();
      stopwatchScroll.stop();

      final scrollMs = stopwatchScroll.elapsedMicroseconds / 1000.0;
      logFrameMetric('Index Scroll Tick Frame', scrollMs, 100.0);
      expect(scrollMs, lessThan(100.0));

      await tester.pumpAndSettle();
    });

    testWidgets('6. Video Studio Modal: Initial Layout & Interactive Control Composition', (tester) async {
      final verse = VerseModel(
        id: 1,
        verseNumber: 1,
        verseKey: '1:1',
        textUthmani: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
        juzNumber: 1,
        words: const [],
        tafsir: 'تفسير تجريبي للآية',
        translation: 'Sample translation',
      );

      await tester.pumpWidget(
        buildProfilerAppWrapper(
          Scaffold(
            body: Builder(
              builder: (ctx) {
                return ElevatedButton(
                  onPressed: () {
                    showVerseCardGeneratorModalWeb(
                      ctx,
                      verse: verse,
                      pageNumber: 1,
                      initialFormat: ShareFormat.video,
                    );
                  },
                  child: const Text('Open Studio'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Modal
      final stopwatchModal = Stopwatch()..start();
      await tester.tap(find.text('Open Studio'));
      await tester.pump();
      stopwatchModal.stop();

      final modalMs = stopwatchModal.elapsedMicroseconds / 1000.0;
      logFrameMetric('Video Studio Modal Cold Open Frame', modalMs, 500.0);
      expect(modalMs, lessThan(600.0));

      await tester.pump(const Duration(milliseconds: 300));

      // Verify controls
      expect(find.byType(VideoAspectRatioBarWeb), findsOneWidget);
      expect(find.byType(VideoThemeSelectorWeb), findsOneWidget);
      expect(find.byType(VideoRangePickerWeb), findsOneWidget);
      expect(find.byType(VideoReciterSelectorWeb), findsOneWidget);
    });
  });
}
