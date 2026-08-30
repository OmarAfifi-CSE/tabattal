import 'package:equatable/equatable.dart';
import '../../../quran_reader/data/models/verse_model.dart';
import '../../domain/entities/video_enums.dart';
import '../../domain/entities/video_project_config.dart';
import '../../domain/entities/video_render_progress.dart';

import '../../domain/entities/word_timing_segment.dart';

class VideoStudioState extends Equatable {
  final VideoProjectConfig config;
  final List<VerseModel> verses;
  final bool isPlaying;
  final int currentVerseIndex;
  final List<String> audioFilePaths;
  final List<Duration> verseDurations;
  final Map<int, List<WordTimingSegment>> wordTimingsMap;
  final bool isPreparingAudio;
  final VideoRenderProgress exportProgress;
  final VideoExportAction? pendingExportAction;
  final String? errorMessage;
  final int playbackResetTrigger;

  const VideoStudioState({
    required this.config,
    this.verses = const [],
    this.isPlaying = false,
    this.currentVerseIndex = 0,
    this.audioFilePaths = const [],
    this.verseDurations = const [],
    this.wordTimingsMap = const {},
    this.isPreparingAudio = false,
    this.exportProgress = const VideoRenderProgress(),
    this.pendingExportAction,
    this.errorMessage,
    this.playbackResetTrigger = 0,
  });

  VerseModel? get currentVerse {
    if (verses.isEmpty || currentVerseIndex < 0 || currentVerseIndex >= verses.length) {
      return verses.isNotEmpty ? verses.first : null;
    }
    return verses[currentVerseIndex];
  }

  Duration get totalVideoDuration {
    if (verseDurations.isEmpty) {
      return Duration.zero;
    }
    return verseDurations.fold<Duration>(
      Duration.zero,
      (sum, dur) => sum + dur,
    );
  }

  String? get formattedTotalDuration {
    final total = totalVideoDuration;
    if (total == Duration.zero) return null;
    return formatDurationToMinutesSeconds(total);
  }

  static String formatDurationToMinutesSeconds(Duration dur) {
    final int sec = dur.inSeconds;
    final int minutes = sec ~/ 60;
    final int remainingSeconds = sec % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Duration calculateCumulativePosition(int currentVerseIndex, Duration currentVersePosition) {
    if (verseDurations.isEmpty) return currentVersePosition;
    int accumulatedMs = 0;
    for (int i = 0; i < currentVerseIndex && i < verseDurations.length; i++) {
      accumulatedMs += verseDurations[i].inMilliseconds;
    }
    final totalMs = totalVideoDuration.inMilliseconds;
    final currentDur = currentVerseIndex < verseDurations.length ? verseDurations[currentVerseIndex].inMilliseconds : 0;
    final safeVersePosMs = currentDur > 0 ? currentVersePosition.inMilliseconds.clamp(0, currentDur) : currentVersePosition.inMilliseconds;
    final resMs = (accumulatedMs + safeVersePosMs).clamp(0, totalMs > 0 ? totalMs : accumulatedMs + safeVersePosMs);
    return Duration(milliseconds: resMs);
  }

  List<WordTimingSegment> get currentVerseWordTimings {
    final v = currentVerse;
    if (v == null) return const [];
    return wordTimingsMap[v.verseNumber] ?? const [];
  }

  VideoStudioState copyWith({
    VideoProjectConfig? config,
    List<VerseModel>? verses,
    bool? isPlaying,
    int? currentVerseIndex,
    List<String>? audioFilePaths,
    List<Duration>? verseDurations,
    Map<int, List<WordTimingSegment>>? wordTimingsMap,
    bool? isPreparingAudio,
    VideoRenderProgress? exportProgress,
    VideoExportAction? pendingExportAction,
    String? errorMessage,
    bool clearError = false,
    int? playbackResetTrigger,
  }) {
    return VideoStudioState(
      config: config ?? this.config,
      verses: verses ?? this.verses,
      isPlaying: isPlaying ?? this.isPlaying,
      currentVerseIndex: currentVerseIndex ?? this.currentVerseIndex,
      audioFilePaths: audioFilePaths ?? this.audioFilePaths,
      verseDurations: verseDurations ?? this.verseDurations,
      wordTimingsMap: wordTimingsMap ?? this.wordTimingsMap,
      isPreparingAudio: isPreparingAudio ?? this.isPreparingAudio,
      exportProgress: exportProgress ?? this.exportProgress,
      pendingExportAction: pendingExportAction ?? this.pendingExportAction,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      playbackResetTrigger: playbackResetTrigger ?? this.playbackResetTrigger,
    );
  }

  @override
  List<Object?> get props => [
        config,
        verses,
        isPlaying,
        currentVerseIndex,
        audioFilePaths,
        verseDurations,
        wordTimingsMap,
        isPreparingAudio,
        exportProgress,
        pendingExportAction,
        errorMessage,
        playbackResetTrigger,
      ];
}

