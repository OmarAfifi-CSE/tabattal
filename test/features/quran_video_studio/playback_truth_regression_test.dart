// Audit reproductions: assert the required behavior against the unchanged app.
// ignore_for_file: depend_on_referenced_packages, invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:tabattal/features/quran_reader/data/models/verse_model.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/video_project_config.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/video_enums.dart';
import 'package:tabattal/features/quran_video_studio/domain/repositories/i_video_studio_repository.dart';
import 'package:tabattal/features/quran_video_studio/data/services/audio_timeline_service.dart';
import 'package:tabattal/features/quran_video_studio/presentation/bloc/video_studio_bloc.dart';
import 'package:tabattal/features/quran_video_studio/presentation/bloc/video_studio_event.dart';

class AuditRepository extends Fake implements IVideoStudioRepository {
  Completer<void>? firstLoadGate;
  int loadCalls = 0;
  @override
  Future<List<VerseModel>> loadVersesForSpan({required int surahNumber, required int startAyah, required int endAyah}) async {
    if (++loadCalls == 1) { await firstLoadGate?.future; }
    return List.generate(endAyah - startAyah + 1, (i) => VerseModel(id: startAyah + i, verseNumber: startAyah + i,
      verseKey: '$surahNumber:${startAyah + i}', textUthmani: 'fixture', juzNumber: 1, words: const []));
  }
  @override
  Future<List<String>> prepareVerseAudioFiles({required String reciterPath, required int surahNumber, required int startAyah, required int endAyah, void Function(double)? onDownloadProgress}) async =>
    List.generate(endAyah - startAyah + 1, (i) => 'https://example.invalid/${startAyah + i}.mp3');
  @override
  Future<List<Duration>> measureVerseDurations({required List<String> audioFilePaths}) async => List.filled(audioFilePaths.length, const Duration(seconds: 30));
  @override
  void cancelAudioPreparation() {}
}

class AuditPlatform extends JustAudioPlatform {
  late AuditPlayer player;
  bool failLoads = false;
  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async => player = AuditPlayer(request.id)..failLoads = failLoads;
  @override
  Future<DisposePlayerResponse> disposePlayer(DisposePlayerRequest request) async {
    await player.events.close();
    return DisposePlayerResponse();
  }
  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(DisposeAllPlayersRequest request) async => DisposeAllPlayersResponse();
}

