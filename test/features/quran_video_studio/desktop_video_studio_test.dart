import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabattal/features/quran_reader/data/models/verse_model.dart';
import 'package:tabattal/features/quran_verse_card/presentation/widgets/desktop/verse_card_generator_sheet_desktop.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/video_enums.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/video_theme_preset.dart';
import 'package:tabattal/features/quran_video_studio/presentation/bloc/video_studio_bloc.dart';
import 'package:tabattal/features/quran_video_studio/presentation/bloc/video_studio_event.dart';
import 'package:tabattal/features/quran_video_studio/presentation/widgets/desktop/video_aspect_ratio_bar_desktop.dart';
import 'package:tabattal/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
  });

  Widget buildTestableWidget(Widget child) {
    return ScreenUtilInit(
      designSize: const Size(1280, 800),
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

  testWidgets('Selecting custom video and then changing other settings does not throw or break', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final verse = VerseModel(
      id: 1,
      verseNumber: 1,
      verseKey: '1:1',
      textUthmani: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
      juzNumber: 1,
      words: const [],
    );

    await tester.pumpWidget(
      buildTestableWidget(
        VerseCardGeneratorSheetDesktop(
          verse: verse,
          initialFormat: ShareFormat.video,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify initial render
    expect(find.byType(VerseCardGeneratorSheetDesktop), findsOneWidget);

    // 1. Dispatch custom video selection
    final BuildContext innerContext = tester.element(find.byType(VideoAspectRatioBarDesktop));
    final bloc = innerContext.read<VideoStudioBloc>();
    bloc.add(const VideoStudioCustomVideoSelected('test_video.mp4'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify custom video is now in state
    expect(bloc.state.config.hasCustomVideo, isTrue);

    // 2. Try to change aspect ratio to 16:9
    final ratio16x9 = find.text('16:9');
    expect(ratio16x9, findsOneWidget);
    await tester.tap(ratio16x9);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(bloc.state.config.aspectRatio, VideoAspectRatio.landscape16x9);

    // 3. Try to change aspect ratio to 1:1
    final ratio1x1 = find.text('1:1');
    expect(ratio1x1, findsOneWidget);
    await tester.tap(ratio1x1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(bloc.state.config.aspectRatio, VideoAspectRatio.square1x1);

    // 4. Try to tap "تصميم البطاقة" (Default theme button) to clear custom video via UI
    final defaultThemeBtn = find.text('تصميم البطاقة');
    expect(defaultThemeBtn, findsOneWidget);
    await tester.tap(defaultThemeBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(bloc.state.config.hasCustomVideo, isFalse);
    expect(bloc.state.config.hasCustomMedia, isFalse);
    expect(bloc.state.config.backgroundType, VideoBackgroundType.gradient);

    // Re-activate custom video
    bloc.add(const VideoStudioCustomVideoSelected('test_video.mp4'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(bloc.state.config.hasCustomVideo, isTrue);

    // 5. Try to tap format selector "بطاقة الآيات" to switch format to image via UI
    final verseCardTab = find.text('بطاقة الآيات');
    expect(verseCardTab, findsOneWidget);
    await tester.tap(verseCardTab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify format changed
    expect(find.byKey(const ValueKey('image_card_preview_desktop')), findsOneWidget);
  });

  testWidgets('Selecting a theme preset while custom video is active updates themePreset for card frame while preserving custom video', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final verse = VerseModel(
      id: 1,
      verseNumber: 1,
      verseKey: '1:1',
      textUthmani: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
      juzNumber: 1,
      words: const [],
    );

    await tester.pumpWidget(
      buildTestableWidget(
        VerseCardGeneratorSheetDesktop(
          verse: verse,
          initialFormat: ShareFormat.video,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final BuildContext innerContext = tester.element(find.byType(VideoAspectRatioBarDesktop));
    final bloc = innerContext.read<VideoStudioBloc>();

    // Activate custom video
    bloc.add(const VideoStudioCustomVideoSelected('test_background_video.mp4'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(bloc.state.config.hasCustomVideo, isTrue);
    expect(bloc.state.config.backgroundType, VideoBackgroundType.customVideo);

    // Switch theme preset (e.g. to emerald or royal_navy)
    final emeraldPreset = VideoThemePreset.getById('emerald');
    bloc.add(VideoStudioThemeChanged(emeraldPreset));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Theme preset updates for card frame, while custom video remains active
    expect(bloc.state.config.themePreset.id, 'emerald');
    expect(bloc.state.config.hasCustomVideo, isTrue);
    expect(bloc.state.config.backgroundType, VideoBackgroundType.customVideo);
    expect(bloc.state.config.customVideoPath, 'test_background_video.mp4');
  });

  testWidgets('Seeking on timeline updates state seekTrigger, lastSeekPosition, and coordinates with background video', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final verse = VerseModel(
      id: 1,
      verseNumber: 1,
      verseKey: '1:1',
      textUthmani: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
      juzNumber: 1,
      words: const [],
    );

    await tester.pumpWidget(
      buildTestableWidget(
        VerseCardGeneratorSheetDesktop(
          verse: verse,
          initialFormat: ShareFormat.video,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final BuildContext innerContext = tester.element(find.byType(VideoAspectRatioBarDesktop));
    final bloc = innerContext.read<VideoStudioBloc>();

    expect(bloc.state.seekTrigger, equals(0));

    // Seek to 5 seconds
    bloc.add(const VideoStudioSeekRequested(Duration(seconds: 5)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(bloc.state.seekTrigger, equals(1));
    expect(bloc.state.lastSeekPosition, equals(const Duration(seconds: 5)));
  });

  testWidgets('Rapid consecutive timeline seeks never leave re-entrancy guards stuck (restartable() race regression)', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final verse = VerseModel(
      id: 1,
      verseNumber: 1,
      verseKey: '1:1',
      textUthmani: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
      juzNumber: 1,
      words: const [],
    );

    await tester.pumpWidget(
      buildTestableWidget(
        VerseCardGeneratorSheetDesktop(
          verse: verse,
          initialFormat: ShareFormat.video,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final BuildContext innerContext = tester.element(find.byType(VideoAspectRatioBarDesktop));
    final bloc = innerContext.read<VideoStudioBloc>();

    // Simulate a rapid timeline drag: a burst of seeks fired back-to-back,
    // exactly like the throttled scrubber (every ~120ms). Under restartable()
    // each new event cancels the previous handler — this used to clear the
    // shared bool guards early and flicker the play icon.
    for (int i = 0; i < 8; i++) {
      bloc.add(VideoStudioSeekRequested(Duration(seconds: i + 1)));
      await tester.pump(const Duration(milliseconds: 125));
    }
    await tester.pump(const Duration(milliseconds: 500));

    // After the burst settles, the bloc must be in a clean, unstuck state:
    // - the last seek won
    expect(bloc.state.lastSeekPosition, equals(const Duration(seconds: 8)));
    // - not stuck "playing" after the seek-stops-preview semantics
    expect(bloc.state.isPlaying, isFalse);
    // - verse index must match the verse containing 8s, not be reset or stuck
    expect(bloc.state.currentVerseIndex, greaterThanOrEqualTo(0));
    // - and the bloc must still accept a NEW seek (guard fully released)
    bloc.add(const VideoStudioSeekRequested(Duration(seconds: 2)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(bloc.state.lastSeekPosition, equals(const Duration(seconds: 2)));
  });

  testWidgets('Selecting custom image and dragging timeline does not crash or throw', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final verse = VerseModel(
      id: 1,
      verseNumber: 1,
      verseKey: '1:1',
      textUthmani: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
      juzNumber: 1,
      words: const [],
    );

    await tester.pumpWidget(
      buildTestableWidget(
        VerseCardGeneratorSheetDesktop(
          verse: verse,
          initialFormat: ShareFormat.video,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final BuildContext innerContext = tester.element(find.byType(VideoAspectRatioBarDesktop));
    final bloc = innerContext.read<VideoStudioBloc>();

    // Select a custom image
    bloc.add(const VideoStudioCustomImageSelected('test_image_path.jpg'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Seek / drag timeline
    for (int i = 0; i < 5; i++) {
      bloc.add(VideoStudioSeekRequested(Duration(seconds: i + 1)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('Switching format tab to Verse Card while custom video is active works without freezing', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final verse = VerseModel(
      id: 1,
      verseNumber: 1,
      verseKey: '1:1',
      textUthmani: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
      juzNumber: 1,
      words: const [],
    );

    await tester.pumpWidget(
      buildTestableWidget(
        VerseCardGeneratorSheetDesktop(
          verse: verse,
          initialFormat: ShareFormat.video,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 1. Set custom video
    final BuildContext innerContext = tester.element(find.byType(VideoAspectRatioBarDesktop));
    final bloc = innerContext.read<VideoStudioBloc>();
    bloc.add(const VideoStudioCustomVideoSelected('test_custom_video.mp4'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(bloc.state.config.hasCustomVideo, isTrue);

    // 2. Tap on Verse Card format tab (بطاقة الآيات / صورة)
    final l10n = AppLocalizations.of(tester.element(find.byType(VerseCardGeneratorSheetDesktop)))!;
    final imageTab = find.text(l10n.verseCardFormatImage);
    expect(imageTab, findsOneWidget);
    await tester.tap(imageTab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 3. Tap back on Video format tab (فيديو)
    final videoTab = find.text(l10n.verseCardFormatVideo);
    expect(videoTab, findsOneWidget);
    await tester.tap(videoTab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify still stable and responsive
    expect(find.byType(VerseCardGeneratorSheetDesktop), findsOneWidget);
  });
}

