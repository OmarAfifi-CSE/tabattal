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
  // Incremented each time a new PlayVerse starts. Any in-flight handler or
  // background prefill that sees a different value self-cancels immediately.
  int _playlistGeneration = 0;
  // Set to the generation value ONLY AFTER setAudioSource+play() actually succeed.
  // Used in the `completed` handler to detect stale events from a previous
  // surah that fired while a new PlayVerse was still loading its files.
  int _activePlaylistGeneration = 0;

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
        // Guard against stale completed events: if a new PlayVerse has started
        // but hasn't called play() yet, _currentVerseIds already holds the new
        // surah's data while the OLD player fires completed. Without this check,
        // the recovery path would read the new surah's partial list and jump to
        // the wrong ayah (e.g., ayah 4 of the next surah).
        if (_playlistGeneration != _activePlaylistGeneration) return;

        // The playlist finished
        if (_currentVerseIds.isNotEmpty && _currentRepeatCount != -1) {
          if (kIsWeb) {
            // On web, we only load 1 ayah at a time (to avoid browser DOM limits and ConcatenatingAudioSource bugs).
            // So when it completes, we advance to the next Ayah.
            add(const NextAyah());
          } else {
            // Snapshot the last verse in the list — NOT _currentIndex — because by the time
            // `completed` fires the index stream may have already updated _currentIndex.
            // The last entry in the list is always the final ayah of the loaded playlist.
            final lastVerse = _currentVerseIds.lastWhere(
              (v) => v.ayah > 0, // skip basmalah (ayah == 0)
              orElse: () => _currentVerseIds.last,
            );
            final surahLength = QuranMetadata.surahLengthOf(lastVerse.surah);

            if (lastVerse.ayah < surahLength) {
              // The player ran out of buffered audio before the surah finished (e.g. slow network)
              // Resume from the next ayah without re-playing basmalah.
              final nextAyah = lastVerse.next;
              if (nextAyah != null) {
                add(PlayVerse('', nextAyah.verseId, skipBasmalah: true));
              }
            } else {
              // The entire surah playlist finished — advance to the next surah (WITH basmalah)
              final nextSurah = lastVerse.surah + 1;
              if (nextSurah <= 114) {
                add(PlayVerse('', VerseRef(nextSurah, 1).verseId));
              } else {
                add(const AudioStateChanged(isPlaying: false));
              }
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

  /// Returns up to [count] consecutive VerseRefs starting from [startVerse],
  /// BOUNDED to the same surah. Never crosses a surah boundary — callers
  /// must handle transitions to the next surah (with basmalah) separately.
  List<VerseRef> _nextVerses(VerseRef startVerse, int count) {
    final surahLength = QuranMetadata.surahLengthOf(startVerse.surah);
    final result = <VerseRef>[];
    for (int i = 0; i < count; i++) {
      final ayah = startVerse.ayah + i;
      if (ayah > surahLength) break;
      result.add(VerseRef(startVerse.surah, ayah));
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
    // Grab a unique generation token. If a new PlayVerse fires while we are
    // awaiting anything, _playlistGeneration changes and all in-flight work
    // (this handler + the background prefill) self-cancels cleanly.
    final int myGen = ++_playlistGeneration;
    try {
      _playedCount = 0;
      final verse = VerseRef.fromId(event.verseId);
      final bool needsBasmalah = !event.skipBasmalah &&
          verse.ayah == 1 &&
          verse.surah != 1 &&
          verse.surah != 9;
      final int repeat = _currentRepeatCount > 0 ? _currentRepeatCount : 1;

      // --- Step 1: Pre-download first 3 ayahs (+ Basmalah) in PARALLEL ---
      // _nextVerses is BOUNDED to the same surah — it never crosses into the
      // next surah, which would cause ayahs to play without their basmalah.
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
      // Guard: a newer PlayVerse may have started during the await above.
      if (_playlistGeneration != myGen) return;

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

      // ignore: deprecated_member_use
      final playlist = ConcatenatingAudioSource(children: initialSources);

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
      if (_playlistGeneration != myGen) return;

      await _audioHandler.updateItem(MediaItem(
        id: verseQueue.first.verseId.toString(),
        title: initialTitle,
        artist: ReciterLocalization.localizeByLang(isEn, _currentReciter),
        duration: _audioPlayer.duration,
        artUri: artUri,
      ));

      // Commit state only after ALL async work is done and generation is valid.
      // This prevents a stale `completed` event (from the old surah, fired
      // during the download await above) from reading partial/wrong state.
      _currentVerseIds = verseQueue;
      _currentIndex = 0;

      await _audioPlayer.stop();
      if (_playlistGeneration != myGen) return;
      await _audioPlayer.setAudioSource(playlist, initialIndex: 0);
      if (_playlistGeneration != myGen) return;
      await _audioPlayer.setLoopMode(_currentRepeatCount == -1 ? LoopMode.one : LoopMode.off);
      _audioPlayer.play();
      // Mark this generation as the ACTIVE one — only now is the player truly
      // running with this playlist. Stale completed events from the previous
      // playlist (that fired during the stop/setAudioSource transition) will
      // be ignored by the _playlistGeneration != _activePlaylistGeneration check.
      _activePlaylistGeneration = myGen;
      emit(AudioPlaying(_currentVerseIds.first.verseId));

      // --- Step 3: Background-append remaining ayahs (SAME surah ONLY) ---
      // We deliberately never cross into the next surah here. The `completed`
      // event handler is the single, correct place that triggers the next-surah
      // transition WITH basmalah.
      if (!kIsWeb && _currentRepeatCount != -1 && versesToPreload.isNotEmpty) {
        final lastPreloadedAyah = versesToPreload.last.ayah;
        final surahLength = QuranMetadata.surahLengthOf(verse.surah);
        if (lastPreloadedAyah < surahLength) {
          _backgroundPrefill(
            playlist: playlist,
            reciter: _currentReciter,
            surah: verse.surah,
            startAyah: lastPreloadedAyah + 1,
            repeat: repeat,
            lookahead: 5,
            generation: myGen,
          );
        }
      }

    } on PlayerException catch (_) {
      emit(const AudioError("audioErrorFileNotFound"));
    } on PlayerInterruptedException catch (_) {
      // Interrupted by a new play request — expected
    } catch (_) {
      emit(const AudioError("audioErrorPlayback"));
    }
  }

  /// Downloads the remaining ayahs of [surah] sequentially and appends them
  /// to [playlist]. Runs ONLY within the same surah — never crosses into the
  /// next surah. [generation] is used to self-cancel if a new PlayVerse fires.
  Future<void> _backgroundPrefill({
    // ignore: deprecated_member_use
    required ConcatenatingAudioSource playlist,
    required String reciter,
    required int surah,
    required int startAyah,
    required int repeat,
    required int lookahead,
    required int generation,
  }) async {
    final surahLength = QuranMetadata.surahLengthOf(surah);

    for (int a = startAyah; a <= surahLength; a++) {
      // Self-cancel if a newer PlayVerse or StopAudio has started.
      if (_playlistGeneration != generation) return;

      // Only prefetch if we're within [lookahead] ayahs of the current position.
      final currentAyah = _currentVerseIds.isNotEmpty
          ? _currentVerseIds[_currentIndex].ayah
          : startAyah;
      if (a > currentAyah + lookahead) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (_playlistGeneration != generation) return;
        a--;
        continue;
      }

      final v = VerseRef(surah, a);
      final String path;
      try {
        path = await _ensureLocalPath(v.surah, v.ayah, v.verseId);
      } catch (_) {
        // Download failed — skip this ayah. Do NOT add it to verseIds either
        // since playlist source and verseId list MUST stay perfectly in sync.
        continue;
      }

      // Check again after the download await — a new PlayVerse may have fired.
      if (_playlistGeneration != generation) return;

      for (int r = 0; r < repeat; r++) {
        // ignore: deprecated_member_use
        await playlist.add(_createAudioSource(path));
        // Verify generation AFTER the async add before touching shared state.
        if (_playlistGeneration != generation) return;
        _currentVerseIds = [..._currentVerseIds, v];
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
      emit(const AudioError("audioErrorPlaylist"));
    } on PlayerInterruptedException catch (_) {
      // Interrupted
    } catch (_) {
      emit(const AudioError("audioErrorPlaylist"));
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
    // Increment generation to cancel any in-flight PlayVerse handler or prefill.
    _playlistGeneration++;
    _activePlaylistGeneration = 0;
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