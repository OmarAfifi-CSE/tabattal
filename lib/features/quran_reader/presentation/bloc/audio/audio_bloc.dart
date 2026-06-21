import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import '../../../../../core/network/audio_download_manager.dart';
import '../../../../../core/services/audio_preferences_service.dart';
import 'audio_event.dart';
import 'audio_state.dart';

class AudioBloc extends Bloc<AudioEvent, AudioState> {
  final AudioPlayer _audioPlayer;
  final AudioDownloadManager _downloadManager;
  final AudioPreferencesService _prefs;
  List<int> _currentVerseIds = [];
  int _currentIndex = 0;
  int _playedCount = 0; // Tracks how many times current verse has been played

  late String _currentReciter;
  late int _currentRepeatCount;

  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _currentIndexSubscription;
  StreamSubscription? _playbackEventSubscription;
  Timer? _sleepTimer;

  String get currentReciter => _currentReciter;
  int get currentRepeatCount => _currentRepeatCount;

  /// Real surah lengths for proper cross-surah advancing
  static const List<int> _surahLengths = [
    7, 286, 200, 176, 120, 165, 206, 75, 129, 109,
    123, 111, 43, 52, 99, 128, 111, 110, 98, 135,
    112, 78, 118, 64, 77, 227, 93, 88, 69, 60,
    34, 30, 73, 54, 45, 83, 182, 88, 75, 85,
    54, 53, 89, 59, 37, 35, 38, 29, 18, 45,
    60, 49, 62, 55, 78, 96, 29, 22, 24, 13,
    14, 11, 11, 18, 12, 12, 30, 52, 52, 44,
    28, 28, 20, 56, 40, 31, 50, 40, 46, 42,
    29, 19, 36, 25, 22, 17, 19, 26, 30, 20,
    15, 21, 11, 8, 8, 19, 5, 8, 8, 11,
    11, 8, 3, 9, 5, 4, 7, 3, 6, 3,
    5, 4, 5, 6
  ];

  AudioBloc(this._downloadManager, this._prefs)
      : _audioPlayer = AudioPlayer(),
        super(AudioIdle()) {
    // Load saved preferences
    _currentReciter = _prefs.reciter;
    _currentRepeatCount = _prefs.repeatCount;

    on<PlayVerse>(_onPlayVerse, transformer: restartable());
    on<PlayPlaylist>(_onPlayPlaylist, transformer: restartable());
    on<PauseAudio>(_onPauseAudio);
    on<ResumeAudio>(_onResumeAudio);
    on<StopAudio>(_onStopAudio);
    on<AudioStateChanged>(_onStateChanged);
    on<ChangeReciter>(_onChangeReciter);
    on<ChangeRepeatCount>(_onChangeRepeatCount);
    on<SetSleepTimer>(_onSetSleepTimer);
    on<CancelSleepTimer>(_onCancelSleepTimer);
    on<AudioErrorEvent>((event, emit) => emit(AudioError(event.message)));

    _initStreams();
  }

  /// Given a verseId (surah * 1000 + ayah), returns the next verseId
  int? _getNextVerseId(int verseId) {
    final surah = verseId ~/ 1000;
    final ayah = verseId % 1000;

    if (surah < 1 || surah > 114) return null;
    final maxAyah = _surahLengths[surah - 1];

    if (ayah < maxAyah) {
      return surah * 1000 + (ayah + 1);
    } else if (surah < 114) {
      return (surah + 1) * 1000 + 1;
    }
    return null;
  }

