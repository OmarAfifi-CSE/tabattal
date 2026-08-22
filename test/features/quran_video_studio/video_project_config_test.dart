import 'package:flutter_test/flutter_test.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/video_enums.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/video_project_config.dart';
import 'package:tabattal/features/quran_video_studio/domain/entities/video_theme_preset.dart';

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
      expect(VideoQuality.uhd4k.bitrateKbps, 24000);

      expect(VideoQuality.fhd1080p.crf, 22);
      expect(VideoQuality.hd720p.crf, 24);
      expect(VideoQuality.uhd4k.crf, 20);

      expect(VideoAspectRatio.portrait9x16.getTargetWidth(VideoQuality.fhd1080p), 1080);
      expect(VideoAspectRatio.portrait9x16.getTargetHeight(VideoQuality.fhd1080p), 1920);

      expect(VideoAspectRatio.portrait9x16.getTargetWidth(VideoQuality.uhd4k), 2160);
      expect(VideoAspectRatio.portrait9x16.getTargetHeight(VideoQuality.uhd4k), 3840);
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
      expect(initial.showTafsir, false);
      expect(initial.showEnglishTranslation, false);

      final updated = initial.copyWith(
        aspectRatio: VideoAspectRatio.square1x1,
        startAyah: 2,
        endAyah: 5,
        themePreset: VideoThemePreset.burgundy,
        videoQuality: VideoQuality.uhd4k,
        showTafsir: true,
        showEnglishTranslation: true,
      );

      expect(updated.aspectRatio, VideoAspectRatio.square1x1);
      expect(updated.totalAyahsCount, 4);
      expect(updated.themePreset.id, 'burgundy');
      expect(updated.videoQuality, VideoQuality.uhd4k);
      expect(updated.showTafsir, true);
      expect(updated.showEnglishTranslation, true);
    });
  });
}
