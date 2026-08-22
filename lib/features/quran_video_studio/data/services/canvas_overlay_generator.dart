import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../core/constants/quran_metadata.dart';
import '../../../quran_reader/data/models/verse_model.dart';
import '../../domain/entities/video_enums.dart';
import '../../domain/entities/video_project_config.dart';

class CanvasOverlayGenerator {
  const CanvasOverlayGenerator();

  /// Generates a full-resolution frame PNG for a single verse with customizable content opacity.
  Future<Uint8List?> generateVerseFramePng({
    required VerseModel verse,
    required VideoProjectConfig config,
    required int pageNumber,
    String? translationText,
    String? tafsirText,
    bool includeBackground = true,
    double contentOpacity = 1.0,
  }) async {
    final int width = config.aspectRatio.getTargetWidth(config.videoQuality);
    final int height = config.aspectRatio.getTargetHeight(config.videoQuality);

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
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
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

    if (config.backgroundType == VideoBackgroundType.solid) {
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

    final cardBgPaint = Paint()..color = theme.cardBackgroundColor;
    final cardBorderPaint = Paint()
      ..color = theme.borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = baseScale * 0.004;

    canvas.drawRRect(cardRect, cardBgPaint);
    canvas.drawRRect(cardRect, cardBorderPaint);

    // Decorative Top Ornament inside Card
    final double ornamentCenterY = config.aspectRatio == VideoAspectRatio.landscape16x9
        ? cardMarginV + (height * 0.038)
        : (config.aspectRatio == VideoAspectRatio.square1x1
            ? cardMarginV + (height * 0.038)
            : cardMarginV + (height * 0.030));

    final linePaint = Paint()
      ..color = theme.accentColor.withValues(alpha: 0.4)
      ..strokeWidth = baseScale * 0.002;

    final lineLength = baseScale * 0.12;
    final space = baseScale * 0.03;
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

    final dotPaint = Paint()..color = theme.accentColor.withValues(alpha: 0.7);
    canvas.drawCircle(Offset(width / 2, ornamentCenterY), baseScale * 0.008, dotPaint);
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
    final surahName = QuranMetadata.getSurahName(config.surahNumber);
    final reciterName = config.reciterName;

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

    // Surah Badge (سورة without Tashkeel)
    if (config.showSurahBadge) {
      final surahText = 'سورة $surahName';
      final textPainter = TextPainter(
        text: TextSpan(
          text: surahText,
          style: TextStyle(
            color: theme.accentColor,
            fontSize: baseScale * 0.032,
            fontWeight: FontWeight.bold,
            fontFamily: 'Amiri',
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
      )..layout(maxWidth: width * 0.8);

      final badgeWidth = textPainter.width + (baseScale * 0.08);
      final badgeHeight = textPainter.height + (height * 0.016);
      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(width / 2, surahCenterY),
          width: badgeWidth,
          height: badgeHeight,
        ),
        Radius.circular(badgeHeight / 2),
      );

      final badgePaint = Paint()..color = theme.badgeBackgroundColor;
      final borderPaint = Paint()
        ..color = theme.accentColor.withValues(alpha: 0.4)
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
      final reciterText = 'بصوت القارئ: $reciterName';
      final textPainter = TextPainter(
        text: TextSpan(
          text: reciterText,
          style: TextStyle(
            color: theme.secondaryTextColor,
            fontSize: baseScale * 0.024,
            fontWeight: FontWeight.w500,
            fontFamily: 'Amiri',
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
      )..layout(maxWidth: width * 0.8);

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
    double baseScale,
  ) {
    final theme = config.themePreset;

    final double cardMarginV = height * 0.05;
    double topLimit;
    if (config.showSurahBadge && config.showReciterName) {
      topLimit = config.aspectRatio == VideoAspectRatio.landscape16x9
          ? cardMarginV + (height * 0.200)
          : (config.aspectRatio == VideoAspectRatio.square1x1
              ? cardMarginV + (height * 0.190)
              : cardMarginV + (height * 0.155));
    } else if (config.showSurahBadge || config.showReciterName) {
      topLimit = config.aspectRatio == VideoAspectRatio.landscape16x9
          ? cardMarginV + (height * 0.140)
          : (config.aspectRatio == VideoAspectRatio.square1x1
              ? cardMarginV + (height * 0.135)
              : cardMarginV + (height * 0.110));
    } else {
      topLimit = config.aspectRatio == VideoAspectRatio.landscape16x9
          ? cardMarginV + (height * 0.080)
          : (config.aspectRatio == VideoAspectRatio.square1x1
              ? cardMarginV + (height * 0.075)
              : cardMarginV + (height * 0.060));
    }

    final double bottomLimit = config.aspectRatio == VideoAspectRatio.landscape16x9
        ? height - cardMarginV - (height * 0.095)
        : (config.aspectRatio == VideoAspectRatio.square1x1
            ? height - cardMarginV - (height * 0.085)
            : height - cardMarginV - (height * 0.060));

    final double availableHeight = (bottomLimit - topLimit).clamp(100.0, height);
    final double maxContentWidth = config.aspectRatio == VideoAspectRatio.landscape16x9
        ? width * 0.78
        : width * 0.84;

    // 1. Dynamic length scaling matching Tabattal VerseCard generator
    final int len = verse.textUthmani.length;
    double lengthScale;
    double lineHeight;
    if (len <= 60) {
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
      optionsScale = 0.76;
    } else if (hasTafsir || hasTranslation) {
      optionsScale = 0.88;
    }

    final double baseVerseSize = config.aspectRatio == VideoAspectRatio.landscape16x9
        ? baseScale * 0.046
        : (config.aspectRatio == VideoAspectRatio.square1x1
            ? baseScale * 0.054
            : baseScale * 0.060);

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
      final effectiveVerseSize = baseVerseSize * lengthScale * optionsScale * scale;
      final effectiveTafsirSize = (baseScale * 0.024) * optionsScale * scale;
      final effectiveTransSize = (baseScale * 0.022) * optionsScale * scale;

      // Verse painter
      TextSpan verseTextSpan;
      if (verse.words.isNotEmpty) {
        final children = <InlineSpan>[];
        for (final w in verse.words) {
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
              style: TextStyle(fontFamily: font),
            ),
          );
        }
        verseTextSpan = TextSpan(
          style: TextStyle(
            color: theme.primaryTextColor,
            fontSize: effectiveVerseSize,
            height: lineHeight,
          ),
          children: children,
        );
      } else {
        final displayText = '﴿ ${verse.textUthmani} ﴾';
        verseTextSpan = TextSpan(
          text: displayText,
          style: TextStyle(
            color: theme.primaryTextColor,
            fontSize: effectiveVerseSize,
            height: lineHeight,
            fontFamily: 'Amiri',
          ),
        );
      }

      final vPainter = TextPainter(
        text: verseTextSpan,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
      )..layout(maxWidth: maxContentWidth);

      // Tafsir painter
      TextPainter? tBadgePainter;
      TextPainter? tTextPainter;
      double tTotalH = 0;
      double tBadgeH = 0;

      if (hasTafsir) {
        tBadgePainter = TextPainter(
          text: TextSpan(
            text: 'التفسير الميسر',
            style: TextStyle(
              color: theme.accentColor,
              fontSize: (baseScale * 0.021) * scale,
              fontWeight: FontWeight.bold,
              fontFamily: 'Amiri',
            ),
          ),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
        )..layout(maxWidth: width * 0.6);

        tBadgeH = tBadgePainter.height + (height * 0.008);

        tTextPainter = TextPainter(
          text: TextSpan(
            text: tafsir.trim(),
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: effectiveTafsirSize,
              height: 1.50,
              fontFamily: 'Amiri',
            ),
          ),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          maxLines: config.aspectRatio == VideoAspectRatio.landscape16x9 ? 3 : 4,
          ellipsis: '...',
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
          trBadgePainter = TextPainter(
            text: TextSpan(
              text: 'الترجمة الإنجليزية',
              style: TextStyle(
                color: theme.accentColor,
                fontSize: (baseScale * 0.020) * scale,
                fontWeight: FontWeight.bold,
                fontFamily: 'Amiri',
              ),
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
          )..layout(maxWidth: width * 0.6);

          trBadgeH = trBadgePainter.height + (height * 0.008);
        }

        trTextPainter = TextPainter(
          text: TextSpan(
            text: translation.trim(),
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: effectiveTransSize,
              height: 1.40,
              fontStyle: FontStyle.italic,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLines: config.aspectRatio == VideoAspectRatio.landscape16x9 ? 3 : 4,
          ellipsis: '...',
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

    var layout = computeLayout(currentScaleMultiplier);

    // Guaranteed Zero Overflow: if total height exceeds available height, scale down dynamically
    if (layout.$11 > availableHeight && availableHeight > 50) {
      final double fitRatio = (availableHeight * 0.94) / layout.$11;
      currentScaleMultiplier = fitRatio.clamp(0.40, 1.0);
      layout = computeLayout(currentScaleMultiplier);
    }

    final versePainter = layout.$1;
    final tafsirBadgePainter = layout.$2;
    final tafsirTextPainter = layout.$3;
    final tafsirBadgeHeight = layout.$5;
    final translationBadgePainter = layout.$6;
    final translationTextPainter = layout.$7;
    final translationBadgeHeight = layout.$9;
    final sectionGap = layout.$10;
    final totalContentHeight = layout.$11;

    // Center content area vertically between header and footer
    final double centerZoneY = topLimit + ((bottomLimit - topLimit) / 2);
    double currentY = (centerZoneY - (totalContentHeight / 2)).clamp(topLimit, bottomLimit);

    // Draw Verse Text
    versePainter.paint(canvas, Offset((width - versePainter.width) / 2, currentY));
    currentY += versePainter.height;

    // Draw Tafsir (if active)
    if (tafsirTextPainter != null && tafsirBadgePainter != null) {
      currentY += sectionGap;

      final badgeWidth = tafsirBadgePainter.width + (baseScale * 0.04);
      final badgeCenterY = currentY + (tafsirBadgeHeight / 2);
      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(width / 2, badgeCenterY),
          width: badgeWidth,
          height: tafsirBadgeHeight,
        ),
        Radius.circular(tafsirBadgeHeight / 2),
      );

      final badgePaint = Paint()..color = theme.accentColor.withValues(alpha: 0.12);
      canvas.drawRRect(badgeRect, badgePaint);
      tafsirBadgePainter.paint(
        canvas,
        Offset((width - tafsirBadgePainter.width) / 2, badgeCenterY - (tafsirBadgePainter.height / 2)),
      );

      currentY += tafsirBadgeHeight + (height * 0.008);
      tafsirTextPainter.paint(canvas, Offset((width - tafsirTextPainter.width) / 2, currentY));
      currentY += tafsirTextPainter.height;
    }

    // Draw Translation (if active)
    if (translationTextPainter != null) {
      currentY += sectionGap;

      if (hasTafsir && translationBadgePainter != null) {
        final badgeWidth = translationBadgePainter.width + (baseScale * 0.04);
        final badgeCenterY = currentY + (translationBadgeHeight / 2);
        final badgeRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(width / 2, badgeCenterY),
            width: badgeWidth,
            height: translationBadgeHeight,
          ),
          Radius.circular(translationBadgeHeight / 2),
        );

        final badgePaint = Paint()..color = theme.accentColor.withValues(alpha: 0.12);
        canvas.drawRRect(badgeRect, badgePaint);
        translationBadgePainter.paint(
          canvas,
          Offset((width - translationBadgePainter.width) / 2, badgeCenterY - (translationBadgePainter.height / 2)),
        );
        currentY += translationBadgeHeight + (height * 0.008);
      }

      translationTextPainter.paint(canvas, Offset((width - translationTextPainter.width) / 2, currentY));
    }
  }

  static void _drawFooterBrand(
    Canvas canvas,
    double width,
    double height,
    VideoProjectConfig config,
    double baseScale,
  ) {
    final theme = config.themePreset;
    final double iconFontSize = baseScale * 0.024;
    final double arabicFontSize = baseScale * 0.027;
    final double dotFontSize = baseScale * 0.022;
    final double englishFontSize = baseScale * 0.023;
    final double spacing = baseScale * 0.008;

    // 1. Icon Painter
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.auto_stories_rounded.codePoint),
        style: TextStyle(
          fontFamily: 'MaterialIcons',
          fontSize: iconFontSize,
          color: theme.accentColor.withValues(alpha: 0.85),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // 2. Arabic Name Painter
    final arabicPainter = TextPainter(
      text: TextSpan(
        text: 'تَـبَـتَّـلْ',
        style: TextStyle(
          fontFamily: 'Amiri',
          fontSize: arabicFontSize,
          fontWeight: FontWeight.bold,
          color: theme.secondaryTextColor.withValues(alpha: 0.85),
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();

    // 3. Dot Painter
    final dotPainter = TextPainter(
      text: TextSpan(
        text: '•',
        style: TextStyle(
          fontSize: dotFontSize,
          color: theme.accentColor.withValues(alpha: 0.6),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // 4. English Name Painter
    final englishPainter = TextPainter(
      text: TextSpan(
        text: 'Tabattal',
        style: TextStyle(
          fontSize: englishFontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: theme.secondaryTextColor.withValues(alpha: 0.85),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Total width of all items + spacings
    final double totalFooterWidth = iconPainter.width +
        spacing +
        arabicPainter.width +
        spacing +
        dotPainter.width +
        spacing +
        englishPainter.width;

    // Center Y position inside card
    final double cardMarginV = height * 0.05;
    final double bottomCenterY = config.aspectRatio == VideoAspectRatio.landscape16x9
        ? height - cardMarginV - (height * 0.038)
        : (config.aspectRatio == VideoAspectRatio.square1x1
            ? height - cardMarginV - (height * 0.038)
            : height - cardMarginV - (height * 0.028));

    // Visual RTL order: [Icon] -> [تَـبَـتَّـلْ] -> [•] -> [Tabattal]
    // Painted from left to right on canvas: Tabattal (left) -> Dot -> Arabic -> Icon (right)
    double startX = (width - totalFooterWidth) / 2;

    englishPainter.paint(canvas, Offset(startX, bottomCenterY - (englishPainter.height / 2)));
    startX += englishPainter.width + spacing;

    dotPainter.paint(canvas, Offset(startX, bottomCenterY - (dotPainter.height / 2)));
    startX += dotPainter.width + spacing;

    arabicPainter.paint(canvas, Offset(startX, bottomCenterY - (arabicPainter.height / 2)));
    startX += arabicPainter.width + spacing;

    iconPainter.paint(canvas, Offset(startX, bottomCenterY - (iconPainter.height / 2)));
  }
}
