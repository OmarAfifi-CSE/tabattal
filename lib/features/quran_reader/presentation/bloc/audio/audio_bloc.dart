import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import '../../../../../core/network/audio_download_manager.dart';
import '../../../../../core/services/audio_preferences_service.dart';
import '../../../../../core/utils/verse_ref.dart';
import 'audio_event.dart';
import 'audio_state.dart';

import '../../../../../core/services/quran_audio_handler.dart';
import 'package:audio_service/audio_service.dart';
import '../../../../../core/utils/arabic_text_utils.dart';
import '../../widgets/quran_metadata.dart';

class AudioBloc extends Bloc<AudioEvent, AudioState> {
  final QuranAudioHandler _audioHandler;
  final AudioPlayer _audioPlayer;
  final AudioDownloadManager _downloadManager;
  final AudioPreferencesService _prefs;
  List<VerseRef> _currentVerseIds = [];
  int _currentIndex = 0;
  int _playedCount = 0; 

  late String _currentReciter;
  late int _currentRepeatCount;

  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _currentIndexSubscription;
  StreamSubscription? _playbackEventSubscription;
  StreamSubscription? _actionSubscription;
  Timer? _sleepTimer;

  String get currentReciter => _currentReciter;
  int get currentRepeatCount => _currentRepeatCount;

  AudioBloc(this._audioHandler, this._downloadManager, this._prefs)
      : _audioPlayer = _audioHandler.player,
        super(AudioIdle()) {
    _currentReciter = _prefs.reciter;
    _currentRepeatCount = _prefs.repeatCount;

    on<PlayVerse>(_onPlayVerse, transformer: restartable());
    on<PlayPlaylist>(_onPlayPlaylist, transformer: restartable());
    on<PauseAudio>(_onPauseAudio);
    on<ResumeAudio>(_onResumeAudio);
    on<StopAudio>(_onStopAudio);
    on<NextAyah>(_onNextAyah);
    on<PreviousAyah>(_onPreviousAyah);
    on<NextSurah>(_onNextSurah);
    on<PreviousSurah>(_onPreviousSurah);
    on<AudioStateChanged>(_onStateChanged);
    on<ChangeReciter>(_onChangeReciter);
    on<ChangeRepeatCount>(_onChangeRepeatCount);
    on<SetSleepTimer>(_onSetSleepTimer);
    on<CancelSleepTimer>(_onCancelSleepTimer);
    on<AudioErrorEvent>((event, emit) => emit(AudioError(event.message)));

    _initStreams();
  }

