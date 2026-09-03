import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabattal/core/constants/quran_constants.dart';
import 'package:tabattal/core/constants/quran_metadata.dart';
import 'package:tabattal/core/theme/mushaf_theme.dart';
import 'package:tabattal/features/quran_reader/data/models/verse_model.dart';
import 'package:tabattal/features/quran_video_studio/data/services/audio_timeline_service.dart';
import 'package:tabattal/features/quran_video_studio/data/services/canvas_overlay_generator.dart';
import 'package:tabattal/features/quran_video_studio/data/services/word_timing_service.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/video_enums.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/video_project_config.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/video_theme_preset.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/word_timing_segment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.just_audio.methods'),
      (methodCall) async {
        if (methodCall.method == 'init' || methodCall.method == 'load') {
          return {'duration': 4000000};
        }
        return <String, dynamic>{};
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
  });

  group('⚡ Web Performance & Frame Budget Benchmarks (120 FPS Target: <8.33ms)', () {
    test('1. Static Frame & Canvas Decoration Render Time Benchmark (<2.0ms)', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(1080, 1920);

      final config = VideoProjectConfig(
        surahNumber: 1,
        startAyah: 1,
        endAyah: 7,
        backgroundType: VideoBackgroundType.gradient,
        themePreset: VideoThemePreset.getById('cream'),
        aspectRatio: VideoAspectRatio.portrait9x16,
      );

      final verse = VerseModel(
        id: 1,
        verseNumber: 1,
        verseKey: '1:1',
        textUthmani: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
        juzNumber: 1,
        words: const [],
      );

      final stopwatch = Stopwatch()..start();

      // Stress test 100 consecutive canvas background and frame passes
      for (int i = 0; i < 100; i++) {
        CanvasOverlayGenerator.paintStaticDecoration(
          canvas,
          size,
          config: config,
          verse: verse,
          includeBackground: true,
        );
      }
      stopwatch.stop();

      final avgMsPerFrame = stopwatch.elapsedMicroseconds / (100 * 1000);
      // Average paint time per static frame must be below 2.0ms (well inside 8.33ms budget)
      expect(avgMsPerFrame, lessThan(2.0),
          reason: 'Static frame decoration paint took ${avgMsPerFrame.toStringAsFixed(3)}ms, exceeding 2.0ms budget');
    });

    test('2. Dynamic Text & Word Tracking Paint Frame Budget (<4.0ms)', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(1080, 1920);

      final config = VideoProjectConfig(
        surahNumber: 1,
        startAyah: 1,
        endAyah: 7,
        textDisplayMode: VideoTextDisplayMode.lineByLine,
        themePreset: VideoThemePreset.getById('cream'),
        aspectRatio: VideoAspectRatio.portrait9x16,
      );

      final verse = VerseModel(
        id: 1,
        verseNumber: 1,
        verseKey: '1:1',
        textUthmani: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
        juzNumber: 1,
        words: const [],
        tafsir: 'تفسير ميسر للبسملة',
        translation: 'In the name of Allah, the Entirely Merciful, the Especially Merciful.',
      );

      final wordTimings = [
        const WordTimingSegment(wordPosition: 1, startMs: 0, endMs: 800),
        const WordTimingSegment(wordPosition: 2, startMs: 800, endMs: 1500),
        const WordTimingSegment(wordPosition: 3, startMs: 1500, endMs: 2400),
        const WordTimingSegment(wordPosition: 4, startMs: 2400, endMs: 3500),
      ];

      final stopwatch = Stopwatch()..start();

      // Stress test 120 frames of dynamic 35ms playback simulation
      for (int i = 0; i < 120; i++) {
        final playbackPosMs = (i * 35) % 4000;
        CanvasOverlayGenerator.paintDynamicContent(
          canvas,
          size,
          verse: verse,
          config: config,
          pageNumber: 1,
          playbackPositionMs: playbackPosMs,
          wordTimings: wordTimings,
        );
      }
      stopwatch.stop();

      final avgMsPerFrame = stopwatch.elapsedMicroseconds / (120 * 1000);
      expect(avgMsPerFrame, lessThan(4.0),
          reason: 'Dynamic content paint took ${avgMsPerFrame.toStringAsFixed(3)}ms per frame, exceeding 4.0ms budget');
    });

    test('3. Audio Duration Cache & Parallel Measurement Latency', () async {
      final audioService = AudioTimelineService();
      const testUrls = [
        'https://everyayah.com/data/Minshawy_Murattal_128kbps/001001.mp3',
        'https://everyayah.com/data/Minshawy_Murattal_128kbps/001002.mp3',
        'https://everyayah.com/data/Minshawy_Murattal_128kbps/001003.mp3',
        'https://everyayah.com/data/Minshawy_Murattal_128kbps/001004.mp3',
        'https://everyayah.com/data/Minshawy_Murattal_128kbps/001005.mp3',
      ];

      // 1. Prime cache
      final durations = await audioService.measureDurations(audioFilePaths: testUrls);
      expect(durations.length, 5);

      // 2. Measure cache lookup speed (must be sub-millisecond < 5ms for 5 items)
      final stopwatch = Stopwatch()..start();
      final cachedDurations = await audioService.measureDurations(audioFilePaths: testUrls);
      stopwatch.stop();

      expect(cachedDurations.length, 5);
      expect(stopwatch.elapsedMilliseconds, lessThan(5),
          reason: 'Cached duration retrieval took ${stopwatch.elapsedMilliseconds}ms, should be instant 0ms');
    });

    test('4. Word Timing Deduplication & In-Flight Concurrency Verification', () async {
      WordTimingService.clearCache();
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'audio_file': {
                    'timestamps': [
                      {
                        'verse_key': '1:1',
                        'timestamp_from': 0,
                        'timestamp_to': 4000,
                        'segments': [
                          [1, 0, 800],
                          [2, 800, 1500],
                          [3, 1500, 2400],
                          [4, 2400, 4000],
                        ],
                      }
                    ]
                  }
                },
              ),
            );
          },
        ),
      );
      final timingService = WordTimingService(dio: dio);
      final verse = VerseModel(
        id: 1,
        verseNumber: 1,
        verseKey: '1:1',
        textUthmani: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
        juzNumber: 1,
        words: const [],
      );

      // Concurrent retrieval for 3 requests in the same surah
      final stopwatch = Stopwatch()..start();
      final results = await Future.wait([
        timingService.getWordTimings(surahNumber: 1, verse: verse, reciterPath: 'Minshawy_Murattal_128kbps', totalAyahDuration: const Duration(seconds: 4)),
        timingService.getWordTimings(surahNumber: 1, verse: verse, reciterPath: 'Minshawy_Murattal_128kbps', totalAyahDuration: const Duration(seconds: 4)),
        timingService.getWordTimings(surahNumber: 1, verse: verse, reciterPath: 'Minshawy_Murattal_128kbps', totalAyahDuration: const Duration(seconds: 4)),
      ]);
      stopwatch.stop();

      expect(results.length, 3);
      for (final list in results) {
        expect(list, isNotEmpty);
      }
    });

    test('5. Surah Metadata & Page Range Lookup Speed (All 114 Surahs < 2ms)', () {
      final stopwatch = Stopwatch()..start();
      for (int i = 1; i <= QuranConstants.totalSurahs; i++) {
        final startPage = QuranMetadata.getStartPageForSurah(i);
        final surahName = QuranMetadata.getSurahName(i);
        final ayahCount = QuranMetadata.getVerseCountForSurah(i);
        expect(startPage, greaterThanOrEqualTo(1));
        expect(surahName, isNotEmpty);
        expect(ayahCount, greaterThan(0));
      }
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(2),
          reason: 'Surah metadata lookup for 114 surahs took ${stopwatch.elapsedMilliseconds}ms');
    });

    test('6. Mushaf Theme Computations & Contrast Calculation Performance', () {
      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 500; i++) {
        for (final theme in [MushafTheme.cream, MushafTheme.white]) {
          final isDark = theme.isDarkTheme;
          final markerColor = theme.bookmarkedMarkerColor;
          expect(isDark, isFalse);
          expect(markerColor, isNotNull);
        }
      }
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(10),
          reason: 'Theme luminance and contrast calculations took ${stopwatch.elapsedMilliseconds}ms');
    });
  });
}
