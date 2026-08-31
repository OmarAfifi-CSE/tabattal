import 'dart:async';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/constants/quran_metadata.dart';
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
  final AudioPlayer _previewPlayer = AudioPlayer(
    handleInterruptions: false,
    androidApplyAudioAttributes: false,
  );
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<int?>? _currentIndexSubscription;
  Timer? _positionTicker;
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  Duration _currentVersePosition = Duration.zero;
  DateTime? _playbackStartTime;
  Duration _playbackStartPosition = Duration.zero;
  bool _isSeeking = false;
  int? _pendingSeekVerseIndex;

  VideoStudioBloc({
    required this.repository,
    required VideoProjectConfig initialConfig,
  }) : super(VideoStudioState(config: initialConfig)) {
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
    on<VideoStudioPlaybackToggled>(_onPlaybackToggled);
    on<VideoStudioPlaybackReset>(_onPlaybackReset);
    on<VideoStudioPlaybackStateChanged>(_onPlaybackStateChanged);
    on<VideoStudioActiveVerseIndexChanged>(_onActiveVerseIndexChanged);
    on<VideoStudioExportStarted>(_onExportStarted, transformer: droppable());
    on<VideoStudioExportCancelled>(_onExportCancelled);
    on<VideoStudioSeekRequested>(_onSeekRequested, transformer: restartable());

    _initAudioListeners();
  }

  Stream<Duration> get playbackPositionStream => _positionController.stream;
  Duration get currentVersePosition => _currentVersePosition;

  void _startPositionTicker() {
    _positionTicker?.cancel();
    _playbackStartTime = DateTime.now();
    _playbackStartPosition = _currentVersePosition;
    _positionTicker = Timer.periodic(const Duration(milliseconds: 35), (_) {
      if (_playbackStartTime == null) return;
      final elapsed = DateTime.now().difference(_playbackStartTime!);
      final pos = _playbackStartPosition + elapsed;
      _currentVersePosition = pos;
      if (!_positionController.isClosed) {
        _positionController.add(pos);
      }

      final total = state.audioFilePaths.length;
      if (total > 0 && state.currentVerseIndex >= total - 1) {
        final duration = _previewPlayer.duration ?? Duration.zero;
        if (duration > Duration.zero && pos >= duration - const Duration(milliseconds: 150)) {
          if (state.isPlaying) {
            _stopPositionTicker();
            _currentVersePosition = Duration.zero;
            _previewPlayer.pause();
            if (!_positionController.isClosed) {
              _positionController.add(Duration.zero);
            }
            _previewPlayer.seek(Duration.zero, index: 0);
            add(const VideoStudioPlaybackStateChanged(false, isReset: true));
          }
        }
      }
    });
  }

  void _stopPositionTicker() {
    if (_playbackStartTime != null) {
      final elapsed = DateTime.now().difference(_playbackStartTime!);
      _currentVersePosition = _playbackStartPosition + elapsed;
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
      if (playerState.processingState == ProcessingState.completed) {
        _stopPositionTicker();
        _currentVersePosition = Duration.zero;
        _previewPlayer.pause();
        if (!_positionController.isClosed) {
          _positionController.add(Duration.zero);
        }
        _previewPlayer.seek(Duration.zero, index: 0);
        add(const VideoStudioPlaybackStateChanged(false, isReset: true));
      } else {
        final isPlaying = playerState.playing && playerState.processingState != ProcessingState.completed;
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
    });

    _currentIndexSubscription = _previewPlayer.currentIndexStream.listen((index) {
      if (_isSeeking || _pendingSeekVerseIndex != null) {
        return;
      }
      if (index != null && index != state.currentVerseIndex) {
        _currentVersePosition = Duration.zero;
        if (_previewPlayer.playing) {
          _playbackStartTime = DateTime.now();
          _playbackStartPosition = Duration.zero;
        }
        if (!_positionController.isClosed) {
          _positionController.add(Duration.zero);
        }
        add(VideoStudioActiveVerseIndexChanged(index));
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
      ));
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
    _stopPositionTicker();
    _currentVersePosition = Duration.zero;
    _isSeeking = false;
    _pendingSeekVerseIndex = null;
    if (!_positionController.isClosed) {
      _positionController.add(Duration.zero);
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
        config: state.config.copyWith(
          reciterName: event.reciterName,
          reciterCategory: event.reciterCategory,
          reciterPath: event.reciterPath,
        ),
      ),
    );

    await _loadAudioAndVersesForCurrentSpan(emit);
  }

  Future<void> _onVerseRangeChanged(
    VideoStudioVerseRangeChanged event,
    Emitter<VideoStudioState> emit,
  ) async {
    _stopPositionTicker();
    _currentVersePosition = Duration.zero;
    _isSeeking = false;
    _pendingSeekVerseIndex = null;
    if (!_positionController.isClosed) {
      _positionController.add(Duration.zero);
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
        config: state.config.copyWith(
          startAyah: safeStart,
          endAyah: safeEnd,
        ),
      ),
    );

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
    if (event.imagePath == null) {
      emit(
        state.copyWith(
          config: state.config.copyWith(
            clearCustomImage: true,
            backgroundType: VideoBackgroundType.gradient,
          ),
        ),
      );
    } else {
      await CustomImageService.loadUiImage(event.imagePath!);
      await CustomImageService.calculateImageLuminance(event.imagePath!);
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
  ) {
    emit(state.copyWith(config: state.config.copyWith(textDisplayMode: event.mode)));
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

    final totalVerses = state.audioFilePaths.length;
    final isLastVerse = state.currentVerseIndex >= totalVerses - 1;
    final currentPos = _previewPlayer.position;
    final currentDur = _previewPlayer.duration ?? Duration.zero;
    final isAtOrNearEnd = currentDur > Duration.zero &&
        (currentPos >= currentDur || (currentDur - currentPos) <= const Duration(milliseconds: 250));

    final isCompleted = _previewPlayer.processingState == ProcessingState.completed ||
        (isLastVerse && isAtOrNearEnd);

    // If at the end of the recitation span, immediately restart from Verse 0 on a single tap
    if (isCompleted) {
      try {
        _currentVersePosition = Duration.zero;
        if (!_positionController.isClosed) {
          _positionController.add(Duration.zero);
        }
        await _previewPlayer.seek(Duration.zero, index: 0);
        _startPositionTicker();
        await _previewPlayer.play();
        emit(state.copyWith(
          currentVerseIndex: 0,
          isPlaying: true,
        ));
      } catch (_) {
        _stopPositionTicker();
        emit(state.copyWith(isPlaying: false));
      }
      return;
    }

    // If actively playing, pause
    if (state.isPlaying && _previewPlayer.playing && _previewPlayer.processingState != ProcessingState.completed) {
      _stopPositionTicker();
      await _previewPlayer.pause();
      emit(state.copyWith(isPlaying: false));
    } else {
      // Start or resume playback
      try {
        final safeIndex = state.currentVerseIndex.clamp(0, totalVerses - 1);
        if (_previewPlayer.currentIndex != safeIndex) {
          _currentVersePosition = Duration.zero;
          if (!_positionController.isClosed) {
            _positionController.add(Duration.zero);
          }
          await _previewPlayer.seek(Duration.zero, index: safeIndex);
        }
        _startPositionTicker();
        await _previewPlayer.play();
        emit(state.copyWith(isPlaying: true));
      } catch (_) {
        _stopPositionTicker();
        emit(state.copyWith(isPlaying: false));
      }
    }
  }

  Future<void> _onPlaybackReset(
    VideoStudioPlaybackReset event,
    Emitter<VideoStudioState> emit,
  ) async {
    _stopPositionTicker();
    _currentVersePosition = Duration.zero;
    _isSeeking = false;
    _pendingSeekVerseIndex = null;
    if (!_positionController.isClosed) {
      _positionController.add(Duration.zero);
    }

    try {
      if (_previewPlayer.playing) {
        await _previewPlayer.pause();
      }
      if (state.audioFilePaths.isNotEmpty) {
        await _previewPlayer.seek(Duration.zero, index: 0);
      }
    } catch (_) {}

    emit(state.copyWith(
      currentVerseIndex: 0,
      isPlaying: false,
      playbackResetTrigger: state.playbackResetTrigger + 1,
    ));
  }

  Future<void> _onActiveVerseIndexChanged(
    VideoStudioActiveVerseIndexChanged event,
    Emitter<VideoStudioState> emit,
  ) async {
    if (_isSeeking || _pendingSeekVerseIndex != null) return;
    final safeIndex = event.activeIndex.clamp(0, state.verses.isNotEmpty ? state.verses.length - 1 : 0);
    _currentVersePosition = Duration.zero;
    if (_previewPlayer.playing) {
      _playbackStartTime = DateTime.now();
      _playbackStartPosition = Duration.zero;
    }
    if (!_positionController.isClosed) {
      _positionController.add(Duration.zero);
    }
    emit(state.copyWith(currentVerseIndex: safeIndex));

    if (state.audioFilePaths.isNotEmpty) {
      try {
        if (_previewPlayer.currentIndex != safeIndex) {
          await _previewPlayer.seek(Duration.zero, index: safeIndex);
        }
      } catch (_) {
        // Safe audio seek fallback
      }
    }
  }

  Future<void> _onSeekRequested(
    VideoStudioSeekRequested event,
    Emitter<VideoStudioState> emit,
  ) async {
    if (state.verseDurations.isEmpty || state.audioFilePaths.isEmpty) return;

    int accumulatedMs = 0;
    int targetVerseIndex = 0;
    Duration verseOffset = Duration.zero;

    for (int i = 0; i < state.verseDurations.length; i++) {
      final dur = state.verseDurations[i];
      final nextAccumulatedMs = accumulatedMs + dur.inMilliseconds;
      if (event.position.inMilliseconds < nextAccumulatedMs || i == state.verseDurations.length - 1) {
        targetVerseIndex = i;
        verseOffset = event.position - Duration(milliseconds: accumulatedMs);
        if (verseOffset < Duration.zero) verseOffset = Duration.zero;
        if (verseOffset > dur && dur > Duration.zero) verseOffset = dur;
        break;
      }
      accumulatedMs = nextAccumulatedMs;
    }

    final totalVerses = state.audioFilePaths.length;
    final safeIndex = targetVerseIndex.clamp(0, totalVerses - 1);

    _isSeeking = true;
    _pendingSeekVerseIndex = safeIndex;
    _currentVersePosition = verseOffset;

    if (_previewPlayer.playing) {
      _playbackStartTime = DateTime.now();
      _playbackStartPosition = verseOffset;
    }
    if (!_positionController.isClosed) {
      _positionController.add(verseOffset);
    }
    emit(state.copyWith(currentVerseIndex: safeIndex));

    try {
      if (_previewPlayer.currentIndex != safeIndex) {
        await _previewPlayer.seek(verseOffset, index: safeIndex);
      } else {
        await _previewPlayer.seek(verseOffset);
      }
    } catch (_) {
    } finally {
      _isSeeking = false;
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
    emit(state.copyWith(isPreparingAudio: true, clearError: true));

    try {
      final verses = await repository.loadVersesForSpan(
        surahNumber: state.config.surahNumber,
        startAyah: state.config.startAyah,
        endAyah: state.config.endAyah,
      );

      final effectiveVerses = verses.isNotEmpty ? verses : state.verses;

      // Immediately sync verses into state to prevent stale range if export starts
      if (!emit.isDone && effectiveVerses.isNotEmpty) {
        emit(state.copyWith(verses: effectiveVerses));
      }

      final paths = await repository.prepareVerseAudioFiles(
        reciterPath: state.config.reciterPath,
        surahNumber: state.config.surahNumber,
        startAyah: state.config.startAyah,
        endAyah: state.config.endAyah,
      );

      final durations = await repository.measureVerseDurations(audioFilePaths: paths);
      final Map<int, List<WordTimingSegment>> timingsMap = {};

      final isEn = state.config.isEnglish;
      for (int i = 0; i < effectiveVerses.length; i++) {
        final v = effectiveVerses[i];
        if (i >= durations.length || durations[i] == Duration.zero) {
          throw Exception(isEn
              ? 'Failed to measure exact audio duration for verse ${v.verseNumber}'
              : 'تعذر قياس المدة الصوتية الدقيقة للآية ${v.verseNumber}');
        }
        final dur = durations[i];
        final timings = await _wordTimingService.getWordTimings(
          surahNumber: state.config.surahNumber,
          verse: v,
          reciterPath: state.config.reciterPath,
          totalAyahDuration: dur,
        );
        timingsMap[v.verseNumber] = timings;
      }

      if (!emit.isDone) {
        _stopPositionTicker();
        _currentVersePosition = Duration.zero;
        if (!_positionController.isClosed) {
          _positionController.add(Duration.zero);
        }
        if (paths.isNotEmpty) {
          try {
            await _previewPlayer.stop();
            await _previewPlayer.setAudioSources(
              paths.map(_createAudioSource).toList(),
              initialIndex: 0,
              initialPosition: Duration.zero,
              preload: true,
            );
          } catch (_) {}
        }

        emit(
          state.copyWith(
            verses: effectiveVerses,
            audioFilePaths: paths,
            verseDurations: durations,
            wordTimingsMap: timingsMap,
            isPreparingAudio: false,
            currentVerseIndex: 0,
          ),
        );
      }
    } catch (e) {
      if (!emit.isDone) {
        final cleanMsg = e.toString().replaceAll('Exception:', '').trim();
        final defaultMsg = state.config.isEnglish
            ? 'Failed to load recitation for selected reciter'
            : 'تعذر تحميل التلاوة الصوتية للقارئ المحدد';
        emit(
          state.copyWith(
            isPreparingAudio: false,
            errorMessage: cleanMsg.isNotEmpty ? cleanMsg : defaultMsg,
          ),
        );
      }
    }
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

    // Strictly ensure all verses and audio files for the exact selected range are loaded
    final expectedCount = state.config.endAyah - state.config.startAyah + 1;
    var currentVerses = state.verses;
    var currentAudios = state.audioFilePaths;
    var currentDurations = state.verseDurations;

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
    _stopPositionTicker();
    await _playerStateSubscription?.cancel();
    await _currentIndexSubscription?.cancel();
    await _positionController.close();
    await _previewPlayer.dispose();
    return super.close();
  }
}
