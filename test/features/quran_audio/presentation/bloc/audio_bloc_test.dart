// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:tabattal/core/network/audio_download_manager.dart';
import 'package:tabattal/core/services/audio_preferences_service.dart';
import 'package:tabattal/core/services/quran_audio_handler.dart';
import 'package:tabattal/features/quran_audio/data/models/surah_timing_model.dart';
import 'package:tabattal/features/quran_audio/data/services/surah_audio_timing_service.dart';
import 'package:tabattal/features/quran_audio/presentation/bloc/audio_bloc.dart';
import 'package:tabattal/features/quran_audio/presentation/bloc/audio_event.dart';
import 'package:tabattal/features/quran_audio/presentation/bloc/audio_state.dart';

class _MockPlatform extends JustAudioPlatform {
  late _MockPlayer player;

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async =>
      player = _MockPlayer(request.id);

  @override
  Future<DisposePlayerResponse> disposePlayer(DisposePlayerRequest request) async =>
      DisposePlayerResponse();

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
          DisposeAllPlayersRequest request) async =>
      DisposeAllPlayersResponse();
}

class _MockPlayer extends AudioPlayerPlatform {
  _MockPlayer(super.id);
  final events = StreamController<PlaybackEventMessage>.broadcast();

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => events.stream;

  Duration _currentPos = Duration.zero;
  int _currentIndex = 0;

  void broadcast([
    ProcessingStateMessage state = ProcessingStateMessage.ready,
    Duration position = Duration.zero,
    int? currentIndex,
  ]) {
    if (currentIndex != null) {
      _currentIndex = currentIndex;
    }
    events.add(PlaybackEventMessage(
      processingState: state,
      updateTime: DateTime.now(),
      updatePosition: position,
      bufferedPosition: const Duration(minutes: 5),
      duration: const Duration(minutes: 5),
      currentIndex: _currentIndex,
      icyMetadata: null,
      androidAudioSessionId: null,
    ));
  }

  LoadRequest? lastLoadRequest;

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    lastLoadRequest = request;
    _currentPos = request.initialPosition ?? Duration.zero;
    _currentIndex = request.initialIndex ?? 0;
    broadcast(ProcessingStateMessage.ready, _currentPos, _currentIndex);
    return LoadResponse(duration: const Duration(minutes: 5));
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    broadcast(ProcessingStateMessage.ready, _currentPos, _currentIndex);
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    broadcast(ProcessingStateMessage.ready, _currentPos, _currentIndex);
    return PauseResponse();
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    _currentPos = request.position ?? Duration.zero;
    if (request.index != null) {
      _currentIndex = request.index!;
    }
    broadcast(ProcessingStateMessage.ready, _currentPos, _currentIndex);
    return SeekResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async =>
      SetVolumeResponse();

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async =>
      SetSpeedResponse();

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse();

  @override
  Future<SetShuffleModeResponse> setShuffleMode(SetShuffleModeRequest request) async =>
      SetShuffleModeResponse();

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async =>
      SetPitchResponse();

}

class _MockPreferencesService extends Fake implements AudioPreferencesService {
  String _cat = 'مرتل';
  String _rec = 'محمد صديق المنشاوي';
  int _repeat = 1;
  bool _once = false;

  @override
  String get category => _cat;
  @override
  String get reciter => _rec;
  @override
  int get repeatCount => _repeat;
  @override
  bool get playOnce => _once;
  @override
  String get appLocale => 'ar';
  @override
  double get volume => 1.0;

  @override
  Future<void> saveCategory(String category) async => _cat = category;
  @override
  Future<void> saveReciter(String reciter) async => _rec = reciter;
  @override
  Future<void> saveRepeatCount(int count) async => _repeat = count;
  @override
  Future<void> savePlayOnce(bool playOnce) async => _once = playOnce;
}

class _MockDownloadManager extends Fake implements AudioDownloadManager {
  bool throwError = false;
  String? mockLocalSurah;
  String? mockLocalVerse;

  @override
  Future<String> getReciterDirectory(String category, String reciterKey) async =>
      '/mock/reciter';

  @override
  Future<String?> getLocalVersePath(
    String category,
    String reciterKey,
    int verseId,
  ) async =>
      mockLocalVerse;

