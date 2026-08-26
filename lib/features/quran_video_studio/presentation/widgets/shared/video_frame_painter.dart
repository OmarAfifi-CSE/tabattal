import 'package:flutter/material.dart';
import '../../../../quran_reader/data/models/verse_model.dart';
import '../../../data/services/canvas_overlay_generator.dart';
import '../../../domain/entities/video_project_config.dart';
import '../../../domain/entities/word_timing_segment.dart';

/// Full-frame painter for single-pass rendering.
class VideoFramePainter extends CustomPainter {
  final VerseModel? verse;
  final VideoProjectConfig config;
  final int pageNumber;
  final String? tafsirText;
  final String? translationText;
  final bool includeBackground;
  final int playbackPositionMs;
  final List<WordTimingSegment>? wordTimings;
  final int? overrideLineIndex;

  const VideoFramePainter({
    required this.verse,
    required this.config,
    required this.pageNumber,
    this.tafsirText,
    this.translationText,
    this.includeBackground = true,
    this.playbackPositionMs = 0,
    this.wordTimings,
    this.overrideLineIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (verse == null) return;
    CanvasOverlayGenerator.paintFrame(
      canvas,
      size,
      verse: verse!,
      config: config,
      pageNumber: pageNumber,
      tafsirText: tafsirText ?? verse?.tafsir,
      translationText: translationText ?? verse?.translation,
      includeBackground: includeBackground,
      playbackPositionMs: playbackPositionMs,
      wordTimings: wordTimings,
      overrideLineIndex: overrideLineIndex,
    );
  }

  @override
  bool shouldRepaint(covariant VideoFramePainter oldDelegate) {
    return oldDelegate.verse != verse ||
        oldDelegate.config != config ||
        oldDelegate.pageNumber != pageNumber ||
        oldDelegate.tafsirText != tafsirText ||
        oldDelegate.translationText != translationText ||
        oldDelegate.includeBackground != includeBackground ||
        oldDelegate.playbackPositionMs != playbackPositionMs ||
        oldDelegate.wordTimings != wordTimings ||
        oldDelegate.overrideLineIndex != overrideLineIndex;
  }
}

/// Renders ONLY the static frame elements (Background, Card, Ornaments, Header Badges, Footer Brand).
/// This layer never fades or flickers during verse transitions.
class VideoStaticFramePainter extends CustomPainter {
  final VideoProjectConfig config;
  final VerseModel? verse;
  final bool includeBackground;

  const VideoStaticFramePainter({
    required this.config,
    this.verse,
    this.includeBackground = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    CanvasOverlayGenerator.paintStaticDecoration(
      canvas,
      size,
      config: config,
      verse: verse,
      includeBackground: includeBackground,
    );
  }

  @override
  bool shouldRepaint(covariant VideoStaticFramePainter oldDelegate) {
    return oldDelegate.config != config ||
        oldDelegate.verse != verse ||
        oldDelegate.includeBackground != includeBackground;
  }
}


/// Renders ONLY the dynamic center content (Verse text, Tafsir, Translation) for smooth cross-fading and word tracking.
class VideoDynamicContentPainter extends CustomPainter {
  final VerseModel? verse;
  final VideoProjectConfig config;
  final int pageNumber;
  final String? tafsirText;
  final String? translationText;
  final int playbackPositionMs;
  final List<WordTimingSegment>? wordTimings;
  final int? overrideLineIndex;

  const VideoDynamicContentPainter({
    required this.verse,
    required this.config,
    required this.pageNumber,
    this.tafsirText,
    this.translationText,
    this.playbackPositionMs = 0,
    this.wordTimings,
    this.overrideLineIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (verse == null) return;
    CanvasOverlayGenerator.paintDynamicContent(
      canvas,
      size,
      verse: verse!,
      config: config,
      pageNumber: pageNumber,
      tafsirText: tafsirText ?? verse?.tafsir,
      translationText: translationText ?? verse?.translation,
      playbackPositionMs: playbackPositionMs,
      wordTimings: wordTimings,
      overrideLineIndex: overrideLineIndex,
    );
  }

  @override
  bool shouldRepaint(covariant VideoDynamicContentPainter oldDelegate) {
    return oldDelegate.verse != verse ||
        oldDelegate.config != config ||
        oldDelegate.pageNumber != pageNumber ||
        oldDelegate.tafsirText != tafsirText ||
        oldDelegate.translationText != translationText ||
        oldDelegate.playbackPositionMs != playbackPositionMs ||
        oldDelegate.wordTimings != wordTimings ||
        oldDelegate.overrideLineIndex != overrideLineIndex;
  }
}

