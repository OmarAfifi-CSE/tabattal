import '../../../../core/constants/quran_metadata.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/utils/arabic_text_utils.dart';
import '../../../quran_reader/data/models/verse_model.dart';
import '../../domain/entities/video_project_config.dart';
import '../../domain/entities/video_render_progress.dart';
import '../../domain/repositories/i_video_studio_repository.dart';
import '../services/audio_timeline_service.dart';
import '../services/video_export_service.dart';

class VideoStudioRepositoryImpl implements IVideoStudioRepository {
  final AudioTimelineService _audioService;
  final VideoExportService _exportService;

  VideoStudioRepositoryImpl({
    AudioTimelineService? audioService,
    VideoExportService? exportService,
  })  : _audioService = audioService ?? AudioTimelineService(),
        _exportService = exportService ?? VideoExportService();

  @override
  Future<List<VerseModel>> loadVersesForSpan({
    required int surahNumber,
    required int startAyah,
    required int endAyah,
  }) async {
    try {
      final db = await DatabaseHelper().database;
      final safeStart = startAyah <= endAyah ? startAyah : endAyah;
      final safeEnd = endAyah >= startAyah ? endAyah : startAyah;

      final verseKeys = List.generate(
        safeEnd - safeStart + 1,
        (i) => '$surahNumber:${safeStart + i}',
      );

      final placeholders = List.filled(verseKeys.length, '?').join(',');
      final wordMaps = await db.query(
        'quran_words',
        where: 'verse_key IN ($placeholders)',
        whereArgs: verseKeys,
        orderBy: 'id ASC',
      );

      final searchMaps = await db.query(
        'quran_search',
        columns: ['text_uthmani', 'verse_key', 'ayah', 'page'],
        where: 'verse_key IN ($placeholders)',
        whereArgs: verseKeys,
        orderBy: 'ayah ASC',
      );

      final tafsirMaps = await db.query(
        'tafsir',
        columns: ['verse_key', 'text'],
        where: 'verse_key IN ($placeholders) AND resource_id = ?',
        whereArgs: [...verseKeys, 16],
      );

      final Map<String, String> tafsirByVerse = {
        for (final row in tafsirMaps)
          (row['verse_key'] as String?) ?? '':
              ArabicTextUtils.cleanTafsirOrHtml((row['text'] as String?) ?? ''),
      };

      final translationMaps = await db.query(
        'translation',
        columns: ['verse_key', 'text'],
        where: 'verse_key IN ($placeholders) AND resource_id = ?',
        whereArgs: [...verseKeys, 20],
      );

      final Map<String, String> translationByVerse = {
        for (final row in translationMaps)
          (row['verse_key'] as String?) ?? '':
              ArabicTextUtils.cleanTafsirOrHtml((row['text'] as String?) ?? ''),
      };

      final Map<String, List<WordModel>> wordsByVerse = {};
      for (final row in wordMaps) {
        final vk = (row['verse_key'] as String?) ?? '';
        wordsByVerse.putIfAbsent(vk, () => []).add(
          WordModel(
            id: row['id'] as int? ?? 0,
            textUthmani: (row['text_uthmani'] as String?) ?? '',
            codeV2: (row['code_v2'] as String?) ?? '',
            lineNumber: (row['line_number'] as int?) ?? 1,
            charTypeName: (row['char_type_name'] as String?) ?? 'word',
            verseKey: vk,
            pageNumber: (row['page'] as int?) ?? 1,
          ),
        );
      }

      final List<VerseModel> result = [];
      for (int i = 0; i < verseKeys.length; i++) {
        final vk = verseKeys[i];
        final ayahNum = safeStart + i;
        final searchRow = searchMaps.firstWhere(
          (m) => m['verse_key'] == vk,
          orElse: () => <String, dynamic>{},
        );
        final words = wordsByVerse[vk] ?? [];
        final searchUthmani = (searchRow['text_uthmani'] as String?) ?? '';
        final wordsUthmani = words
            .where((w) => w.charTypeName == 'word')
            .map((w) => w.textUthmani)
            .join(' ');
        final textUthmani = searchUthmani.isNotEmpty ? searchUthmani : wordsUthmani;
        final page = (searchRow['page'] as int?) ?? (words.isNotEmpty ? 1 : 1);
        final juz = QuranMetadata.getJuzNumberByPage(page);

        result.add(
          VerseModel(
            id: ayahNum,
            verseNumber: ayahNum,
            verseKey: vk,
            textUthmani: textUthmani,
            words: words,
            juzNumber: juz,
            tafsir: tafsirByVerse[vk],
            translation: translationByVerse[vk],
          ),
        );
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<String>> prepareVerseAudioFiles({
    required String reciterPath,
    required int surahNumber,
    required int startAyah,
    required int endAyah,
    void Function(double progress)? onDownloadProgress,
  }) {
    return _audioService.prepareAudioFiles(
      reciterPath: reciterPath,
      surahNumber: surahNumber,
      startAyah: startAyah,
      endAyah: endAyah,
      onProgress: onDownloadProgress,
    );
  }

  @override
  Future<List<Duration>> measureVerseDurations({
    required List<String> audioFilePaths,
  }) {
    return _audioService.measureDurations(audioFilePaths: audioFilePaths);
  }

  @override
  Stream<VideoRenderProgress> exportVideo({
    required VideoProjectConfig config,
    required List<VerseModel> verses,
    required List<String> audioFilePaths,
    required List<Duration> verseDurations,
  }) {
    return _exportService.exportVideo(
      config: config,
      verses: verses,
      audioFilePaths: audioFilePaths,
      verseDurations: verseDurations,
    );
  }

  @override
  void cancelExport() {
    _audioService.cancel();
    _exportService.cancel();
  }
}
