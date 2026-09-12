import 'dart:async';
import 'dart:io' show Platform;
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/bloc/volume/app_volume_cubit.dart';
import '../../../../core/constants/quran_metadata.dart';
import '../../../../core/constants/reciter_catalog.dart';
import '../../../quran_reader/data/models/verse_model.dart';
import '../../domain/entities/video_enums.dart';
import '../../domain/entities/video_project_config.dart';
import '../../domain/entities/video_render_progress.dart';
import '../../domain/repositories/i_video_studio_repository.dart';
import '../../data/services/canvas_overlay_generator.dart';
import '../../data/services/custom_image_service.dart';
import '../../data/services/word_timing_service.dart';
import '../../domain/entities/word_timing_segment.dart';
import 'video_studio_event.dart';
import 'video_studio_state.dart';

class VideoStudioBloc extends Bloc<VideoStudioEvent, VideoStudioState> {
  final IVideoStudioRepository repository;
  final WordTimingService _wordTimingService = WordTimingService();
  final AudioPlayer _previewPlayer = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<int?>? _currentIndexSubscription;
  Timer? _positionTicker;
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  final StreamController<Duration> _timelinePositionController = StreamController<Duration>.broadcast();
  Duration _currentVersePosition = Duration.zero;
  DateTime? _playbackStartTime;
  Duration _playbackStartPosition = Duration.zero;
  Duration _playbackStartTimelinePosition = Duration.zero;
  // Re-entrancy guards as COUNTERS, not bools: `VideoStudioSeekRequested` is
  // restartable(), so a cancelled handler keeps running in the background and
  // its finally block would clear a shared bool while a newer handler is still
  // in flight — prematurely releasing the guard and letting stream listeners
  // act on transient native player states (the intermittent play-icon
  // flicker). Counters only return to zero when ALL handlers are done.
  int _seekDepth = 0;
  int _verseSwitchDepth = 0;
  int? _pendingSeekVerseIndex;
  // Shared load generation: reciter/range/retry/init loads overlap freely
  // (restartable() is per event TYPE), so every load carries the generation
  // captured at its start and commits nothing once superseded.
  int _loadGeneration = 0;
  // Index into audioFilePaths of the file ACTUALLY loaded in the native
  // player on Windows (single-source mode). The player object alone can't
  // tell us which verse file it holds, so resume/restart paths must compare
  // against this instead of assuming audioSource != null means "correct".
  int? _loadedVerseIndex;
  final AppVolumeCubit? appVolumeCubit;

  VideoStudioBloc({
    required this.repository,
    required VideoProjectConfig initialConfig,
    this.appVolumeCubit,
  }) : super(VideoStudioState(config: initialConfig)) {
    appVolumeCubit?.registerPlayer(_previewPlayer);
    on<VideoStudioInitRequested>(_onInitRequested);
    on<VideoStudioReciterChanged>(_onReciterChanged, transformer: restartable());
    on<VideoStudioVerseRangeChanged>(_onVerseRangeChanged, transformer: restartable());
    on<VideoStudioAspectRatioChanged>(_onAspectRatioChanged);
    on<VideoStudioThemeChanged>(_onThemeChanged);
    on<VideoStudioBackgroundTypeChanged>(_onBackgroundTypeChanged);
    on<VideoStudioCustomImageSelected>(_onCustomImageSelected);
    on<VideoStudioCustomVideoSelected>(_onCustomVideoSelected);
    on<VideoStudioDimmingChanged>(_onDimmingChanged);
    on<VideoStudioTextStyleChanged>(_onTextStyleChanged);
    on<VideoStudioTextDisplayModeChanged>(_onTextDisplayModeChanged);
    on<VideoStudioQualityChanged>(_onQualityChanged);
    on<VideoStudioOptionToggled>(_onOptionToggled);
    on<VideoStudioPlaybackToggled>(_onPlaybackToggled, transformer: sequential());
    on<VideoStudioPlaybackPaused>(_onPlaybackPaused, transformer: sequential());
    on<VideoStudioPlaybackReset>(_onPlaybackReset);
    on<VideoStudioPlaybackStateChanged>(_onPlaybackStateChanged);
    on<VideoStudioActiveVerseIndexChanged>(_onActiveVerseIndexChanged);
    on<VideoStudioExportStarted>(_onExportStarted, transformer: droppable());
    on<VideoStudioExportCancelled>(_onExportCancelled);
    on<VideoStudioSeekRequested>(_onSeekRequested, transformer: restartable());
    on<VideoStudioRetryRequested>(_onRetryRequested);

    _initAudioListeners();
  }

  Stream<Duration> get playbackPositionStream => _positionController.stream;
  Stream<Duration> get timelinePositionStream => _timelinePositionController.stream;
  Duration get currentVersePosition => _currentVersePosition;
  Duration get currentTimelinePosition {
    if (state.mergedPreviewAudioPath != null) {
      if (_playbackStartTime != null) {
        final elapsed = DateTime.now().difference(_playbackStartTime!);
        return _playbackStartTimelinePosition + elapsed;
      }
      return state.calculateCumulativePosition(state.currentVerseIndex, _currentVersePosition);
    }
    return state.calculateCumulativePosition(state.currentVerseIndex, _currentVersePosition);
  }

  @visibleForTesting
  bool get isPositionTickerActive => _positionTicker != null;

