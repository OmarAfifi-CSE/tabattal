import 'package:equatable/equatable.dart';
import 'video_enums.dart';

enum VideoProgressStep {
  initial,
  downloadingAudio,
  readingTimings,
  creatingBaseFrame,
  renderingLine,
  renderingVerse,
  uploadingPayload,
  serverEncoding,
  preparingDownload,
  concatenatingSegments,
  completed,
  failed,
  cancelled,
}

class VideoRenderProgress extends Equatable {
  final VideoRenderPhase phase;
  final VideoProgressStep step;
  final double progress; // 0.0 to 1.0
  final String statusMessage;
  final String? outputPath;
  final String? errorMessage;
  final int? ayahNumber;
  final int? currentLine;
  final int? totalLines;
  final int? uploadPercent;

  const VideoRenderProgress({
    this.phase = VideoRenderPhase.idle,
    this.step = VideoProgressStep.initial,
    this.progress = 0.0,
    this.statusMessage = '',
    this.outputPath,
    this.errorMessage,
    this.ayahNumber,
    this.currentLine,
    this.totalLines,
    this.uploadPercent,
  });

  bool get isCompleted => phase == VideoRenderPhase.completed || step == VideoProgressStep.completed;
  bool get isFailed => phase == VideoRenderPhase.failed || step == VideoProgressStep.failed;
  bool get isRendering =>
      phase == VideoRenderPhase.downloadingAudio ||
      phase == VideoRenderPhase.generatingOverlays ||
      phase == VideoRenderPhase.encodingVideo;

  VideoRenderProgress copyWith({
    VideoRenderPhase? phase,
    VideoProgressStep? step,
    double? progress,
    String? statusMessage,
    String? outputPath,
    String? errorMessage,
    int? ayahNumber,
    int? currentLine,
    int? totalLines,
    int? uploadPercent,
  }) {
    return VideoRenderProgress(
      phase: phase ?? this.phase,
      step: step ?? this.step,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      outputPath: outputPath ?? this.outputPath,
      errorMessage: errorMessage ?? this.errorMessage,
      ayahNumber: ayahNumber ?? this.ayahNumber,
      currentLine: currentLine ?? this.currentLine,
      totalLines: totalLines ?? this.totalLines,
      uploadPercent: uploadPercent ?? this.uploadPercent,
    );
  }

  @override
  List<Object?> get props => [
        phase,
        step,
        progress,
        statusMessage,
        outputPath,
        errorMessage,
        ayahNumber,
        currentLine,
        totalLines,
        uploadPercent,
      ];
}
