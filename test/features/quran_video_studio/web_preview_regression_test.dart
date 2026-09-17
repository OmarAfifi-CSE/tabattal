// Web preview regressions & strict timing verification:
// 1. A reciter without verified Quran.com timings (or a failed timing fetch)
//    must throw an explicit exception instead of fabricating fake or proportional timings.
// 2. A reload commit must always end playback (isPlaying: false) so a play()
//    issued on a stale source mid-load cannot leave the UI "playing" silently.
// 3. The play toggle must be a no-op while an audio load is in flight.
// 4. Failed reciter load emits an errorMessage and stops the player completely.
// ignore_for_file: depend_on_referenced_packages, invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:tabattal/features/quran_reader/data/models/verse_model.dart';
import 'package:tabattal/features/quran_video_studio/data/services/audio_timeline_service.dart';
import 'package:tabattal/features/quran_video_studio/data/services/word_timing_service.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/video_project_config.dart';
import 'package:tabattal/features/quran_video_studio/domain/repositories/i_video_studio_repository.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/word_timing_segment.dart';
import 'package:tabattal/features/quran_video_studio/presentation/bloc/video_studio_bloc.dart';
import 'package:tabattal/features/quran_video_studio/presentation/bloc/video_studio_event.dart';

class _ThrowingAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List?>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      type: DioExceptionType.connectionTimeout,
      requestOptions: options,
    );
  }
}

class _CountingAdapter implements HttpClientAdapter {
  _CountingAdapter({required this.onFetch});

  final void Function() onFetch;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List?>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onFetch();
    throw DioException(
      type: DioExceptionType.connectionTimeout,
      requestOptions: options,
    );
  }
}

class _FailingRepository extends Fake implements IVideoStudioRepository {
  @override
  void cancelAudioPreparation() {}

  @override
  Future<List<VerseModel>> loadVersesForSpan({required int surahNumber, required int startAyah, required int endAyah}) async {
    return List.generate(
      endAyah - startAyah + 1,
      (i) => VerseModel(
        id: startAyah + i,
        verseNumber: startAyah + i,
        verseKey: '$surahNumber:${startAyah + i}',
        textUthmani: 'قُلْ هُوَ ٱللَّهُ أَحَدٌ',
        juzNumber: 1,
        words: const [],
      ),
    );
  }

  @override
  Future<List<String>> prepareVerseAudioFiles({required String reciterPath, required int surahNumber, required int startAyah, required int endAyah, void Function(double)? onDownloadProgress}) async {
    throw Exception('fixture: reciter audio unavailable');
  }
}

class _WorkingRepository extends Fake implements IVideoStudioRepository {
  @override
  void cancelAudioPreparation() {}

  @override
  Future<List<VerseModel>> loadVersesForSpan({required int surahNumber, required int startAyah, required int endAyah}) async {
    return List.generate(
      endAyah - startAyah + 1,
      (i) => VerseModel(
        id: startAyah + i,
        verseNumber: startAyah + i,
        verseKey: '$surahNumber:${startAyah + i}',
        textUthmani: 'قُلْ هُوَ ٱللَّهُ أَحَدٌ',
        juzNumber: 1,
        words: const [],
      ),
    );
  }

  @override
  Future<List<String>> prepareVerseAudioFiles({required String reciterPath, required int surahNumber, required int startAyah, required int endAyah, void Function(double)? onDownloadProgress}) async {
    return List.generate(endAyah - startAyah + 1, (i) => 'https://example.invalid/$reciterPath/${startAyah + i}.mp3');
  }

  @override
  Future<List<Duration>> measureVerseDurations({required List<String> audioFilePaths, int? firstAyahNumber}) async {
    return List.filled(audioFilePaths.length, const Duration(seconds: 30));
  }

  @override
  Future<String?> prepareMergedAudio({required List<String> audioFilePaths}) async => null;
}

class _RecordingPlatform extends JustAudioPlatform {
  final players = <_RecordingPlayer>[];
  int playCalls = 0;
  List<String>? lastPlaylistUris;

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    final player = _RecordingPlayer(request.id, this);
    players.add(player);
    return player;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(DisposePlayerRequest request) async {
    await players.lastWhere((p) => p.id == request.id).events.close();
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(DisposeAllPlayersRequest request) async => DisposeAllPlayersResponse();
}

class _RecordingPlayer extends AudioPlayerPlatform {
  _RecordingPlayer(super.id, this._platform);

  final _RecordingPlatform _platform;

  final events = StreamController<PlaybackEventMessage>.broadcast();

