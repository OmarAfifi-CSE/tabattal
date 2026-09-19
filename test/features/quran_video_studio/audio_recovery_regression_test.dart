// Regression tests for the Windows audio recovery & intent-queuing changes.
// ignore_for_file: depend_on_referenced_packages, invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:tabattal/features/quran_reader/data/models/verse_model.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/video_enums.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/video_project_config.dart';
import 'package:tabattal/features/quran_video_studio/domain/repositories/i_video_studio_repository.dart';
import 'package:tabattal/features/quran_video_studio/presentation/bloc/video_studio_bloc.dart';
import 'package:tabattal/features/quran_video_studio/presentation/bloc/video_studio_event.dart';

class _Repo extends Fake implements IVideoStudioRepository {
  Completer<void>? loadGate;
  int loadCalls = 0;
  bool failLoad = false;

  @override
  Future<List<VerseModel>> loadVersesForSpan(
      {required int surahNumber,
      required int startAyah,
      required int endAyah}) async {
    loadCalls++;
    await loadGate?.future;
    if (failLoad) {
      throw Exception('fixture load failure');
    }
    return List.generate(
        endAyah - startAyah + 1,
        (i) => VerseModel(
            id: startAyah + i,
            verseNumber: startAyah + i,
            verseKey: '$surahNumber:${startAyah + i}',
            textUthmani: 'fixture',
            juzNumber: 1,
            words: const []));
  }

  @override
  Future<List<String>> prepareVerseAudioFiles(
          {required String reciterPath,
          required int surahNumber,
          required int startAyah,
          required int endAyah,
          void Function(double)? onDownloadProgress}) async =>
      List.generate(
          endAyah - startAyah + 1, (i) => 'https://example.invalid/${startAyah + i}.mp3');

  @override
  Future<List<Duration>> measureVerseDurations(
          {required List<String> audioFilePaths, int? firstAyahNumber}) async =>
      List.filled(audioFilePaths.length, const Duration(seconds: 30));

  @override
  Future<String?> prepareMergedAudio(
      {required List<String> audioFilePaths}) async {
    if (audioFilePaths.isEmpty) return null;
    return '/fixture/merged-preview.m4a';
  }

  @override
  void cancelAudioPreparation() {}
}

class _Platform extends JustAudioPlatform {
  final players = <_Player>[];
  int get totalPlayCalls => players.fold(0, (sum, p) => sum + p.playCalls);
  Iterable<String> get allLoads => players.expand((p) => p.loads);
  _Player get player => players.last;
  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    final p = _Player(request.id);
    players.add(p);
    return p;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(DisposePlayerRequest request) async {
    final p = players.firstWhere((e) => e.id == request.id, orElse: () => player);
    await p.events.close();
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
          DisposeAllPlayersRequest request) async =>
      DisposeAllPlayersResponse();
}

class _Player extends AudioPlayerPlatform {
  _Player(super.id);
  final events = StreamController<PlaybackEventMessage>.broadcast();
  final loads = <String>[];
  int playCalls = 0;
  bool failLoads = false;

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => events.stream;

  void broadcast(
      [ProcessingStateMessage state = ProcessingStateMessage.ready,
      Duration position = Duration.zero]) {
    events.add(PlaybackEventMessage(
        processingState: state,
        updateTime: DateTime.now(),
        updatePosition: position,
        bufferedPosition: const Duration(seconds: 30),
        duration: const Duration(seconds: 30),
        currentIndex: 0,
        icyMetadata: null,
        androidAudioSessionId: null));
  }

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    AudioSourceMessage source = request.audioSourceMessage;
    while (source is ConcatenatingAudioSourceMessage) {
      source = source.children.first;
    }
    loads.add((source as UriAudioSourceMessage).uri);
    broadcast();
    return LoadResponse(duration: const Duration(seconds: 30));
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    playCalls++;
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async => PauseResponse();

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    broadcast(ProcessingStateMessage.ready, request.position ?? Duration.zero);
    return SeekResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async =>
      SetVolumeResponse();

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async =>
      SetSpeedResponse();

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async =>
      SetPitchResponse();