  void _startPositionTicker() {
    _positionTicker?.cancel();
    _playbackStartTime = DateTime.now();
    _playbackStartPosition = _currentVersePosition;
    _playbackStartTimelinePosition = state.calculateCumulativePosition(state.currentVerseIndex, _currentVersePosition);
    _positionTicker = Timer.periodic(const Duration(milliseconds: 20), (_) {
      if (_playbackStartTime == null) return;
      if (_seekDepth > 0 || _verseSwitchDepth > 0 || _pendingSeekVerseIndex != null) return;
      final elapsed = DateTime.now().difference(_playbackStartTime!);

      if (state.mergedPreviewAudioPath != null) {
        final currentTimeline = _playbackStartTimelinePosition + elapsed;
        final totalDuration = state.totalVideoDuration;
        if (totalDuration > Duration.zero && currentTimeline >= totalDuration) {
          if (state.isPlaying) {
            add(const VideoStudioPlaybackReset());
          }
          return;
        }

        final (activeIdx, verseOffset) = state.findVerseAt(currentTimeline);
        _currentVersePosition = verseOffset;
        if (!_positionController.isClosed) {
          _positionController.add(verseOffset);
        }
        if (!_timelinePositionController.isClosed) {
          _timelinePositionController.add(currentTimeline);
        }

        if (activeIdx != state.currentVerseIndex) {
          add(VideoStudioActiveVerseIndexChanged(activeIdx, isUserInitiated: false));
        }
      } else {
        final pos = _playbackStartPosition + elapsed;
        _currentVersePosition = pos;
        if (!_positionController.isClosed) {
          _positionController.add(pos);
        }
        final cumulative = state.calculateCumulativePosition(state.currentVerseIndex, pos);
        if (!_timelinePositionController.isClosed) {
          _timelinePositionController.add(cumulative);
        }

        final total = state.audioFilePaths.length;
        if (total > 0 && state.currentVerseIndex >= total - 1) {
          final duration = _previewPlayer.duration ?? Duration.zero;
          if (duration > Duration.zero && pos >= duration) {
            if (state.isPlaying) {
              add(const VideoStudioPlaybackReset());
            }
          }
        }
      }
    });
  }

  void _stopPositionTicker({bool commitFinalPosition = true}) {
    if (commitFinalPosition && _playbackStartTime != null) {
      final elapsed = DateTime.now().difference(_playbackStartTime!);
      if (state.mergedPreviewAudioPath != null) {
        final currentTimeline = _playbackStartTimelinePosition + elapsed;
        final (_, verseOffset) = state.findVerseAt(currentTimeline);
        _currentVersePosition = verseOffset;
        if (!_timelinePositionController.isClosed) {
          _timelinePositionController.add(currentTimeline);
        }
      } else {
        _currentVersePosition = _playbackStartPosition + elapsed;
        final cumulative = state.calculateCumulativePosition(state.currentVerseIndex, _currentVersePosition);
        if (!_timelinePositionController.isClosed) {
          _timelinePositionController.add(cumulative);
        }
      }
      if (!_positionController.isClosed) {
        _positionController.add(_currentVersePosition);
      }
    }
    _positionTicker?.cancel();
    _positionTicker = null;
    _playbackStartTime = null;
  }

