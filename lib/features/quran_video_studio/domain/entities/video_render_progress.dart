import 'package:equatable/equatable.dart';
import 'video_enums.dart';

class VideoRenderProgress extends Equatable {
  final VideoRenderPhase phase;
  final double progress; // 0.0 to 1.0
  final String statusMessage;
  final String? outputPath;
  final String? errorMessage;

  const VideoRenderProgress({
    this.phase = VideoRenderPhase.idle,
    this.progress = 0.0,
    this.statusMessage = '',
    this.outputPath,
    this.errorMessage,
  });

  bool get isCompleted => phase == VideoRenderPhase.completed;
  bool get isFailed => phase == VideoRenderPhase.failed;
  bool get isRendering =>
      phase == VideoRenderPhase.downloadingAudio ||
      phase == VideoRenderPhase.generatingOverlays ||
      phase == VideoRenderPhase.encodingVideo;

  VideoRenderProgress copyWith({
    VideoRenderPhase? phase,
    double? progress,
    String? statusMessage,
    String? outputPath,
    String? errorMessage,
  }) {
    return VideoRenderProgress(
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      outputPath: outputPath ?? this.outputPath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        phase,
        progress,
        statusMessage,
        outputPath,
        errorMessage,
      ];
}
