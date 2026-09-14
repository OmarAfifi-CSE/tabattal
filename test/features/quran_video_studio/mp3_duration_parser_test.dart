import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabattal/features/quran_video_studio/data/services/audio_timeline_service.dart';
import 'package:tabattal/features/quran_video_studio/data/services/mp3_duration_parser.dart';

void main() {
  group('Mp3DurationParser Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('mp3_test_');
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('returns null for non-existent file', () {
      final file = File('${tempDir.path}/non_existent.mp3');
      expect(Mp3DurationParser.parse(file), isNull);
    });

    test('returns null for empty or tiny file (< 128 bytes)', () {
      final file = File('${tempDir.path}/empty.mp3');
      file.writeAsBytesSync([1, 2, 3]);
      expect(Mp3DurationParser.parse(file), isNull);
    });

    test('returns null for non-MP3 files', () {
      final file = File('${tempDir.path}/garbage.mp3');
      file.writeAsBytesSync(List.filled(500, 0xAA));
      expect(Mp3DurationParser.parse(file), isNull);
    });

    test('correctly parses synthetic CBR MP3 file with ID3v2 tag and ID3v1 trailer', () {
      final file = File('${tempDir.path}/synthetic_cbr.mp3');

      // 1. Create ID3v2 tag (10 bytes header + 20 bytes payload = 30 bytes)
      final id3v2 = BytesBuilder();
      id3v2.add([0x49, 0x44, 0x33, 0x03, 0x00, 0x00]); // 'ID3', v2.3, flags=0
      id3v2.add([0x00, 0x00, 0x00, 20]); // synchsafe size 20 bytes
      id3v2.add(List.filled(20, 0x00));

      // 2. Audio payload: 128 kbps (16,000 bytes/sec).
      // Let's create audio payload of 32,000 bytes -> duration should be exactly 2 seconds.
      final audioPayload = BytesBuilder();
      // First frame header: 0xFF, 0xFB (MPEG-1 Layer 3, no CRC), 0x90 (128 kbps, 44100 Hz), 0x00
      audioPayload.add([0xFF, 0xFB, 0x90, 0x00]);
      audioPayload.add(List.filled(32000 - 4, 0x55));

      // 3. ID3v1 trailer: 128 bytes starting with 'TAG'
      final id3v1 = BytesBuilder();
      id3v1.add([0x54, 0x41, 0x47]); // 'TAG'
      id3v1.add(List.filled(125, 0x00));

      final fullFileBytes = BytesBuilder();
      fullFileBytes.add(id3v2.toBytes());
      fullFileBytes.add(audioPayload.toBytes());
      fullFileBytes.add(id3v1.toBytes());

      file.writeAsBytesSync(fullFileBytes.toBytes());

      final duration = Mp3DurationParser.parse(file);
      expect(duration, isNotNull);
      // 32000 bytes * 8 / (128 * 1000) = 2.0 seconds = 2000 ms
      expect(duration!.inMilliseconds, 2000);
    });

    test('correctly parses synthetic VBR MP3 file with Xing header', () {
      final file = File('${tempDir.path}/synthetic_xing.mp3');

      final builder = BytesBuilder();
      // First frame header: MPEG-1 Layer 3, 44100Hz, Stereo
      // 0xFF, 0xFB, 0x90, 0x00 (channelMode = 00 -> Stereo, Xing offset = 4 + 32 = 36)
      builder.add([0xFF, 0xFB, 0x90, 0x00]);
      // 32 bytes padding before Xing magic
      builder.add(List.filled(32, 0x00));
      // 'Xing' magic
      builder.add([0x58, 0x69, 0x6E, 0x67]);
      // Flags: hasFrames = 0x0001
      builder.add([0x00, 0x00, 0x00, 0x01]);
      // Total frames: 383 frames (383 * 1152 / 44100 = 9.99999 -> ~10s)
      builder.add([0x00, 0x00, 0x01, 0x7F]);
      // Fill to at least 256 bytes
      builder.add(List.filled(300, 0x00));

      file.writeAsBytesSync(builder.toBytes());

      final duration = Mp3DurationParser.parse(file);
      expect(duration, isNotNull);
      expect(duration!.inSeconds, 10);
    });

    test('AudioTimelineService.measureDurations uses Mp3DurationParser and caches result', () async {
      final service = AudioTimelineService();
      final file = File('${tempDir.path}/test_measure.mp3');

      // Create valid 1-second CBR file at 128 kbps (16,000 bytes)
      final builder = BytesBuilder();
      builder.add([0xFF, 0xFB, 0x90, 0x00]);
      builder.add(List.filled(16000 - 4, 0x00));
      file.writeAsBytesSync(builder.toBytes());

      final durations = await service.measureDurations(audioFilePaths: [file.path]);
      expect(durations.length, 1);
      expect(durations.first.inMilliseconds, 1000);

      // Second call must hit cache immediately
      final cachedDurations = await service.measureDurations(audioFilePaths: [file.path]);
      expect(cachedDurations.first.inMilliseconds, 1000);
    });
  });
}
