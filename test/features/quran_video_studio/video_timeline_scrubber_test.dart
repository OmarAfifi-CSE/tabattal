// ignore_for_file: depend_on_referenced_packages, invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
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
import 'package:tabattal/features/quran_video_studio/presentation/bloc/video_studio_event.dart';
import 'package:tabattal/features/quran_video_studio/presentation/bloc/video_studio_state.dart';
import 'package:tabattal/features/quran_video_studio/presentation/widgets/shared/video_timeline_scrubber.dart';

class _MockRepo extends Fake implements IVideoStudioRepository {
  @override
  Future<List<VerseModel>> loadVersesForSpan({required int surahNumber, required int startAyah, required int endAyah}) async => [];
  @override
  Future<List<String>> prepareVerseAudioFiles({required String reciterPath, required int surahNumber, required int startAyah, required int endAyah, void Function(double)? onDownloadProgress}) async => [];
  @override
  Future<List<Duration>> measureVerseDurations({required List<String> audioFilePaths, int? firstAyahNumber}) async => [];
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
  Future<SeekResponse> seek(SeekRequest request) async {
    broadcast(ProcessingStateMessage.ready, request.position ?? Duration.zero);
    return SeekResponse();
  }
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
  late VideoStudioBloc bloc;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_session'), (_) async => null);
    JustAudioPlatform.instance = _MockPlatform();
    bloc = VideoStudioBloc(
      repository: _MockRepo(),
      initialConfig: const VideoProjectConfig(surahNumber: 1, startAyah: 1, endAyah: 2),
    );
    bloc.emit(bloc.state.copyWith(
      verses: [
        VerseModel(id: 1, verseNumber: 1, verseKey: '1:1', textUthmani: 'آية 1', juzNumber: 1, words: const []),
        VerseModel(id: 2, verseNumber: 2, verseKey: '1:2', textUthmani: 'آية 2', juzNumber: 1, words: const []),
      ],
      audioFilePaths: const ['https://example.invalid/1.mp3', 'https://example.invalid/2.mp3'],
      verseDurations: const [Duration(seconds: 20), Duration(seconds: 40)], // Total = 60s
    ));
  });

  tearDown(() async {
    await bloc.close();
  });

  Widget buildTestableWidget([Widget Function(VideoStudioState state)? builder]) {
    return MaterialApp(
      home: ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (context, _) => Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: BlocBuilder<VideoStudioBloc, VideoStudioState>(
              builder: (context, state) =>
                  builder != null ? builder(state) : VideoTimelineScrubber(state: state),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('VideoTimelineScrubber renders total duration correctly and updates on position stream', (tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Total 60 seconds should be formatted as 1:00
    expect(find.text('1:00'), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);

    await tester.runAsync(() async {
      bloc.add(const VideoStudioSeekRequested(Duration(seconds: 30)));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    // Display should reflect 0:30
    expect(find.text('0:30'), findsOneWidget);
    expect(find.text('1:00'), findsOneWidget);
  });

  testWidgets('VideoTimelineScrubber resets cleanly to 0:00 when VideoStudioPlaybackReset fires', (tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pump();

    // Move to verse 1 at 30 seconds
    await tester.runAsync(() async {
      bloc.add(const VideoStudioSeekRequested(Duration(seconds: 30)));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(find.text('0:30'), findsOneWidget);

    // Trigger atomic reset
    await tester.runAsync(() async {
      bloc.add(const VideoStudioPlaybackReset());
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    // Must show 0:00, not verse 1 start or anything else
    expect(find.text('0:00'), findsOneWidget);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 0.0);
  });

  testWidgets('VideoTimelineScrubber with zero total duration returns SizedBox.shrink', (tester) async {
    final emptyState = bloc.state.copyWith(verseDurations: const []);
    await tester.pumpWidget(buildTestableWidget((_) => VideoTimelineScrubber(state: emptyState)));
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsNothing);
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('VideoTimelineScrubber user dragging slider triggers throttled and final seek', (tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pump();

    final sliderFinder = find.byType(Slider);
    expect(sliderFinder, findsOneWidget);

    await tester.runAsync(() async {
      final center = tester.getCenter(sliderFinder);
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(40, 0));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await gesture.up();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(bloc.state.seekTrigger, greaterThan(0));
    expect(bloc.state.lastSeekPosition, isNotNull);
  });

  testWidgets('VideoTimelineScrubber renders in landscape and dark mode without throwing or overflow', (tester) async {
    await tester.pumpWidget(buildTestableWidget((state) => VideoTimelineScrubber(
      state: state,
      isLandscape: true,
      isDark: true,
    )));
    await tester.pump();

    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('1:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('VideoTimelineScrubber seeking to exact end boundary updates properly', (tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pump();

    await tester.runAsync(() async {
      bloc.add(const VideoStudioSeekRequested(Duration(seconds: 60)));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.text('1:00'), findsNWidgets(2)); // Current is 1:00, Total is 1:00
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 60000.0);
  });

  testWidgets('VideoTimelineScrubber with merged audio reflects continuous timeline and does not jump on verse change', (tester) async {
    bloc.emit(bloc.state.copyWith(
      mergedPreviewAudioPath: 'C:\\fake_merged.mp3',
    ));

    await tester.pumpWidget(buildTestableWidget());
    await tester.pump();

    // Initial state: 0:00 / 1:00
    expect(find.text('0:00'), findsOneWidget);
    expect(find.text('1:00'), findsOneWidget);

    // Seek across verse boundary into verse 1 (e.g. 25 seconds, since verse 0 is 20s)
    await tester.runAsync(() async {
      bloc.add(const VideoStudioSeekRequested(Duration(seconds: 25)));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.text('0:25'), findsOneWidget);
    expect(bloc.state.currentVerseIndex, 1);

    // Non-user-initiated verse change (ticker natural progression) must NOT reset timeline or jump back
    await tester.runAsync(() async {
      bloc.add(const VideoStudioActiveVerseIndexChanged(1, isUserInitiated: false));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    // Still at 0:25, didn't reset to 0:00!
    expect(find.text('0:25'), findsOneWidget);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 25000.0);
  });

  testWidgets('VideoTimelineScrubber resets to 0:00 when reciter changes', (tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pump();

    // Seek to 0:25 first
    await tester.runAsync(() async {
      bloc.add(const VideoStudioSeekRequested(Duration(seconds: 25)));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(find.text('0:25'), findsOneWidget);

    // Change reciter
    await tester.runAsync(() async {
      bloc.add(const VideoStudioReciterChanged(
        reciterName: 'محمود خليل الحصري',
        reciterCategory: 'مرتل',
        reciterPath: 'Husary_128kbps',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    // Must reset to 0:00 immediately
    expect(find.text('0:00'), findsOneWidget);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 0.0);
  });
}