  void broadcast([ProcessingStateMessage state = ProcessingStateMessage.ready, bool playing = false]) {
    events.add(PlaybackEventMessage(
      processingState: state,
      updateTime: DateTime.now(),
      updatePosition: Duration.zero,
      bufferedPosition: const Duration(seconds: 30),
      duration: const Duration(seconds: 30),
      currentIndex: 0,
      icyMetadata: null,
      androidAudioSessionId: null,
    ));
  }

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => events.stream;

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    AudioSourceMessage source = request.audioSourceMessage;
    final uris = <String>[];
    while (source is ConcatenatingAudioSourceMessage) {
      for (final child in source.children) {
        if (child is UriAudioSourceMessage) uris.add(child.uri.toString());
      }
      source = source.children.first;
    }
    if (source is UriAudioSourceMessage) uris.add(source.uri.toString());
    _platform.lastPlaylistUris = uris;
    broadcast();
    return LoadResponse(duration: const Duration(seconds: 30));
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    _platform.playCalls++;
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async => PauseResponse();

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    broadcast(ProcessingStateMessage.ready);
    return SeekResponse();
  }

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

class _FailingAudioPlatform extends _RecordingPlatform {
  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    final player = _FailingAudioPlayer(request.id, this);
    players.add(player);
    return player;
  }
}

class _FailingAudioPlayer extends _RecordingPlayer {
  _FailingAudioPlayer(super.id, super.platform);

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    throw Exception('Failed to load duration');
  }
}