  void _initStreams() {
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (_currentVerseIds.isNotEmpty) {
          final currentVerseId = _currentVerseIds[_currentIndex];

          bool shouldRepeat = false;
          if (_currentRepeatCount == -1) {
            shouldRepeat = true;
          } else if (_currentRepeatCount > 0 && _playedCount < _currentRepeatCount) {
            shouldRepeat = true;
          }

          if (shouldRepeat) {
            // Repeat current verse
            _playedCount++;
            _playLocalOrStream(currentVerseId);
          } else {
            // Move to next verse
            final nextVerseId = _getNextVerseId(currentVerseId);
            if (nextVerseId != null) {
              add(PlayVerse('', nextVerseId));
            } else {
              add(const AudioStateChanged(isPlaying: false));
            }
          }
        } else {
          add(const AudioStateChanged(isPlaying: false));
        }
      } else {
        add(AudioStateChanged(isPlaying: state.playing));
      }
    });

    _currentIndexSubscription = _audioPlayer.currentIndexStream.listen((index) {
      if (index != null && _currentVerseIds.isNotEmpty && index < _currentVerseIds.length) {
        _currentIndex = index;
        add(AudioStateChanged(isPlaying: _audioPlayer.playing));
      }
    });

    _playbackEventSubscription = _audioPlayer.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace stackTrace) {
        if (e is PlayerException) {
          add(const AudioStateChanged(isPlaying: false));
          add(const AudioErrorEvent("Network error: Check connection to stream audio."));
        } else {
          add(const AudioStateChanged(isPlaying: false));
          add(const AudioErrorEvent("Failed to play audio."));
        }
      },
    );
  }

  Future<void> _playLocalOrStream(int verseId) async {
    final surah = verseId ~/ 1000;
    final ayah = verseId % 1000;

    final localPath = await _downloadManager.getLocalVersePath(_currentReciter, verseId);

    if (localPath != null) {
      await _audioPlayer.setFilePath(localPath);
    } else {
      final url = _downloadManager.getStreamingUrl(_currentReciter, surah, ayah);
      await _audioPlayer.setUrl(url);
      _downloadManager.downloadVerse(_currentReciter, surah, ayah, null).catchError((_) => '');
    }
    _audioPlayer.play();
  }

  Future<void> _onPlayVerse(PlayVerse event, Emitter<AudioState> emit) async {
    emit(AudioLoading());
    try {
      // Reset play count if it's a new verse request, not an internal repeat
      // Wait, since we call add(PlayVerse) for the next verse, we should reset it.
      _playedCount = 0; 
      _currentVerseIds = [event.verseId];
      _currentIndex = 0;

      await _playLocalOrStream(event.verseId);

      emit(AudioPlaying(event.verseId));

      final surah = event.verseId ~/ 1000;
      final ayah = event.verseId % 1000;
      _prefetchNext(_currentReciter, surah, ayah);

    } on PlayerException catch (_) {
      emit(const AudioError("الملف الصوتي غير متوفر."));
    } on PlayerInterruptedException catch (_) {
      // Interrupted by a new play request
    } catch (_) {
      emit(const AudioError("حدث خطأ أثناء تشغيل التلاوة."));
    }
  }

  void _prefetchNext(String reciter, int surah, int ayah, {int count = 3}) {
    int curSurah = surah;
    int curAyah = ayah;
    for (int i = 0; i < count; i++) {
      final nextId = _getNextVerseId(curSurah * 1000 + curAyah);
      if (nextId == null) break;
      curSurah = nextId ~/ 1000;
      curAyah = nextId % 1000;
      _downloadManager.downloadVerse(reciter, curSurah, curAyah, null).catchError((_) => '');
    }
  }

  Future<void> _onPlayPlaylist(PlayPlaylist event, Emitter<AudioState> emit) async {
    emit(AudioLoading());
    try {
      _playedCount = 0;
      _currentVerseIds = event.verseIds;
      _currentIndex = event.startIndex;

      final playlist = event.audioUrls.map((path) => AudioSource.file(path)).toList();

      // ignore: deprecated_member_use
      await _audioPlayer.setAudioSource(ConcatenatingAudioSource(children: playlist), initialIndex: event.startIndex);
      _audioPlayer.play();
      emit(AudioPlaying(_currentVerseIds[_currentIndex]));
    } catch (_) {
      emit(const AudioError("Error loading playlist."));
    }
  }

  Future<void> _onPauseAudio(PauseAudio event, Emitter<AudioState> emit) async {
    await _audioPlayer.pause();
    if (_currentVerseIds.isNotEmpty) {
      emit(AudioPaused(_currentVerseIds[_currentIndex]));
    } else {
      emit(AudioIdle());
    }
  }

  Future<void> _onResumeAudio(ResumeAudio event, Emitter<AudioState> emit) async {
    _audioPlayer.play();
    if (_currentVerseIds.isNotEmpty) {
      emit(AudioPlaying(_currentVerseIds[_currentIndex]));
    }
  }

  Future<void> _onStopAudio(StopAudio event, Emitter<AudioState> emit) async {
    await _audioPlayer.stop();
    _currentVerseIds = [];
    _currentIndex = 0;
    _playedCount = 0;
    emit(AudioIdle());
  }

  void _onStateChanged(AudioStateChanged event, Emitter<AudioState> emit) {
    if (_currentVerseIds.isEmpty) return;

    final verseId = _currentVerseIds[_currentIndex];
    if (event.isPlaying) {
      emit(AudioPlaying(verseId));
    } else {
      if (_audioPlayer.processingState == ProcessingState.completed) {
        emit(AudioIdle());
      } else {
        emit(AudioPaused(verseId));
      }
    }
  }

  void _onChangeReciter(ChangeReciter event, Emitter<AudioState> emit) {
    _currentReciter = event.reciterName;
    _prefs.saveReciter(event.reciterName);
    if (state is AudioPlaying || state is AudioPaused) {
      if (_currentVerseIds.isNotEmpty) {
        // Reset play count since we're restarting the verse with a new reciter
        _playedCount = 0; 
        add(PlayVerse('', _currentVerseIds[_currentIndex]));
      }
    }
  }

  Future<void> _onChangeRepeatCount(ChangeRepeatCount event, Emitter<AudioState> emit) async {
    _currentRepeatCount = event.repeatCount;
    await _prefs.saveRepeatCount(event.repeatCount);
    if (_currentVerseIds.isNotEmpty) {
      final verseId = _currentVerseIds[_currentIndex];
      if (state is AudioPlaying) emit(AudioPlaying(verseId));
      if (state is AudioPaused) emit(AudioPaused(verseId));
    }
  }

  void _onSetSleepTimer(SetSleepTimer event, Emitter<AudioState> emit) {
    _sleepTimer?.cancel();
    _sleepTimer = Timer(event.duration, () {
      add(const StopAudio());
    });
  }

  void _onCancelSleepTimer(CancelSleepTimer event, Emitter<AudioState> emit) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
  }

  @override
  Future<void> close() {
    _playerStateSubscription?.cancel();
    _currentIndexSubscription?.cancel();
    _playbackEventSubscription?.cancel();
    _sleepTimer?.cancel();
    _audioPlayer.dispose();
    return super.close();
  }
}