class AuditPlayer extends AudioPlayerPlatform {
  AuditPlayer(super.id);
  final events = StreamController<PlaybackEventMessage>.broadcast();
  String? loadedUri;
  bool failLoads = false;
  Completer<void>? loadGate;
  final loads = <String>[];
  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => events.stream;
  void broadcast([ProcessingStateMessage state = ProcessingStateMessage.ready, Duration position = Duration.zero]) {
    events.add(PlaybackEventMessage(processingState: state, updateTime: DateTime.now(),
      updatePosition: position, bufferedPosition: const Duration(seconds: 30),
      duration: const Duration(seconds: 30), currentIndex: 0, icyMetadata: null, androidAudioSessionId: null));
  }
  @override
  Future<LoadResponse> load(LoadRequest request) async {
    if (failLoads) { throw PlatformException(code: 'fixture_load_error', message: 'controlled duration probe failure'); }
    AudioSourceMessage source = request.audioSourceMessage;
    while (source is ConcatenatingAudioSourceMessage) { source = source.children.first; }
    final uri = (source as UriAudioSourceMessage).uri;
    loads.add(uri);
    await loadGate?.future;
    loadedUri = uri;
    broadcast();
    return LoadResponse(duration: const Duration(seconds: 30));
  }
  @override
  Future<PlayResponse> play(PlayRequest request) async => PlayResponse();
  @override
  Future<PauseResponse> pause(PauseRequest request) async => PauseResponse();
  @override
  Future<SeekResponse> seek(SeekRequest request) async { broadcast(ProcessingStateMessage.ready, request.position ?? Duration.zero); return SeekResponse(); }
  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async => SetVolumeResponse();
  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async => SetSpeedResponse();
  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async => SetPitchResponse();
  @override
  Future<SetSkipSilenceResponse> setSkipSilence(SetSkipSilenceRequest request) async => SetSkipSilenceResponse();
  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async => SetLoopModeResponse();
  @override
  Future<SetShuffleModeResponse> setShuffleMode(SetShuffleModeRequest request) async => SetShuffleModeResponse();
  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(SetShuffleOrderRequest request) async => SetShuffleOrderResponse();
  @override
  Future<SetAutomaticallyWaitsToMinimizeStallingResponse> setAutomaticallyWaitsToMinimizeStalling(SetAutomaticallyWaitsToMinimizeStallingRequest request) async => SetAutomaticallyWaitsToMinimizeStallingResponse();
  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(SetAndroidAudioAttributesRequest request) async => SetAndroidAudioAttributesResponse();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AuditPlatform platform;
  late VideoStudioBloc bloc;
  late AuditRepository repository;
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_session'), (_) async => null);
    platform = AuditPlatform();
    JustAudioPlatform.instance = platform;
    repository = AuditRepository();
    bloc = VideoStudioBloc(repository: repository, initialConfig: const VideoProjectConfig(surahNumber: 1, startAyah: 1, endAyah: 3));
    bloc.emit(bloc.state.copyWith(
      verses: List.generate(3, (i) => VerseModel(id: i + 1, verseNumber: i + 1, verseKey: '1:${i + 1}', textUthmani: 'verse', juzNumber: 1, words: const [])),
      audioFilePaths: const ['https://example.invalid/1.mp3', 'https://example.invalid/2.mp3', 'https://example.invalid/3.mp3'],
      verseDurations: const [Duration(seconds: 30), Duration(seconds: 30), Duration(seconds: 30)],
    ));
  });
  tearDown(() async { await bloc.close(); });
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

  test('Completed Windows preview must reload verse one before replay', () async {
    bloc.add(const VideoStudioSeekRequested(Duration(seconds: 61)));
    await settle();
    expect(platform.player.loadedUri, endsWith('/3.mp3'));
    bloc.add(const VideoStudioPlaybackToggled());
    await settle();
    expect(bloc.state.isPlaying, isTrue);
    platform.player.broadcast(ProcessingStateMessage.completed, const Duration(seconds: 30));
    await settle();
    expect(bloc.state.currentVerseIndex, 0);
    bloc.add(const VideoStudioPlaybackToggled());
    await settle();
    expect(platform.player.loadedUri, endsWith('/1.mp3'), reason: 'The UI reset to verse one; audio must match it.');
  });

  test('Two verse clicks during source loading must leave audio on latest verse', () async {
    bloc.add(const VideoStudioSeekRequested(Duration.zero));
    await settle();
    final gate = Completer<void>();
    platform.player.loadGate = gate;
    bloc.add(const VideoStudioActiveVerseIndexChanged(1));
    await settle();
    bloc.add(const VideoStudioActiveVerseIndexChanged(2));
    await settle();
    expect(bloc.state.currentVerseIndex, 2);
    gate.complete();
    await settle();
    expect(platform.player.loadedUri, endsWith('/3.mp3'), reason: 'Later click was published but its source swap was dropped.');
  });

  test('A failed duration probe must not cache a made-up duration for later successful probes', () async {
    final service = AudioTimelineService();
    const paths = ['https://example.invalid/duration-fixture.mp3'];
    platform.failLoads = true;
    final failed = await service.measureDurations(audioFilePaths: paths);
    expect(failed.single, const Duration(seconds: 4));
    platform.failLoads = false;
    final retried = await service.measureDurations(audioFilePaths: paths);
    expect(retried.single, const Duration(seconds: 30), reason: 'Successful backend duration is 30 seconds; the fallback must not poison its cache.');
  });

  test('Reciter and verse-range reloads must commit one coherent latest snapshot', () async {
    bloc.emit(bloc.state.copyWith(config: bloc.state.config.copyWith(textDisplayMode: VideoTextDisplayMode.staticFull)));
    final gate = Completer<void>();
    repository.firstLoadGate = gate;
    bloc.add(VideoStudioReciterChanged(reciterName: bloc.state.config.reciterName,
      reciterCategory: bloc.state.config.reciterCategory, reciterPath: bloc.state.config.reciterPath));
    await settle();
    expect(repository.loadCalls, 1);
    bloc.add(const VideoStudioVerseRangeChanged(startAyah: 3, endAyah: 5));
    await settle();
    expect(bloc.state.verses.first.verseNumber, 3);
    gate.complete();
    await settle();
    expect(bloc.state.config.startAyah, 3);
    expect(bloc.state.verses.first.verseNumber, 3, reason: 'An older reciter reload overwrote verses while retaining the newer range and audio.');
  });

  test('Natural verse advance (isUserInitiated: false) updates verse without incrementing seekTrigger', () async {
    final initialSeekTrigger = bloc.state.seekTrigger;
    bloc.add(const VideoStudioActiveVerseIndexChanged(1, isUserInitiated: false));
    await settle();
    expect(bloc.state.currentVerseIndex, 1);
    expect(bloc.state.seekTrigger, initialSeekTrigger, reason: 'Natural playback must not bump seekTrigger or force video decoder seek.');
  });

  test('User-initiated verse change increments seekTrigger and sets lastSeekPosition', () async {
    final initialSeekTrigger = bloc.state.seekTrigger;
    bloc.add(const VideoStudioActiveVerseIndexChanged(2, isUserInitiated: true));
    await settle();
    expect(bloc.state.currentVerseIndex, 2);
    expect(bloc.state.seekTrigger, initialSeekTrigger + 1);
    expect(bloc.state.lastSeekPosition, const Duration(seconds: 60));
  });

  test('Playback reset atomically returns to verse 0, position 0, and triggers seek/reset', () async {
    bloc.emit(bloc.state.copyWith(
      currentVerseIndex: 2,
      isPlaying: true,
    ));
    final receivedPositions = <Duration>[];
    final sub = bloc.playbackPositionStream.listen(receivedPositions.add);
    final initialResetTrigger = bloc.state.playbackResetTrigger;
    final initialSeekTrigger = bloc.state.seekTrigger;

    bloc.add(const VideoStudioPlaybackReset());
    await settle();
    await sub.cancel();

    expect(bloc.state.currentVerseIndex, 0);
    expect(bloc.state.isPlaying, isFalse);
    expect(bloc.state.playbackResetTrigger, initialResetTrigger + 1);
    expect(bloc.state.seekTrigger, initialSeekTrigger + 1);
    expect(bloc.state.lastSeekPosition, Duration.zero);
    expect(receivedPositions.last, Duration.zero);

    // Assert timeline scrubber cumulative position on reset is 0:00, NEVER total - 3s
    final scrubberPos = bloc.state.calculateCumulativePosition(bloc.state.currentVerseIndex, receivedPositions.last);
    expect(scrubberPos, Duration.zero);
  });

  test('Single-verse span cleanly resets on completion with 0:00 scrubber position', () async {
    final singleVerseBloc = VideoStudioBloc(
      repository: repository,
      initialConfig: const VideoProjectConfig(surahNumber: 1, startAyah: 1, endAyah: 1),
    );
    singleVerseBloc.emit(singleVerseBloc.state.copyWith(
      verses: [
        VerseModel(id: 1, verseNumber: 1, verseKey: '1:1', textUthmani: 'بسم الله', juzNumber: 1, words: const []),
      ],
      audioFilePaths: const ['https://example.invalid/1.mp3'],
      verseDurations: const [Duration(seconds: 15)],
      isPlaying: true,
      currentVerseIndex: 0,
    ));

    final receivedPositions = <Duration>[];
    final sub = singleVerseBloc.playbackPositionStream.listen(receivedPositions.add);

    singleVerseBloc.add(const VideoStudioPlaybackReset());
    await settle();
    await sub.cancel();

    expect(singleVerseBloc.state.currentVerseIndex, 0);
    expect(singleVerseBloc.state.isPlaying, isFalse);
    expect(singleVerseBloc.state.lastSeekPosition, Duration.zero);
    expect(receivedPositions.last, Duration.zero);

    final scrubberPos = singleVerseBloc.state.calculateCumulativePosition(
      singleVerseBloc.state.currentVerseIndex,
      receivedPositions.last,
    );
    expect(scrubberPos, Duration.zero);
    await singleVerseBloc.close();
  });

  test('Out-of-bounds timeline seeks clamp safely without exceptions', () async {
    // Negative seek should clamp to start of verse 0
    bloc.add(const VideoStudioSeekRequested(Duration(seconds: -10)));
    await settle();
    expect(bloc.state.currentVerseIndex, 0);
    expect(bloc.state.lastSeekPosition, const Duration(seconds: -10));
    expect(
      bloc.state.calculateCumulativePosition(bloc.state.currentVerseIndex, Duration.zero),
      Duration.zero,
    );

    // Beyond total duration seek (total = 90s, seek = 150s) clamps to last verse
    bloc.add(const VideoStudioSeekRequested(Duration(seconds: 150)));
    await settle();
    expect(bloc.state.currentVerseIndex, 2);
    final clamped = bloc.state.calculateCumulativePosition(
      bloc.state.currentVerseIndex,
      const Duration(seconds: 30),
    );
    expect(clamped, const Duration(seconds: 90));
  });

  test('Natural transition across all 3 verses in sequence preserves seekTrigger until final completion', () async {
    final startSeekTrigger = bloc.state.seekTrigger;

    // Transition: Verse 0 -> Verse 1
    bloc.add(const VideoStudioActiveVerseIndexChanged(1, isUserInitiated: false));
    await settle();
    expect(bloc.state.currentVerseIndex, 1);
    expect(bloc.state.seekTrigger, startSeekTrigger);

    // Transition: Verse 1 -> Verse 2
    bloc.add(const VideoStudioActiveVerseIndexChanged(2, isUserInitiated: false));
    await settle();
    expect(bloc.state.currentVerseIndex, 2);
    expect(bloc.state.seekTrigger, startSeekTrigger);

    // End of recitation: Completion reset
    bloc.add(const VideoStudioPlaybackReset());
    await settle();
    expect(bloc.state.currentVerseIndex, 0);
    expect(bloc.state.isPlaying, isFalse);
    expect(bloc.state.seekTrigger, startSeekTrigger + 1);
    expect(bloc.state.lastSeekPosition, Duration.zero);
  });

  test('Rapid consecutive play/pause toggles settle cleanly without leaking ticker', () async {
    expect(bloc.state.isPlaying, isFalse);

    // 4 rapid toggles (even number -> final state should be paused)
    bloc.add(const VideoStudioPlaybackToggled());
    bloc.add(const VideoStudioPlaybackToggled());
    bloc.add(const VideoStudioPlaybackToggled());
    bloc.add(const VideoStudioPlaybackToggled());
    await settle();

    expect(bloc.state.isPlaying, isFalse);
    expect(bloc.isPositionTickerActive, isFalse);
  });
}

