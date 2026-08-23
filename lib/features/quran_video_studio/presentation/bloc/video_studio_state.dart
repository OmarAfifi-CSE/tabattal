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
  });

  VerseModel? get currentVerse {
    if (verses.isEmpty || currentVerseIndex < 0 || currentVerseIndex >= verses.length) {
      return verses.isNotEmpty ? verses.first : null;
    }
    return verses[currentVerseIndex];
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
      ];
}

