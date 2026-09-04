import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../core/constants/quran_metadata.dart';
import '../../../../core/constants/reciter_catalog.dart';
import '../../../quran_reader/data/models/verse_model.dart';
import '../../domain/entities/video_enums.dart';
import '../../domain/entities/video_project_config.dart';

import '../../domain/entities/word_timing_segment.dart';
import 'custom_image_service.dart';
import 'word_timing_service.dart';
import '../../../quran_verse_card/presentation/widgets/shared/helpers/verse_card_text_utils.dart';

class _CachedDynamicLayout {
  final TextPainter versePainter;
  final TextPainter? tafsirBadgePainter;
  final TextPainter? tafsirTextPainter;
  final TextPainter? translationBadgePainter;
  final TextPainter? translationTextPainter;
  final double tafsirBadgeHeight;
  final double translationBadgeHeight;
  final double sectionGap;
  final double totalContentHeight;

  const _CachedDynamicLayout({
    required this.versePainter,
    this.tafsirBadgePainter,
    this.tafsirTextPainter,
    this.translationBadgePainter,
    this.translationTextPainter,
    required this.tafsirBadgeHeight,
    required this.translationBadgeHeight,
    required this.sectionGap,
    required this.totalContentHeight,
  });
}

class VerseOverlayCropResult {
  final Uint8List bytes;
  final int cropY;
  final int cropHeight;

  const VerseOverlayCropResult({
    required this.bytes,
    required this.cropY,
    required this.cropHeight,
  });
}

class CanvasOverlayGenerator {
  const CanvasOverlayGenerator();

  static final Map<String, _CachedDynamicLayout> _dynamicLayoutCache = {};

  static void clearLayoutCache() {
    _dynamicLayoutCache.clear();
  }