VerseModel _verseWithWords(String verseKey) {
  final parts = verseKey.split(':');
  return VerseModel(
    id: int.parse(parts[1]),
    verseNumber: int.parse(parts[1]),
    verseKey: verseKey,
    textUthmani: 'قُلْ هُوَ ٱللَّهُ أَحَدٌ',
    juzNumber: 1,
    words: [
      WordModel(id: 1, textUthmani: 'قُلْ', codeV2: '', lineNumber: 1, charTypeName: 'word', verseKey: verseKey, pageNumber: 1),
      WordModel(id: 2, textUthmani: 'هُوَ', codeV2: '', lineNumber: 1, charTypeName: 'word', verseKey: verseKey, pageNumber: 1),
      WordModel(id: 3, textUthmani: 'ٱللَّهُ', codeV2: '', lineNumber: 1, charTypeName: 'word', verseKey: verseKey, pageNumber: 1),
      WordModel(id: 4, textUthmani: 'أَحَدٌ', codeV2: '', lineNumber: 1, charTypeName: 'word', verseKey: verseKey, pageNumber: 1),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_session'), (_) async => null);
    WordTimingService.clearCache();
  });

  group('WordTimingService strict verification (zero fake timings/fallbacks)', () {
    test('Unknown reciter throws explicit exception instead of fake timings', () async {
      final service = WordTimingService();
      expect(
        () => service.getWordTimings(
          surahNumber: 112,
          verse: _verseWithWords('112:1'),
          reciterPath: 'Fares_Abbad_64kbps',
          totalAyahDuration: const Duration(seconds: 6),
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('لا تتوفر بيانات توقيت حقيقية'),
        )),
      );
    });

    test('Verified reciter with a failing network throws instead of fake timings', () async {
      final service = WordTimingService(dio: Dio(BaseOptions())
        ..httpClientAdapter = _ThrowingAdapter());
      expect(
        () => service.getWordTimings(
          surahNumber: 112,
          verse: _verseWithWords('112:1'),
          reciterPath: 'Husary_128kbps',
          totalAyahDuration: const Duration(seconds: 6),
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('تعذر جلب التوقيت الحقيقي الدقيق'),
        )),
      );
    });

    test('A failed chapter fetch is negative-cached: later verses fail fast without re-downloading', () async {
      var fetchCalls = 0;
      final adapter = _CountingAdapter(onFetch: () => fetchCalls++);
      final service = WordTimingService(dio: Dio(BaseOptions())..httpClientAdapter = adapter);

      // First verse triggers the chapter download, which fails.
      await expectLater(
        () => service.getWordTimings(
          surahNumber: 112,
          verse: _verseWithWords('112:1'),
          reciterPath: 'Husary_128kbps',
          totalAyahDuration: const Duration(seconds: 6),
        ),
        throwsA(isA<Exception>()),
      );
      expect(fetchCalls, 1);

      // Second verse of the SAME chapter must fail fast: no second download.
      await expectLater(
        () => service.getWordTimings(
          surahNumber: 112,
          verse: _verseWithWords('112:2'),
          reciterPath: 'Husary_128kbps',
          totalAyahDuration: const Duration(seconds: 6),
        ),
        throwsA(isA<Exception>()),
      );
      expect(fetchCalls, 1, reason: 'A failed chapter must not be re-downloaded once per verse.');

      // A new load (clearCache at load start) must genuinely retry the fetch.
      WordTimingService.clearCache();
      await expectLater(
        () => service.getWordTimings(
          surahNumber: 112,
          verse: _verseWithWords('112:1'),
          reciterPath: 'Husary_128kbps',
          totalAyahDuration: const Duration(seconds: 6),
        ),
        throwsA(isA<Exception>()),
      );
      expect(fetchCalls, 2, reason: 'clearCache (called on every load) must restore retry semantics.');
    });
  });

  group('AudioTimelineService strict verification (zero 4s fake fallbacks)', () {
    test('Failing audio duration probe throws explicit exception instead of 4s fallback', () async {
      JustAudioPlatform.instance = _FailingAudioPlatform();
      final service = AudioTimelineService();
      expect(
        () => service.measureDurations(audioFilePaths: const ['https://invalid-host.nonexistent/sample.mp3']),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('تعذر قياس مدة المقطع الصوتي بدقة'),
        )),
      );
    });

    test('Measurement failure reports the REAL surah ayah number, not the list index', () async {
      JustAudioPlatform.instance = _FailingAudioPlatform();
      final service = AudioTimelineService();
      // Range starts at ayah 5; the first file (index 0) is ayah 5, not ayah 1.
      expect(
        () => service.measureDurations(
          audioFilePaths: const ['https://invalid-host.nonexistent/a.mp3'],
          firstAyahNumber: 5,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('للآية 5.'),
        )),
      );
    });
  });

  group('Reload lifecycle regressions', () {
    test('A successful reload after playback always ends in isPlaying=false', () async {
      final platform = _RecordingPlatform();
      JustAudioPlatform.instance = platform;
      final bloc = VideoStudioBloc(
        repository: _WorkingRepository(),
        initialConfig: const VideoProjectConfig(surahNumber: 1, startAyah: 1, endAyah: 1),
      );

      bloc.emit(bloc.state.copyWith(
        verses: [_verseWithWords('1:1')],
        audioFilePaths: const ['https://example.invalid/OldReciter/001001.mp3'],
        verseDurations: const [Duration(seconds: 30)],
      ));

      // Simulate active playback (as if the user pressed play before).
      bloc.emit(bloc.state.copyWith(isPlaying: true));

      WordTimingService.primeVerseCacheForTesting(
        'Minshawy_Murattal_128kbps',
        '1:1',
        const [
          WordTimingSegment(wordPosition: 1, startMs: 0, endMs: 7500),
          WordTimingSegment(wordPosition: 2, startMs: 7500, endMs: 15000),
          WordTimingSegment(wordPosition: 3, startMs: 15000, endMs: 22500),
          WordTimingSegment(wordPosition: 4, startMs: 22500, endMs: 30000),
        ],
      );

      bloc.add(const VideoStudioReciterChanged(
        reciterName: 'Minshawy',
        reciterCategory: 'Murattal',
        reciterPath: 'Minshawy_Murattal_128kbps',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await bloc.close();

      expect(platform.lastPlaylistUris, isNotNull);
      expect(platform.lastPlaylistUris!.first, contains('Minshawy_Murattal_128kbps'));
      expect(bloc.state.isPlaying, isFalse);
    });

    test('Play toggle during an in-flight load is a no-op (no stale playback)', () async {
      final platform = _RecordingPlatform();
      JustAudioPlatform.instance = platform;
      final bloc = VideoStudioBloc(
        repository: _WorkingRepository(),
        initialConfig: const VideoProjectConfig(surahNumber: 1, startAyah: 1, endAyah: 1),
      );

      bloc.emit(bloc.state.copyWith(isPreparingAudio: true));
      bloc.add(const VideoStudioPlaybackToggled());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await bloc.close();

      expect(platform.playCalls, 0);
    });

    test('A failed reciter load reports an error without playing anything', () async {
      final platform = _RecordingPlatform();
      JustAudioPlatform.instance = platform;
      final bloc = VideoStudioBloc(
        repository: _FailingRepository(),
        initialConfig: const VideoProjectConfig(surahNumber: 1, startAyah: 1, endAyah: 1),
      );
      bloc.emit(bloc.state.copyWith(
        verses: [_verseWithWords('1:1')],
        audioFilePaths: const ['https://example.invalid/OldReciter/001001.mp3'],
        verseDurations: const [Duration(seconds: 30)],
        wordTimingsMap: const {
          1: [WordTimingSegment(wordPosition: 1, startMs: 0, endMs: 30000)],
        },
      ));
      bloc.add(const VideoStudioReciterChanged(
        reciterName: 'Fares Abbad',
        reciterCategory: 'Murattal',
        reciterPath: 'Fares_Abbad_64kbps',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await bloc.close();

      expect(bloc.state.errorMessage, isNotNull);
      expect(bloc.state.isPlaying, isFalse);
      expect(platform.playCalls, 0);
      // A failed load must not leave a playable stale source behind.
      expect(bloc.state.audioFilePaths, isEmpty);
      expect(bloc.state.mergedPreviewAudioPath, isNull);
    });
  });
}