  @override
  Future<String?> getLocalSurahPath(
    String category,
    String reciterKey,
    int surah,
  ) async =>
      mockLocalSurah;

  @override
  Future<void> autoCacheSurah(
    String category,
    String reciterKey,
    int surah,
  ) async {}

  @override
  Future<String?> getOrPrecacheStreamingSurah({
    required String category,
    required String reciterKey,
    required int surahNumber,
    required String remoteUrl,
    Duration timeout = const Duration(seconds: 4),
  }) async => null;

  @override
  Future<String> getVerseAudioPath(
    String category,
    String reciterKey,
    int surah,
    int ayah,
  ) async {
    if (throwError) {
      throw Exception("Network error loading ayah");
    }
    final surahStr = surah.toString().padLeft(3, '0');
    final ayahStr = ayah.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/$reciterKey/$surahStr$ayahStr.mp3';
  }
}

class _MockAudioHandler extends Fake implements QuranAudioHandler {
  final _actionSubject = StreamController<QuranAudioAction>.broadcast();
  late AudioPlayer _player;

  _MockAudioHandler() {
    _player = AudioPlayer();
  }

  @override
  Stream<QuranAudioAction> get actions => _actionSubject.stream;

  @override
  AudioPlayer get player => _player;

  @override
  Future<void> updateItem(MediaItem item) async {}

  @override
  Future<void> showStoppedNotification({required String title, required String subtitle}) async {}

  @override
  Future<void> stop() async {
    await _player.stop();
  }

  @override
  void switchPlayer(AudioPlayer newPlayer) {
    _player = newPlayer;
  }
}

class _MockTimingService extends Fake implements SurahAudioTimingService {
  bool returnNull = false;
  bool returnDirectNoTimings = false;

