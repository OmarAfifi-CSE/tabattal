import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabattal/features/quran_reader/data/models/verse_model.dart';
import 'package:tabattal/features/quran_verse_card/presentation/widgets/web/verse_card_generator_sheet_web.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/video_enums.dart';
import 'package:tabattal/features/quran_video_studio/presentation/bloc/video_studio_bloc.dart';
import 'package:tabattal/features/quran_video_studio/presentation/bloc/video_studio_event.dart';
import 'package:tabattal/features/quran_video_studio/presentation/widgets/web/video_aspect_ratio_bar_web.dart';
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
      designSize: const Size(1440, 900),
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

  testWidgets('Web VerseCardGeneratorSheetWeb renders widescreen desktop/web controls smoothly', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
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
        VerseCardGeneratorSheetWeb(
          verse: verse,
          initialFormat: ShareFormat.video,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify initial render
    expect(find.byType(VerseCardGeneratorSheetWeb), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 1. Dispatch custom video selection on web
    final BuildContext innerContext = tester.element(find.byType(VideoAspectRatioBarWeb));
    final bloc = innerContext.read<VideoStudioBloc>();

    bloc.add(const VideoStudioCustomVideoSelected('blob:http://localhost:8080/test_web_video'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(bloc.state.config.hasCustomVideo, isTrue);
    expect(bloc.state.config.customVideoPath, 'blob:http://localhost:8080/test_web_video');

    // 2. Change aspect ratio to 16:9 on web
    final ratio16x9 = find.text('16:9');
    expect(ratio16x9, findsOneWidget);
    await tester.tap(ratio16x9);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(bloc.state.config.aspectRatio, VideoAspectRatio.landscape16x9);

    // 3. Change aspect ratio to 1:1 on web
    final ratio1x1 = find.text('1:1');
    expect(ratio1x1, findsOneWidget);
    await tester.tap(ratio1x1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(bloc.state.config.aspectRatio, VideoAspectRatio.square1x1);
    expect(tester.takeException(), isNull);
  });
}