  void _initAudioListeners() {
    _playerStateSubscription = _previewPlayer.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed && state.isPlaying && _verseSwitchDepth == 0 && _seekDepth == 0) {
        if (state.mergedPreviewAudioPath != null) {
          add(const VideoStudioPlaybackReset());
          return;
        }
        if (!kIsWeb && Platform.isWindows && state.currentVerseIndex < state.verses.length - 1) {
          // Windows drives one audio source per verse. Advance through the
          // SAME event the verse strip uses so there is exactly ONE swap of
          // the source (the handler reloads it and resumes playback).
          add(VideoStudioActiveVerseIndexChanged(state.currentVerseIndex + 1, isUserInitiated: false));
          return;
        }
        add(const VideoStudioPlaybackReset());
      } else {
        final isPlaying = playerState.playing && playerState.processingState != ProcessingState.completed;
        if (_seekDepth == 0 && _verseSwitchDepth == 0 && _pendingSeekVerseIndex == null) {
          if (isPlaying) {
            if (_positionTicker == null) {
              _startPositionTicker();
            }
          } else {
            _stopPositionTicker();
          }
          if (isPlaying != state.isPlaying) {
            add(VideoStudioPlaybackStateChanged(isPlaying));
          }
        }
      }
    });

    _currentIndexSubscription = _previewPlayer.currentIndexStream.listen((index) {
      // When playing merged audio, the entire track is in a single audio source.
      // currentIndex is always 0 and must never override currentVerseIndex.
      if (state.mergedPreviewAudioPath != null) return;
      if (_seekDepth > 0 || _pendingSeekVerseIndex != null || _verseSwitchDepth > 0) return;
      // On Windows we drive a single audio source, so currentIndex is always 0
      // and must never be mapped back onto currentVerseIndex (it would rewind
      // to verse 0 mid-playback). Verse advancement is handled by the
      // `completed` listener instead.
      if (!kIsWeb && Platform.isWindows) return;
      if (index != null &&
          index >= 0 &&
          index < state.verses.length &&
          index != state.currentVerseIndex) {
        _currentVersePosition = Duration.zero;
        if (_previewPlayer.playing) {
          _playbackStartTime = DateTime.now();
          _playbackStartPosition = Duration.zero;
        }
        add(VideoStudioActiveVerseIndexChanged(index, isUserInitiated: false));
      }
    });
  }

  void _onPlaybackStateChanged(
    VideoStudioPlaybackStateChanged event,
    Emitter<VideoStudioState> emit,
  ) {
    if (event.isReset) {
      emit(state.copyWith(
        isPlaying: event.isPlaying,
        currentVerseIndex: 0,
        playbackResetTrigger: state.playbackResetTrigger + 1,
        seekTrigger: state.seekTrigger + 1,
        lastSeekPosition: Duration.zero,
      ));
      if (!_positionController.isClosed) {
        _positionController.add(Duration.zero);
      }
    } else {
      emit(state.copyWith(isPlaying: event.isPlaying));
    }
  }

  Future<void> _onInitRequested(
    VideoStudioInitRequested event,
    Emitter<VideoStudioState> emit,
  ) async {
    emit(
      state.copyWith(
        config: state.config.copyWith(
          surahNumber: event.surahNumber,
          startAyah: event.startAyah,
          endAyah: event.endAyah,
        ),
        verses: event.verses,
      ),
    );

    await _loadAudioAndVersesForCurrentSpan(emit);
  }

  Future<void> _onReciterChanged(
    VideoStudioReciterChanged event,
    Emitter<VideoStudioState> emit,
  ) async {
    repository.cancelAudioPreparation();
    _stopPositionTicker(commitFinalPosition: false);
    _currentVersePosition = Duration.zero;
    _playbackStartPosition = Duration.zero;
    _playbackStartTimelinePosition = Duration.zero;
    _seekDepth = 0;
    _verseSwitchDepth = 0;
    _pendingSeekVerseIndex = null;
    if (!_positionController.isClosed) {
      _positionController.add(Duration.zero);
    }
    if (!_timelinePositionController.isClosed) {
      _timelinePositionController.add(Duration.zero);
    }
    try {
      if (_previewPlayer.playing) {
        await _previewPlayer.pause();
      }
      await _previewPlayer.stop();
    } catch (_) {}

    emit(
      state.copyWith(
        currentVerseIndex: 0,
        isPlaying: false,
        playbackResetTrigger: state.playbackResetTrigger + 1,
        seekTrigger: state.seekTrigger + 1,
        lastSeekPosition: Duration.zero,
        config: state.config.copyWith(
          reciterName: event.reciterName,
          reciterCategory: event.reciterCategory,
          reciterPath: event.reciterPath,
        ),
      ),
    );

    if (emit.isDone) return;

    await _loadAudioAndVersesForCurrentSpan(emit);
  }

  Future<void> _onVerseRangeChanged(
    VideoStudioVerseRangeChanged event,
    Emitter<VideoStudioState> emit,
  ) async {
    repository.cancelAudioPreparation();
    _stopPositionTicker(commitFinalPosition: false);
    _currentVersePosition = Duration.zero;
    _playbackStartPosition = Duration.zero;
    _playbackStartTimelinePosition = Duration.zero;
    _seekDepth = 0;
    _verseSwitchDepth = 0;
    _pendingSeekVerseIndex = null;
    if (!_positionController.isClosed) {
      _positionController.add(Duration.zero);
    }
    if (!_timelinePositionController.isClosed) {
      _timelinePositionController.add(Duration.zero);
    }
    try {
      if (_previewPlayer.playing) {
        await _previewPlayer.pause();
      }
      await _previewPlayer.stop();
    } catch (_) {}

    final totalAyahs = QuranMetadata.getVerseCountForSurah(state.config.surahNumber);
    final safeStart = event.startAyah.clamp(1, totalAyahs);
    final safeEnd = event.endAyah.clamp(safeStart, (safeStart + 9).clamp(1, totalAyahs));

    emit(
      state.copyWith(
        currentVerseIndex: 0,
        isPlaying: false,
        playbackResetTrigger: state.playbackResetTrigger + 1,
        seekTrigger: state.seekTrigger + 1,
        lastSeekPosition: Duration.zero,
        config: state.config.copyWith(
          startAyah: safeStart,
          endAyah: safeEnd,
        ),
      ),
    );

    if (emit.isDone) return;

    await _loadAudioAndVersesForCurrentSpan(emit);
  }

  void _onAspectRatioChanged(
    VideoStudioAspectRatioChanged event,
    Emitter<VideoStudioState> emit,
  ) {
    emit(state.copyWith(config: state.config.copyWith(aspectRatio: event.aspectRatio)));
  }

  void _onThemeChanged(
    VideoStudioThemeChanged event,
    Emitter<VideoStudioState> emit,
  ) {
    CanvasOverlayGenerator.clearLayoutCache();
    emit(state.copyWith(config: state.config.copyWith(themePreset: event.theme)));
  }

  void _onBackgroundTypeChanged(
    VideoStudioBackgroundTypeChanged event,
    Emitter<VideoStudioState> emit,
  ) {
    CanvasOverlayGenerator.clearLayoutCache();
    emit(
      state.copyWith(
        config: state.config.copyWith(
          backgroundType: event.backgroundType,
          clearCustomImage: event.backgroundType != VideoBackgroundType.customImage,
          clearCustomVideo: event.backgroundType != VideoBackgroundType.customVideo,
        ),
      ),
    );
  }

  Future<void> _onCustomImageSelected(
    VideoStudioCustomImageSelected event,
    Emitter<VideoStudioState> emit,
  ) async {
    CanvasOverlayGenerator.clearLayoutCache();
    CustomImageService.setActiveImagePath(event.imagePath);
    if (event.imagePath == null) {
      emit(
        state.copyWith(
          config: state.config.copyWith(
            clearCustomImage: true,
            clearCustomVideo: true,
            backgroundType: VideoBackgroundType.gradient,
          ),
        ),
      );
    } else {
      try {
        await CustomImageService.loadUiImage(event.imagePath!);
        await CustomImageService.calculateImageLuminance(event.imagePath!);
      } catch (e) {
        debugPrint('Error loading custom image: $e');
      }
      emit(
        state.copyWith(
          config: state.config.copyWith(
            customImagePath: event.imagePath,
            backgroundType: VideoBackgroundType.customImage,
            clearCustomVideo: true,
          ),
        ),
      );
    }
  }

  void _onCustomVideoSelected(
    VideoStudioCustomVideoSelected event,
    Emitter<VideoStudioState> emit,
  ) {
    CanvasOverlayGenerator.clearLayoutCache();
    if (event.videoPath == null) {
      emit(
        state.copyWith(
          config: state.config.copyWith(
            clearCustomVideo: true,
            clearCustomImage: true,
            backgroundType: VideoBackgroundType.gradient,
          ),
        ),
      );
    } else {
      emit(
        state.copyWith(
          config: state.config.copyWith(
            customVideoPath: event.videoPath,
            backgroundType: VideoBackgroundType.customVideo,
            clearCustomImage: true,
          ),
        ),
      );
    }
  }

  void _onDimmingChanged(
    VideoStudioDimmingChanged event,
    Emitter<VideoStudioState> emit,
  ) {
    CanvasOverlayGenerator.clearLayoutCache();
    emit(state.copyWith(config: state.config.copyWith(backgroundDimming: event.dimming)));
  }

  void _onTextStyleChanged(
    VideoStudioTextStyleChanged event,
    Emitter<VideoStudioState> emit,
  ) {
    emit(state.copyWith(config: state.config.copyWith(textStyle: event.textStyle)));
  }

  void _onTextDisplayModeChanged(
    VideoStudioTextDisplayModeChanged event,
    Emitter<VideoStudioState> emit,
  ) async {
    var newConfig = state.config.copyWith(textDisplayMode: event.mode);
    final isSupported = ReciterCatalog.isReciterSupportedForMode(
      newConfig.reciterPath,
      event.mode,
      surahNumber: newConfig.surahNumber,
    );
    final shouldReload = !isSupported || (event.mode == VideoTextDisplayMode.lineByLine);
    if (!isSupported) {
      newConfig = newConfig.copyWith(
        reciterName: ReciterCatalog.defaultReciter,
        reciterPath: ReciterCatalog.defaultReciterPath,
        reciterCategory: ReciterCatalog.defaultCategory,
      );
    }
    emit(state.copyWith(config: newConfig));
    if (shouldReload) {
      await _loadAudioAndVersesForCurrentSpan(emit);
    }
  }

  void _onQualityChanged(
    VideoStudioQualityChanged event,
    Emitter<VideoStudioState> emit,
  ) {
    emit(state.copyWith(config: state.config.copyWith(videoQuality: event.quality)));
  }

  void _onOptionToggled(
    VideoStudioOptionToggled event,
    Emitter<VideoStudioState> emit,
  ) {
    CanvasOverlayGenerator.clearLayoutCache();
    emit(
      state.copyWith(
        config: state.config.copyWith(
          showSurahBadge: event.showSurahBadge,
          showReciterName: event.showReciterName,
          showCardFrame: event.showCardFrame,
          showTafsir: event.showTafsir,
          showEnglishTranslation: event.showEnglishTranslation,
          showAudioWaveform: event.showAudioWaveform,
        ),
      ),
    );
  }

  Future<void> _onPlaybackToggled(
    VideoStudioPlaybackToggled event,
    Emitter<VideoStudioState> emit,
  ) async {
    if (state.audioFilePaths.isEmpty) {
      await _loadAudioAndVersesForCurrentSpan(emit);
    }

    if (state.audioFilePaths.isEmpty) return;

    // If actively playing (or native player is playing), pause immediately
    final bool isActuallyPlaying = state.isPlaying || _previewPlayer.playing;
    if (isActuallyPlaying) {
      _stopPositionTicker();
      emit(state.copyWith(isPlaying: false));
      try {
        await _previewPlayer.pause();
      } catch (_) {}
      return;
    }

    final totalVerses = state.audioFilePaths.length;
    final isLastVerse = state.currentVerseIndex >= totalVerses - 1;
    final currentPos = _previewPlayer.position;
    final currentDur = _previewPlayer.duration ?? Duration.zero;
    final isAtOrNearEnd = currentDur > Duration.zero &&
        (currentPos >= currentDur || (currentDur - currentPos) <= const Duration(milliseconds: 250));

    final isCompleted = _previewPlayer.processingState == ProcessingState.completed ||
        (isLastVerse && isAtOrNearEnd);

    // If at the end of the recitation span, restart from Verse 0 on single tap
    if (isCompleted) {
      try {
        _currentVersePosition = Duration.zero;
        _playbackStartPosition = Duration.zero;
        _playbackStartTimelinePosition = Duration.zero;
        if (!_positionController.isClosed) {
          _positionController.add(Duration.zero);
        }
        if (!_timelinePositionController.isClosed) {
          _timelinePositionController.add(Duration.zero);
        }

        if (state.mergedPreviewAudioPath != null) {
          if (_previewPlayer.audioSource == null) {
            await _previewPlayer.setAudioSource(_createAudioSource(state.mergedPreviewAudioPath!));
            _loadedVerseIndex = 0;
          }
          await _previewPlayer.seek(Duration.zero);
        } else if (!kIsWeb && Platform.isWindows) {
          if (state.audioFilePaths.isNotEmpty) {
            _verseSwitchDepth++;
            try {
              await _previewPlayer.setAudioSource(_createAudioSource(state.audioFilePaths[0]));
              _loadedVerseIndex = 0;
            } finally {
              _verseSwitchDepth--;
            }
            await _previewPlayer.seek(Duration.zero);
          }
        } else {
          await _previewPlayer.seek(Duration.zero, index: 0);
        }

        _playbackStartTime = DateTime.now();
        emit(state.copyWith(
          currentVerseIndex: 0,
          isPlaying: true,
        ));
        _startPositionTicker();
        unawaited(_previewPlayer.play());
      } catch (_) {
        _stopPositionTicker();
        emit(state.copyWith(isPlaying: false));
      }
      return;
    } else {
      // Start or resume playback
      try {
        final safeIndex = state.currentVerseIndex.clamp(0, totalVerses - 1);
        if (state.mergedPreviewAudioPath != null) {
          if (_previewPlayer.audioSource == null) {
            await _previewPlayer.setAudioSource(_createAudioSource(state.mergedPreviewAudioPath!));
            _loadedVerseIndex = 0;
          }
          final timelinePos = state.calculateCumulativePosition(safeIndex, _currentVersePosition);
          await _previewPlayer.seek(timelinePos);
        } else if (!kIsWeb && Platform.isWindows) {
          if (state.audioFilePaths.isNotEmpty) {
            // audioSource != null is NOT enough: after a natural completion
            // the player still holds the LAST verse file while the UI reset
            // to verse 0. Always re-assert that the loaded file matches the
            // verse we are about to play.
            if (_previewPlayer.audioSource == null || _loadedVerseIndex != safeIndex) {
              _verseSwitchDepth++;
              try {
                await _previewPlayer.setAudioSource(_createAudioSource(state.audioFilePaths[safeIndex]));
                _loadedVerseIndex = safeIndex;
              } finally {
                _verseSwitchDepth--;
              }
            }
            if (_currentVersePosition > Duration.zero) {
              await _previewPlayer.seek(_currentVersePosition);
            }
          }
        } else if (_previewPlayer.currentIndex != safeIndex) {
          _currentVersePosition = Duration.zero;
          if (!_positionController.isClosed) {
            _positionController.add(Duration.zero);
          }
          await _previewPlayer.seek(Duration.zero, index: safeIndex);
        }
        _playbackStartTime = DateTime.now();
        _playbackStartPosition = _currentVersePosition;
        _startPositionTicker();
        emit(state.copyWith(isPlaying: true));
        unawaited(_previewPlayer.play());
      } catch (_) {
        _stopPositionTicker();
        emit(state.copyWith(isPlaying: false));
      }
    }
  }

  Future<void> _onPlaybackPaused(
    VideoStudioPlaybackPaused event,
    Emitter<VideoStudioState> emit,
  ) async {
    _stopPositionTicker();
    emit(state.copyWith(isPlaying: false));
    try {
      await _previewPlayer.pause();
    } catch (_) {}
  }

  Future<void> _onPlaybackReset(
    VideoStudioPlaybackReset event,
    Emitter<VideoStudioState> emit,
  ) async {
    _stopPositionTicker(commitFinalPosition: false);
    _currentVersePosition = Duration.zero;
    _playbackStartPosition = Duration.zero;
    _playbackStartTimelinePosition = Duration.zero;
    _seekDepth = 0;
    _verseSwitchDepth = 0;
    _pendingSeekVerseIndex = null;

    try {
      if (_previewPlayer.playing) {
        await _previewPlayer.pause();
      }
      if (state.audioFilePaths.isNotEmpty) {
        if (state.mergedPreviewAudioPath != null) {
          await _previewPlayer.seek(Duration.zero);
        } else if (!kIsWeb && Platform.isWindows) {
          _verseSwitchDepth++;
          try {
            await _previewPlayer.setAudioSource(_createAudioSource(state.audioFilePaths[0]));
            _loadedVerseIndex = 0;
          } finally {
            _verseSwitchDepth--;
          }
          await _previewPlayer.seek(Duration.zero);
        } else {
          await _previewPlayer.seek(Duration.zero, index: 0);
        }
      }
    } catch (_) {}

    emit(state.copyWith(
      currentVerseIndex: 0,
      isPlaying: false,
      playbackResetTrigger: state.playbackResetTrigger + 1,
      seekTrigger: state.seekTrigger + 1,
      lastSeekPosition: Duration.zero,
    ));

    if (!_positionController.isClosed) {
      _positionController.add(Duration.zero);
    }
    if (!_timelinePositionController.isClosed) {
      _timelinePositionController.add(Duration.zero);
    }
  }

  Future<void> _onActiveVerseIndexChanged(
    VideoStudioActiveVerseIndexChanged event,
    Emitter<VideoStudioState> emit,
  ) async {
    final safeIndex = event.activeIndex.clamp(0, state.verses.isNotEmpty ? state.verses.length - 1 : 0);

    if (state.mergedPreviewAudioPath != null) {
      if (!event.isUserInitiated) {
        // Automatic timeline advance with merged audio: the single continuous
        // audio track is ALREADY playing across this verse boundary smoothly.
        // No resets, no seeks, zero gap and zero timeline jump!
        emit(state.copyWith(currentVerseIndex: safeIndex));
        return;
      }

      // User tapped a verse card in the strip or Next/Prev button with merged audio
      _stopPositionTicker(commitFinalPosition: false);
      _verseSwitchDepth++;
      _pendingSeekVerseIndex = safeIndex;
      try {
        _currentVersePosition = Duration.zero;
        final targetSeekPos = state.calculateCumulativePosition(safeIndex, Duration.zero);
        final wasPlaying = state.isPlaying || _previewPlayer.playing;

        _playbackStartTimelinePosition = targetSeekPos;
        _playbackStartPosition = Duration.zero;
        _currentVersePosition = Duration.zero;

        emit(state.copyWith(
          currentVerseIndex: safeIndex,
          seekTrigger: state.seekTrigger + 1,
          lastSeekPosition: targetSeekPos,
          isPlaying: wasPlaying,
        ));
        if (!_positionController.isClosed) {
          _positionController.add(Duration.zero);
        }
        if (!_timelinePositionController.isClosed) {
          _timelinePositionController.add(targetSeekPos);
        }

        if (_previewPlayer.audioSource == null) {
          await _previewPlayer.setAudioSource(_createAudioSource(state.mergedPreviewAudioPath!));
          _loadedVerseIndex = 0;
        }
        await _previewPlayer.seek(targetSeekPos);
        if (safeIndex != state.currentVerseIndex) return;

        if (wasPlaying) {
          _playbackStartTime = DateTime.now();
          _playbackStartPosition = Duration.zero;
          _playbackStartTimelinePosition = targetSeekPos;
          _startPositionTicker();
          if (!_previewPlayer.playing) {
            await _previewPlayer.play();
          }
        }
      } catch (_) {
      } finally {
        _verseSwitchDepth--;
        _pendingSeekVerseIndex = null;
      }
      return;
    }

    // Fallback: unmerged multi-file audio (Web or when merged audio unavailable)
    _stopPositionTicker(commitFinalPosition: false);
    _verseSwitchDepth++;
    _pendingSeekVerseIndex = safeIndex;
    try {
      _currentVersePosition = Duration.zero;
      final wasPlaying = state.isPlaying || _previewPlayer.playing;
      final targetSeekPos = state.calculateCumulativePosition(safeIndex, Duration.zero);
      final newSeekTrigger = event.isUserInitiated ? state.seekTrigger + 1 : state.seekTrigger;

      _playbackStartTimelinePosition = targetSeekPos;
      _playbackStartPosition = Duration.zero;
      _currentVersePosition = Duration.zero;

      emit(state.copyWith(
        currentVerseIndex: safeIndex,
        seekTrigger: newSeekTrigger,
        lastSeekPosition: targetSeekPos,
        isPlaying: wasPlaying,
      ));
      if (!_positionController.isClosed) {
        _positionController.add(Duration.zero);
      }
      if (!_timelinePositionController.isClosed) {
        _timelinePositionController.add(targetSeekPos);
      }

      if (!kIsWeb && Platform.isWindows && state.audioFilePaths.isNotEmpty) {
        await _previewPlayer.setAudioSource(_createAudioSource(state.audioFilePaths[safeIndex]));
        _loadedVerseIndex = safeIndex;
        if (safeIndex != state.currentVerseIndex) return;
        if (wasPlaying) {
          _playbackStartTime = DateTime.now();
          _playbackStartPosition = Duration.zero;
          _playbackStartTimelinePosition = targetSeekPos;
          _startPositionTicker();
          await _previewPlayer.play();
        }
      } else if (state.audioFilePaths.isNotEmpty) {
        if (event.isUserInitiated) {
          if (_previewPlayer.currentIndex != safeIndex) {
            await _previewPlayer.seek(Duration.zero, index: safeIndex);
          } else {
            await _previewPlayer.seek(Duration.zero);
          }
          if (safeIndex != state.currentVerseIndex) return;
          if (wasPlaying) {
            _playbackStartTime = DateTime.now();
            _playbackStartPosition = Duration.zero;
            _playbackStartTimelinePosition = targetSeekPos;
            _startPositionTicker();
            if (!_previewPlayer.playing) {
              await _previewPlayer.play();
            }
          }
        } else {
          if (wasPlaying && _positionTicker == null) {
            _playbackStartTime = DateTime.now();
            _playbackStartPosition = Duration.zero;
            _playbackStartTimelinePosition = targetSeekPos;
            _startPositionTicker();
          }
        }
      }
    } catch (_) {
    } finally {
      _verseSwitchDepth--;
      _pendingSeekVerseIndex = null;
    }
  }

  Future<void> _onSeekRequested(
    VideoStudioSeekRequested event,
    Emitter<VideoStudioState> emit,
  ) async {
    if (state.verseDurations.isEmpty || state.audioFilePaths.isEmpty) {
      emit(state.copyWith(
        seekTrigger: state.seekTrigger + 1,
        lastSeekPosition: event.position,
      ));
      return;
    }

    final (targetVerseIndex, verseOffset) = state.findVerseAt(event.position);
    final totalVerses = state.audioFilePaths.length;
    final safeIndex = targetVerseIndex.clamp(0, totalVerses > 0 ? totalVerses - 1 : 0);
    final wasPlaying = state.isPlaying || _previewPlayer.playing;
    final bool needsSourceSwap = safeIndex != state.currentVerseIndex;

    _stopPositionTicker(commitFinalPosition: false);
    _seekDepth++;
    _pendingSeekVerseIndex = safeIndex;
    _currentVersePosition = verseOffset;
    _playbackStartTimelinePosition = event.position;
    _playbackStartPosition = verseOffset;

    emit(state.copyWith(
      currentVerseIndex: safeIndex,
      seekTrigger: state.seekTrigger + 1,
      lastSeekPosition: event.position,
      isPlaying: wasPlaying,
    ));
    if (!_positionController.isClosed) {
      _positionController.add(verseOffset);
    }
    if (!_timelinePositionController.isClosed) {
      _timelinePositionController.add(event.position);
    }

    try {
      if (state.mergedPreviewAudioPath != null) {
        if (_previewPlayer.audioSource == null) {
          await _previewPlayer.setAudioSource(_createAudioSource(state.mergedPreviewAudioPath!));
          _loadedVerseIndex = 0;
        }
        await _previewPlayer.seek(event.position);
        if (wasPlaying) {
          _playbackStartTime = DateTime.now();
          _playbackStartPosition = verseOffset;
          _playbackStartTimelinePosition = event.position;
          _startPositionTicker();
          if (!_previewPlayer.playing) {
            await _previewPlayer.play();
          }
        }
      } else if (!kIsWeb && Platform.isWindows) {
        if (state.audioFilePaths.isNotEmpty) {
          if (_previewPlayer.audioSource == null || needsSourceSwap) {
            _verseSwitchDepth++;
            try {
              await _previewPlayer.setAudioSource(_createAudioSource(state.audioFilePaths[safeIndex]));
              _loadedVerseIndex = safeIndex;
            } finally {
              _verseSwitchDepth--;
            }
          }
          await _previewPlayer.seek(verseOffset);
          if (wasPlaying) {
            _playbackStartTime = DateTime.now();
            _playbackStartPosition = verseOffset;
            _playbackStartTimelinePosition = event.position;
            _startPositionTicker();
            if (!_previewPlayer.playing) {
              await _previewPlayer.play();
            }
          }
        }
      } else {
        if (_previewPlayer.currentIndex != safeIndex) {
          await _previewPlayer.seek(verseOffset, index: safeIndex);
        } else {
          await _previewPlayer.seek(verseOffset);
        }
        if (wasPlaying) {
          _playbackStartTime = DateTime.now();
          _playbackStartPosition = verseOffset;
          _playbackStartTimelinePosition = event.position;
          _startPositionTicker();
          if (!_previewPlayer.playing) {
            await _previewPlayer.play();
          }
        }
      }
    } catch (_) {
    } finally {
      _seekDepth--;
      _pendingSeekVerseIndex = null;
    }
  }

  AudioSource _createAudioSource(String path) {
    if (kIsWeb || path.startsWith('http')) {
      return AudioSource.uri(Uri.parse(path));
    }
    return AudioSource.file(path);
  }

  Future<void> _loadAudioAndVersesForCurrentSpan(Emitter<VideoStudioState> emit) async {
    // Shared load generation: reciter/range/retry/init loads overlap freely
    // (restartable() is per event TYPE), so a stale load must never commit.
    // Snapshot the config up-front — reading state.config after awaits would
    // mix a newer range/reciter with this older load's verses and audio.
    final int myLoadGen = ++_loadGeneration;
    final VideoProjectConfig loadConfig = state.config;
    final List<VerseModel> previousVerses = List<VerseModel>.of(state.verses);
    emit(state.copyWith(isPreparingAudio: true, clearError: true));

    try {
      final verses = await repository.loadVersesForSpan(
          surahNumber: loadConfig.surahNumber,
          startAyah: loadConfig.startAyah,
          endAyah: loadConfig.endAyah,
        );
        if (myLoadGen != _loadGeneration || emit.isDone) return;

        final effectiveVerses = verses.isNotEmpty ? verses : previousVerses;

        // Immediately sync verses into state to prevent stale range if export starts
        if (effectiveVerses.isNotEmpty) {
          emit(state.copyWith(verses: effectiveVerses));
        }

        final paths = await repository.prepareVerseAudioFiles(
          reciterPath: loadConfig.reciterPath,
          surahNumber: loadConfig.surahNumber,
          startAyah: loadConfig.startAyah,
          endAyah: loadConfig.endAyah,
        );
        if (myLoadGen != _loadGeneration || emit.isDone) return;

        final durations = await repository.measureVerseDurations(audioFilePaths: paths);
        if (myLoadGen != _loadGeneration || emit.isDone) return;
        final Map<int, List<WordTimingSegment>> timingsMap = {};

        final isEn = loadConfig.isEnglish;
        for (int i = 0; i < effectiveVerses.length; i++) {
          if (myLoadGen != _loadGeneration || emit.isDone) return;
          final v = effectiveVerses[i];
          if (i >= durations.length || durations[i] == Duration.zero) {
            throw Exception(isEn
                ? 'Failed to measure exact audio duration for verse ${v.verseNumber}'
                : 'تعذر قياس المدة الصوتية الدقيقة للآية ${v.verseNumber}');
          }
          final dur = durations[i];
          final List<WordTimingSegment> timings;
          if (loadConfig.textDisplayMode == VideoTextDisplayMode.staticFull) {
            timings = [
              WordTimingSegment(
                wordPosition: 1,
                startMs: 0,
                endMs: dur.inMilliseconds,
              ),
            ];
          } else {
            timings = await _wordTimingService.getWordTimings(
              surahNumber: loadConfig.surahNumber,
              verse: v,
              reciterPath: loadConfig.reciterPath,
              totalAyahDuration: dur,
            );
            if (myLoadGen != _loadGeneration || emit.isDone) return;
          }
          timingsMap[v.verseNumber] = timings;
        }

        if (myLoadGen != _loadGeneration || emit.isDone) return;
        _stopPositionTicker(commitFinalPosition: false);
        _currentVersePosition = Duration.zero;
        _playbackStartPosition = Duration.zero;
        _playbackStartTimelinePosition = Duration.zero;
        if (!_positionController.isClosed) {
          _positionController.add(Duration.zero);
        }
        if (!_timelinePositionController.isClosed) {
          _timelinePositionController.add(Duration.zero);
        }
        String? mergedAudioPath;
        if (paths.isNotEmpty) {
          mergedAudioPath = await repository.prepareMergedAudio(audioFilePaths: paths);
          if (myLoadGen != _loadGeneration || emit.isDone) return;
          try {
            await _previewPlayer.stop();
            if (mergedAudioPath != null) {
              _verseSwitchDepth++;
              try {
                await _previewPlayer.setAudioSource(_createAudioSource(mergedAudioPath));
                _loadedVerseIndex = 0;
              } finally {
                _verseSwitchDepth--;
              }
            } else if (!kIsWeb && Platform.isWindows) {
              _verseSwitchDepth++;
              try {
                await _previewPlayer.setAudioSource(_createAudioSource(paths[0]));
                _loadedVerseIndex = 0;
              } finally {
                _verseSwitchDepth--;
              }
            } else {
              // ignore: deprecated_member_use
              final playlist = ConcatenatingAudioSource(
                children: paths.map(_createAudioSource).toList(),
              );
              await _previewPlayer.setAudioSource(
                playlist,
                initialIndex: 0,
              );
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Failed to set audio source for preview player: $e');
            }
          }
        }

        emit(
          state.copyWith(
            verses: effectiveVerses,
            audioFilePaths: paths,
            verseDurations: durations,
            wordTimingsMap: timingsMap,
            isPreparingAudio: false,
            currentVerseIndex: 0,
            mergedPreviewAudioPath: mergedAudioPath,
            lastSeekPosition: Duration.zero,
            seekTrigger: state.seekTrigger + 1,
            playbackResetTrigger: state.playbackResetTrigger + 1,
          ),
        );
    } catch (e) {
      if (myLoadGen != _loadGeneration || emit.isDone) return;
      final cleanMsg = e.toString().replaceAll('Exception:', '').trim();
      final defaultMsg = loadConfig.isEnglish
          ? 'Failed to load recitation for selected reciter'
          : 'تعذر تحميل التلاوة الصوتية للقارئ المحدد';
      emit(
        state.copyWith(
          isPreparingAudio: false,
          errorMessage: cleanMsg.isNotEmpty ? cleanMsg : defaultMsg,
        ),
      );
    } finally {
      if (myLoadGen == _loadGeneration && !emit.isDone) {
        if (state.isPreparingAudio) {
          emit(state.copyWith(isPreparingAudio: false));
        }
      }
    }
  }

  Future<void> _onRetryRequested(
    VideoStudioRetryRequested event,
    Emitter<VideoStudioState> emit,
  ) async {
    emit(state.copyWith(clearError: true, isPreparingAudio: true));
    await _loadAudioAndVersesForCurrentSpan(emit);
  }

  Future<void> _onExportStarted(
    VideoStudioExportStarted event,
    Emitter<VideoStudioState> emit,
  ) async {
    _stopPositionTicker();
    if (_previewPlayer.playing) {
      try {
        await _previewPlayer.pause();
      } catch (_) {}
    }

    emit(state.copyWith(
      isPlaying: false,
      pendingExportAction: event.action,
      exportProgress: const VideoRenderProgress(
        phase: VideoRenderPhase.generatingOverlays,
        step: VideoProgressStep.initial,
        progress: 0.05,
      ),
    ));

    // Strictly ensure all verses and audio files for the exact selected range are loaded.
    // This preparation runs BEFORE the export subscription exists, so any
    // failure here must surface as a failed progress state explicitly —
    // otherwise the export button would stay stuck on "rendering" forever.
    final expectedCount = state.config.endAyah - state.config.startAyah + 1;
    var currentVerses = state.verses;
    var currentAudios = state.audioFilePaths;
    var currentDurations = state.verseDurations;

    try {
      final isVersesStale = currentVerses.length != expectedCount ||
          (currentVerses.isNotEmpty &&
              (currentVerses.first.verseNumber != state.config.startAyah ||
                  currentVerses.last.verseNumber != state.config.endAyah));

      if (isVersesStale || currentVerses.isEmpty) {
        currentVerses = await repository.loadVersesForSpan(
          surahNumber: state.config.surahNumber,
          startAyah: state.config.startAyah,
          endAyah: state.config.endAyah,
        );
      }

      final isAudiosStale = currentAudios.length != expectedCount;
      if (isAudiosStale || currentAudios.isEmpty) {
        currentAudios = await repository.prepareVerseAudioFiles(
          reciterPath: state.config.reciterPath,
          surahNumber: state.config.surahNumber,
          startAyah: state.config.startAyah,
          endAyah: state.config.endAyah,
        );
        currentDurations = await repository.measureVerseDurations(audioFilePaths: currentAudios);
      }
    } catch (e) {
      final rawMsg = e.toString().replaceFirst('Exception: ', '').trim();
      emit(state.copyWith(
        exportProgress: VideoRenderProgress(
          phase: VideoRenderPhase.failed,
          step: VideoProgressStep.failed,
          errorMessage: rawMsg.isNotEmpty ? rawMsg : null,
        ),
      ));
      return;
    }

    await emit.forEach<VideoRenderProgress>(
      repository.exportVideo(
        config: state.config,
        verses: currentVerses,
        audioFilePaths: currentAudios,
        verseDurations: currentDurations,
      ),
      onData: (progress) {
        if (state.exportProgress.step == VideoProgressStep.cancelled ||
            state.exportProgress.phase == VideoRenderPhase.idle) {
          return state;
        }
        return state.copyWith(exportProgress: progress);
      },
      onError: (error, _) {
        if (state.exportProgress.step == VideoProgressStep.cancelled ||
            state.exportProgress.phase == VideoRenderPhase.idle) {
          return state;
        }
        final rawMsg = error.toString().replaceFirst('Exception: ', '').trim();
        return state.copyWith(
          exportProgress: VideoRenderProgress(
            phase: VideoRenderPhase.failed,
            step: VideoProgressStep.failed,
            errorMessage: rawMsg.isNotEmpty ? rawMsg : null,
          ),
        );
      },
    );
  }

  void _onExportCancelled(
    VideoStudioExportCancelled event,
    Emitter<VideoStudioState> emit,
  ) {
    repository.cancelExport();
    emit(state.copyWith(
      pendingExportAction: null,
      errorMessage: null,
      exportProgress: const VideoRenderProgress(
        phase: VideoRenderPhase.idle,
        step: VideoProgressStep.cancelled,
      ),
    ));
  }

  @override
  Future<void> close() async {
    appVolumeCubit?.unregisterPlayer(_previewPlayer);
    _stopPositionTicker();
    await _playerStateSubscription?.cancel();
    await _currentIndexSubscription?.cancel();
    await _positionController.close();
    await _timelinePositionController.close();
    try {
      await _previewPlayer.stop();
    } catch (_) {}
    try {
      await _previewPlayer.dispose();
    } catch (_) {}
    return super.close();
  }
}