  /// Generates a full-resolution frame PNG for a single verse with customizable content opacity.
  Future<Uint8List?> generateVerseFramePng({
    required VerseModel verse,
    required VideoProjectConfig config,
    required int pageNumber,
    String? translationText,
    String? tafsirText,
    bool includeBackground = true,
    double contentOpacity = 1.0,
    int playbackPositionMs = 0,
    List<WordTimingSegment>? wordTimings,
    int? overrideLineIndex,
  }) async {
    final int width = config.aspectRatio.getTargetWidth(config.videoQuality);
    final int height = config.aspectRatio.getTargetHeight(config.videoQuality);

    if (config.customImagePath != null && config.customImagePath!.isNotEmpty) {
      await CustomImageService.loadUiImage(config.customImagePath!);
      await CustomImageService.calculateImageLuminance(config.customImagePath!);
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    paintFrame(
      canvas,
      Size(width.toDouble(), height.toDouble()),
      verse: verse,
      config: config,
      pageNumber: pageNumber,
      translationText: translationText,
      tafsirText: tafsirText,
      includeBackground: includeBackground,
      contentOpacity: contentOpacity,
      playbackPositionMs: playbackPositionMs,
      wordTimings: wordTimings,
      overrideLineIndex: overrideLineIndex,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  /// Generates the static background frame (background, luxury card, header badges, watermark).
  Future<Uint8List?> generateStaticBaseFramePng({
    required VideoProjectConfig config,
    VerseModel? verse,
    bool includeBackground = true,
  }) async {
    final int width = config.aspectRatio.getTargetWidth(config.videoQuality);
    final int height = config.aspectRatio.getTargetHeight(config.videoQuality);

    if (config.customImagePath != null && config.customImagePath!.isNotEmpty) {
      await CustomImageService.loadUiImage(config.customImagePath!);
      await CustomImageService.calculateImageLuminance(config.customImagePath!);
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    paintStaticDecoration(
      canvas,
      Size(width.toDouble(), height.toDouble()),
      config: config,
      verse: verse,
      includeBackground: includeBackground,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  /// Generates the transparent overlay PNG containing only the dynamic center content (Verse, Tafsir, Translation).
  Future<Uint8List?> generateVerseOverlayPng({
    required VerseModel verse,
    required VideoProjectConfig config,
    required int pageNumber,
    String? translationText,
    String? tafsirText,
    int playbackPositionMs = 0,
    List<WordTimingSegment>? wordTimings,
    int? overrideLineIndex,
  }) async {
    final int width = config.aspectRatio.getTargetWidth(config.videoQuality);
    final int height = config.aspectRatio.getTargetHeight(config.videoQuality);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    paintDynamicContent(
      canvas,
      Size(width.toDouble(), height.toDouble()),
      verse: verse,
      config: config,
      pageNumber: pageNumber,
      translationText: translationText,
      tafsirText: tafsirText,
      playbackPositionMs: playbackPositionMs,
      wordTimings: wordTimings,
      overrideLineIndex: overrideLineIndex,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  /// Generates an ultra-lightweight cropped transparent overlay PNG
  /// containing only the active text area, reducing payload size by over 90%.
  Future<VerseOverlayCropResult?> generateVerseOverlayCrop({
    required VerseModel verse,
    required VideoProjectConfig config,
    required int pageNumber,
    String? translationText,
    String? tafsirText,
    int playbackPositionMs = 0,
    List<WordTimingSegment>? wordTimings,
    int? overrideLineIndex,
  }) async {
    final int width = config.aspectRatio.getTargetWidth(config.videoQuality);
    final int height = config.aspectRatio.getTargetHeight(config.videoQuality);

    final bounds = computeDynamicContentBounds(
      Size(width.toDouble(), height.toDouble()),
      verse: verse,
      config: config,
      pageNumber: pageNumber,
      translationText: translationText,
      tafsirText: tafsirText,
      overrideLineIndex: overrideLineIndex,
    );

    final int cropY = max(0, (bounds.top - 16).floor());
    final int cropHeight = min(height - cropY, (bounds.height + 32).ceil());

    final cropRecorder = ui.PictureRecorder();
    final cropCanvas = Canvas(cropRecorder, Rect.fromLTWH(0, 0, width.toDouble(), cropHeight.toDouble()));
    cropCanvas.translate(0, -cropY.toDouble());

    paintDynamicContent(
      cropCanvas,
      Size(width.toDouble(), height.toDouble()),
      verse: verse,
      config: config,
      pageNumber: pageNumber,
      translationText: translationText,
      tafsirText: tafsirText,
      playbackPositionMs: playbackPositionMs,
      wordTimings: wordTimings,
      overrideLineIndex: overrideLineIndex,
    );

    final picture = cropRecorder.endRecording();
    final image = await picture.toImage(width, cropHeight);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData?.buffer.asUint8List();

    if (bytes == null) return null;

    return VerseOverlayCropResult(
      bytes: bytes,
      cropY: cropY,
      cropHeight: cropHeight,
    );
  }

  /// Computes the exact vertical bounds of the dynamic center content.
  static Rect computeDynamicContentBounds(
    Size size, {
    required VerseModel verse,
    required VideoProjectConfig config,
    required int pageNumber,
    String? translationText,
    String? tafsirText,
    int? overrideLineIndex,
  }) {
    final width = size.width;
    final height = size.height;

    final double topLimit;
    final double bottomLimit;
    if (config.showSurahBadge && config.showReciterName) {
      if (config.aspectRatio == VideoAspectRatio.landscape16x9) {
        topLimit = height * 0.22;
        bottomLimit = height * 0.78;
      } else if (config.aspectRatio == VideoAspectRatio.square1x1) {
        topLimit = height * 0.20;
        bottomLimit = height * 0.80;
      } else {
        topLimit = height * 0.18;
        bottomLimit = height * 0.82;
      }
    } else if (config.showSurahBadge || config.showReciterName) {
      if (config.aspectRatio == VideoAspectRatio.landscape16x9) {
        topLimit = height * 0.16;
        bottomLimit = height * 0.84;
      } else if (config.aspectRatio == VideoAspectRatio.square1x1) {
        topLimit = height * 0.15;
        bottomLimit = height * 0.85;
      } else {
        topLimit = height * 0.14;
        bottomLimit = height * 0.86;
      }
    } else {
      if (config.aspectRatio == VideoAspectRatio.landscape16x9) {
        topLimit = height * 0.11;
        bottomLimit = height * 0.89;
      } else if (config.aspectRatio == VideoAspectRatio.square1x1) {
        topLimit = height * 0.10;
        bottomLimit = height * 0.90;
      } else {
        topLimit = height * 0.10;
        bottomLimit = height * 0.90;
      }
    }

    final double availableHeight = (bottomLimit - topLimit).clamp(100.0, height);
    final hasTafsir = (config.showTafsir && (tafsirText ?? verse.tafsir) != null && (tafsirText ?? verse.tafsir)!.isNotEmpty);
    final hasTranslation = (config.showEnglishTranslation && (translationText ?? verse.translation) != null && (translationText ?? verse.translation)!.isNotEmpty);

    final cacheKey = '${verse.verseKey}_${config.themePreset.id}_${config.aspectRatio.name}_${config.backgroundType.name}_${config.textDisplayMode.name}_${config.isEnglish}_${hasTafsir}_${hasTranslation}_${config.showCardFrame}_${config.customImagePath ?? "no_img"}_${config.customVideoPath ?? "no_vid"}_${config.backgroundDimming}_${overrideLineIndex ?? 0}_${width.round()}_${height.round()}';

    final cached = _dynamicLayoutCache[cacheKey];
    final double totalContentHeight = cached?.totalContentHeight ?? (height * 0.35);
    final double startY = topLimit + ((availableHeight - totalContentHeight) / 2);

    return Rect.fromLTWH(0, startY, width, totalContentHeight);
  }

  /// Single Source of Truth: Paints the exact video frame on any canvas at any resolution.
  static void paintFrame(
    Canvas canvas,
    Size size, {
    required VerseModel verse,
    required VideoProjectConfig config,
    required int pageNumber,
    String? translationText,
    String? tafsirText,
    bool includeBackground = true,
    double contentOpacity = 1.0,
    int playbackPositionMs = 0,
    List<WordTimingSegment>? wordTimings,
    int? overrideLineIndex,
  }) {
    paintStaticDecoration(
      canvas,
      size,
      config: config,
      verse: verse,
      includeBackground: includeBackground,
    );

    paintDynamicContent(
      canvas,
      size,
      verse: verse,
      config: config,
      pageNumber: pageNumber,
      translationText: translationText,
      tafsirText: tafsirText,
      contentOpacity: contentOpacity,
      playbackPositionMs: playbackPositionMs,
      wordTimings: wordTimings,
      overrideLineIndex: overrideLineIndex,
    );
  }

  /// Paints the static background, card frame, header badges (Surah & Reciter), and footer branding.
  static void paintStaticDecoration(
    Canvas canvas,
    Size size, {
    required VideoProjectConfig config,
    VerseModel? verse,
    bool includeBackground = true,
  }) {
    final width = size.width;
    final height = size.height;
    final baseScale = min(width, height);

    if (includeBackground) {
      _drawBackground(canvas, width, height, config, baseScale);
    } else {
      _drawCardFrameAndOrnaments(canvas, width, height, config, baseScale);
    }

    _drawHeaderBadges(canvas, width, height, config, verse, baseScale);
    _drawFooterBrand(canvas, width, height, config, baseScale);
  }

  /// Paints ONLY the dynamic center content (Verse text, Tafsir, Translation) for clean fade in / fade out.
  static void paintDynamicContent(
    Canvas canvas,
    Size size, {
    required VerseModel verse,
    required VideoProjectConfig config,
    required int pageNumber,
    String? translationText,
    String? tafsirText,
    double contentOpacity = 1.0,
    int playbackPositionMs = 0,
    int? totalDurationMs,
    bool isPlaying = false,
    List<WordTimingSegment>? wordTimings,
    int? overrideLineIndex,
  }) {
    if (contentOpacity <= 0.0) return;

    final width = size.width;
    final height = size.height;
    final baseScale = min(width, height);

    final effectiveTafsir = (config.showTafsir && (tafsirText ?? verse.tafsir) != null && (tafsirText ?? verse.tafsir)!.isNotEmpty)
        ? (tafsirText ?? verse.tafsir)
        : null;

    final effectiveTranslation = (config.showEnglishTranslation && (translationText ?? verse.translation) != null && (translationText ?? verse.translation)!.isNotEmpty)
        ? (translationText ?? verse.translation)
        : null;

    if (contentOpacity < 1.0) {
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, width, height),
        Paint()..color = Color.fromRGBO(255, 255, 255, contentOpacity.clamp(0.0, 1.0)),
      );
    }

    _drawCenterContent(
      canvas,
      width,
      height,
      config,
      verse,
      pageNumber,
      effectiveTafsir,
      effectiveTranslation,
      baseScale,
      playbackPositionMs: playbackPositionMs,
      totalDurationMs: totalDurationMs,
      isPlaying: isPlaying,
      wordTimings: wordTimings,
      overrideLineIndex: overrideLineIndex,
    );

    if (contentOpacity < 1.0) {
      canvas.restore();
    }
  }

  static void _drawBackground(
    Canvas canvas,
    double width,
    double height,
    VideoProjectConfig config,
    double baseScale,
  ) {
    final theme = config.themePreset;
    final rect = Rect.fromLTWH(0, 0, width, height);

    final hasCustomImage = config.hasCustomImage;

    if (hasCustomImage) {
      final uiImage = CustomImageService.getCachedUiImage(config.customImagePath!);
      if (uiImage != null) {
        _paintImageCover(canvas, rect, uiImage);
      } else {
        final paint = Paint()
          ..shader = ui.Gradient.linear(
            Offset(width / 2, 0),
            Offset(width / 2, height),
            theme.gradientColors,
          );
        canvas.drawRect(rect, paint);
      }

      // Draw Dimming Layer
      final dimmingPaint = Paint()
        ..color = Colors.black.withValues(alpha: config.backgroundDimming);
      canvas.drawRect(rect, dimmingPaint);
    } else if (config.backgroundType == VideoBackgroundType.solid) {
      final paint = Paint()..color = theme.gradientColors.first;
      canvas.drawRect(rect, paint);
    } else {
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(width / 2, 0),
          Offset(width / 2, height),
          theme.gradientColors,
        );
      canvas.drawRect(rect, paint);
    }

    _drawCardFrameAndOrnaments(canvas, width, height, config, baseScale);
  }

  /// Resolves whether the background is light or dark (based on custom image or video dimming).
  static bool _isLightBackground(VideoProjectConfig config) {
    if (config.hasCustomImage) {
      final rawLuminance = CustomImageService.getCachedLuminance(config.customImagePath!);
      final effectiveLuminance = rawLuminance * (1.0 - config.backgroundDimming);
      return effectiveLuminance > 0.55;
    }

    if (config.hasCustomVideo) {
      const baseLuminance = 0.5;
      final effectiveLuminance = baseLuminance * (1.0 - config.backgroundDimming);
      return effectiveLuminance > 0.55;
    }

    return false;
  }

  /// Resolves whether custom media (image or video) is active.
  static bool _hasCustomMedia(VideoProjectConfig config) {
    return config.hasCustomMedia;
  }

  /// Resolves the accent / ornament / brand color.
  /// When frameless custom media is active, it strictly adheres to pure white or dark based on luminance,
  /// completely detached from the theme preset.
  static Color _resolveAccentColor(VideoProjectConfig config) {
    final hasMedia = _hasCustomMedia(config);
    final isFrameless = hasMedia && !config.showCardFrame;
    if (isFrameless) {
      final isLight = _isLightBackground(config);
      return isLight ? const Color(0xFF111418) : const Color(0xFFFFFFFF);
    }
    return config.themePreset.accentColor;
  }

  static void _drawCardFrameAndOrnaments(
    Canvas canvas,
    double width,
    double height,
    VideoProjectConfig config,
    double baseScale,
  ) {
    final theme = config.themePreset;
    final hasCustomMedia = _hasCustomMedia(config);

    // Optional Card Container Box & Border
    if (config.showCardFrame) {
      // Dynamic Card Margin based on AspectRatio
      final double cardMarginH = config.aspectRatio == VideoAspectRatio.landscape16x9
          ? width * 0.08
          : width * 0.05;
      final double cardMarginV = height * 0.05;

      final cardRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          cardMarginH,
          cardMarginV,
          width - (cardMarginH * 2),
          height - (cardMarginV * 2),
        ),
        Radius.circular(baseScale * 0.04),
      );

      final Color cardBgColor;
      final Color cardBorderColor;

      if (hasCustomMedia) {
        cardBgColor = const Color(0xFF0B0F14).withValues(alpha: 0.60);
        cardBorderColor = theme.accentColor.withValues(alpha: 0.55);
      } else {
        cardBgColor = theme.cardBackgroundColor;
        cardBorderColor = theme.borderColor;
      }

      final cardBgPaint = Paint()..color = cardBgColor;
      final cardBorderPaint = Paint()
        ..color = cardBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = baseScale * 0.004;

      canvas.drawRRect(cardRect, cardBgPaint);
      canvas.drawRRect(cardRect, cardBorderPaint);
    }

    // Decorative Top Ornament (100% Matching VerseCard Star & Lines Header)
    final double cardMarginV = height * 0.05;
    final double ornamentCenterY = config.aspectRatio == VideoAspectRatio.landscape16x9
        ? cardMarginV + (height * 0.038)
        : (config.aspectRatio == VideoAspectRatio.square1x1
            ? cardMarginV + (height * 0.038)
            : cardMarginV + (height * 0.030));

    final Color ornamentColor = _resolveAccentColor(config);

    final linePaint = Paint()
      ..color = ornamentColor.withValues(alpha: 0.45)
      ..strokeWidth = baseScale * 0.002;

    final lineLength = baseScale * 0.12;
    final space = baseScale * 0.032;
    canvas.drawLine(
      Offset((width / 2) - lineLength - space, ornamentCenterY),
      Offset((width / 2) - space, ornamentCenterY),
      linePaint,
    );
    canvas.drawLine(
      Offset((width / 2) + space, ornamentCenterY),
      Offset((width / 2) + lineLength + space, ornamentCenterY),
      linePaint,
    );

    // Draw Center Rounded Star Icon (Matching VerseCard Image Header)
    final starSize = baseScale * 0.026;
    final starPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.star_rate_rounded.codePoint),
        style: TextStyle(
          fontSize: starSize,
          fontFamily: Icons.star_rate_rounded.fontFamily,
          package: Icons.star_rate_rounded.fontPackage,
          color: ornamentColor.withValues(alpha: 0.90),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    starPainter.paint(
      canvas,
      Offset((width - starPainter.width) / 2, ornamentCenterY - (starPainter.height / 2)),
    );
  }

  static void _drawHeaderBadges(
    Canvas canvas,
    double width,
    double height,
    VideoProjectConfig config,
    VerseModel? verse,
    double baseScale,
  ) {
    if (!config.showSurahBadge && !config.showReciterName) return;

    final theme = config.themePreset;
    final isEn = config.isEnglish;
    final surahName = QuranMetadata.getSurahNameByLang(isEn, config.surahNumber);
    final reciterName = ReciterCatalog.localizeByLang(isEn, config.reciterName);

    final double cardMarginV = height * 0.05;
    final double surahCenterY = config.aspectRatio == VideoAspectRatio.landscape16x9
        ? cardMarginV + (height * 0.105)
        : (config.aspectRatio == VideoAspectRatio.square1x1
            ? cardMarginV + (height * 0.100)
            : cardMarginV + (height * 0.075));

    final double reciterCenterY = config.aspectRatio == VideoAspectRatio.landscape16x9
        ? cardMarginV + (height * 0.165)
        : (config.aspectRatio == VideoAspectRatio.square1x1
            ? cardMarginV + (height * 0.160)
            : cardMarginV + (height * 0.125));

    final bool hasCustomMedia = _hasCustomMedia(config);
    final bool isFramelessCustom = hasCustomMedia && !config.showCardFrame;
    final Color badgeAccentColor = _resolveAccentColor(config);

    if (config.showSurahBadge) {
      final bool isLineByLine = config.textDisplayMode == VideoTextDisplayMode.lineByLine;
      final String surahText;
      if (isLineByLine) {
        final ayahNum = verse?.verseNumber ?? config.startAyah;
        if (isEn) {
          surahText = 'Surah $surahName • Ayah $ayahNum';
        } else {
          final arabicAyahNum = VerseCardTextUtils.toArabicDigits(ayahNum);
          surahText = 'سورة $surahName • الآية $arabicAyahNum';
        }
      } else {
        if (config.startAyah == config.endAyah) {
          if (isEn) {
            surahText = 'Surah $surahName • Ayah ${config.startAyah}';
          } else {
            final arabicAyahNum = VerseCardTextUtils.toArabicDigits(config.startAyah);
            surahText = 'سورة $surahName • الآية $arabicAyahNum';
          }
        } else {
          if (isEn) {
            surahText = 'Surah $surahName • Ayahs ${config.startAyah}-${config.endAyah}';
          } else {
            final startArabic = VerseCardTextUtils.toArabicDigits(config.startAyah);
            final endArabic = VerseCardTextUtils.toArabicDigits(config.endAyah);
            surahText = 'سورة $surahName • الآيات ($startArabic - $endArabic)';
          }
        }
      }

      final textPainter = TextPainter(
        text: TextSpan(
          text: surahText,
          style: TextStyle(
            color: isFramelessCustom ? badgeAccentColor : theme.accentColor,
            fontSize: baseScale * 0.026,
            fontWeight: FontWeight.w600,
            fontFamily: isEn ? null : 'Amiri',
          ),
        ),
        textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
        textAlign: TextAlign.center,
      )..layout();

      // Proportions matching VerseCard generator (generous padding & rounded pill border)
      final badgeW = textPainter.width + (baseScale * 0.08);
      final badgeH = textPainter.height + (baseScale * 0.024);
      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(width / 2, surahCenterY),
          width: badgeW,
          height: badgeH,
        ),
        Radius.circular(badgeH / 2),
      );

      final badgePaint = Paint()
        ..color = isFramelessCustom
            ? badgeAccentColor.withValues(alpha: 0.16)
            : theme.accentColor.withValues(alpha: 0.15);
      final borderPaint = Paint()
        ..color = isFramelessCustom
            ? badgeAccentColor.withValues(alpha: 0.45)
            : theme.accentColor.withValues(alpha: 0.40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = baseScale * 0.002;

      canvas.drawRRect(badgeRect, badgePaint);
      canvas.drawRRect(badgeRect, borderPaint);

      textPainter.paint(
        canvas,
        Offset((width - textPainter.width) / 2, surahCenterY - (textPainter.height / 2)),
      );
    }

    // Reciter Name
    if (config.showReciterName) {
      final textColors = _resolveTextColors(config);
      final reciterText = isEn ? 'Recited by: $reciterName' : 'بصوت القارئ: $reciterName';
      final textPainter = TextPainter(
        text: TextSpan(
          text: reciterText,
          style: TextStyle(
            color: textColors.secondaryTextColor,
            fontSize: baseScale * 0.023,
            fontWeight: FontWeight.w600,
            fontFamily: isEn ? null : 'Amiri',
          ),
        ),
        textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
        textAlign: TextAlign.center,
      )..layout(maxWidth: width * 0.85);

      textPainter.paint(
        canvas,
        Offset((width - textPainter.width) / 2, reciterCenterY - (textPainter.height / 2)),
      );
    }
  }

  static void _drawCenterContent(
    Canvas canvas,
    double width,
    double height,
    VideoProjectConfig config,
    VerseModel verse,
    int pageNumber,
    String? tafsir,
    String? translation,
    double baseScale, {
    int playbackPositionMs = 0,
    int? totalDurationMs,
    bool isPlaying = false,
    List<WordTimingSegment>? wordTimings,
    int? overrideLineIndex,
  }) {
    final theme = config.themePreset;
    final textColors = _resolveTextColors(config);
    final bool hasCustomMedia = _hasCustomMedia(config);
    final bool isFramelessCustom = hasCustomMedia && !config.showCardFrame;
    final Color badgeAccentColor = _resolveAccentColor(config);
    final bool isEn = config.isEnglish;

    final timings = wordTimings ?? const <WordTimingSegment>[];

    // Vertical limits calibrated symmetrically around 50% screen height
    // to guarantee the verse sits in the true visual & mathematical center of the video frame.
    final double topLimit;
    final double bottomLimit;
    if (config.showSurahBadge && config.showReciterName) {
      if (config.aspectRatio == VideoAspectRatio.landscape16x9) {
        topLimit = height * 0.22;
        bottomLimit = height * 0.78;
      } else if (config.aspectRatio == VideoAspectRatio.square1x1) {
        topLimit = height * 0.20;
        bottomLimit = height * 0.80;
      } else {
        topLimit = height * 0.18;
        bottomLimit = height * 0.82;
      }
    } else if (config.showSurahBadge || config.showReciterName) {
      if (config.aspectRatio == VideoAspectRatio.landscape16x9) {
        topLimit = height * 0.16;
        bottomLimit = height * 0.84;
      } else if (config.aspectRatio == VideoAspectRatio.square1x1) {
        topLimit = height * 0.15;
        bottomLimit = height * 0.85;
      } else {
        topLimit = height * 0.14;
        bottomLimit = height * 0.86;
      }
    } else {
      if (config.aspectRatio == VideoAspectRatio.landscape16x9) {
        topLimit = height * 0.11;
        bottomLimit = height * 0.89;
      } else if (config.aspectRatio == VideoAspectRatio.square1x1) {
        topLimit = height * 0.10;
        bottomLimit = height * 0.90;
      } else {
        topLimit = height * 0.10;
        bottomLimit = height * 0.90;
      }
    }

    final double availableHeight = (bottomLimit - topLimit).clamp(100.0, height);
    final double maxContentWidth = config.aspectRatio == VideoAspectRatio.landscape16x9
        ? width * 0.78
        : width * 0.84;

    final isLineByLine = config.textDisplayMode == VideoTextDisplayMode.lineByLine;

    // 1. Dynamic length scaling matching Tabattal VerseCard generator
    final int len = verse.textUthmani.length;
    double lengthScale;
    double lineHeight;
    if (isLineByLine) {
      lengthScale = 1.28;
      lineHeight = 1.95;
    } else if (len <= 60) {
      lengthScale = 1.16;
      lineHeight = 1.95;
    } else if (len <= 120) {
      lengthScale = 1.08;
      lineHeight = 1.90;
    } else if (len <= 200) {
      lengthScale = 0.96;
      lineHeight = 1.85;
    } else if (len <= 320) {
      lengthScale = 0.84;
      lineHeight = 1.80;
    } else if (len <= 500) {
      lengthScale = 0.72;
      lineHeight = 1.75;
    } else if (len <= 750) {
      lengthScale = 0.62;
      lineHeight = 1.70;
    } else {
      lengthScale = 0.54;
      lineHeight = 1.65;
    }

    double optionsScale = 1.0;
    final hasTafsir = tafsir != null && tafsir.trim().isNotEmpty;
    final hasTranslation = translation != null && translation.trim().isNotEmpty;
    if (hasTafsir && hasTranslation) {
      optionsScale = isLineByLine ? 0.82 : 0.76;
    } else if (hasTafsir || hasTranslation) {
      optionsScale = isLineByLine ? 0.90 : 0.88;
    }

    final double baseVerseSize = config.aspectRatio == VideoAspectRatio.landscape16x9
        ? baseScale * 0.046
        : (config.aspectRatio == VideoAspectRatio.square1x1
            ? baseScale * 0.054
            : baseScale * 0.060);

    // Determine active line segment for lineByLine mode
    List<LineTimingSegment> lineSegments = [];
    LineTimingSegment? activeLine;
    double lineCrossfadeOpacity = 1.0;

    if (isLineByLine && verse.words.isNotEmpty) {
      lineSegments = WordTimingService.groupIntoLineSegments(
        verse: verse,
        wordTimings: timings,
        totalAyahDurationMs: totalDurationMs,
      );
      if (overrideLineIndex != null && overrideLineIndex >= 0 && overrideLineIndex < lineSegments.length) {
        activeLine = lineSegments[overrideLineIndex];
        lineCrossfadeOpacity = 1.0;
      } else {
        for (int i = 0; i < lineSegments.length; i++) {
          final line = lineSegments[i];
          final isLast = i == lineSegments.length - 1;
          if (isLast ? (playbackPositionMs >= line.startMs) : (playbackPositionMs >= line.startMs && playbackPositionMs < line.endMs)) {
            activeLine = line;
            break;
          }
        }
        activeLine ??= lineSegments.first;

        // Smooth cubic line crossfade matching export video engine
        final lineStart = activeLine.startMs;
        final lineEnd = activeLine.endMs;
        final lineDur = max(lineEnd - lineStart, 400);
        final lineDurSec = lineDur / 1000.0;
        final safeFadeSec = 0.30.clamp(0.05, lineDurSec * 0.20);
        final fadeMs = (safeFadeSec * 1000).round();

        if (!isPlaying && playbackPositionMs == 0) {
          lineCrossfadeOpacity = 1.0;
        } else if (playbackPositionMs < lineStart + fadeMs && fadeMs > 0) {
          final t = (playbackPositionMs - lineStart) / fadeMs;
          lineCrossfadeOpacity = Curves.easeInOutCubic.transform(t.clamp(0.0, 1.0));
        } else if (playbackPositionMs > lineEnd - fadeMs && fadeMs > 0) {
          final t = (lineEnd - playbackPositionMs) / fadeMs;
          lineCrossfadeOpacity = Curves.easeInOutCubic.transform(t.clamp(0.0, 1.0));
        } else {
          lineCrossfadeOpacity = 1.0;
        }
      }
    } else {
      // Whole verse mode:
      // Smooth cubic fade-in at the start and fade-out at the tail end matching export video engine
      final totalMs = totalDurationMs ?? (timings.isNotEmpty ? timings.last.endMs : 4000);
      final durSec = max(totalMs, 400) / 1000.0;
      final safeFadeSec = 0.30.clamp(0.05, durSec * 0.20);
      final fadeMs = (safeFadeSec * 1000).round();

      if (!isPlaying && playbackPositionMs == 0) {
        lineCrossfadeOpacity = 1.0;
      } else if (playbackPositionMs < fadeMs && fadeMs > 0) {
        final t = playbackPositionMs / fadeMs;
        lineCrossfadeOpacity = Curves.easeInOutCubic.transform(t.clamp(0.0, 1.0));
      } else if (playbackPositionMs > totalMs - fadeMs && fadeMs > 0 && totalMs > fadeMs * 2) {
        final t = (totalMs - playbackPositionMs) / fadeMs;
        lineCrossfadeOpacity = Curves.easeInOutCubic.transform(t.clamp(0.0, 1.0));
      } else {
        lineCrossfadeOpacity = 1.0;
      }
    }

    double currentScaleMultiplier = 1.0;

    (
      TextPainter versePainter,
      TextPainter? tafsirBadgePainter,
      TextPainter? tafsirTextPainter,
      double tafsirTotalHeight,
      double tafsirBadgeHeight,
      TextPainter? transBadgePainter,
      TextPainter? transTextPainter,
      double transTotalHeight,
      double transBadgeHeight,
      double sectionGap,
      double totalHeight
    ) computeLayout(double scale) {
      double effectiveVerseSize = baseVerseSize * lengthScale * optionsScale * scale;
      final effectiveTafsirSize = (baseScale * 0.033) * optionsScale * scale;
      final effectiveTransSize = (baseScale * 0.022) * optionsScale * scale;

      // Helper to build verse text span with a specified font size
      TextSpan buildVerseSpan(double vSize) {
        if (verse.words.isNotEmpty) {
          final children = <InlineSpan>[];
          final wordsToRender = isLineByLine && activeLine != null
              ? verse.words.sublist(activeLine.startWordIndex, min(activeLine.endWordIndex + 1, verse.words.length))
              : verse.words;

          final wordColor = textColors.primaryTextColor;

          // If lineByLine, add Right Quranic Bracket (U+FD5F) at the start (in RTL it renders on the right)
          if (isLineByLine) {
            children.add(
              TextSpan(
                text: '\uFD5F',
                style: TextStyle(
                  fontFamily: 'KFGQPC HAFS Uthmanic Script Regular',
                  color: wordColor,
                  fontWeight: FontWeight.normal,
                ),
              ),
            );
          }

          for (int i = 0; i < wordsToRender.length; i++) {
            final w = wordsToRender[i];
            final pageNum = w.pageNumber > 0 ? w.pageNumber : pageNumber;
            final pageStr = pageNum.toString().padLeft(3, '0');
            final font = 'QCF_P$pageStr';
            final text = w.codeV2.isNotEmpty ? w.codeV2 : (w.code.isNotEmpty ? w.code : w.textUthmani);

            if (children.isNotEmpty) {
              children.add(const TextSpan(text: ' '));
            }
            children.add(
              TextSpan(
                text: text,
                style: TextStyle(
                  fontFamily: font,
                  color: wordColor,
                  fontWeight: FontWeight.normal,
                ),
              ),
            );
          }

          // If lineByLine, add Left Quranic Bracket (U+FD5E) at the end (in RTL it renders on the left)
          if (isLineByLine) {
            children.add(const TextSpan(text: ' '));
            children.add(
              TextSpan(
                text: '\uFD5E',
                style: TextStyle(
                  fontFamily: 'KFGQPC HAFS Uthmanic Script Regular',
                  color: wordColor,
                  fontWeight: FontWeight.normal,
                ),
              ),
            );
          }

          return TextSpan(
            style: TextStyle(
              color: textColors.primaryTextColor,
              fontSize: vSize,
              height: lineHeight,
            ),
            children: children,
          );
        } else {
          final displayText = isLineByLine
              ? '\uFD5F ${verse.textUthmani} \uFD5E'
              : '﴿ ${verse.textUthmani} ﴾';
          return TextSpan(
            text: displayText,
            style: TextStyle(
              color: textColors.primaryTextColor,
              fontSize: vSize,
              height: lineHeight,
              fontFamily: isLineByLine ? 'KFGQPC HAFS Uthmanic Script Regular' : 'Amiri',
            ),
          );
        }
      }

      var verseTextSpan = buildVerseSpan(effectiveVerseSize);
      var vPainter = TextPainter(
        text: verseTextSpan,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
      )..layout(maxWidth: maxContentWidth);

      // In line-by-line mode: guarantee text fits on exactly ONE single visual line without wrapping
      if (isLineByLine && vPainter.computeLineMetrics().length > 1) {
        double fitScale = 0.92;
        while (vPainter.computeLineMetrics().length > 1 && fitScale >= 0.45) {
          effectiveVerseSize = baseVerseSize * lengthScale * optionsScale * scale * fitScale;
          verseTextSpan = buildVerseSpan(effectiveVerseSize);
          vPainter = TextPainter(
            text: verseTextSpan,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
          )..layout(maxWidth: maxContentWidth);
          fitScale -= 0.06;
        }
      }

      // Tafsir painter
      TextPainter? tBadgePainter;
      TextPainter? tTextPainter;
      double tTotalH = 0;
      double tBadgeH = 0;

      if (hasTafsir) {
        final Color badgeTextColor = isFramelessCustom ? badgeAccentColor : theme.accentColor;
        tBadgePainter = TextPainter(
          text: TextSpan(
            text: isEn ? 'Al-Muyassar Tafsir' : 'التفسير الميسر',
            style: TextStyle(
              color: badgeTextColor,
              fontSize: (baseScale * 0.024) * scale,
              fontWeight: FontWeight.w600,
              fontFamily: isEn ? null : 'Amiri',
            ),
          ),
          textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
          textAlign: TextAlign.center,
        )..layout(maxWidth: width * 0.6);

        tBadgeH = tBadgePainter.height + (height * 0.008);

        tTextPainter = TextPainter(
          text: TextSpan(
            text: tafsir.trim(),
            style: TextStyle(
              color: textColors.secondaryTextColor,
              fontSize: effectiveTafsirSize,
              height: 1.55,
              fontFamily: 'Amiri',
            ),
          ),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
        )..layout(maxWidth: maxContentWidth);

        tTotalH = tBadgeH + (height * 0.008) + tTextPainter.height;
      }

      // Translation painter
      TextPainter? trBadgePainter;
      TextPainter? trTextPainter;
      double trTotalH = 0;
      double trBadgeH = 0;

      if (hasTranslation) {
        if (hasTafsir) {
          final Color badgeTextColor = isFramelessCustom ? badgeAccentColor : theme.accentColor;
          trBadgePainter = TextPainter(
            text: TextSpan(
              text: isEn ? 'English Translation' : 'الترجمة الإنجليزية',
              style: TextStyle(
                color: badgeTextColor,
                fontSize: (baseScale * 0.020) * scale,
                fontWeight: FontWeight.w600,
                fontFamily: isEn ? null : 'Amiri',
              ),
            ),
            textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
            textAlign: TextAlign.center,
          )..layout(maxWidth: width * 0.6);

          trBadgeH = trBadgePainter.height + (height * 0.008);
        }

        trTextPainter = TextPainter(
          text: TextSpan(
            text: translation.trim(),
            style: TextStyle(
              color: textColors.secondaryTextColor,
              fontSize: effectiveTransSize,
              height: 1.40,
              fontStyle: FontStyle.italic,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout(maxWidth: maxContentWidth);

        trTotalH = (hasTafsir ? (trBadgeH + height * 0.008) : 0) + trTextPainter.height;
      }

      final gap = config.aspectRatio == VideoAspectRatio.landscape16x9
          ? height * 0.018
          : (config.aspectRatio == VideoAspectRatio.square1x1
              ? height * 0.022
              : height * 0.026);

      double totH = vPainter.height;
      if (tTextPainter != null) {
        totH += gap + tTotalH;
      }
      if (trTextPainter != null) {
        totH += gap + trTotalH;
      }

      return (
        vPainter,
        tBadgePainter,
        tTextPainter,
        tTotalH,
        tBadgeH,
        trBadgePainter,
        trTextPainter,
        trTotalH,
        trBadgeH,
        gap,
        totH
      );
    }

    final cacheKey = '${verse.verseKey}_${config.themePreset.id}_${config.aspectRatio.name}_${config.backgroundType.name}_${config.textDisplayMode.name}_${config.isEnglish}_${hasTafsir}_${hasTranslation}_${config.showCardFrame}_${config.customImagePath ?? "no_img"}_${config.customVideoPath ?? "no_vid"}_${config.backgroundDimming}_${overrideLineIndex ?? activeLine?.lineNumber ?? 0}_${width.round()}_${height.round()}';

    final cached = _dynamicLayoutCache.putIfAbsent(cacheKey, () {
      var layout = computeLayout(currentScaleMultiplier);
      while (layout.$11 > availableHeight && currentScaleMultiplier > 0.40) {
        currentScaleMultiplier -= 0.04;
        layout = computeLayout(currentScaleMultiplier);
      }
      return _CachedDynamicLayout(
        versePainter: layout.$1,
        tafsirBadgePainter: layout.$2,
        tafsirTextPainter: layout.$3,
        translationBadgePainter: layout.$6,
        translationTextPainter: layout.$7,
        tafsirBadgeHeight: layout.$5,
        translationBadgeHeight: layout.$9,
        sectionGap: layout.$10,
        totalContentHeight: layout.$11,
      );
    });

    final double startY = topLimit + ((availableHeight - cached.totalContentHeight) / 2);
    double currentY = startY;

    // Wrap entire center content block (verse, tafsir, translation) in saveLayer for clean, unified crossfade
    final bool isContentFading = lineCrossfadeOpacity < 0.999;
    if (isContentFading) {
      canvas.saveLayer(
        Rect.fromLTWH(0, startY - 20, width, cached.totalContentHeight + 40),
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: lineCrossfadeOpacity.clamp(0.0, 1.0)),
      );
    }

    cached.versePainter.paint(
      canvas,
      Offset((width - cached.versePainter.width) / 2, currentY),
    );
    currentY += cached.versePainter.height;

    // Draw Tafsir
    if (cached.tafsirTextPainter != null) {
      currentY += cached.sectionGap;
      if (cached.tafsirBadgePainter != null) {
        final badgeW = cached.tafsirBadgePainter!.width + (baseScale * 0.04);
        final badgeH = cached.tafsirBadgeHeight;
        final badgeRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(width / 2, currentY + (badgeH / 2)),
            width: badgeW,
            height: badgeH,
          ),
          Radius.circular(badgeH / 2),
        );

        final badgePaint = Paint()
          ..color = isFramelessCustom
              ? badgeAccentColor.withValues(alpha: 0.16)
              : theme.accentColor.withValues(alpha: 0.15);
        final borderPaint = Paint()
          ..color = isFramelessCustom
              ? badgeAccentColor.withValues(alpha: 0.45)
              : theme.accentColor.withValues(alpha: 0.40)
          ..style = PaintingStyle.stroke
          ..strokeWidth = baseScale * 0.0015;

        canvas.drawRRect(badgeRect, badgePaint);
        canvas.drawRRect(badgeRect, borderPaint);

        cached.tafsirBadgePainter!.paint(
          canvas,
          Offset((width - cached.tafsirBadgePainter!.width) / 2, currentY + ((badgeH - cached.tafsirBadgePainter!.height) / 2)),
        );
        currentY += badgeH + (height * 0.008);
      }

      cached.tafsirTextPainter!.paint(
        canvas,
        Offset((width - cached.tafsirTextPainter!.width) / 2, currentY),
      );
      currentY += cached.tafsirTextPainter!.height;
    }

    // Draw Translation
    if (cached.translationTextPainter != null) {
      currentY += cached.sectionGap;
      if (cached.translationBadgePainter != null) {
        final badgeW = cached.translationBadgePainter!.width + (baseScale * 0.04);
        final badgeH = cached.translationBadgeHeight;
        final badgeRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(width / 2, currentY + (badgeH / 2)),
            width: badgeW,
            height: badgeH,
          ),
          Radius.circular(badgeH / 2),
        );

        final badgePaint = Paint()
          ..color = isFramelessCustom
              ? badgeAccentColor.withValues(alpha: 0.16)
              : theme.accentColor.withValues(alpha: 0.15);
        final borderPaint = Paint()
          ..color = isFramelessCustom
              ? badgeAccentColor.withValues(alpha: 0.45)
              : theme.accentColor.withValues(alpha: 0.40)
          ..style = PaintingStyle.stroke
          ..strokeWidth = baseScale * 0.0015;

        canvas.drawRRect(badgeRect, badgePaint);
        canvas.drawRRect(badgeRect, borderPaint);

        cached.translationBadgePainter!.paint(
          canvas,
          Offset((width - cached.translationBadgePainter!.width) / 2, currentY + ((badgeH - cached.translationBadgePainter!.height) / 2)),
        );
        currentY += badgeH + (height * 0.008);
      }

      cached.translationTextPainter!.paint(
        canvas,
        Offset((width - cached.translationTextPainter!.width) / 2, currentY),
      );
    }

    if (isContentFading) {
      canvas.restore();
    }
  }

