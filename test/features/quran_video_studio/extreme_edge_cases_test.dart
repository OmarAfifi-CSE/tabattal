// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:tabattal/features/quran_reader/data/models/verse_model.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/video_project_config.dart';
import 'package:tabattal/features/quran_video_studio/domain/repositories/i_video_studio_repository.dart';
import 'package:tabattal/features/quran_video_studio/presentation/bloc/video_studio_bloc.dart';
import 'package:tabattal/features/quran_video_studio/presentation/widgets/shared/video_background_player_view.dart';
import 'package:tabattal/features/quran_video_studio/presentation/widgets/shared/video_fullscreen_preview_modal.dart';
import 'package:tabattal/features/quran_video_studio/presentation/widgets/shared/video_timeline_scrubber.dart';
import 'package:tabattal/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class _MockRepo extends Fake implements IVideoStudioRepository {
  @override
  Future<List<VerseModel>> loadVersesForSpan({
    required int surahNumber,
    required int startAyah,
    required int endAyah,
  }) async => [];

  @override
  Future<List<String>> prepareVerseAudioFiles({
    required String reciterPath,
    required int surahNumber,
    required int startAyah,
    required int endAyah,
    void Function(double)? onDownloadProgress,
  }) async => [];

  @override
  Future<List<Duration>> measureVerseDurations({
    required List<String> audioFilePaths,
    int? firstAyahNumber,
  }) async => [];

  @override
  void cancelAudioPreparation() {}
}

class _MockPlatform extends JustAudioPlatform {
  late _MockPlayer player;
  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async => player = _MockPlayer(request.id);
  @override
  Future<DisposePlayerResponse> disposePlayer(DisposePlayerRequest request) async => DisposePlayerResponse();
  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(DisposeAllPlayersRequest request) async => DisposeAllPlayersResponse();
}

class _MockPlayer extends AudioPlayerPlatform {
  _MockPlayer(super.id);
  final events = StreamController<PlaybackEventMessage>.broadcast();
  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => events.stream;

  void broadcast([ProcessingStateMessage state = ProcessingStateMessage.ready, Duration position = Duration.zero]) {
    events.add(PlaybackEventMessage(
      processingState: state,
      updateTime: DateTime.now(),
      updatePosition: position,
      bufferedPosition: const Duration(seconds: 30),
      duration: const Duration(seconds: 30),
      currentIndex: 0,
      icyMetadata: null,
      androidAudioSessionId: null,
    ));
  }

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    broadcast();
    return LoadResponse(duration: const Duration(seconds: 30));
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async => PlayResponse();
  @override
  Future<PauseResponse> pause(PauseRequest request) async => PauseResponse();
  @override
  Future<SeekResponse> seek(SeekRequest request) async => SeekResponse();
  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async => SetVolumeResponse();
  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async => SetSpeedResponse();
  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async => SetPitchResponse();
  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async => SetLoopModeResponse();
  @override
  Future<SetShuffleModeResponse> setShuffleMode(SetShuffleModeRequest request) async => SetShuffleModeResponse();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MockPlatform platform;
  late _MockRepo repository;
  late VideoStudioBloc bloc;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_session'),
      (methodCall) async => null,
    );
    platform = _MockPlatform();
    JustAudioPlatform.instance = platform;
    repository = _MockRepo();
    bloc = VideoStudioBloc(
      repository: repository,
      initialConfig: const VideoProjectConfig(surahNumber: 1, startAyah: 1, endAyah: 2),
    );
  });

  tearDown(() async {
    await bloc.close();
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

  group('Extreme Edge Cases & Hardening Tests', () {
    testWidgets('Missing or corrupt video file shows graceful error card without infinite spinner', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const SizedBox(
            width: 300,
            height: 500,
            child: VideoBackgroundPlayerView(
              videoPath: '/path/does/not/exist/corrupt_file.mp4',
              isPlaying: false,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Must display the error card icon
      expect(find.byIcon(Icons.videocam_off_rounded), findsOneWidget);
      expect(find.text('تعذر تشغيل ملف الفيديو المحدد.'), findsOneWidget);

      // Must NOT show an endless circular progress indicator
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Timeline scrubber renders 2-hour long recitation without overflow on 320px narrow screen', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Total duration 2 hours (7200 seconds)
      bloc.emit(bloc.state.copyWith(
        verseDurations: const [Duration(hours: 2)],
      ));

      await tester.pumpWidget(
        buildTestableWidget(
          BlocProvider.value(
            value: bloc,
            child: VideoTimelineScrubber(
              state: bloc.state,
            ),
          ),
          size: const Size(320, 568),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(VideoTimelineScrubber), findsOneWidget);
    });

    testWidgets('Fullscreen preview modal renders cleanly directly as a widget', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bloc.emit(bloc.state.copyWith(
        verses: [
          VerseModel(
            id: 1,
            verseNumber: 1,
            verseKey: '1:1',
            textUthmani: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
            juzNumber: 1,
            words: const [],
          ),
        ],
        verseDurations: const [Duration(seconds: 15)],
      ));

      await tester.pumpWidget(
        buildTestableWidget(
          BlocProvider.value(
            value: bloc,
            child: const VideoFullscreenPreviewModal(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(VideoFullscreenPreviewModal), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byIcon(Icons.fullscreen_exit_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tapping pause or closing fullscreen preview modal immediately stops audio', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bloc.emit(bloc.state.copyWith(
        verses: [
          VerseModel(
            id: 1,
            verseNumber: 1,
            verseKey: '1:1',
            textUthmani: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
            juzNumber: 1,
            words: const [],
          ),
        ],
        verseDurations: const [Duration(seconds: 10)],
        audioFilePaths: const ['https://everyayah.com/data/test/001001.mp3'],
        isPlaying: true,
      ));

      await tester.pumpWidget(
        buildTestableWidget(
          BlocProvider.value(
            value: bloc,
            child: const VideoFullscreenPreviewModal(),
          ),
        ),
      );
      await tester.pump();

      // Verify pause icon is shown
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      // Tap pause button
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();

      // Audio must now be paused!
      expect(bloc.state.isPlaying, isFalse);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      // Now play again
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(bloc.state.isPlaying, isTrue);

      // Tap close button on top bar: must pause playback!
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(bloc.state.isPlaying, isFalse);
    });
  });
}
