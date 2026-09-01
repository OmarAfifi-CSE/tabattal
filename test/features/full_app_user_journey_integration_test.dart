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
import 'package:tabattal/core/theme/app_theme.dart';
import 'package:tabattal/features/quran_audio/presentation/bloc/audio_bloc.dart';
import 'package:tabattal/features/quran_audio/presentation/bloc/audio_event.dart';
import 'package:tabattal/features/quran_audio/presentation/bloc/audio_state.dart';
import 'package:tabattal/features/quran_bookmarks/domain/repositories/bookmark_repository.dart';
import 'package:tabattal/features/quran_bookmarks/presentation/bloc/bookmark_bloc.dart';
import 'package:tabattal/features/quran_bookmarks/presentation/bloc/bookmark_event.dart';
import 'package:tabattal/features/quran_hifz/presentation/bloc/hifz_bloc.dart';
import 'package:tabattal/features/quran_hifz/presentation/bloc/hifz_event.dart';
import 'package:tabattal/features/quran_reader/presentation/bloc/quran_bloc.dart';
import 'package:tabattal/features/quran_reader/presentation/bloc/quran_page_cache.dart';
import 'package:tabattal/features/quran_reader/presentation/bloc/quran_state.dart';
import 'package:tabattal/features/quran_reader/data/models/verse_model.dart';
import 'package:tabattal/features/quran_reader/domain/repositories/quran_repository.dart';
import 'package:tabattal/features/quran_reader/presentation/screens/web/quran_web_screen.dart';
import 'package:tabattal/features/quran_reader/presentation/widgets/drawer/web/quran_drawer_web.dart';
import 'package:tabattal/features/quran_reader/presentation/widgets/drawer/web/quran_index_view_web.dart';
import 'package:tabattal/features/quran_search/data/models/search_verse_model.dart';
import 'package:tabattal/features/quran_search/presentation/screens/web/quran_search_screen_web.dart';
import 'package:tabattal/features/quran_bookmarks/presentation/widgets/web/quran_bookmarks_view_web.dart';
import 'package:tabattal/features/quran_verse_card/presentation/widgets/web/verse_card_generator_sheet_web.dart';
import 'package:tabattal/features/quran_video_studio/presentation/widgets/web/video_background_selector_web.dart';
import 'package:tabattal/features/quran_video_studio/presentation/widgets/web/video_range_picker_web.dart';
import 'package:tabattal/features/quran_video_studio/presentation/widgets/web/video_reciter_selector_web.dart';
import 'package:tabattal/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:tabattal/l10n/app_localizations.dart';

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
  final List<String> _bookmarks = ['1:1', '1:2'];

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

    // Pre-populate page cache for pages 1 through 10
    for (int p = 1; p <= 10; p++) {
      QuranPageCache.put(p, createMockQuranPage(p));
    }
  });

  Widget buildFullAppWrapper(Widget child, {
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
            theme: appTheme(),
            home: child,
          ),
        ),
      ),
    );
  }

  group('🌐 COMPLETE USER JOURNEY & INTERACTION BENCHMARKS', () {
    testWidgets('Journey 1: Quran Web Screen Loading, Page Flipping & Gestures', (tester) async {
      await tester.pumpWidget(buildFullAppWrapper(const QuranWebScreen()));
      await tester.pumpAndSettle();

      // Verify Page 1 rendered
      expect(find.byType(QuranWebScreen), findsOneWidget);

      // Simulate horizontal swipe gesture to next page
      final stopwatch = Stopwatch()..start();
      await tester.drag(find.byType(QuranWebScreen), const Offset(-400, 0));
      await tester.pumpAndSettle();
      stopwatch.stop();

      // Frame settle budget verification
      expect(stopwatch.elapsedMilliseconds, lessThan(300),
          reason: 'Page drag transition must settle instantly without frame freeze');
    });

    testWidgets('Journey 2: Hifz Mode Activation & Word Masking/Revealing', (tester) async {
      await tester.pumpWidget(
        buildFullAppWrapper(
          const QuranWebScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger Hifz mode activation
      final stopwatch = Stopwatch()..start();
      tester.element(find.byType(QuranWebScreen)).read<HifzBloc>().add(
        const ToggleHifzMode(enabled: true),
      );
      tester.element(find.byType(QuranWebScreen)).read<HifzBloc>().add(
        const SetHifzMaskingType(HifzMaskingType.wordByWord),
      );
      await tester.pumpAndSettle();
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(300),
          reason: 'Hifz masking state toggle must apply in <300ms');
    });

    testWidgets('Journey 3: Web Drawer Navigation, Index & Bookmarks Explorer', (tester) async {
      await tester.pumpWidget(
        buildFullAppWrapper(
          QuranDrawerWeb(
            currentPage: 1,
            onNavigateToPage: (p, {verseKey}) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Drawer Items Rendered
      expect(find.text('البحث المتقدم'), findsOneWidget);
      expect(find.text('الفهرس'), findsOneWidget);
      expect(find.text('العلامات المرجعية'), findsOneWidget);

      // Verify Scroll Direction Toggle
      expect(find.text('اتجاه التمرير'), findsOneWidget);
    });

    testWidgets('Journey 4: Surah & Juz Index Full Search & Tab Switching', (tester) async {
      await tester.pumpWidget(
        buildFullAppWrapper(
          const QuranIndexViewWeb(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Juz tab
      await tester.tap(find.text('الأجزاء'));
      await tester.pumpAndSettle();

      // Verify Juz list rendered
      expect(find.text('الجزء الأول'), findsOneWidget);

      // Switch back to Surahs tab
      await tester.tap(find.text('السور'));
      await tester.pumpAndSettle();

      // Verify Surah Al-Fatihah tile rendered
      expect(find.text('سورة الفاتحة'), findsOneWidget);
    });

    testWidgets('Journey 5: Quran Search Screen Debouncing & Topic Filters', (tester) async {
      await tester.pumpWidget(
        buildFullAppWrapper(
          const QuranSearchScreenWeb(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify search input rendered
      expect(find.byType(TextField), findsOneWidget);

      // Verify topic sections rendered
      expect(find.byIcon(Icons.auto_stories_rounded), findsWidgets);

      // Type search query
      await tester.enterText(find.byType(TextField), 'الله');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
    });

    testWidgets('Journey 6: Verse Action Bottom Sheet & Bookmarking Pathway', (tester) async {
      final bookmarkBloc = BookmarkBloc(repository: FullMockBookmarkRepository());
      await tester.pumpWidget(
        buildFullAppWrapper(
          const QuranBookmarksViewWeb(),
          bookmarkRepo: FullMockBookmarkRepository(),
        ),
      );
      await tester.pumpAndSettle();

      // Toggle a bookmark
      bookmarkBloc.add(const ToggleBookmark('1:3'));
      await tester.pumpAndSettle();
    });

    testWidgets('Journey 7: Video Studio Full Modal & Interactive Controls', (tester) async {
      final verse = VerseModel(
        id: 1,
        verseNumber: 1,
        verseKey: '1:1',
        textUthmani: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
        juzNumber: 1,
        words: const [],
        tafsir: 'تفسير تجريبي للبسملة',
        translation: 'In the name of Allah',
      );

      await tester.pumpWidget(
        buildFullAppWrapper(
          Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showVerseCardGeneratorModalWeb(
                      context,
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
      await tester.tap(find.text('Open Studio'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Video Studio Controls are rendered
      expect(find.byType(VideoReciterSelectorWeb), findsOneWidget);
      expect(find.byType(VideoRangePickerWeb), findsOneWidget);
      expect(find.byType(VideoBackgroundSelectorWeb), findsOneWidget);
    });
  });
}