  @override
  Future<SetSkipSilenceResponse> setSkipSilence(
          SetSkipSilenceRequest request) async =>
      SetSkipSilenceResponse();

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse();

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
          SetShuffleModeRequest request) async =>
      SetShuffleModeResponse();

  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(
          SetShuffleOrderRequest request) async =>
      SetShuffleOrderResponse();

  @override
  Future<SetAutomaticallyWaitsToMinimizeStallingResponse>
      setAutomaticallyWaitsToMinimizeStalling(
          SetAutomaticallyWaitsToMinimizeStallingRequest request) async =>
      SetAutomaticallyWaitsToMinimizeStallingResponse();

  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(
          SetAndroidAudioAttributesRequest request) async =>
      SetAndroidAudioAttributesResponse();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Platform platform;
  late VideoStudioBloc bloc;
  late _Repo repository;
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.ryanheise.audio_session'),
            (_) async => null);
    platform = _Platform();
    JustAudioPlatform.instance = platform;
    repository = _Repo();
    bloc = VideoStudioBloc(
      repository: repository,
      // staticFull keeps the load network-free: word timings become synthetic
      // instead of hitting the real timing server (unreachable in tests).
      initialConfig: const VideoProjectConfig(
          surahNumber: 1,
          startAyah: 1,
          endAyah: 3,
          textDisplayMode: VideoTextDisplayMode.staticFull),
    );
    bloc.emit(bloc.state.copyWith(
      verses: List.generate(
          3,
          (i) => VerseModel(
              id: i + 1,
              verseNumber: i + 1,
              verseKey: '1:${i + 1}',
              textUthmani: 'verse',
              juzNumber: 1,
              words: const [])),
    ));
  });
  tearDown(() async => bloc.close());
  Future<void> settle([int ms = 60]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  test('A play tap during audio preparation is queued and auto-starts after the load commits', () async {
    repository.loadGate = Completer<void>();
    // Kick off a load (reciter change) and keep it gated mid-preparation.
    bloc.add(VideoStudioReciterChanged(
        reciterName: bloc.state.config.reciterName,
        reciterCategory: bloc.state.config.reciterCategory,
        reciterPath: bloc.state.config.reciterPath));
    await settle();
    expect(bloc.state.isPreparingAudio, isTrue);
    expect(bloc.state.audioFilePaths, isEmpty);

    // The user taps play while the load is in flight: previously swallowed
    // silently (forcing a second tap); now the intent must be queued.
    bloc.add(const VideoStudioPlaybackToggled());
    await settle();
    expect(bloc.state.isPlaying, isFalse, reason: 'stale source must not play');
    expect(platform.totalPlayCalls, 0);

    // The load commits: the queued intent must auto-start playback.
    repository.loadGate!.complete();
    await settle(150);
    expect(bloc.state.isPlaying, isTrue,
        reason: 'One tap during preparation must start playback once ready');
    expect(platform.totalPlayCalls, greaterThanOrEqualTo(1));
    expect(
        platform.allLoads.where((u) => u.contains('merged-preview')),
        isNotEmpty);
  });

  test('A queued play intent is cleared when the load fails (no surprise autoplay)', () async {
    repository.loadGate = Completer<void>();
    bloc.add(VideoStudioReciterChanged(
        reciterName: bloc.state.config.reciterName,
        reciterCategory: bloc.state.config.reciterCategory,
        reciterPath: bloc.state.config.reciterPath));
    await settle();
    bloc.add(const VideoStudioPlaybackToggled());
    await settle();

    repository.failLoad = true;
    repository.loadGate!.complete();
    await settle(150);
    expect(bloc.state.isPreparingAudio, isFalse);
    expect(bloc.state.isPlaying, isFalse);
    expect(bloc.state.errorMessage, isNotEmpty);

    // A later successful load without any new play tap must NOT auto-start.
    bloc.add(VideoStudioReciterChanged(
        reciterName: bloc.state.config.reciterName,
        reciterCategory: bloc.state.config.reciterCategory,
        reciterPath: bloc.state.config.reciterPath));
    await settle(150);
    expect(bloc.state.isPlaying, isFalse);
    expect(platform.totalPlayCalls, 0);
  });

  testWindowsOnly('Completed-state recovery stays a thin client: seek + play, no source churn',
      () async {
    // Responsibility split: the library (just_audio_windows_plus 0.5.3) owns
    // restart-from-completed correctness natively — its integration suite
    // covers the exact app recovery sequence. The app must stay a thin
    // client: no source re-loads that could race the video player init.
    bloc.emit(bloc.state.copyWith(
      audioFilePaths: const [
        'https://example.invalid/1.mp3',
        'https://example.invalid/2.mp3',
        'https://example.invalid/3.mp3'
      ],
      verseDurations: const [Duration(seconds: 30), Duration(seconds: 30), Duration(seconds: 30)],
      mergedPreviewAudioPath: '/fixture/merged-preview.m4a',
      isPlaying: true,
    ));
    await settle();
    // Initialize the platform player + source exactly like the app does on a
    // seek, so the events broadcast below reaches a live engine.
    bloc.add(const VideoStudioSeekRequested(Duration.zero));
    await settle();
    final mergedLoadsAfterInit =
        platform.allLoads.where((u) => u.contains('merged-preview')).length;
    expect(mergedLoadsAfterInit, 1);

    // Natural end reached.
    platform.player
        .broadcast(ProcessingStateMessage.completed, const Duration(seconds: 30));
    await settle();

    // Reset from completed: bare seek only — the source must NOT churn.
    bloc.add(const VideoStudioPlaybackReset());
    await settle();
    final mergedLoadsAfterReset =
        platform.allLoads.where((u) => u.contains('merged-preview')).length;
    expect(mergedLoadsAfterReset, mergedLoadsAfterInit,
        reason: 'The library owns completed-state recovery; the app must not '
            're-open files on reset.');

    // Play from completed must work through the fixed library and never add
    // a redundant source load in the app layer.
    bloc.add(const VideoStudioPlaybackToggled());
    await settle(120);
    expect(bloc.state.isPlaying, isTrue);
    expect(platform.totalPlayCalls, greaterThanOrEqualTo(1));
    final mergedLoadsAfterToggle =
        platform.allLoads.where((u) => u.contains('merged-preview')).length;
    expect(mergedLoadsAfterToggle, mergedLoadsAfterInit,
        reason: 'A thin client must not re-open the source on completed restarts.');
  });

  test('Rapid dimming drags coalesce while the final value always lands', () async {
    bloc.add(const VideoStudioDimmingChanged(0.1));
    await settle();
    for (var i = 0; i < 20; i++) {
      bloc.add(VideoStudioDimmingChanged(0.2 + i * 0.03));
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    // Wait past the 60ms coalesce window for the trailing event.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(bloc.state.config.backgroundDimming, closeTo(0.2 + 19 * 0.03, 0.0001),
        reason: 'The trailing dimming value must never be dropped.');
  });
}

/// Gates a test to Windows where Platform.isWindows branches are active; the
/// suite still runs everywhere but the Windows-specific paths skip elsewhere.
void testWindowsOnly(String description, Future<void> Function() body) {
  if (Platform.isWindows) {
    test(description, body);
  }
}