  void _initStreams() {
    _actionSubscription = _audioHandler.actions.listen((action) {
      if (_currentVerseIds.isEmpty) return;
      final currentVerse = _currentVerseIds[_currentIndex];
      switch (action) {
        case QuranAudioAction.nextAyah:
          final next = currentVerse.next;
          if (next != null) add(PlayVerse('', next.verseId));
          break;
        case QuranAudioAction.prevAyah:
          final prev = currentVerse.previous;
          if (prev != null) add(PlayVerse('', prev.verseId));
          break;
        case QuranAudioAction.nextSurah:
          if (currentVerse.surah < 114) add(PlayVerse('', VerseRef(currentVerse.surah + 1, 1).verseId));
          break;
        case QuranAudioAction.prevSurah:
          if (currentVerse.surah > 1) add(PlayVerse('', VerseRef(currentVerse.surah - 1, 1).verseId));
          break;
        case QuranAudioAction.stop:
          _currentVerseIds = [];
          _currentIndex = 0;
          _playedCount = 0;
          add(const StopAudio());
          break;
        case QuranAudioAction.timer:
          break;
      }
    });

    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (_currentVerseIds.isNotEmpty) {
          final currentVerse = _currentVerseIds[_currentIndex];

          bool shouldRepeat = false;
          if (_currentRepeatCount == -1) {
            shouldRepeat = true;
          } else if (_currentRepeatCount > 0 && _playedCount < _currentRepeatCount) {
            shouldRepeat = true;
          }

          if (shouldRepeat) {
            _playedCount++;
            _playLocalOrStream(currentVerse);
          } else {
            final nextVerse = currentVerse.next;
            if (nextVerse != null) {
              add(PlayVerse('', nextVerse.verseId));
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
        add(const AudioStateChanged(isPlaying: false));
        if (e is PlayerException) {
          add(const AudioErrorEvent("Network error: Check connection to stream audio."));
        } else if (e is PlayerInterruptedException) {
          add(const AudioErrorEvent("Playback interrupted."));
        } else {
          add(const AudioErrorEvent("Failed to play audio."));
        }
      },
    );
  }

  Future<void> _playLocalOrStream(VerseRef verse) async {
    final localPath = await _downloadManager.getLocalVersePath(_currentReciter, verse.verseId);

    await _audioHandler.updateItem(MediaItem(
      id: verse.verseId.toString(),
      title: '${QuranMetadata.getSurahNameWithTashkeel(verse.surah)} - الآية ${verse.ayah.toArabicDigits}',
      artist: _currentReciter,
    ));

    if (localPath != null) {
      await _audioPlayer.setFilePath(localPath);
    } else {
      final url = _downloadManager.getStreamingUrl(_currentReciter, verse.surah, verse.ayah);
      await _audioPlayer.setUrl(url);
      _downloadManager.downloadVerse(_currentReciter, verse.surah, verse.ayah, null).catchError((_) => '');
    }
    _audioPlayer.play();
  }

  Future<void> _onPlayVerse(PlayVerse event, Emitter<AudioState> emit) async {
    emit(AudioLoading());
    try {
      _playedCount = 0; 
      final verse = VerseRef.fromId(event.verseId);
      _currentVerseIds = [verse];
      _currentIndex = 0;

      await _playLocalOrStream(verse);

      emit(AudioPlaying(verse.verseId));

      _downloadManager.prefetchVerses(_currentReciter, verse.surah, verse.ayah);

    } on PlayerException catch (_) {
      emit(const AudioError("الملف الصوتي غير متوفر."));
    } on PlayerInterruptedException catch (_) {
      // Interrupted by a new play request
    } catch (_) {
      emit(const AudioError("حدث خطأ أثناء تشغيل التلاوة."));
    }
  }

  Future<void> _onPlayPlaylist(PlayPlaylist event, Emitter<AudioState> emit) async {
    emit(AudioLoading());
    try {
      _playedCount = 0;
      _currentVerseIds = event.verseIds.map((id) => VerseRef.fromId(id)).toList();
      _currentIndex = event.startIndex;

      final playlist = event.audioUrls.map((path) => AudioSource.file(path)).toList();

      // ignore: deprecated_member_use
      await _audioPlayer.setAudioSource(ConcatenatingAudioSource(children: playlist), initialIndex: event.startIndex);
      _audioPlayer.play();
      emit(AudioPlaying(_currentVerseIds[_currentIndex].verseId));
    } on PlayerException catch (_) {
      emit(const AudioError("Error loading playlist."));
    } on PlayerInterruptedException catch (_) {
      // Interrupted
    } catch (_) {
      emit(const AudioError("حدث خطأ أثناء تشغيل القائمة."));
    }
  }

  Future<void> _onPauseAudio(PauseAudio event, Emitter<AudioState> emit) async {
    await _audioPlayer.pause();
    if (_currentVerseIds.isNotEmpty) {
      emit(AudioPaused(_currentVerseIds[_currentIndex].verseId));
    } else {
      emit(AudioIdle());
    }
  }

  Future<void> _onResumeAudio(ResumeAudio event, Emitter<AudioState> emit) async {
    _audioPlayer.play();
    if (_currentVerseIds.isNotEmpty) {
      emit(AudioPlaying(_currentVerseIds[_currentIndex].verseId));
    }
  }

  Future<void> _onStopAudio(StopAudio event, Emitter<AudioState> emit) async {
    _currentVerseIds = [];
    _currentIndex = 0;
    _playedCount = 0;
    await _audioHandler.stop();
    emit(AudioIdle());
  }

  Future<void> _onNextAyah(NextAyah event, Emitter<AudioState> emit) async {
    if (_currentVerseIds.isEmpty) return;
    final next = _currentVerseIds[_currentIndex].next;
    if (next != null) add(PlayVerse('', next.verseId));
  }

  Future<void> _onPreviousAyah(PreviousAyah event, Emitter<AudioState> emit) async {
    if (_currentVerseIds.isEmpty) return;
    final prev = _currentVerseIds[_currentIndex].previous;
    if (prev != null) add(PlayVerse('', prev.verseId));
  }

  Future<void> _onNextSurah(NextSurah event, Emitter<AudioState> emit) async {
    if (_currentVerseIds.isEmpty) return;
    final currentSurah = _currentVerseIds[_currentIndex].surah;
    if (currentSurah < 114) add(PlayVerse('', VerseRef(currentSurah + 1, 1).verseId));
  }

  Future<void> _onPreviousSurah(PreviousSurah event, Emitter<AudioState> emit) async {
    if (_currentVerseIds.isEmpty) return;
    final currentSurah = _currentVerseIds[_currentIndex].surah;
    if (currentSurah > 1) add(PlayVerse('', VerseRef(currentSurah - 1, 1).verseId));
  }

  void _onStateChanged(AudioStateChanged event, Emitter<AudioState> emit) {
    if (_currentVerseIds.isEmpty) return;

    final verseId = _currentVerseIds[_currentIndex].verseId;
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
        _playedCount = 0; 
        add(PlayVerse('', _currentVerseIds[_currentIndex].verseId));
      }
    }
  }

  Future<void> _onChangeRepeatCount(ChangeRepeatCount event, Emitter<AudioState> emit) async {
    _currentRepeatCount = event.repeatCount;
    await _prefs.saveRepeatCount(event.repeatCount);
    if (_currentVerseIds.isNotEmpty) {
      final verseId = _currentVerseIds[_currentIndex].verseId;
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
    _actionSubscription?.cancel();
    _sleepTimer?.cancel();
    _audioPlayer.dispose();
    return super.close();
  }
}