  @override
  Future<SurahTimings?> getSurahTimings({
    required String reciterPath,
    required int surahNumber,
  }) async {
    if (returnNull || surahNumber == 999) return null;
    if (returnDirectNoTimings) {
      return const SurahTimings(
        surah: 1,
        audioUrl: 'https://download.quranicaudio.com/quran/huthayfi/001.mp3',
        verseTimings: [],
      );
    }
    if (surahNumber == 1) {
      return const SurahTimings(
        surah: 1,
        audioUrl: 'https://download.quranicaudio.com/quran/minshawi/001.mp3',
        verseTimings: [
          VerseTimestamp(surah: 1, ayah: 1, start: Duration.zero, end: Duration(seconds: 5)),
          VerseTimestamp(surah: 1, ayah: 2, start: Duration(seconds: 5), end: Duration(seconds: 11)),
          VerseTimestamp(surah: 1, ayah: 3, start: Duration(seconds: 11), end: Duration(seconds: 16)),
          VerseTimestamp(surah: 1, ayah: 4, start: Duration(seconds: 16), end: Duration(seconds: 21)),
          VerseTimestamp(surah: 1, ayah: 5, start: Duration(seconds: 21), end: Duration(seconds: 28)),
          VerseTimestamp(surah: 1, ayah: 6, start: Duration(seconds: 28), end: Duration(seconds: 35)),
          VerseTimestamp(surah: 1, ayah: 7, start: Duration(seconds: 35), end: Duration(seconds: 48)),
        ],
      );
    }
    return const SurahTimings(
      surah: 2,
      audioUrl: 'https://download.quranicaudio.com/quran/minshawi/002.mp3',
      verseTimings: [
        VerseTimestamp(surah: 2, ayah: 1, start: Duration.zero, end: Duration(seconds: 8)),
        VerseTimestamp(surah: 2, ayah: 2, start: Duration(seconds: 8), end: Duration(seconds: 18)),
      ],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MockPlatform mockPlatform;
  late _MockAudioHandler mockHandler;
  late _MockPreferencesService mockPrefs;
  late _MockDownloadManager mockDownload;
  late _MockTimingService mockTiming;
  late AudioBloc bloc;

  setUpAll(() {
    mockPlatform = _MockPlatform();
    JustAudioPlatform.instance = mockPlatform;
  });

  setUp(() {
    mockHandler = _MockAudioHandler();
    mockPrefs = _MockPreferencesService();
    mockDownload = _MockDownloadManager();
    mockTiming = _MockTimingService();

    bloc = AudioBloc(
      mockHandler,
      mockDownload,
      mockPrefs,
      timingService: mockTiming,
    );
  });

  tearDown(() async {
    await bloc.close();
  });

  group('Continuous Surah Audio Engine - AudioBloc Tests', () {
    test('Initial state is AudioIdle', () {
      expect(bloc.state, isA<AudioIdle>());
      expect(bloc.currentReciter, 'محمد صديق المنشاوي');
      expect(bloc.currentRepeatCount, 1);
    });

    test('PlayVerse emits AudioLoading then AudioPlaying with correct verseId', () async {
      final states = <AudioState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const PlayVerse('', 1001));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(states, [
        isA<AudioLoading>(),
        isA<AudioPlaying>().having((s) => s.currentVerseId, 'currentVerseId', 1001),
      ]);

      await sub.cancel();
    });

    test('NextAyah within same surah advances ayah via sub-millisecond seek', () async {
      final states = <AudioState>[];
      final sub = bloc.stream.listen(states.add);

      // Play 1:1 first
      bloc.add(const PlayVerse('', 1001));
      await Future.delayed(const Duration(milliseconds: 50));

      // Advance to 1:2
      bloc.add(const NextAyah());
      await Future.delayed(const Duration(milliseconds: 50));

      expect(states.last, isA<AudioPlaying>().having((s) => s.currentVerseId, 'currentVerseId', 1002));

      await sub.cancel();
    });

    test('PreviousAyah within same surah rewinds to previous ayah', () async {
      final states = <AudioState>[];
      final sub = bloc.stream.listen(states.add);

      // Play 1:2 first
      bloc.add(const PlayVerse('', 1002));
      await Future.delayed(const Duration(milliseconds: 50));

      // Rewind to 1:1
      bloc.add(const PreviousAyah());
      await Future.delayed(const Duration(milliseconds: 50));

      expect(states.last, isA<AudioPlaying>().having((s) => s.currentVerseId, 'currentVerseId', 1001));

      await sub.cancel();
    });

    test('PauseAudio and ResumeAudio transition state faithfully', () async {
      final states = <AudioState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const PlayVerse('', 1003));
      await Future.delayed(const Duration(milliseconds: 50));

      bloc.add(const PauseAudio());
      await Future.delayed(const Duration(milliseconds: 50));
      expect(states.last, isA<AudioPaused>().having((s) => s.currentVerseId, 'currentVerseId', 1003));

      bloc.add(const ResumeAudio());
      await Future.delayed(const Duration(milliseconds: 50));
      expect(states.last, isA<AudioPlaying>().having((s) => s.currentVerseId, 'currentVerseId', 1003));

      await sub.cancel();
    });

    test('StopAudio resets state to AudioIdle', () async {
      final states = <AudioState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const PlayVerse('', 1001));
      await Future.delayed(const Duration(milliseconds: 50));

      bloc.add(const StopAudio());
      await Future.delayed(const Duration(milliseconds: 50));

      expect(states.last, isA<AudioIdle>());

      await sub.cancel();
    });

    test('ChangeRepeatCount saves to preferences and updates active state', () async {
      bloc.add(const PlayVerse('', 1001));
      await Future.delayed(const Duration(milliseconds: 50));

      bloc.add(const ChangeRepeatCount(3));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.currentRepeatCount, 3);
      expect(mockPrefs.repeatCount, 3);
    });

