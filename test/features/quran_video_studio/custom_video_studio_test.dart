import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabattal/features/quran_reader/data/models/verse_model.dart';
import 'package:tabattal/features/quran_video_studio/data/services/canvas_overlay_generator.dart';
import 'package:tabattal/features/quran_video_studio/data/services/custom_video_service.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/video_enums.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/video_project_config.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/video_theme_preset.dart';
import 'package:tabattal/features/quran_video_studio/presentation/widgets/shared/video_frame_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
  });

  group('Custom Video Studio Feature Tests', () {
    test('VideoProjectConfig correctly identifies custom video state', () {
      const config = VideoProjectConfig(
        surahNumber: 1,
        startAyah: 1,
        endAyah: 7,
        backgroundType: VideoBackgroundType.customVideo,
        customVideoPath: 'https://assets.example.com/test_video.mp4',
        backgroundDimming: 0.4,
      );

      expect(config.hasCustomVideo, isTrue);
      expect(config.hasCustomMedia, isTrue);
      expect(config.hasCustomImage, isFalse);
      expect(config.backgroundType, VideoBackgroundType.customVideo);
      expect(config.customVideoPath, 'https://assets.example.com/test_video.mp4');
      expect(config.backgroundDimming, 0.4);
    });

    test('VideoProjectConfig copyWith clears customVideoPath when reset', () {
      const config = VideoProjectConfig(
        surahNumber: 1,
        startAyah: 1,
        endAyah: 7,
        backgroundType: VideoBackgroundType.customVideo,
        customVideoPath: 'blob:http://localhost:8080/test',
      );

      final resetConfig = config.copyWith(
        backgroundType: VideoBackgroundType.gradient,
        clearCustomVideo: true,
      );

      expect(resetConfig.hasCustomVideo, isFalse);
      expect(resetConfig.hasCustomMedia, isFalse);
      expect(resetConfig.backgroundType, VideoBackgroundType.gradient);
      expect(resetConfig.customVideoPath, isNull);
    });

    test('CustomVideoService throws FormatException on invalid URL', () async {
      expect(
        () => CustomVideoService.downloadVideoFromUrl('invalid-url-without-protocol'),
        throwsA(isA<FormatException>()),
      );
    });

    test('CustomVideoService validates protocol correctly', () {
      const invalidUrl = 'ftp://assets.example.com/video.mp4';
      expect(
        () => CustomVideoService.downloadVideoFromUrl(invalidUrl),
        throwsA(isA<FormatException>()),
      );
    });

    test('CanvasOverlayGenerator.paintStaticDecoration renders without error when customVideo is active', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(1080, 1920);

      final config = VideoProjectConfig(
        surahNumber: 1,
        startAyah: 1,
        endAyah: 7,
        backgroundType: VideoBackgroundType.customVideo,
        customVideoPath: 'https://assets.example.com/test.mp4',
        themePreset: VideoThemePreset.getById('cream'),
      );

      final verse = VerseModel(
        id: 1,
        verseNumber: 1,
        verseKey: '1:1',
        textUthmani: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
        juzNumber: 1,
        words: const [],
      );

      expect(
        () => CanvasOverlayGenerator.paintStaticDecoration(
          canvas,
          size,
          config: config,
          verse: verse,
          includeBackground: false,
        ),
        returnsNormally,
      );

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
      picture.dispose();
    });

    test('CanvasOverlayGenerator.paintDynamicContent renders ayah text with custom video', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(1080, 1920);

      const config = VideoProjectConfig(
        surahNumber: 1,
        startAyah: 1,
        endAyah: 7,
        backgroundType: VideoBackgroundType.customVideo,
        customVideoPath: 'https://assets.example.com/test.mp4',
      );

      final verse = VerseModel(
        id: 1,
        verseNumber: 1,
        verseKey: '1:1',
        textUthmani: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
        juzNumber: 1,
        words: const [],
      );

      expect(
        () => CanvasOverlayGenerator.paintDynamicContent(
          canvas,
          size,
          verse: verse,
          config: config,
          pageNumber: 1,
          contentOpacity: 1.0,
        ),
        returnsNormally,
      );

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
      picture.dispose();
    });

    test('All VideoAspectRatio variations calculate dimensions correctly for export', () {
      for (final ratio in VideoAspectRatio.values) {
        for (final quality in VideoQuality.values) {
          final width = ratio.getTargetWidth(quality);
          final height = ratio.getTargetHeight(quality);
          expect(width, greaterThan(0));
          expect(height, greaterThan(0));
          // Width & height must be even numbers for H.264 / FFmpeg encoding
          expect(width % 2, 0);
          expect(height % 2, 0);
        }
      }
    });

    testWidgets('VideoStaticFramePainter renders properly in widget tree', (tester) async {
      const config = VideoProjectConfig(
        surahNumber: 1,
        startAyah: 1,
        endAyah: 7,
        backgroundType: VideoBackgroundType.customVideo,
        customVideoPath: 'blob:http://localhost:8080/test',
      );

      final verse = VerseModel(
        id: 1,
        verseNumber: 1,
        verseKey: '1:1',
        textUthmani: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
        juzNumber: 1,
        words: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 533,
                child: CustomPaint(
                  painter: VideoStaticFramePainter(
                    config: config,
                    verse: verse,
                    includeBackground: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
