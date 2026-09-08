import 'package:flutter_test/flutter_test.dart';
import 'package:tabattal/features/quran_audio/data/models/surah_timing_model.dart';

void main() {
  group('VerseTimestamp Tests', () {
    test('Calculates duration and properties correctly', () {
      const vt = VerseTimestamp(
        surah: 1,
        ayah: 1,
        start: Duration(milliseconds: 0),
        end: Duration(milliseconds: 5500),
      );

      expect(vt.verseId, 1001);
      expect(vt.verseKey, '1:1');
      expect(vt.duration, const Duration(milliseconds: 5500));
    });

    test('Serializes to and from JSON faithfully', () {
      const vt = VerseTimestamp(
        surah: 2,
        ayah: 255,
        start: Duration(seconds: 120),
        end: Duration(seconds: 165),
      );

      final json = vt.toJson();
      final fromJson = VerseTimestamp.fromJson(json);

      expect(fromJson.surah, 2);
      expect(fromJson.ayah, 255);
      expect(fromJson.start, const Duration(seconds: 120));
      expect(fromJson.end, const Duration(seconds: 165));
      expect(fromJson.verseId, 2255);
    });
  });

  group('SurahTimings Binary Search & Lookup Tests', () {
    late SurahTimings timings;

    setUp(() {
      timings = const SurahTimings(
        surah: 1,
        audioUrl: 'https://download.quranicaudio.com/quran/minshawi/001.mp3',
        verseTimings: [
          VerseTimestamp(
            surah: 1,
            ayah: 1,
            start: Duration(milliseconds: 0),
            end: Duration(milliseconds: 5000),
          ),
          VerseTimestamp(
            surah: 1,
            ayah: 2,
            start: Duration(milliseconds: 5200),
            end: Duration(milliseconds: 10500),
          ),
          VerseTimestamp(
            surah: 1,
            ayah: 3,
            start: Duration(milliseconds: 10800),
            end: Duration(milliseconds: 15000),
          ),
          VerseTimestamp(
            surah: 1,
            ayah: 4,
            start: Duration(milliseconds: 15200),
            end: Duration(milliseconds: 20000),
          ),
          VerseTimestamp(
            surah: 1,
            ayah: 5,
            start: Duration(milliseconds: 20200),
            end: Duration(milliseconds: 26000),
          ),
          VerseTimestamp(
            surah: 1,
            ayah: 6,
            start: Duration(milliseconds: 26200),
            end: Duration(milliseconds: 32000),
          ),
          VerseTimestamp(
            surah: 1,
            ayah: 7,
            start: Duration(milliseconds: 32200),
            end: Duration(milliseconds: 45000),
          ),
        ],
      );
    });

    test('Finds exact verse at position within range', () {
      expect(timings.findVerseAt(Duration.zero)?.ayah, 1);
      expect(timings.findVerseAt(const Duration(milliseconds: 2500))?.ayah, 1);
      expect(timings.findVerseAt(const Duration(milliseconds: 6000))?.ayah, 2);
      expect(timings.findVerseAt(const Duration(milliseconds: 12000))?.ayah, 3);
      expect(timings.findVerseAt(const Duration(milliseconds: 18000))?.ayah, 4);
      expect(timings.findVerseAt(const Duration(milliseconds: 23000))?.ayah, 5);
      expect(timings.findVerseAt(const Duration(milliseconds: 30000))?.ayah, 6);
      expect(timings.findVerseAt(const Duration(milliseconds: 40000))?.ayah, 7);
    });

    test('Finds verse in boundary gap without dropping or jumping early', () {
      // 5050ms falls between ayah 1 (ends at 5000) and ayah 2 (starts at 5200)
      final gapVerse = timings.findVerseAt(const Duration(milliseconds: 5050));
      expect(gapVerse?.ayah, 1);
    });

    test('Clamps safely to first and last verses when out of bounds', () {
      expect(timings.findVerseAt(const Duration(seconds: -10))?.ayah, 1);
      expect(timings.findVerseAt(const Duration(seconds: 100))?.ayah, 7);
    });

    test('Direct getVerse lookup works accurately', () {
      expect(timings.getVerse(3)?.start, const Duration(milliseconds: 10800));
      expect(timings.getVerse(8), isNull);
    });

    test('Serializes full SurahTimings to and from JSON', () {
      final json = timings.toJson();
      final fromJson = SurahTimings.fromJson(json);

      expect(fromJson.surah, 1);
      expect(fromJson.audioUrl, timings.audioUrl);
      expect(fromJson.verseTimings.length, 7);
      expect(fromJson.verseTimings[2].ayah, 3);
    });
  });
}
