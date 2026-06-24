import 'package:flutter/services.dart';

class FontService {
  static final Set<String> _loadedFonts = {};

  static Future<void> loadFontForPage(int pageNumber) async {
    final pageStr = pageNumber.toString().padLeft(3, '0');
    final fontName = 'QCF_P$pageStr';

    if (_loadedFonts.contains(fontName)) return;

    try {
      final fontLoader = FontLoader(fontName);
      fontLoader.addFont(rootBundle.load('assets/fonts/v1/QCF_P$pageStr.ttf'));
      await fontLoader.load();
      _loadedFonts.add(fontName);
    } catch (e) {
      // Failed to load font
    }
  }
}
