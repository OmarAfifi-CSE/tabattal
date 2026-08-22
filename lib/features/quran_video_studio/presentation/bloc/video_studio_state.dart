import 'package:equatable/equatable.dart';
import '../../../quran_reader/data/models/verse_model.dart';
import '../../domain/entities/video_enums.dart';
import '../../domain/entities/video_project_config.dart';
import '../../domain/entities/video_render_progress.dart';

class VideoStudioState extends Equatable {
  final VideoProjectConfig config;
  final List<VerseModel> verses;
  final bool isPlaying;
  final int currentVerseIndex;
  final List<String> audioFilePaths;
  final List<Duration> verseDurations;
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

  VideoStudioState copyWith({
    VideoProjectConfig? config,
    List<VerseModel>? verses,
    bool? isPlaying,
    int? currentVerseIndex,
    List<String>? audioFilePaths,
    List<Duration>? verseDurations,
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
        isPreparingAudio,
        exportProgress,
        pendingExportAction,
        errorMessage,
      ];
}
