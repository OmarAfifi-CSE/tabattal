import '../../../quran_reader/data/models/verse_model.dart';
import '../entities/video_project_config.dart';
import '../entities/video_render_progress.dart';

abstract class IVideoExportService {
  /// Coordinates video generation, overlay frames, audio muxing, and video export.
  Stream<VideoRenderProgress> exportVideo({
    required VideoProjectConfig config,
    required List<VerseModel> verses,
    required List<String> audioFilePaths,
    required List<Duration> verseDurations,
  });

  /// Cancels in-flight video rendering.
  void cancel();
}
