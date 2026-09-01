import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabattal/features/quran_bookmarks/domain/repositories/bookmark_repository.dart';
import 'package:tabattal/features/quran_bookmarks/presentation/bloc/bookmark_bloc.dart';
import 'package:tabattal/features/quran_bookmarks/presentation/widgets/web/quran_bookmarks_view_web.dart';
import 'package:tabattal/features/quran_reader/domain/repositories/quran_repository.dart';
import 'package:tabattal/features/quran_reader/presentation/widgets/drawer/web/quran_index_view_web.dart';
import 'package:tabattal/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MockQuranRepository extends Fake implements QuranRepository {}

class FakeBookmarkRepository extends Fake implements BookmarkRepository {
  @override
  Future<List<String>> loadBookmarks() async => [];

  @override
  Future<List<String>> toggle(String verseKey) async => [verseKey];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget(Widget child, {List<BlocProvider>? blocProviders}) {
    return ScreenUtilInit(
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
        home: RepositoryProvider<QuranRepository>(
          create: (_) => MockQuranRepository(),
          child: blocProviders != null
              ? MultiBlocProvider(providers: blocProviders, child: child)
              : child,
        ),
      ),
    );
  }

  group('🖥️ Web UI Flow & Integration Tests', () {
    testWidgets('1. Quran Index View Web (Surahs & Juzs Tab Navigation)', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          Navigator(
            onGenerateRoute: (settings) => MaterialPageRoute(
              builder: (context) => const QuranIndexViewWeb(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify TabBar is visible with 2 tabs
      expect(find.text('السور'), findsOneWidget);
      expect(find.text('الأجزاء'), findsOneWidget);

      // Verify Surah Al-Fatihah and Al-Baqarah are displayed
      expect(find.text('سورة الفاتحة'), findsOneWidget);
      expect(find.text('سورة البقرة'), findsOneWidget);

      // Tap on the Juzs tab
      await tester.tap(find.text('الأجزاء'));
      await tester.pumpAndSettle();

      // Verify Juz list items are rendered
      expect(find.text('الجزء الأول'), findsOneWidget);
      expect(find.text('الجزء الثاني'), findsOneWidget);

      // Tap on Juz 2 tile
      await tester.tap(find.text('الجزء الثاني'));
      await tester.pumpAndSettle();
    });

    testWidgets('2. Quran Bookmarks View Web (Empty State & Fast Rendering)', (tester) async {
      final bookmarkBloc = BookmarkBloc(repository: FakeBookmarkRepository());

      await tester.pumpWidget(
        buildTestableWidget(
          const QuranBookmarksViewWeb(),
          blocProviders: [
            BlocProvider<BookmarkBloc>.value(value: bookmarkBloc),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Verify Empty Bookmarks State renders cleanly
      expect(find.text('لا توجد علامات مرجعية'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
    });
  });
}
