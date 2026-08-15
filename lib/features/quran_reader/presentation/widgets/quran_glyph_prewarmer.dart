import 'package:flutter/material.dart';
import '../../../../core/services/font_service.dart';
import '../../bloc/quran/quran_page_cache.dart';

/// Pre-warms the GPU Glyph Atlas for a specific page's QCF font family.
///
/// Because each Quran page uses a distinct font file (QCF_P001.ttf - QCF_P604.ttf),
/// Flutter's GPU raster thread normally stalls for 20-30ms to build the GPU
/// Glyph Atlas the first time a new font family is drawn inside the viewport.
///
/// By rendering a tiny offscreen widget with the page's text during idle time,
/// Flutter Engine's raster thread builds the GPU Glyph Atlas BEFORE the user
/// swipes to that page — eliminating the raster thread VSYNC stall completely.
class QuranGlyphPrewarmer extends StatelessWidget {
  final int pageNumber;

  const QuranGlyphPrewarmer({super.key, required this.pageNumber});

  @override
  Widget build(BuildContext context) {
    final pageStr = pageNumber.toString().padLeft(3, '0');
    final fontName = 'QCF_P$pageStr';

    if (!FontService.isLoaded(fontName)) {
      return const SizedBox.shrink();
    }

    final cachedState = QuranPageCache.get(pageNumber);
    String sampleText = 'ﭑ ﭒ ﭓ ﭔ ﭕ ﭖ ﭗ ﭘ ﭙ ﭚ ﭛ ﭜ ﭝ ﭞ ﭟ ﭠ ﭡ ﭢ';
    if (cachedState != null && cachedState.lines.isNotEmpty) {
      final buffer = StringBuffer();
      for (final line in cachedState.lines) {
        for (final word in line.words) {
          final t = word.code;
          if (t.isNotEmpty) buffer.write('$t ');
        }
      }
      if (buffer.isNotEmpty) {
        sampleText = buffer.toString();
      }
    }

    return SizedBox(
      width: 1,
      height: 1,
      child: Text(
        sampleText,
        style: TextStyle(
          fontFamily: fontName,
          fontSize: 8,
          color: const Color(0x01000000),
        ),
      ),
    );
  }
}
