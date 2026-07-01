import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../../core/network/audio_download_manager.dart';
import '../../../../../core/services/audio_preferences_service.dart';
import '../../../../../core/utils/verse_ref.dart';
import 'audio_event.dart';
import 'audio_state.dart';

import '../../../../../core/services/quran_audio_handler.dart';
import 'package:audio_service/audio_service.dart';
import '../../../../../core/utils/arabic_text_utils.dart';
import '../../../../../core/utils/reciter_localization.dart';
import '../../widgets/quran_metadata.dart';

class AudioBloc extends Bloc<AudioEvent, AudioState> {
  final QuranAudioHandler _audioHandler;
  final AudioPlayer _audioPlayer;
  final AudioDownloadManager _downloadManager;
  final AudioPreferencesService _prefs;
  List<VerseRef> _currentVerseIds = [];
  int _currentIndex = 0;
  // ignore: unused_field — kept for compatibility with existing event handlers
  int _playedCount = 0;

  static Uri? _cachedArtUri;

  Future<Uri> _getArtUri() async {
    if (_cachedArtUri != null) return _cachedArtUri!;
    if (kIsWeb) {
      _cachedArtUri = Uri.parse('/assets/images/app_icon.png');
      return _cachedArtUri!;
    }
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/app_icon.png');
      if (!await file.exists()) {
        final byteData = await rootBundle.load('assets/images/app_icon.png');
        await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
      }
      _cachedArtUri = Uri.parse('file://${file.path}');
    } catch (e) {
      _cachedArtUri = Uri.parse('asset:///assets/images/app_icon.png');
    }
    return _cachedArtUri!;
  }

  late String _currentReciter;
  late int _currentRepeatCount;

  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _currentIndexSubscription;
  StreamSubscription? _playbackEventSubscription;
  StreamSubscription? _actionSubscription;
  Timer? _sleepTimer;

  String get currentReciter => _currentReciter;
  int get currentRepeatCount => _currentRepeatCount;

  // Used to cancel in-progress background prefill when a new verse is played.
  // ignore: deprecated_member_use
  ConcatenatingAudioSource? _activePrefillPlaylist;

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
          if (prev != null) add(PlayVerse('', prev.verseId, skipBasmalah: true));
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
        // The playlist finished
        if (_currentVerseIds.isNotEmpty && _currentRepeatCount != -1) {
          if (kIsWeb) {
            // On web, we only load 1 ayah at a time (to avoid browser DOM limits and ConcatenatingAudioSource bugs).
            // So when it completes, we advance to the next Ayah.
            add(const NextAyah());
          } else {
            // On mobile, the entire surah playlist finished — advance to the next surah
            final currentVerse = _currentVerseIds[_currentIndex];
            final nextSurah = currentVerse.surah + 1;
            if (nextSurah <= 114) {
              add(PlayVerse('', VerseRef(nextSurah, 1).verseId));
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

    _currentIndexSubscription = _audioPlayer.currentIndexStream.listen((index) async {
      if (index != null && _currentVerseIds.isNotEmpty && index < _currentVerseIds.length) {
        _currentIndex = index;
        final verse = _currentVerseIds[index];
        final isEn = _prefs.appLocale == 'en';
        final String title;
        if (verse.ayah == 0) {
          title = isEn 
              ? 'Surah ${QuranMetadata.getSurahNameEnglish(verse.surah)} - Basmalah' 
              : '${QuranMetadata.getSurahNameWithTashkeel(verse.surah)} - البسملة';
        } else {
          title = isEn
              ? 'Surah ${QuranMetadata.getSurahNameEnglish(verse.surah)} - Ayah ${verse.ayah}'
              : '${QuranMetadata.getSurahNameWithTashkeel(verse.surah)} - الآية ${verse.ayah.toArabicDigits}';
        }
        
        final artUri = await _getArtUri();
        
        _audioHandler.updateItem(MediaItem(
          id: verse.verseId.toString(),
          title: title,
          artist: ReciterLocalization.localizeByLang(isEn, _currentReciter),
          duration: _audioPlayer.duration,
          artUri: artUri,
        ));
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

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns the local path, downloading first if not yet cached.
  Future<String> _ensureLocalPath(int surah, int ayah, int verseId) async {
    final existing = await _downloadManager.getLocalVersePath(_currentReciter, verseId);
    if (existing != null) return existing;
    return _downloadManager.downloadVerse(_currentReciter, surah, ayah, null);
  }

  /// Returns up to [count] consecutive VerseRefs starting from [startVerse].
  List<VerseRef> _nextVerses(VerseRef startVerse, int count) {
    final result = <VerseRef>[];
    VerseRef? cur = startVerse;
    for (int i = 0; i < count; i++) {
      if (cur == null) break;
      result.add(cur);
      cur = cur.next;
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // _onPlayVerse — Gapless Surah Playlist Strategy
  //
  // 1. Download the starting ayah (+ Basmalah if needed) first → begin playback.
  // 2. In the background, download the next 5 ayahs sequentially (one at a time)
  //    and append each to the live ConcatenatingAudioSource as it becomes ready.
  // 3. Repeat: after each download completes, start the next one, for up to 5
  //    ayahs ahead of the currently-playing ayah.
  //
  // This gives true gapless playback (no stop/start between ayahs) while
  // keeping network usage minimal (sequential, one file at a time).
  // ---------------------------------------------------------------------------
  Future<void> _onPlayVerse(PlayVerse event, Emitter<AudioState> emit) async {
    emit(AudioLoading());
    try {
      _playedCount = 0;
      final verse = VerseRef.fromId(event.verseId);
      final bool needsBasmalah = !event.skipBasmalah &&
          verse.ayah == 1 &&
          verse.surah != 1 &&
          verse.surah != 9;
      final int repeat = _currentRepeatCount > 0 ? _currentRepeatCount : 1;

      // --- Step 1: Pre-download first 3 ayahs (+ Basmalah) in PARALLEL ---
      // This ensures ExoPlayer has items buffered from the start, eliminating
      // the audio click that occurs when items are added after playback starts.
      final List<Future<String>> downloadFutures = [];
      if (needsBasmalah) {
        downloadFutures.add(_ensureLocalPath(1, 1, 1001));
      }
      const int preloadCount = kIsWeb ? 1 : 3;
      final List<VerseRef> versesToPreload = _nextVerses(verse, preloadCount);
      for (final v in versesToPreload) {
        downloadFutures.add(_ensureLocalPath(v.surah, v.ayah, v.verseId));
      }
      final List<String> prePaths = await Future.wait(downloadFutures);

      // --- Step 2: Build initial playlist from pre-downloaded files ---
      final List<VerseRef> verseQueue = [];
      final List<AudioSource> initialSources = [];
      int pathIdx = 0;

      if (needsBasmalah) {
        verseQueue.add(VerseRef(verse.surah, 0));
        initialSources.add(_createAudioSource(prePaths[pathIdx++]));
      }

      for (final v in versesToPreload) {
        final path = prePaths[pathIdx++];
        for (int r = 0; r < repeat; r++) {
          verseQueue.add(v);
          initialSources.add(_createAudioSource(path));
        }
      }

      _currentVerseIds = verseQueue;
      _currentIndex = 0;

      // ignore: deprecated_member_use
      final playlist = ConcatenatingAudioSource(children: initialSources);
      _activePrefillPlaylist = playlist;

      final isEn = _prefs.appLocale == 'en';
      final String initialTitle;
      if (verseQueue.first.ayah == 0) {
        initialTitle = isEn 
            ? 'Surah ${QuranMetadata.getSurahNameEnglish(verse.surah)} - Basmalah' 
            : '${QuranMetadata.getSurahNameWithTashkeel(verse.surah)} - البسملة';
      } else {
        initialTitle = isEn
            ? 'Surah ${QuranMetadata.getSurahNameEnglish(verse.surah)} - Ayah ${verse.ayah}'
            : '${QuranMetadata.getSurahNameWithTashkeel(verse.surah)} - الآية ${verse.ayah.toArabicDigits}';
      }

      final artUri = await _getArtUri();

      await _audioHandler.updateItem(MediaItem(
        id: verseQueue.first.verseId.toString(),
        title: initialTitle,
        artist: ReciterLocalization.localizeByLang(isEn, _currentReciter),
        duration: _audioPlayer.duration,
        artUri: artUri,
      ));

      await _audioPlayer.stop();
      await _audioPlayer.setAudioSource(playlist);
      await _audioPlayer.setLoopMode(_currentRepeatCount == -1 ? LoopMode.one : LoopMode.off);
      _audioPlayer.play();
      emit(AudioPlaying(_currentVerseIds.first.verseId));

      // --- Step 3: Background-append remaining ayahs sequentially ---
      if (!kIsWeb && _currentRepeatCount != -1 && versesToPreload.isNotEmpty) {
        final afterPreload = versesToPreload.last.next;
        if (afterPreload != null) {
          _backgroundPrefill(
            playlist: playlist,
            reciter: _currentReciter,
            surah: afterPreload.surah,
            startAyah: afterPreload.ayah,
            repeat: repeat,
            lookahead: 5,
          );
        }
      }

    } on PlayerException catch (_) {
      emit(const AudioError("الملف الصوتي غير متوفر."));
    } on PlayerInterruptedException catch (_) {
      // Interrupted by a new play request — expected
    } catch (_) {
      emit(const AudioError("حدث خطأ أثناء تشغيل التلاوة."));
    }
  }

  /// Downloads the next ayahs sequentially and appends them to [playlist].
  /// Downloads one at a time (low network footprint), up to [lookahead] ahead
  /// of the CURRENTLY playing index, not from the starting ayah.
  Future<void> _backgroundPrefill({
    // ignore: deprecated_member_use
    required ConcatenatingAudioSource playlist,
    required String reciter,
    required int surah,
    required int startAyah,
    required int repeat,
    required int lookahead,
  }) async {
    final surahLength = QuranMetadata.surahLengthOf(surah);

    for (int a = startAyah; a <= surahLength; a++) {
      // Stop if this playlist was replaced by a new PlayVerse call
      if (_activePrefillPlaylist != playlist) return;

      // Only prefetch if we're within [lookahead] ayahs of the current position
      final currentAyah = _currentVerseIds.isNotEmpty
          ? _currentVerseIds[_currentIndex].ayah
          : startAyah;
      if (a > currentAyah + lookahead) {
        // Too far ahead — wait until the player catches up
        await Future.delayed(const Duration(milliseconds: 500));
        // Retry this same ayah
        a--;
        continue;
      }

      final v = VerseRef(surah, a);
      final String path;
      try {
        path = await _ensureLocalPath(v.surah, v.ayah, v.verseId);
      } catch (_) {
        continue; // skip if download fails, player will handle the missing item
      }

      if (_activePrefillPlaylist != playlist) return;

      for (int r = 0; r < repeat; r++) {
        _currentVerseIds = [..._currentVerseIds, v];
        // ignore: deprecated_member_use
        await playlist.add(_createAudioSource(path));
      }
    }
  }

  Future<void> _onPlayPlaylist(PlayPlaylist event, Emitter<AudioState> emit) async {
    emit(AudioLoading());
    try {
      _playedCount = 0;
      _currentVerseIds = event.verseIds.map((id) => VerseRef.fromId(id)).toList();
      _currentIndex = event.startIndex;

      final playlist = event.audioUrls.map((path) => _createAudioSource(path)).toList();

      await _audioPlayer.stop();
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
    _activePrefillPlaylist = null;
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
    if (prev != null) add(PlayVerse('', prev.verseId, skipBasmalah: true));
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
  // ---------------------------------------------------------------------------
  // Web-safe AudioSource helper
  // ---------------------------------------------------------------------------
  AudioSource _createAudioSource(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return AudioSource.uri(Uri.parse(path));
    } else {
      return AudioSource.file(path);
    }
  }

}