  static void _drawFooterBrand(
    Canvas canvas,
    double width,
    double height,
    VideoProjectConfig config,
    double baseScale,
  ) {
    final textColors = _resolveTextColors(config);
    final bool hasCustomMedia = _hasCustomMedia(config);
    final bool isFramelessCustom = hasCustomMedia && !config.showCardFrame;
    final Color footerAccentColor = _resolveAccentColor(config);

    final double iconFontSize = baseScale * 0.026;
    final double textFontSize = baseScale * 0.024;
    final double spacing = baseScale * 0.016;

    // 1. Icon Painter
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.auto_stories_rounded.codePoint),
        style: TextStyle(
          fontFamily: 'MaterialIcons',
          fontSize: iconFontSize,
          color: footerAccentColor.withValues(alpha: isFramelessCustom ? 0.90 : 0.85),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // 2. Text Painter ('تَـبَـتَّـلْ • Tabattal')
    final textPainter = TextPainter(
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'Amiri',
          fontSize: textFontSize,
          fontWeight: FontWeight.w600,
          color: isFramelessCustom
              ? textColors.primaryTextColor
              : textColors.secondaryTextColor.withValues(alpha: 0.85),
        ),
        children: const [
          TextSpan(text: 'تَـبَـتَّـلْ • '),
          TextSpan(
            text: 'Tabattal',
            style: TextStyle(letterSpacing: 0.6),
          ),
        ],
      ),
      textDirection: TextDirection.rtl,
    )..layout();

    // Total width of items + spacing
    final double totalFooterWidth = iconPainter.width + spacing + textPainter.width;

    // Center Y position inside card
    final double cardMarginV = height * 0.05;
    final double bottomCenterY = config.aspectRatio == VideoAspectRatio.landscape16x9
        ? height - cardMarginV - (height * 0.038)
        : (config.aspectRatio == VideoAspectRatio.square1x1
            ? height - cardMarginV - (height * 0.038)
            : height - cardMarginV - (height * 0.028));

    // Visual RTL order: [Icon] -> [تَـبَـتَّـلْ • Tabattal]
    // Painted from left to right on canvas: Text (left) -> Icon (right)
    double startX = (width - totalFooterWidth) / 2;

    textPainter.paint(canvas, Offset(startX, bottomCenterY - (textPainter.height / 2)));
    startX += textPainter.width + spacing;

    iconPainter.paint(canvas, Offset(startX, bottomCenterY - (iconPainter.height / 2)));
  }

  /// Resolves optimal high-contrast text colors.
  static ({Color primaryTextColor, Color secondaryTextColor}) _resolveTextColors(
    VideoProjectConfig config,
  ) {
    final theme = config.themePreset;
    final hasMedia = _hasCustomMedia(config);

    if (!hasMedia) {
      return (
        primaryTextColor: theme.primaryTextColor,
        secondaryTextColor: theme.secondaryTextColor,
      );
    }

    // When card frame is active over custom media, card container is dark glass (0xFF0B0F14 at 60% opacity)
    if (config.showCardFrame) {
      return (
        primaryTextColor: const Color(0xFFFFFFFF),
        secondaryTextColor: const Color(0xFFFFFFFF),
      );
    }

    // Frameless custom media (image or video): text color depends strictly on luminance (pure white on dark, pure black on light)
    final isLight = _isLightBackground(config);
    if (isLight) {
      return (
        primaryTextColor: const Color(0xFF111418),
        secondaryTextColor: const Color(0xFF111418),
      );
    }

    return (
      primaryTextColor: const Color(0xFFFFFFFF),
      secondaryTextColor: const Color(0xFFFFFFFF),
    );
  }

  static void _paintImageCover(Canvas canvas, Rect destRect, ui.Image image) {
    final double imgW = image.width.toDouble();
    final double imgH = image.height.toDouble();
    final double destW = destRect.width;
    final double destH = destRect.height;

    final double scale = max(destW / imgW, destH / imgH);
    final double scaledW = imgW * scale;
    final double scaledH = imgH * scale;

    final double srcX = (scaledW - destW) / (2 * scale);
    final double srcY = (scaledH - destH) / (2 * scale);
    final double srcW = destW / scale;
    final double srcH = destH / scale;

    final srcRect = Rect.fromLTWH(
      srcX.clamp(0.0, imgW),
      srcY.clamp(0.0, imgH),
      srcW.clamp(0.0, imgW),
      srcH.clamp(0.0, imgH),
    );
    canvas.drawImageRect(
      image,
      srcRect,
      destRect,
      Paint()..filterQuality = FilterQuality.high,
    );
  }
}
