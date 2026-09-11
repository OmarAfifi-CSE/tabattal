import 'package:flutter_test/flutter_test.dart';
import 'package:tabattal/core/constants/reciter_catalog.dart';
import 'package:tabattal/features/quran_audio/data/services/surah_audio_timing_service.dart';

void main() {
  test('All reciters in ReciterCatalog resolve to either Quran.com ID or Direct Full Surah URL', () {
    final missing = <String>[];

    for (final categoryEntry in ReciterCatalog.reciterCategories.entries) {
      final category = categoryEntry.key;
      for (final reciterEntry in categoryEntry.value.entries) {
        final reciterName = reciterEntry.key;
        final reciterPath = reciterEntry.value;

        final mp3Info =
            SurahAudioTimingService.resolveMp3QuranReadInfo(reciterPath);
        final recId = SurahAudioTimingService.resolveRecitationId(reciterPath);
        final directUrl =
            SurahAudioTimingService.resolveDirectFullSurahUrl(reciterPath, 1);

        if (mp3Info == null && recId == null && directUrl == null) {
          missing.add('$category -> $reciterName ($reciterPath)');
        }
      }
    }

    expect(missing, isEmpty);
  });

  test('resolveDefaultAudioUrl produces non-empty URLs for all 114 surahs for all reciters', () {
    final missingUrls = <String>[];

    for (final categoryEntry in ReciterCatalog.reciterCategories.entries) {
      for (final reciterEntry in categoryEntry.value.entries) {
        final reciterPath = reciterEntry.value;

        for (int s = 1; s <= 114; s++) {
          final url = SurahAudioTimingService.resolveDefaultAudioUrl(reciterPath, s);
          if (url == null || url.isEmpty || !url.startsWith('http')) {
            missingUrls.add('$reciterPath surah $s');
          }
        }
      }
    }

    expect(missingUrls, isEmpty);
  });
}
