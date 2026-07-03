import 'package:flutter/services.dart';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

class FontService {
  static final Set<String> _loadedFonts = {};
  static final Map<String, Future<void>> _loadingTasks = {};

  static Archive? _fontArchive;
  static bool _isInit = false;
  static Future<void>? _initFuture;

  static Future<void> _initArchive() async {
    if (_isInit) return;
    if (_initFuture != null) return _initFuture;

    _initFuture = () async {
      try {
        final zipBytes = await rootBundle.load('assets/fonts/quran_fonts.zip');
        _fontArchive = ZipDecoder().decodeBytes(zipBytes.buffer.asUint8List(), verify: false);
        _isInit = true;
      } catch (e) {
        debugPrint("Failed to load quran_fonts.zip: $e");
      }
    }();
    return _initFuture;
  }

  static Future<void> loadFontForPage(int pageNumber) async {
    final pageStr = pageNumber.toString().padLeft(3, '0');
    final fontName = 'QCF_P$pageStr';

    if (_loadedFonts.contains(fontName)) return;
    if (_loadingTasks.containsKey(fontName)) {
      await _loadingTasks[fontName];
      return;
    }

    final loadTask = () async {
      try {
        if (!_isInit) {
          await _initArchive();
        }

        if (_fontArchive == null) return;

        final fontFile = _fontArchive?.findFile('quran/$fontName.ttf');
        if (fontFile != null) {
          final fontData = fontFile.content as List<int>;
          final fontLoader = FontLoader(fontName);
          fontLoader.addFont(Future.value(ByteData.view(Uint8List.fromList(fontData).buffer)));
          await fontLoader.load();
          _loadedFonts.add(fontName);
        }
      } catch (e) {
        debugPrint("Failed to load font $fontName: $e");
      }
    }();

    _loadingTasks[fontName] = loadTask;
    await loadTask;
    _loadingTasks.remove(fontName);
  }
}
