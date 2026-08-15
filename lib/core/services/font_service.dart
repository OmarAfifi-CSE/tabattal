import 'package:flutter/services.dart';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

class FontService {
  static final Set<String> _loadedFonts = {};
  static final Map<String, Future<void>> _loadingTasks = {};

  static final Map<int, Archive> _archives = {};
  static final Map<int, Future<void>> _initFutures = {};

  static int _getPartIndex(int pageNumber) {
    if (pageNumber <= 200) return 1;
    if (pageNumber <= 400) return 2;
    return 3;
  }

  static Future<void> _initArchive(int part) async {
    if (_archives.containsKey(part)) return;
    if (_initFutures.containsKey(part)) return _initFutures[part];

    final future = () async {
      try {
        final zipBytes = await rootBundle.load('assets/fonts/quran_fonts/quran_fonts_part$part.zip');
        final archive = ZipDecoder().decodeBytes(
          zipBytes.buffer.asUint8List(),
          verify: false,
        );
        _archives[part] = archive;
      } catch (e) {
        debugPrint("Failed to load quran_fonts_part$part.zip: $e");
      }
    }();

    _initFutures[part] = future;
    await future;
    _initFutures.remove(part);
  }

  static bool isLoaded(String fontName) => _loadedFonts.contains(fontName);

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
        final part = _getPartIndex(pageNumber);
        if (!_archives.containsKey(part)) {
          await _initArchive(part);
        }

        final archive = _archives[part];
        if (archive == null) return;

        final fontFile = archive.findFile('quran/$fontName.ttf');
        if (fontFile != null) {
          final fontBytes = fontFile.content;
          final fontLoader = FontLoader(fontName);
          fontLoader.addFont(
            Future.value(
              ByteData.view(
                fontBytes.buffer,
                fontBytes.offsetInBytes,
                fontBytes.lengthInBytes,
              ),
            ),
          );
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
