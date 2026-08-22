import '../../../quran_reader/data/models/verse_model.dart';
import '../entities/video_project_config.dart';
import '../entities/video_render_progress.dart';

abstract class IVideoStudioRepository {
  /// Prepares and downloads the audio files for the selected verse span from EveryAyah.
  Future<List<String>> prepareVerseAudioFiles({
    required String reciterPath,
    required int surahNumber,
    required int startAyah,
    required int endAyah,
    void Function(double progress)? onDownloadProgress,
  });

  /// Reads or measures the audio durations of each prepared verse file.
  Future<List<Duration>> measureVerseDurations({
    required List<String> audioFilePaths,
  });

  /// Exports the final composite video emitting progress ticks.
  Stream<VideoRenderProgress> exportVideo({
    required VideoProjectConfig config,
    required List<VerseModel> verses,
    required List<String> audioFilePaths,
    required List<Duration> verseDurations,
  });

  /// Loads the full list of VerseModels with QCF words from database for the verse span.
  Future<List<VerseModel>> loadVersesForSpan({
    required int surahNumber,
    required int startAyah,
    required int endAyah,
  });

  /// Cancels any in-flight video rendering process.
  void cancelExport();
}
