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

        final recId = SurahAudioTimingService.resolveRecitationId(reciterPath);
        final directUrl = SurahAudioTimingService.resolveDirectFullSurahUrl(reciterPath, 1);

        if (recId == null && directUrl == null) {
          missing.add('$category -> $reciterName ($reciterPath)');
        }
      }
    }

    expect(missing, isEmpty);
  });
}
