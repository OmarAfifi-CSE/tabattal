import 'package:flutter/material.dart';
import '../../../../core/services/font_service.dart';

/// Pre-warms the GPU Glyph Atlas for a specific page's QCF font family.
///
/// Because each Quran page uses a distinct font file (QCF_P001.ttf - QCF_P604.ttf),
/// Flutter's GPU raster thread normally stalls for 20-30ms to build the GPU
/// Glyph Atlas the first time a new font family is drawn inside the viewport.
///
/// By reactively listening to [FontService.loadedFontsNotifier] and rendering
/// an offscreen glyph sample inside an isolated [RepaintBoundary], Flutter Engine's
/// raster thread builds the GPU Glyph Atlas BEFORE the user swipes to that page —
/// eliminating the raster thread VSYNC stall completely.
class QuranGlyphPrewarmer extends StatelessWidget {
  final int pageNumber;

  const QuranGlyphPrewarmer({super.key, required this.pageNumber});

  static const String _sample = 'ﭑ ﭒ ﭓ ﭔ ﭕ ﭖ ﭗ ﭘ';

  @override
  Widget build(BuildContext context) {
    final pageStr = pageNumber.toString().padLeft(3, '0');
    final fontName = 'QCF_P$pageStr';

    return ValueListenableBuilder<Set<String>>(
      valueListenable: FontService.loadedFontsNotifier,
      builder: (context, loadedFonts, _) {
        if (!loadedFonts.contains(fontName)) {
          return const SizedBox.shrink();
        }

        return RepaintBoundary(
          child: SizedBox(
            width: 1,
            height: 1,
            child: Text(
              _sample,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontFamily: fontName,
                fontSize: 8,
                color: const Color(0x01000000),
              ),
            ),
          ),
        );
      },
    );
  }
}

