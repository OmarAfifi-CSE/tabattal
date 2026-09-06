// ignore_for_file: depend_on_referenced_packages, invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:tabattal/features/quran_reader/data/models/verse_model.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/video_enums.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/video_project_config.dart';
import 'package:tabattal/features/quran_video_studio/domain/repositories/i_video_studio_repository.dart';
import 'package:tabattal/features/quran_video_studio/presentation/bloc/video_studio_bloc.dart';
import 'package:tabattal/features/quran_video_studio/presentation/bloc/video_studio_event.dart';

class _ChaosRepository extends Fake implements IVideoStudioRepository {
  Completer<void>? loadGate;
  int loadCalls = 0;
  bool shouldThrow = false;

  @override
  Future<List<VerseModel>> loadVersesForSpan({
    required int surahNumber,
    required int startAyah,
    required int endAyah,
  }) async {
    loadCalls++;
    if (shouldThrow) throw Exception('Simulated network error');
    if (loadGate != null) await loadGate!.future;
    return List.generate(
      endAyah - startAyah + 1,
      (i) => VerseModel(
        id: startAyah + i,
        verseNumber: startAyah + i,
        verseKey: '$surahNumber:${startAyah + i}',
        textUthmani: 'آية ${startAyah + i}',
        juzNumber: 1,
        words: const [],
      ),
    );
  }

  @override
  Future<List<String>> prepareVerseAudioFiles({
    required String reciterPath,
    required int surahNumber,
    required int startAyah,
    required int endAyah,
    void Function(double)? onDownloadProgress,
  }) async {
    if (shouldThrow) throw Exception('Simulated download error');
    return List.generate(
      endAyah - startAyah + 1,
      (i) => 'https://example.invalid/$surahNumber/${startAyah + i}.mp3',
    );
  }

  @override
  Future<List<Duration>> measureVerseDurations({
    required List<String> audioFilePaths,
  }) async {
    if (shouldThrow) throw Exception('Simulated probe error');
    return List.filled(audioFilePaths.length, const Duration(seconds: 25));
  }
}

class _ChaosPlatform extends JustAudioPlatform {
  late _ChaosPlayer player;
  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async => player = _ChaosPlayer(request.id);
  @override
  Future<DisposePlayerResponse> disposePlayer(DisposePlayerRequest request) async {
    await player.events.close();
    return DisposePlayerResponse();
  }
  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(DisposeAllPlayersRequest request) async => DisposeAllPlayersResponse();
}

class _ChaosPlayer extends AudioPlayerPlatform {
  _ChaosPlayer(super.id);
  final events = StreamController<PlaybackEventMessage>.broadcast();
  bool isPlaying = false;
  String? currentLoadedUri;

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => events.stream;

