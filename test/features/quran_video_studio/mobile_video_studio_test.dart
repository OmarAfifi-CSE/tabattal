import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabattal/features/quran_reader/data/models/verse_model.dart';
import 'package:tabattal/features/quran_verse_card/presentation/widgets/mobile/verse_card_generator_sheet_mobile.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/video_enums.dart';
import 'package:tabattal/features/quran_video_studio/presentation/bloc/video_studio_bloc.dart';
import 'package:tabattal/features/quran_video_studio/presentation/bloc/video_studio_event.dart';
import 'package:tabattal/features/quran_video_studio/presentation/widgets/mobile/video_aspect_ratio_bar_mobile.dart';
import 'package:tabattal/features/quran_video_studio/presentation/widgets/shared/video_preview_viewport.dart';
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
      designSize: const Size(375, 812),
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

  testWidgets('Mobile VerseCardGeneratorSheetMobile renders video preview without layout overflow', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
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
        VerseCardGeneratorSheetMobile(
          verse: verse,
          initialFormat: ShareFormat.video,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify initial render
    expect(find.byType(VerseCardGeneratorSheetMobile), findsOneWidget);
    expect(find.byType(VideoPreviewViewport), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 1. Dispatch custom video selection
    final BuildContext innerContext = tester.element(find.byType(VideoAspectRatioBarMobile));
    final bloc = innerContext.read<VideoStudioBloc>();

    bloc.add(const VideoStudioCustomVideoSelected('mobile_custom_video.mp4'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(bloc.state.config.hasCustomVideo, isTrue);
    expect(bloc.state.config.customVideoPath, 'mobile_custom_video.mp4');

    // 2. Change aspect ratio to 1:1 on mobile
    final ratio1x1 = find.text('1:1');
    expect(ratio1x1, findsOneWidget);
    await tester.ensureVisible(ratio1x1);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(ratio1x1, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(bloc.state.config.aspectRatio, VideoAspectRatio.square1x1);

    // 3. Change aspect ratio to 16:9 on mobile
    final ratio16x9 = find.text('16:9');
    expect(ratio16x9, findsOneWidget);
    await tester.ensureVisible(ratio16x9);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(ratio16x9, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(bloc.state.config.aspectRatio, VideoAspectRatio.landscape16x9);

    // 4. Change background dimming
    bloc.add(const VideoStudioDimmingChanged(0.65));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(bloc.state.config.backgroundDimming, 0.65);
    expect(tester.takeException(), isNull);
  });
}