    test('PlayVerse with same surah performs instant seek without re-loading audio', () async {
      final states = <AudioState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const PlayVerse('', 1001));
      await Future.delayed(const Duration(milliseconds: 50));

      // Direct tap on Ayah 5 within same Surah
      bloc.add(const PlayVerse('', 1005));
      await Future.delayed(const Duration(milliseconds: 50));

      // Notice NO second AudioLoading() is emitted because the surah is already loaded!
      final loadingCount = states.whereType<AudioLoading>().length;
      expect(loadingCount, 1);
      expect(states.last, isA<AudioPlaying>().having((s) => s.currentVerseId, 'currentVerseId', 1005));

      await sub.cancel();
    });

    test('PlayVerse emits AudioError when stream cannot be loaded', () async {
      mockTiming.returnNull = true;
      mockDownload.throwError = true;

      final states = <AudioState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const PlayVerse('', 1001));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(states.any((s) => s is AudioError), isTrue);

      await sub.cancel();
    });

    test('Direct full surah stream without verse timestamps plays continuously and supports skip/seek', () async {
      mockTiming.returnDirectNoTimings = true;

      final states = <AudioState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const PlayVerse('', 1001));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(states.any((s) => s is AudioPlaying && s.currentVerseId == 1001), isTrue);

      // Next Ayah in direct stream skips 15 seconds forward
      bloc.add(const NextAyah());
      await Future.delayed(const Duration(milliseconds: 50));

      // Direct tap within same surah preserves continuous playback
      bloc.add(const PlayVerse('', 1005));
      await Future.delayed(const Duration(milliseconds: 50));

      final loadingCount = states.whereType<AudioLoading>().length;
      expect(loadingCount, 1);
      expect(states.last, isA<AudioPlaying>().having((s) => s.currentVerseId, 'currentVerseId', 1005));

      // Previous Ayah rewinds
      bloc.add(const PreviousAyah());
      await Future.delayed(const Duration(milliseconds: 50));

      await sub.cancel();
    });

    test('Direct full surah stream repeat count change updates preferences and active state', () async {
      mockTiming.returnDirectNoTimings = true;

      bloc.add(const PlayVerse('', 1001));
      await Future.delayed(const Duration(milliseconds: 50));

      bloc.add(const ChangeRepeatCount(-1));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.currentRepeatCount, -1);
      expect(mockPrefs.repeatCount, -1);
    });

    test('ChangeReciter with restartPlayback: false does not emit duplicate play events', () async {
      final states = <AudioState>[];
      final sub = bloc.stream.listen(states.add);

      // 1. Start playback on ayah 1001
      bloc.add(const PlayVerse('', 1001));
      await Future.delayed(const Duration(milliseconds: 60));

      final playStateCountBefore = states.whereType<AudioPlaying>().length;
      expect(playStateCountBefore, 1);

      // 2. Change reciter with restartPlayback: false (e.g. from bottom sheet)
      bloc.add(const ChangeReciter('مرتل', 'محمود خليل الحصري', restartPlayback: false));
      await Future.delayed(const Duration(milliseconds: 60));

      // Notice reciter is saved without triggering duplicate PlayVerse!
      expect(bloc.currentReciter, 'محمود خليل الحصري');
      final playStateCountAfter = states.whereType<AudioPlaying>().length;
      expect(playStateCountAfter, playStateCountBefore);

      await sub.cancel();
    });

    test('PlayVerse offline falls back to local full surah file', () async {
      mockTiming.returnNull = true; // Simulating offline - no timing service
      mockDownload.mockLocalSurah = '/local/surahs/001.mp3';

      final states = <AudioState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const PlayVerse('', 1001));
      await Future.delayed(const Duration(milliseconds: 60));

      expect(states.any((s) => s is AudioPlaying && s.currentVerseId == 1001), isTrue);

      await sub.cancel();
    });

    test('PlayVerse offline falls back to local verse file when full surah is unavailable', () async {
      mockTiming.returnNull = true; // Offline
      mockDownload.mockLocalSurah = null;
      mockDownload.mockLocalVerse = '/local/verses/1001.mp3';

      final states = <AudioState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const PlayVerse('', 1001));
      await Future.delayed(const Duration(milliseconds: 60));

      expect(states.any((s) => s is AudioPlaying && s.currentVerseId == 1001), isTrue);

      await sub.cancel();
    });

    test('PlayVerse offline emits audioErrorNoInternet when no local files exist', () async {
      mockTiming.returnNull = true; // Offline
      mockDownload.mockLocalSurah = null;
      mockDownload.mockLocalVerse = null;

      final states = <AudioState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const PlayVerse('', 1001));
      await Future.delayed(const Duration(milliseconds: 60));

      expect(states.any((s) => s is AudioError && s.message == 'audioErrorNoInternet'), isTrue);

      await sub.cancel();
    });

    test('SurahDeletedEvent hot-swaps active playing local surah to remote stream without error', () async {
      mockDownload.mockLocalSurah = '/local/surahs/001.mp3';

      final states = <AudioState>[];
      final sub = bloc.stream.listen(states.add);

      // Start playing local surah 1
      bloc.add(const PlayVerse('', 1001));
      await Future.delayed(const Duration(milliseconds: 60));

      expect(states.any((s) => s is AudioPlaying && s.currentVerseId == 1001), isTrue);

      // Now user deletes surah 1
      bloc.add(const SurahDeletedEvent(
        surahNumber: 1,
        category: 'murattal',
        reciterKey: 'abdul_basit',
      ));
      await Future.delayed(const Duration(milliseconds: 60));

      // Playback remains in AudioPlaying state without throwing AudioError
      expect(states.last, isA<AudioPlaying>().having((s) => s.currentVerseId, 'currentVerseId', 1001));
      expect(states.any((s) => s is AudioError), isFalse);

      await sub.cancel();
    });

    test('PlayVerse within same surah falls back to remote stream if local file was deleted', () async {
      mockDownload.mockLocalSurah = '/local/surahs/non_existent_001.mp3';

      final states = <AudioState>[];
      final sub = bloc.stream.listen(states.add);

      // Start playing
      bloc.add(const PlayVerse('', 1001));
      await Future.delayed(const Duration(milliseconds: 60));

      expect(states.any((s) => s is AudioPlaying && s.currentVerseId == 1001), isTrue);

      // Now mock that the local file is no longer on disk / deleted
      mockDownload.mockLocalSurah = null;

      // User jumps to ayah 3 within the same surah
      bloc.add(const PlayVerse('', 1003));
      await Future.delayed(const Duration(milliseconds: 60));

      // Successfully transitioned to ayah 3 via remote stream without error
      expect(states.last, isA<AudioPlaying>().having((s) => s.currentVerseId, 'currentVerseId', 1003));
      expect(states.any((s) => s is AudioError), isFalse);

      await sub.cancel();
    });

    test('SurahDownloadedEvent auto-promotes active stream to local offline file without error', () async {
      mockDownload.mockLocalSurah = null; // Start with streaming

      final states = <AudioState>[];
      final sub = bloc.stream.listen(states.add);

      // Start playing via stream
      bloc.add(const PlayVerse('', 1001));
      await Future.delayed(const Duration(milliseconds: 60));

      expect(states.any((s) => s is AudioPlaying && s.currentVerseId == 1001), isTrue);

      // Now surah finishes downloading
      mockDownload.mockLocalSurah = '/local/surahs/001.mp3';
      bloc.add(const SurahDownloadedEvent(
        surahNumber: 1,
        category: 'murattal',
        reciterKey: 'abdul_basit',
      ));
      await Future.delayed(const Duration(milliseconds: 60));

      // Playback continues playing smoothly as local file
      expect(states.last, isA<AudioPlaying>().having((s) => s.currentVerseId, 'currentVerseId', 1001));
      expect(states.any((s) => s is AudioError), isFalse);

      await sub.cancel();
    });

    test('Streaming mode: playing ayah 1 does not send explicit initialPosition to setAudioSource avoiding native seek-to-0 buffer flush stutter', () async {
      mockDownload.mockLocalSurah = null; // Streaming mode

      bloc.add(const PlayVerse('', 1001));
      await Future.delayed(const Duration(milliseconds: 60));

      expect(bloc.state, isA<AudioPlaying>().having((s) => s.currentVerseId, 'currentVerseId', 1001));
      // Must be null to avoid scheduling an explicit seek-to-0 in ExoPlayer/AVPlayer/WinRT
      expect(mockPlatform.player.lastLoadRequest?.initialPosition, isNull);
    });

    test('Streaming mode: playing ayah > 1 passes initialPosition matching targetVerse.start', () async {
      mockDownload.mockLocalSurah = null; // Streaming mode

      bloc.add(const PlayVerse('', 1002));
      await Future.delayed(const Duration(milliseconds: 60));

      expect(bloc.state, isA<AudioPlaying>().having((s) => s.currentVerseId, 'currentVerseId', 1002));
      // Ayah 2 starts at 5 seconds
      expect(mockPlatform.player.lastLoadRequest?.initialPosition, equals(const Duration(seconds: 5)));
    });
  });
}

