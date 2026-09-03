import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabattal/core/constants/reciter_catalog.dart';
import 'package:tabattal/features/quran_video_studio/data/services/word_timing_service.dart';

void main() {
  test('Rigorous Audit of All Studio Reciters on EveryAyah and Quran.com API', () async {
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8)));
    const allCategories = ReciterCatalog.verifiedVideoRecitersByCategory;

    for (final reciters in allCategories.values) {
      for (final r in reciters) {
        final name = r['name']!;
        final path = r['path']!;

        // 1. Check ID Mapping
        final recitationId = WordTimingService.getQuranDotComRecitationId(path);
        expect(recitationId, isNotNull, reason: 'Reciter "$name" ($path) MUST have a valid Quran.com recitation ID');

        // 2. Check EveryAyah Audio accessibility for Surah 1 Ayah 1
        final audioUrl = 'https://everyayah.com/data/$path/001001.mp3';
        final audioResp = await dio.head(audioUrl);
        expect(audioResp.statusCode, 200, reason: 'EveryAyah audio for $path must return 200 OK');

        // 3. Check Quran.com API Timestamps for Surah 1
        final apiUrlS1 = 'https://api.quran.com/api/v4/chapter_recitations/$recitationId/1?segments=true';
        final apiRespS1 = await dio.get(apiUrlS1);
        expect(apiRespS1.statusCode, 200);
        final timestampsS1 = (apiRespS1.data['audio_file']['timestamps'] as List);
        expect(timestampsS1.isNotEmpty, true);
        final firstSegS1 = timestampsS1[0]['segments'] as List;
        expect(firstSegS1.isNotEmpty, true, reason: 'Surah 1:1 segments must be non-empty for $name');

        // 4. Check Quran.com API Timestamps for Surah 112 (Al-Ikhlas)
        final apiUrlS112 = 'https://api.quran.com/api/v4/chapter_recitations/$recitationId/112?segments=true';
        final apiRespS112 = await dio.get(apiUrlS112);
        expect(apiRespS112.statusCode, 200);
        final timestampsS112 = (apiRespS112.data['audio_file']['timestamps'] as List);
        expect(timestampsS112.isNotEmpty, true);
      }
    }
  });
}