  void broadcast([
    ProcessingStateMessage state = ProcessingStateMessage.ready,
    Duration position = Duration.zero,
  ]) {
    events.add(PlaybackEventMessage(
      processingState: state,
      updateTime: DateTime.now(),
      updatePosition: position,
      bufferedPosition: const Duration(seconds: 60),
      duration: const Duration(seconds: 25),
      currentIndex: 0,
      icyMetadata: null,
      androidAudioSessionId: null,
    ));
  }

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    AudioSourceMessage source = request.audioSourceMessage;
    while (source is ConcatenatingAudioSourceMessage) {
      source = source.children.first;
    }
    if (source is UriAudioSourceMessage) {
      currentLoadedUri = source.uri;
    }
    broadcast();
    return LoadResponse(duration: const Duration(seconds: 25));
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    isPlaying = true;
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    isPlaying = false;
    return PauseResponse();
  }

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
  late _ChaosPlatform platform;
  late _ChaosRepository repository;
  late VideoStudioBloc bloc;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_session'),
      (_) async => null,
    );
    platform = _ChaosPlatform();
    JustAudioPlatform.instance = platform;
    repository = _ChaosRepository();
    bloc = VideoStudioBloc(
      repository: repository,
      initialConfig: const VideoProjectConfig(surahNumber: 1, startAyah: 1, endAyah: 4),
    );
    bloc.emit(bloc.state.copyWith(
      verses: List.generate(
        4,
        (i) => VerseModel(
          id: i + 1,
          verseNumber: i + 1,
          verseKey: '1:${i + 1}',
          textUthmani: 'آية ${i + 1}',
          juzNumber: 1,
          words: const [],
        ),
      ),
      audioFilePaths: const [
        'https://example.invalid/1/1.mp3',
        'https://example.invalid/1/2.mp3',
        'https://example.invalid/1/3.mp3',
        'https://example.invalid/1/4.mp3',
      ],
      verseDurations: const [
        Duration(seconds: 20),
        Duration(seconds: 30),
        Duration(seconds: 25),
        Duration(seconds: 35),
      ], // Total = 110s
    ));
  });

  tearDown(() async {
    await bloc.close();
  });

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 60));

  group('Real User Complex Multi-Step Journey Tests', () {
    test('User journey: play -> seek while playing -> change settings -> finish -> replay', () async {
      // 1. Initial State: total duration 110s, at rest
      expect(bloc.state.totalVideoDuration, const Duration(seconds: 110));
      expect(bloc.state.currentVerseIndex, 0);
      expect(bloc.state.isPlaying, isFalse);

      // 2. User presses Play
      bloc.add(const VideoStudioPlaybackToggled());
      await settle();
      expect(bloc.state.isPlaying, isTrue);
      expect(bloc.isPositionTickerActive, isTrue);

      // 3. User drags scrubber to 35 seconds (which is in Verse 2 with 15s offset)
      final initialSeekTrigger = bloc.state.seekTrigger;
      bloc.add(const VideoStudioSeekRequested(Duration(seconds: 35)));
      await settle();

      expect(bloc.state.currentVerseIndex, 1);
      expect(bloc.currentVersePosition.inSeconds, 15);
      expect(bloc.state.seekTrigger, initialSeekTrigger + 1);
      expect(bloc.state.isPlaying, isTrue, reason: 'Seeking while playing must continue playing');

      // 4. User changes aspect ratio to 16:9 while playing
      bloc.add(const VideoStudioAspectRatioChanged(VideoAspectRatio.landscape16x9));
      await settle();
      expect(bloc.state.config.aspectRatio, VideoAspectRatio.landscape16x9);
      expect(bloc.state.isPlaying, isTrue);

      // 5. User changes background dimming while playing
      bloc.add(const VideoStudioDimmingChanged(0.75));
      await settle();
      expect(bloc.state.config.backgroundDimming, 0.75);

      // 6. User selects custom video background while playing
      bloc.add(const VideoStudioCustomVideoSelected('https://assets.invalid/bg.mp4'));
      await settle();
      expect(bloc.state.config.hasCustomVideo, isTrue);

      // 7. Natural playlist transition to Verse 3 (index 2)
      final preProgressionSeekTrigger = bloc.state.seekTrigger;
      bloc.add(const VideoStudioActiveVerseIndexChanged(2, isUserInitiated: false));
      await settle();
      expect(bloc.state.currentVerseIndex, 2);
      expect(bloc.state.seekTrigger, preProgressionSeekTrigger, reason: 'Natural audio progression must NOT trigger seeking');

      // 8. Natural playlist transition to Verse 4 (index 3 - last verse)
      bloc.add(const VideoStudioActiveVerseIndexChanged(3, isUserInitiated: false));
      await settle();
      expect(bloc.state.currentVerseIndex, 3);
      expect(bloc.state.seekTrigger, preProgressionSeekTrigger);

      // 9. Playback completes at the end of Verse 4 -> triggers reset
      bloc.add(const VideoStudioPlaybackReset());
      await settle();

      expect(bloc.state.currentVerseIndex, 0);
      expect(bloc.currentVersePosition, Duration.zero);
      expect(bloc.state.isPlaying, isFalse);
      expect(bloc.isPositionTickerActive, isFalse);

      // 10. User clicks Play again -> must start cleanly from beginning
      bloc.add(const VideoStudioPlaybackToggled());
      await settle();
      expect(bloc.state.isPlaying, isTrue);
      expect(bloc.state.currentVerseIndex, 0);
      expect(bloc.isPositionTickerActive, isTrue);
    });
  });

  group('Harsh Stress & Chaos Monkey Tests', () {
    test('Rapid-fire 25 Play/Pause clicks process sequentially without lockup or crash', () async {
      expect(bloc.state.isPlaying, isFalse);

      // Dispatch 25 rapid toggle events
      for (int i = 0; i < 25; i++) {
        bloc.add(const VideoStudioPlaybackToggled());
      }
      await settle();
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // 25 toggles starting from false: 25 % 2 == 1 -> ends at true
      expect(bloc.state.isPlaying, isTrue);
      expect(bloc.isPositionTickerActive, isTrue);
    });

    test('Concurrent conflicting seeks across multiple verses settle safely to last seek', () async {
      // Rapidly fire conflicting seeks across different verses
      bloc.add(const VideoStudioSeekRequested(Duration(seconds: 10))); // verse 0
      bloc.add(const VideoStudioSeekRequested(Duration(seconds: 40))); // verse 1
      bloc.add(const VideoStudioSeekRequested(Duration(seconds: 65))); // verse 2
      bloc.add(const VideoStudioSeekRequested(Duration(seconds: 90))); // verse 3
      bloc.add(const VideoStudioSeekRequested(Duration(seconds: 5)));  // back to verse 0
      bloc.add(const VideoStudioSeekRequested(Duration(seconds: 45))); // verse 1 (final)

      await settle();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // 45s is in verse 1 (offset 25s since verse 0 = 20s)
      expect(bloc.state.currentVerseIndex, 1);
      expect(bloc.currentVersePosition, const Duration(seconds: 25));
    });

    test('Out-of-bounds seeking (negative ms and 1,000,000 ms) clamps cleanly without crash', () async {
      // Seek negative
      bloc.add(const VideoStudioSeekRequested(Duration(seconds: -100)));
      await settle();
      expect(bloc.state.currentVerseIndex, 0);
      expect(bloc.currentVersePosition, Duration.zero);

      // Seek far beyond total duration (total is 110s)
      bloc.add(const VideoStudioSeekRequested(Duration(seconds: 9999)));
      await settle();
      expect(bloc.state.currentVerseIndex, 3); // Clamped to last verse
      expect(bloc.currentVersePosition, const Duration(seconds: 35)); // Clamped to verse 4 duration
    });

    test('Changing reciter mid-playback stops old playback, ticker, and resets to verse 0', () async {
      bloc.add(const VideoStudioPlaybackToggled());
      await settle();
      expect(bloc.state.isPlaying, isTrue);
      expect(bloc.isPositionTickerActive, isTrue);

      // Move to verse 2
      bloc.add(const VideoStudioActiveVerseIndexChanged(2));
      await settle();
      expect(bloc.state.currentVerseIndex, 2);

      // Change reciter
      bloc.add(const VideoStudioReciterChanged(
        reciterName: 'المنشاوي',
        reciterCategory: 'مرتل',
        reciterPath: 'Minshawi_Murattal_128kbps',
      ));
      await settle();

      expect(bloc.state.currentVerseIndex, 0);
      expect(bloc.state.isPlaying, isFalse);
      expect(bloc.isPositionTickerActive, isFalse);
      expect(bloc.state.config.reciterName, 'المنشاوي');
    });

    test('Out-of-bounds active verse indices (-50, +500) clamp safely', () async {
      bloc.add(const VideoStudioActiveVerseIndexChanged(-50));
      await settle();
      expect(bloc.state.currentVerseIndex, 0);

      bloc.add(const VideoStudioActiveVerseIndexChanged(500));
      await settle();
      expect(bloc.state.currentVerseIndex, 3); // Clamped to verses.length - 1
    });

    test('Gracefully handles empty audio files and durations lists without throwing', () async {
      bloc.emit(bloc.state.copyWith(
        audioFilePaths: const [],
        verseDurations: const [],
      ));

      expect(() => bloc.add(const VideoStudioPlaybackToggled()), returnsNormally);
      expect(() => bloc.add(const VideoStudioSeekRequested(Duration(seconds: 10))), returnsNormally);
      expect(() => bloc.add(const VideoStudioPlaybackReset()), returnsNormally);
      await settle();

      expect(bloc.state.totalVideoDuration, Duration.zero);
    });
  });
}
