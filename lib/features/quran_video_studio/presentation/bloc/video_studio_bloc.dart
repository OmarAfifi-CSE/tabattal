import 'dart:async';
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
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<int?>? _currentIndexSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  VideoStudioBloc({
    required this.repository,
    required VideoProjectConfig initialConfig,
  }) : super(VideoStudioState(config: initialConfig)) {
    on<VideoStudioInitRequested>(_onInitRequested);
    on<VideoStudioReciterChanged>(_onReciterChanged);
    on<VideoStudioVerseRangeChanged>(_onVerseRangeChanged);
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
    on<VideoStudioExportStarted>(_onExportStarted);
    on<VideoStudioExportCancelled>(_onExportCancelled);

    _initAudioListeners();
  }

  Stream<Duration> get playbackPositionStream => _previewPlayer.positionStream;

  void _initAudioListeners() {
    _playerStateSubscription = _previewPlayer.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        _previewPlayer.pause();
        _previewPlayer.seek(Duration.zero, index: 0);
        add(const VideoStudioPlaybackStateChanged(false));
      } else {
        final isPlaying = _previewPlayer.playing && playerState.processingState != ProcessingState.completed;
        add(VideoStudioPlaybackStateChanged(isPlaying));
      }
    });

    _playingSubscription = _previewPlayer.playingStream.listen((playing) {
      final isPlaying = playing && _previewPlayer.processingState != ProcessingState.completed;
      add(VideoStudioPlaybackStateChanged(isPlaying));
    });

    _currentIndexSubscription = _previewPlayer.currentIndexStream.listen((index) {
      if (index != null && index != state.currentVerseIndex) {
        add(VideoStudioActiveVerseIndexChanged(index));
      }
    });

    _positionSubscription = _previewPlayer.positionStream.listen((position) {
      final total = state.audioFilePaths.length;
      if (total > 0 && state.currentVerseIndex >= total - 1) {
        final duration = _previewPlayer.duration ?? Duration.zero;
        if (duration > Duration.zero && position >= duration - const Duration(milliseconds: 150)) {
          if (state.isPlaying) {
            _previewPlayer.pause();
            _previewPlayer.seek(Duration.zero, index: 0);
            add(const VideoStudioPlaybackStateChanged(false));
          }
        }
      }
    });
  }

  void _onPlaybackStateChanged(
    VideoStudioPlaybackStateChanged event,
    Emitter<VideoStudioState> emit,
  ) {
    emit(state.copyWith(isPlaying: event.isPlaying));
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
        await _previewPlayer.seek(Duration.zero, index: 0);
        emit(state.copyWith(
          currentVerseIndex: 0,
          playbackResetTrigger: state.playbackResetTrigger + 1,
          isPlaying: true,
        ));
        await _previewPlayer.play();
      } catch (_) {
        emit(state.copyWith(isPlaying: false));
      }
      return;
    }

    // If actively playing, pause
    if (state.isPlaying && _previewPlayer.playing && _previewPlayer.processingState != ProcessingState.completed) {
      emit(state.copyWith(isPlaying: false));
      await _previewPlayer.pause();
    } else {
      // Start or resume playback
      try {
        final safeIndex = state.currentVerseIndex.clamp(0, totalVerses - 1);
        if (_previewPlayer.currentIndex != safeIndex) {
          await _previewPlayer.seek(Duration.zero, index: safeIndex);
        }
        emit(state.copyWith(isPlaying: true));
        await _previewPlayer.play();
      } catch (_) {
        emit(state.copyWith(isPlaying: false));
      }
    }
  }

  Future<void> _onPlaybackReset(
    VideoStudioPlaybackReset event,
    Emitter<VideoStudioState> emit,
  ) async {
    if (_previewPlayer.playing) {
      await _previewPlayer.pause();
    }
    emit(state.copyWith(
      currentVerseIndex: 0,
      isPlaying: false,
      playbackResetTrigger: state.playbackResetTrigger + 1,
    ));

    if (state.audioFilePaths.isNotEmpty) {
      try {
        await _previewPlayer.seek(Duration.zero, index: 0);
      } catch (_) {
        // Safe audio reset fallback
      }
    }
  }

  Future<void> _onActiveVerseIndexChanged(
    VideoStudioActiveVerseIndexChanged event,
    Emitter<VideoStudioState> emit,
  ) async {
    final safeIndex = event.activeIndex.clamp(0, state.verses.isNotEmpty ? state.verses.length - 1 : 0);
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

      final paths = await repository.prepareVerseAudioFiles(
        reciterPath: state.config.reciterPath,
        surahNumber: state.config.surahNumber,
        startAyah: state.config.startAyah,
        endAyah: state.config.endAyah,
      );

      final durations = await repository.measureVerseDurations(audioFilePaths: paths);

      final effectiveVerses = verses.isNotEmpty ? verses : state.verses;
      final Map<int, List<WordTimingSegment>> timingsMap = {};

      for (int i = 0; i < effectiveVerses.length; i++) {
        final v = effectiveVerses[i];
        final dur = i < durations.length ? durations[i] : const Duration(seconds: 4);
        final timings = await _wordTimingService.getWordTimings(
          surahNumber: state.config.surahNumber,
          verse: v,
          reciterPath: state.config.reciterPath,
          totalAyahDuration: dur,
        );
        timingsMap[v.verseNumber] = timings;
      }

      if (!emit.isDone) {
        if (paths.isNotEmpty) {
          try {
            await _previewPlayer.stop();
            await _previewPlayer.setAudioSources(
              paths.map(_createAudioSource).toList(),
              initialIndex: 0,
              initialPosition: Duration.zero,
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
        emit(
          state.copyWith(
            isPreparingAudio: false,
            errorMessage: 'تعذر تحميل التلاوة الصوتية للقارئ المحدد',
          ),
        );
      }
    }
  }

  Future<void> _onExportStarted(
    VideoStudioExportStarted event,
    Emitter<VideoStudioState> emit,
  ) async {
    if (_previewPlayer.playing) {
      try {
        await _previewPlayer.pause();
      } catch (_) {}
    }

    emit(state.copyWith(
      pendingExportAction: event.action,
      exportProgress: const VideoRenderProgress(
        phase: VideoRenderPhase.generatingOverlays,
        progress: 0.05,
        statusMessage: 'جاري بدء إعداد مقطع الفيديو...',
      ),
    ));

    // Ensure verses and audio files are available
    var currentVerses = state.verses;
    var currentAudios = state.audioFilePaths;
    var currentDurations = state.verseDurations;

    if (currentVerses.isEmpty) {
      currentVerses = await repository.loadVersesForSpan(
        surahNumber: state.config.surahNumber,
        startAyah: state.config.startAyah,
        endAyah: state.config.endAyah,
      );
    }

    if (currentAudios.isEmpty) {
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
      onData: (progress) => state.copyWith(exportProgress: progress),
      onError: (error, _) => state.copyWith(
        exportProgress: VideoRenderProgress(
          phase: VideoRenderPhase.failed,
          errorMessage: error.toString(),
        ),
      ),
    );
  }

  void _onExportCancelled(
    VideoStudioExportCancelled event,
    Emitter<VideoStudioState> emit,
  ) {
    repository.cancelExport();
    emit(state.copyWith(exportProgress: const VideoRenderProgress(phase: VideoRenderPhase.cancelled)));
  }

  @override
  Future<void> close() async {
    await _playerStateSubscription?.cancel();
    await _playingSubscription?.cancel();
    await _currentIndexSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _previewPlayer.dispose();
    return super.close();
  }
}
