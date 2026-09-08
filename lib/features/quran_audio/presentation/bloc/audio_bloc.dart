import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audio_service/audio_service.dart';

import '../../../../core/constants/quran_metadata.dart';
import '../../../../core/network/audio_download_manager.dart';
import '../../../../core/services/audio_preferences_service.dart';
import '../../../../core/services/quran_audio_handler.dart';
import '../../../../core/utils/arabic_text_utils.dart';
import '../../../../core/utils/reciter_localization.dart';
import '../../../../core/utils/verse_ref.dart';
import '../../data/models/surah_timing_model.dart';
import '../../data/services/surah_audio_timing_service.dart';
import 'audio_event.dart';
import 'audio_state.dart';

/// Unified 120 FPS Single-Track Continuous Surah Audio Engine.
///
/// Instead of stitching discrete per-ayah files together via fragile multi-file
/// concatenation or crash-prone player ping-pong handoffs on Windows, this engine
/// plays the continuous Surah audio stream with sub-millisecond timestamp seeking
/// and O(log N) binary search active verse synchronization.
class AudioBloc extends Bloc<AudioEvent, AudioState> {
  final QuranAudioHandler _audioHandler;
  final AudioPlayer _audioPlayer;
  final AudioDownloadManager _downloadManager;
  final AudioPreferencesService _prefs;
  final SurahAudioTimingService _timingService;

  SurahTimings? _currentSurahTimings;
  int? _currentPlayingSurah;
  int? _currentPlayingAyah;
  int _playedCount = 0;
  int _playlistGeneration = 0;
  int _activePlaylistGeneration = 0;
  bool _isPlayingOnce = false;
  bool _isSeekingRepeat = false;
  bool _isSingleVersePlayback = false;

  late String _currentCategory;
  late String _currentReciter;
  late int _currentRepeatCount;
  late bool _playOnce;

  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _playbackEventSubscription;
  StreamSubscription? _errorStreamSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _actionSubscription;
  Timer? _sleepTimer;

  static Uri? _cachedArtUri;

  String get currentReciter => _currentReciter;
  String get currentCategory => _currentCategory;
  int get currentRepeatCount => _currentRepeatCount;
  bool get playOnce => _playOnce;

  AudioBloc(
    this._audioHandler,
    this._downloadManager,
    this._prefs, {
    SurahAudioTimingService? timingService,
  })  : _audioPlayer = _audioHandler.player,
        _timingService = timingService ?? SurahAudioTimingService(),
        super(AudioIdle()) {
    _currentCategory = _prefs.category;
    _currentReciter = _prefs.reciter;
    _currentRepeatCount = _prefs.repeatCount;
    _playOnce = _prefs.playOnce;

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
    on<ChangePlayOnce>(_onChangePlayOnce);
    on<SetSleepTimer>(_onSetSleepTimer);
    on<CancelSleepTimer>(_onCancelSleepTimer);
    on<AudioErrorEvent>((event, emit) => emit(AudioError(event.message)));
    on<AudioPlatformError>(_onPlatformError);

    _initStreams();
  }

  void _initStreams() {
    _actionSubscription = _audioHandler.actions.listen((action) {
      switch (action) {
        case QuranAudioAction.nextAyah:
          add(const NextAyah());
          break;
        case QuranAudioAction.prevAyah:
          add(const PreviousAyah());
          break;
        case QuranAudioAction.nextSurah:
          add(const NextSurah());
          break;
        case QuranAudioAction.prevSurah:
          add(const PreviousSurah());
          break;
        case QuranAudioAction.stop:
          add(const StopAudio());
          break;
        case QuranAudioAction.timer:
          break;
      }
    });

    _bindPlayerStreams();
  }

