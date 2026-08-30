import 'package:flutter_test/flutter_test.dart';
import 'package:tabattal/features/quran_video_studio/data/services/custom_image_service.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/video_enums.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/video_project_config.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/video_theme_preset.dart';

import 'package:tabattal/features/quran_reader/data/models/verse_model.dart';
import 'package:tabattal/features/quran_video_studio/data/services/word_timing_service.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/word_timing_segment.dart';

void main() {
  group('VideoProjectConfig & Domain Entities Tests', () {
    test('VideoAspectRatio calculations and dimensions', () {
      expect(VideoAspectRatio.portrait9x16.ratio, closeTo(9 / 16, 0.001));
      expect(VideoAspectRatio.portrait9x16.targetWidth, 1080);
      expect(VideoAspectRatio.portrait9x16.targetHeight, 1920);

      expect(VideoAspectRatio.square1x1.ratio, 1.0);
      expect(VideoAspectRatio.square1x1.targetWidth, 1080);
      expect(VideoAspectRatio.square1x1.targetHeight, 1080);

      expect(VideoAspectRatio.landscape16x9.ratio, closeTo(16 / 9, 0.001));
      expect(VideoAspectRatio.landscape16x9.targetWidth, 1920);
      expect(VideoAspectRatio.landscape16x9.targetHeight, 1080);
    });

    test('VideoThemePreset default lookup', () {
      final cream = VideoThemePreset.getById('cream');
      expect(cream.id, 'cream');
      expect(cream.gradientColors.length, 2);

      final fallback = VideoThemePreset.getById('non_existent');
      expect(fallback.id, 'cream');
    });

    test('VideoQuality options and resolution scaling', () {
      expect(VideoQuality.fhd1080p.bitrateKbps, 12000);
      expect(VideoQuality.hd720p.bitrateKbps, 6000);

      expect(VideoQuality.fhd1080p.crf, 22);
      expect(VideoQuality.hd720p.crf, 24);

      expect(VideoAspectRatio.portrait9x16.getTargetWidth(VideoQuality.fhd1080p), 1080);
      expect(VideoAspectRatio.portrait9x16.getTargetHeight(VideoQuality.fhd1080p), 1920);

      expect(VideoAspectRatio.portrait9x16.getTargetWidth(VideoQuality.hd720p), 720);
      expect(VideoAspectRatio.portrait9x16.getTargetHeight(VideoQuality.hd720p), 1280);

      expect(VideoAspectRatio.square1x1.getTargetWidth(VideoQuality.hd720p), 720);
      expect(VideoAspectRatio.square1x1.getTargetHeight(VideoQuality.hd720p), 720);

      expect(VideoAspectRatio.landscape16x9.getTargetWidth(VideoQuality.hd720p), 1280);
      expect(VideoAspectRatio.landscape16x9.getTargetHeight(VideoQuality.hd720p), 720);
    });

    test('VideoProjectConfig copyWith and properties', () {
      const initial = VideoProjectConfig(
        surahNumber: 1,
        startAyah: 1,
        endAyah: 7,
      );

      expect(initial.totalAyahsCount, 7);
      expect(initial.aspectRatio, VideoAspectRatio.portrait9x16);
      expect(initial.themePreset.id, 'cream');
      expect(initial.videoQuality, VideoQuality.fhd1080p);
      expect(initial.textDisplayMode, VideoTextDisplayMode.lineByLine);
      expect(initial.showTafsir, false);
      expect(initial.showEnglishTranslation, false);

      final updated = initial.copyWith(
        aspectRatio: VideoAspectRatio.square1x1,
        startAyah: 2,
        endAyah: 5,
        themePreset: VideoThemePreset.burgundy,
        videoQuality: VideoQuality.hd720p,
        textDisplayMode: VideoTextDisplayMode.staticFull,
        showTafsir: true,
        showEnglishTranslation: true,
      );

      expect(updated.aspectRatio, VideoAspectRatio.square1x1);
      expect(updated.totalAyahsCount, 4);
      expect(updated.themePreset.id, 'burgundy');
      expect(updated.videoQuality, VideoQuality.hd720p);
      expect(updated.textDisplayMode, VideoTextDisplayMode.staticFull);
      expect(updated.showTafsir, true);
      expect(updated.showEnglishTranslation, true);
    });

    test('WordTimingSegment and LineTimingSegment helpers', () {
      const seg1 = WordTimingSegment(wordPosition: 1, startMs: 0, endMs: 1200);
      const seg2 = WordTimingSegment(wordPosition: 2, startMs: 1200, endMs: 2800);

      expect(seg1.duration, const Duration(milliseconds: 1200));
      expect(seg1.contains(500), true);
      expect(seg1.contains(1500), false);
      expect(seg2.contains(1500), true);

      const line = LineTimingSegment(
        lineNumber: 1,
        startWordIndex: 0,
        endWordIndex: 1,
        startMs: 0,
        endMs: 2800,
      );

      expect(line.duration, const Duration(milliseconds: 2800));
      expect(line.contains(1000), true);
      expect(line.contains(3000), false);
    });

    test('WordTimingService proportional calculation and grouping', () {
      final verse = VerseModel(
        id: 1,
        verseNumber: 1,
        verseKey: '1:1',
        textUthmani: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
        juzNumber: 1,
        words: [
          const WordModel(id: 1, textUthmani: 'بِسْمِ', codeV2: 'p1w1', lineNumber: 1, charTypeName: 'word', verseKey: '1:1'),
          const WordModel(id: 2, textUthmani: 'اللَّهِ', codeV2: 'p1w2', lineNumber: 1, charTypeName: 'word', verseKey: '1:1'),
          const WordModel(id: 3, textUthmani: 'الرَّحْمَٰنِ', codeV2: 'p1w3', lineNumber: 1, charTypeName: 'word', verseKey: '1:1'),
          const WordModel(id: 4, textUthmani: 'الرَّحِيمِ', codeV2: 'p1w4', lineNumber: 1, charTypeName: 'word', verseKey: '1:1'),
        ],
      );

      final timings = WordTimingService.computeProportionalTimings(
        verse: verse,
        totalDurationMs: 4000,
      );

      expect(timings.length, 4);
      expect(timings.first.startMs, greaterThanOrEqualTo(0));
      expect(timings.last.endMs, lessThanOrEqualTo(4000));

      final lines = WordTimingService.groupIntoLineSegments(
        verse: verse,
        wordTimings: timings,
      );

      expect(lines.isNotEmpty, true);
      expect(lines.first.startMs, 0);
      expect(lines.last.endMs, timings.last.endMs);
    });

    test('VideoProjectConfig custom image background and dimming', () {
      const initial = VideoProjectConfig(
        surahNumber: 1,
        startAyah: 1,
        endAyah: 3,
      );

      expect(initial.customImagePath, isNull);
      expect(initial.backgroundType, VideoBackgroundType.gradient);
      expect(initial.backgroundDimming, 0.35);
      expect(initial.showCardFrame, true);

      final withCustom = initial.copyWith(
        customImagePath: '/path/to/custom_bg.jpg',
        backgroundType: VideoBackgroundType.customImage,
        backgroundDimming: 0.50,
        showCardFrame: false,
      );

      expect(withCustom.customImagePath, '/path/to/custom_bg.jpg');
      expect(withCustom.backgroundType, VideoBackgroundType.customImage);
      expect(withCustom.backgroundDimming, 0.50);
      expect(withCustom.showCardFrame, false);

      final cleared = withCustom.copyWith(
        clearCustomImage: true,
        backgroundType: VideoBackgroundType.gradient,
        showCardFrame: true,
      );

      expect(cleared.customImagePath, isNull);
      expect(cleared.backgroundType, VideoBackgroundType.gradient);
      expect(cleared.showCardFrame, true);
    });

    test('VideoProjectConfig custom video background and dimming', () {
      const initial = VideoProjectConfig(
        surahNumber: 1,
        startAyah: 1,
        endAyah: 3,
      );

      expect(initial.customVideoPath, isNull);
      expect(initial.backgroundType, VideoBackgroundType.gradient);

      final withVideo = initial.copyWith(
        customVideoPath: '/path/to/custom_bg.mp4',
        backgroundType: VideoBackgroundType.customVideo,
        backgroundDimming: 0.40,
        showCardFrame: true,
      );

      expect(withVideo.customVideoPath, '/path/to/custom_bg.mp4');
      expect(withVideo.backgroundType, VideoBackgroundType.customVideo);
      expect(withVideo.backgroundDimming, 0.40);
      expect(withVideo.showCardFrame, true);

      final cleared = withVideo.copyWith(
        clearCustomVideo: true,
        backgroundType: VideoBackgroundType.gradient,
      );

      expect(cleared.customVideoPath, isNull);
      expect(cleared.backgroundType, VideoBackgroundType.gradient);
    });

    test('CustomImageService cache and luminance defaults', () {
      CustomImageService.clearCache();
      expect(CustomImageService.getCachedUiImage('non_existent.jpg'), isNull);
      expect(CustomImageService.getCachedLuminance('non_existent.jpg'), 0.5);
    });
  });
}