  void _bindPlayerStreams() {
    _playerStateSubscription?.cancel();
    _playbackEventSubscription?.cancel();
    _errorStreamSubscription?.cancel();
    _positionSubscription?.cancel();

    // 1. Position Stream: Real-time verse tracking and repeat loop management
    _positionSubscription = _audioPlayer.positionStream.listen((pos) {
      if (_activePlaylistGeneration == 0) return;
      if (_currentSurahTimings != null && _currentSurahTimings!.verseTimings.isNotEmpty) {
        final timings = _currentSurahTimings!;
        final verse = timings.findVerseAt(pos);
        if (verse == null) return;

        // Active verse transition: notify UI for instant highlight and update media metadata
        if (_currentPlayingAyah != verse.ayah) {
          _currentPlayingAyah = verse.ayah;
          _playedCount = 0;
          add(AudioStateChanged(
            currentVerseId: verse.verseId,
            isPlaying: _audioPlayer.playing,
          ));
          unawaited(_updateMediaItem(VerseRef(verse.surah, verse.ayah)));
        }

        // Repeat count & Play Once management at verse boundary
        final msRemaining = (verse.end - pos).inMilliseconds;
        if (msRemaining <= 120 && msRemaining >= -350 && !_isSeekingRepeat) {
          if (_currentRepeatCount == -1) {
            _isSeekingRepeat = true;
            _audioPlayer.seek(verse.start).whenComplete(() {
              Future.delayed(const Duration(milliseconds: 250), () {
                _isSeekingRepeat = false;
              });
            });
          } else if (_currentRepeatCount > 1) {
            if (_playedCount + 1 < _currentRepeatCount) {
              _isSeekingRepeat = true;
              _playedCount++;
              _audioPlayer.seek(verse.start).whenComplete(() {
                Future.delayed(const Duration(milliseconds: 250), () {
                  _isSeekingRepeat = false;
                });
              });
            }
          } else if (_isPlayingOnce) {
            add(const StopAudio());
          }
        }
      }
    });

    // 2. Player State Stream: Handles completion and transport play/pause updates
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      if (_activePlaylistGeneration == 0) return;
      if (state.processingState == ProcessingState.completed) {
        if (_isPlayingOnce) {
          add(const StopAudio());
          return;
        }

        if (_currentRepeatCount == -1) {
          _audioPlayer.seek(Duration.zero).then((_) {
            _audioPlayer.play();
          });
          return;
        }

        if (_isSingleVersePlayback) {
          if (_currentRepeatCount > 1 && _playedCount + 1 < _currentRepeatCount) {
            _playedCount++;
            _audioPlayer.seek(Duration.zero).then((_) {
              _audioPlayer.play();
            });
            return;
          }
          if (_currentPlayingSurah != null && _currentPlayingAyah != null) {
            final surahLength = QuranMetadata.surahLengthOf(_currentPlayingSurah!);
            if (_currentPlayingAyah! < surahLength) {
              add(PlayVerse('', VerseRef(_currentPlayingSurah!, _currentPlayingAyah! + 1).verseId));
            } else if (_currentPlayingSurah! < 114) {
              add(PlayVerse('', VerseRef(_currentPlayingSurah! + 1, 1).verseId));
            } else {
              add(const StopAudio());
            }
          }
          return;
        }

        if (_currentPlayingSurah != null && _currentPlayingSurah! < 114) {
          final nextSurah = _currentPlayingSurah! + 1;
          add(PlayVerse('', VerseRef(nextSurah, 1).verseId));
        } else {
          add(const StopAudio());
        }
      } else {
        add(AudioStateChanged(isPlaying: state.playing));
      }
    });

    // 3. Playback event stream error handling
    _playbackEventSubscription = _audioPlayer.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace stackTrace) async {
        _playlistGeneration++;
        _activePlaylistGeneration = 0;
        _currentSurahTimings = null;
        _currentPlayingSurah = null;
        _currentPlayingAyah = null;
        _playedCount = 0;
        _isSingleVersePlayback = false;

        try {
          await _audioPlayer.stop();
          await _audioHandler.stop();
        } catch (_) {}

        if (_isNetworkError(e)) {
          add(const AudioErrorEvent("audioErrorNoInternet"));
        } else if (e is PlayerException) {
          add(const AudioErrorEvent("audioErrorFileNotFound"));
        } else {
          add(const AudioErrorEvent("audioErrorPlayback"));
        }
      },
    );

    // 4. Native platform error stream (just_audio async errors)
    _errorStreamSubscription = _audioPlayer.errorStream.listen((e) {
      add(AudioPlatformError(e));
    });
  }

  Future<void> _onPlayVerse(PlayVerse event, Emitter<AudioState> emit) async {
    final verse = VerseRef.fromId(event.verseId);
    final int myGen = ++_playlistGeneration;
    _isPlayingOnce = _playOnce;

    // Case 1: Same surah already active — sub-millisecond instant seek
    if (_currentPlayingSurah == verse.surah && _activePlaylistGeneration > 0) {
      if (_currentSurahTimings != null && _currentSurahTimings!.verseTimings.isNotEmpty) {
        final targetVerse =
            _currentSurahTimings!.getVerse(verse.ayah) ?? _currentSurahTimings!.verseTimings.first;
        _currentPlayingAyah = targetVerse.ayah;
        _playedCount = 0;

        await _audioPlayer.seek(targetVerse.start);
      } else {
        _currentPlayingAyah = verse.ayah;
        _playedCount = 0;
      }

      if (!_audioPlayer.playing) {
        unawaited(_audioPlayer.play());
      }
      emit(AudioPlaying(verse.verseId));
      unawaited(_updateMediaItem(verse));
      return;
    }

    // Case 2: New Surah or fresh playback (Full Surah Stream or Offline Files)
    _activePlaylistGeneration = 0;
    _currentSurahTimings = null;
    _currentPlayingSurah = null;
    _currentPlayingAyah = null;
    _playedCount = 0;
    emit(AudioLoading());

    try {
      final reciterPath = AudioDownloadManager.getReciterPath(
        _currentCategory,
        _currentReciter,
      );

      // 1. Check for local full surah audio file on disk first
      final localPath = await _downloadManager.getLocalSurahPath(
        _currentCategory,
        _currentReciter,
        verse.surah,
      );

      // 2. Attempt to load surah timings (from memory cache, local SharedPreferences, or remote API)
      SurahTimings? timings;
      try {
        timings = await _timingService.getSurahTimings(
          reciterPath: reciterPath,
          surahNumber: verse.surah,
        );
      } catch (_) {
        timings = null;
      }

      if (_playlistGeneration != myGen) return;

      // 3. Fallback to local individual ayah file if neither full surah nor remote stream is available
      String? localVersePath;
      if ((localPath == null || localPath.isEmpty) &&
          (timings == null || timings.audioUrl.isEmpty)) {
        localVersePath = await _downloadManager.getLocalVersePath(
          _currentCategory,
          _currentReciter,
          verse.verseId,
        );
      }

      if (_playlistGeneration != myGen) return;

      // 4. If no local file on disk and no remote stream available, report no internet
      if ((localPath == null || localPath.isEmpty) &&
          (timings == null || timings.audioUrl.isEmpty) &&
          (localVersePath == null || localVersePath.isEmpty)) {
        emit(const AudioError("audioErrorNoInternet"));
        return;
      }

      final Duration initialPosition;
      final int targetAyah;
      final String audioPath;

      if (localPath != null && localPath.isNotEmpty) {
        audioPath = localPath;
        _isSingleVersePlayback = false;
        if (timings != null && timings.verseTimings.isNotEmpty) {
          final targetVerse = timings.getVerse(verse.ayah) ?? timings.verseTimings.first;
          initialPosition = targetVerse.start;
          targetAyah = targetVerse.ayah;
        } else {
          initialPosition = Duration.zero;
          targetAyah = verse.ayah;
          timings ??= SurahTimings(
            surah: verse.surah,
            audioUrl: localPath,
            verseTimings: const [],
          );
        }
      } else if (timings != null && timings.audioUrl.isNotEmpty) {
        audioPath = timings.audioUrl;
        _isSingleVersePlayback = false;
        if (timings.verseTimings.isNotEmpty) {
          final targetVerse = timings.getVerse(verse.ayah) ?? timings.verseTimings.first;
          initialPosition = targetVerse.start;
          targetAyah = targetVerse.ayah;
        } else {
          initialPosition = Duration.zero;
          targetAyah = verse.ayah;
        }
      } else {
        audioPath = localVersePath!;
        _isSingleVersePlayback = true;
        initialPosition = Duration.zero;
        targetAyah = verse.ayah;
        timings = SurahTimings(
          surah: verse.surah,
          audioUrl: localVersePath,
          verseTimings: const [],
        );
      }

      final AudioSource source = _createAudioSource(audioPath);

      await _audioPlayer.setAudioSource(
        source,
        initialPosition: initialPosition,
      );
      if (_playlistGeneration != myGen) return;

      if (_currentRepeatCount == -1) {
        await _audioPlayer.setLoopMode(LoopMode.one);
      } else {
        await _audioPlayer.setLoopMode(LoopMode.off);
      }

      _currentSurahTimings = timings;
      _currentPlayingSurah = verse.surah;
      _currentPlayingAyah = targetAyah;
      _playedCount = 0;
      _activePlaylistGeneration = myGen;

      emit(AudioPlaying(VerseRef(verse.surah, targetAyah).verseId));
      unawaited(_updateMediaItem(VerseRef(verse.surah, targetAyah)));
      unawaited(_audioPlayer.play());
    } on PlayerException catch (e) {
      if (_playlistGeneration != myGen) return;
      final defaultKey = _isNetworkError(e) ? "audioErrorNoInternet" : "audioErrorFileNotFound";
      await _handleAudioError(e, emit, defaultErrorKey: defaultKey);
    } on PlayerInterruptedException catch (_) {
      // Handled cleanly when a newer request interrupts
    } catch (e) {
      if (_playlistGeneration != myGen) return;
      final defaultKey = _isNetworkError(e) ? "audioErrorNoInternet" : "audioErrorPlayback";
      await _handleAudioError(e, emit, defaultErrorKey: defaultKey);
    }
  }

  Future<void> _onPlayPlaylist(
    PlayPlaylist event,
    Emitter<AudioState> emit,
  ) async {
    if (event.verseIds.isEmpty) return;
    final startVerseId = event.verseIds[event.startIndex.clamp(0, event.verseIds.length - 1)];
    add(PlayVerse('', startVerseId));
  }

  Future<void> _onPauseAudio(PauseAudio event, Emitter<AudioState> emit) async {
    await _audioPlayer.pause();
    if (_currentPlayingSurah != null && _currentPlayingAyah != null) {
      emit(AudioPaused(VerseRef(_currentPlayingSurah!, _currentPlayingAyah!).verseId));
    } else {
      emit(AudioIdle());
    }
  }

  Future<void> _onResumeAudio(
    ResumeAudio event,
    Emitter<AudioState> emit,
  ) async {
    _audioPlayer.play();
    if (_currentPlayingSurah != null && _currentPlayingAyah != null) {
      emit(AudioPlaying(VerseRef(_currentPlayingSurah!, _currentPlayingAyah!).verseId));
    }
  }

  Future<void> _onStopAudio(StopAudio event, Emitter<AudioState> emit) async {
    _playlistGeneration++;
    _activePlaylistGeneration = 0;
    _currentSurahTimings = null;
    _currentPlayingSurah = null;
    _currentPlayingAyah = null;
    _playedCount = 0;
    _isSingleVersePlayback = false;
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    await _audioHandler.stop();
    emit(AudioIdle());
  }

  Future<void> _onNextAyah(NextAyah event, Emitter<AudioState> emit) async {
    if (_currentPlayingSurah == null || _currentPlayingAyah == null) return;
    final surahLength = QuranMetadata.surahLengthOf(_currentPlayingSurah!);

    if (_currentSurahTimings != null && _currentSurahTimings!.verseTimings.isNotEmpty) {
      if (_currentPlayingAyah! < surahLength) {
        final nextAyah = _currentPlayingAyah! + 1;
        final nextVerse = _currentSurahTimings!.getVerse(nextAyah);
        if (nextVerse != null) {
          _currentPlayingAyah = nextAyah;
          _playedCount = 0;
          emit(AudioPlaying(nextVerse.verseId));
          unawaited(_updateMediaItem(VerseRef(_currentPlayingSurah!, nextAyah)));
          await _audioPlayer.seek(nextVerse.start);
          if (!_audioPlayer.playing) unawaited(_audioPlayer.play());
          return;
        }
      }
    } else {
      // Direct full surah stream without verse timestamps: forward 15 seconds
      final currentPos = _audioPlayer.position;
      final dur = _audioPlayer.duration ?? Duration.zero;
      final newPos = currentPos + const Duration(seconds: 15);
      if (newPos < dur) {
        await _audioPlayer.seek(newPos);
        return;
      }
    }

    if (_currentPlayingSurah! < 114) {
      add(PlayVerse('', VerseRef(_currentPlayingSurah! + 1, 1).verseId));
    }
  }

  Future<void> _onPreviousAyah(
    PreviousAyah event,
    Emitter<AudioState> emit,
  ) async {
    if (_currentPlayingSurah == null || _currentPlayingAyah == null) return;

    if (_currentSurahTimings != null && _currentSurahTimings!.verseTimings.isNotEmpty) {
      if (_currentPlayingAyah! > 1) {
        final prevAyah = _currentPlayingAyah! - 1;
        final prevVerse = _currentSurahTimings!.getVerse(prevAyah);
        if (prevVerse != null) {
          _currentPlayingAyah = prevAyah;
          _playedCount = 0;
          emit(AudioPlaying(prevVerse.verseId));
          unawaited(_updateMediaItem(VerseRef(_currentPlayingSurah!, prevAyah)));
          await _audioPlayer.seek(prevVerse.start);
          if (!_audioPlayer.playing) unawaited(_audioPlayer.play());
          return;
        }
      } else {
        // At first ayah of the surah: rewind to the start of this first ayah
        final firstVerse = _currentSurahTimings!.getVerse(1);
        if (firstVerse != null) {
          emit(AudioPlaying(firstVerse.verseId));
          await _audioPlayer.seek(firstVerse.start);
          if (!_audioPlayer.playing) unawaited(_audioPlayer.play());
          return;
        }
      }
    } else {
      // Direct full surah stream without verse timestamps:
      final pos = _audioPlayer.position;
      if (pos.inSeconds > 5) {
        await _audioPlayer.seek(Duration.zero);
        return;
      }
      // If within first 5 seconds, fall through to previous surah below
    }

    if (_currentPlayingSurah! > 1) {
      final prevSurah = _currentPlayingSurah! - 1;
      final prevSurahLength = QuranMetadata.surahLengthOf(prevSurah);
      add(PlayVerse('', VerseRef(prevSurah, prevSurahLength).verseId));
    }
  }

  Future<void> _onNextSurah(NextSurah event, Emitter<AudioState> emit) async {
    final s = _currentPlayingSurah ?? 1;
    if (s < 114) {
      add(PlayVerse('', VerseRef(s + 1, 1).verseId));
    }
  }

  Future<void> _onPreviousSurah(
    PreviousSurah event,
    Emitter<AudioState> emit,
  ) async {
    final s = _currentPlayingSurah ?? 1;
    if (s > 1) {
      add(PlayVerse('', VerseRef(s - 1, 1).verseId));
    }
  }

  void _onStateChanged(AudioStateChanged event, Emitter<AudioState> emit) {
    if ((state is AudioLoading || _activePlaylistGeneration == 0) &&
        event.currentVerseId == null) {
      return;
    }

    final verseId = event.currentVerseId ??
        (_currentPlayingSurah != null && _currentPlayingAyah != null
            ? VerseRef(_currentPlayingSurah!, _currentPlayingAyah!).verseId
            : null);

    if (verseId == null) {
      if (_activePlaylistGeneration == 0) {
        emit(AudioIdle());
      }
      return;
    }

    if (event.isPlaying) {
      emit(AudioPlaying(verseId));
    } else {
      if (_audioPlayer.processingState == ProcessingState.completed) {
        _activePlaylistGeneration = 0;
        _currentPlayingSurah = null;
        _currentPlayingAyah = null;
        _currentSurahTimings = null;
        emit(AudioIdle());
      } else {
        emit(AudioPaused(verseId));
      }
    }
  }

  void _onChangeReciter(ChangeReciter event, Emitter<AudioState> emit) {
    final hasChanged =
        _currentCategory != event.categoryName || _currentReciter != event.reciterName;
    _currentCategory = event.categoryName;
    _currentReciter = event.reciterName;
    _prefs.saveCategory(event.categoryName);
    _prefs.saveReciter(event.reciterName);

    if (hasChanged) {
      final prevSurah = _currentPlayingSurah;
      final prevAyah = _currentPlayingAyah;
      _currentSurahTimings = null;
      _currentPlayingSurah = null;
      _currentPlayingAyah = null;
      _playedCount = 0;
      _activePlaylistGeneration = 0;

      if (event.restartPlayback && (state is AudioPlaying || state is AudioPaused)) {
        if (prevSurah != null && prevAyah != null) {
          final targetVerseId = VerseRef(prevSurah, prevAyah).verseId;
          add(PlayVerse('', targetVerseId));
        }
      }
    }
  }

  Future<void> _onChangeRepeatCount(
    ChangeRepeatCount event,
    Emitter<AudioState> emit,
  ) async {
    _currentRepeatCount = event.repeatCount;
    await _prefs.saveRepeatCount(event.repeatCount);
    if (_currentRepeatCount == -1 &&
        (_currentSurahTimings == null || _currentSurahTimings!.verseTimings.isEmpty)) {
      await _audioPlayer.setLoopMode(LoopMode.one);
    } else {
      await _audioPlayer.setLoopMode(LoopMode.off);
    }
    if (_currentPlayingSurah != null && _currentPlayingAyah != null) {
      final verseId = VerseRef(_currentPlayingSurah!, _currentPlayingAyah!).verseId;
      if (state is AudioPlaying) emit(AudioPlaying(verseId));
      if (state is AudioPaused) emit(AudioPaused(verseId));
    }
  }

  void _onChangePlayOnce(ChangePlayOnce event, Emitter<AudioState> emit) {
    _playOnce = event.playOnce;
    _isPlayingOnce = event.playOnce;
    _prefs.savePlayOnce(event.playOnce);
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

  Future<void> _onPlatformError(
    AudioPlatformError event,
    Emitter<AudioState> emit,
  ) async {
    if (_playlistGeneration != _activePlaylistGeneration) return;
    if (state is! AudioPlaying && state is! AudioLoading) return;
    final e = event.error;
    if (_isNetworkError(e)) {
      await _handleAudioError(e, emit, defaultErrorKey: "audioErrorNoInternet");
    } else {
      await _handleAudioError(e, emit, defaultErrorKey: "audioErrorFileNotFound");
    }
  }

  Future<void> _updateMediaItem(VerseRef verse) async {
    final isEn = _prefs.appLocale == 'en';
    final String title = isEn
        ? 'Surah ${QuranMetadata.getSurahNameEnglish(verse.surah)} • Ayah ${verse.ayah}'
        : '${QuranMetadata.getSurahNameWithTashkeel(verse.surah)} • آية ${verse.ayah.toArabicDigits}';

    final artUri = await _getArtUri();

    await _audioHandler.updateItem(
      MediaItem(
        id: verse.verseId.toString(),
        title: title,
        artist: ReciterLocalization.localizeByLang(isEn, _currentReciter),
        duration: _audioPlayer.duration,
        artUri: artUri,
      ),
    );
  }

  Future<Uri> _getArtUri() async {
    if (_cachedArtUri != null) return _cachedArtUri!;
    if (kIsWeb) {
      _cachedArtUri = Uri.base.resolve('icons/Icon-512.png');
      return _cachedArtUri!;
    }
    try {
      final dir = await getTemporaryDirectory();
      // Guard: Never write to the workspace root or current directory in tests/CLI
      if (dir.path == '.' || dir.path.isEmpty) {
        _cachedArtUri = Uri.parse('asset:///assets/images/app_icon.png');
        return _cachedArtUri!;
      }
      final file = File('${dir.path}/app_icon.png');
      if (!await file.exists()) {
        final byteData = await rootBundle.load('assets/images/app_icon.png');
        await file.writeAsBytes(
          byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          ),
          flush: true,
        );
      }
      _cachedArtUri = Uri.file(file.path);
    } catch (_) {
      _cachedArtUri = Uri.parse('asset:///assets/images/app_icon.png');
    }
    return _cachedArtUri!;
  }

  bool _isNetworkError(Object error) {
    if (error is SocketException ||
        error is TimeoutException ||
        error is HttpException) {
      return true;
    }
    final errStr = error.toString().toLowerCase();
    return errStr.contains('socketexception') ||
        errStr.contains('failed host lookup') ||
        errStr.contains('no internet') ||
        errStr.contains('connection refused') ||
        errStr.contains('connection closed') ||
        errStr.contains('clientexception') ||
        errStr.contains('network') ||
        errStr.contains('offline') ||
        errStr.contains('connection timed out') ||
        errStr.contains('software caused connection abort') ||
        errStr.contains('unknownhostexception') ||
        errStr.contains('httpdatasource') ||
        errStr.contains('unable to connect') ||
        errStr.contains('unresolvedaddress') ||
        errStr.contains('ioexception') ||
        errStr.contains('source error') ||
        errStr.contains('behindlivewindowexception') ||
        errStr.contains('handshake') ||
        errStr.contains('unreachable') ||
        (errStr.contains('response code:') && !errStr.contains('404')) ||
        errStr.contains('failed to connect');
  }

  Future<void> _handleAudioError(
    Object error,
    Emitter<AudioState> emit, {
    String defaultErrorKey = "audioErrorPlayback",
  }) async {
    final VerseRef? stoppedVerse =
        _currentPlayingSurah != null && _currentPlayingAyah != null
            ? VerseRef(_currentPlayingSurah!, _currentPlayingAyah!)
            : null;

    _playlistGeneration++;
    _activePlaylistGeneration = 0;
    _currentSurahTimings = null;
    _currentPlayingSurah = null;
    _currentPlayingAyah = null;
    _playedCount = 0;

    final isNetwork = _isNetworkError(error);

    if (isNetwork && stoppedVerse != null && stoppedVerse.ayah > 0) {
      try {
        final isEn = _prefs.appLocale == 'en';
        final surahName = isEn
            ? QuranMetadata.getSurahNameEnglish(stoppedVerse.surah)
            : QuranMetadata.getSurahNameWithTashkeel(stoppedVerse.surah);
        final ayahStr = isEn
            ? stoppedVerse.ayah.toString()
            : stoppedVerse.ayah.toArabicDigits;

        final title = isEn
            ? 'Surah $surahName • Ayah $ayahStr (Stopped)'
            : '$surahName • آية $ayahStr (توقفت)';
        final subtitle = isEn
            ? 'Internet required for non-downloaded ayahs'
            : 'يلزم الإنترنت لتشغيل الآيات غير المحملة';

        await _audioHandler.showStoppedNotification(
          title: title,
          subtitle: subtitle,
        );
      } catch (_) {
        try {
          await _audioPlayer.stop();
          await _audioHandler.stop();
        } catch (_) {}
      }
    } else {
      try {
        await _audioPlayer.stop();
        await _audioHandler.stop();
      } catch (_) {}
    }

    if (isNetwork) {
      emit(const AudioError("audioErrorNoInternet"));
    } else if (error is PlayerException) {
      emit(const AudioError("audioErrorFileNotFound"));
    } else {
      emit(AudioError(defaultErrorKey));
    }
  }

  AudioSource _createAudioSource(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return AudioSource.uri(Uri.parse(path));
    } else {
      return AudioSource.file(path);
    }
  }

  @override
  Future<void> close() {
    _playerStateSubscription?.cancel();
    _playbackEventSubscription?.cancel();
    _errorStreamSubscription?.cancel();
    _positionSubscription?.cancel();
    _actionSubscription?.cancel();
    _sleepTimer?.cancel();
    _audioPlayer.dispose();
    return super.close();
  }
}
