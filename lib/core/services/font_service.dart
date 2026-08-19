import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:archive/archive.dart';

class FontService {
  static final Set<String> _loadedFonts = {};
  static final Map<String, Future<void>> _loadingTasks = {};

  static final Map<int, Map<String, Uint8List>> _extractedPartFonts = {};
  static final Map<int, Future<void>> _initFutures = {};

  /// Preloads, decompresses, and registers ALL 604 Quran fonts into the Flutter engine.
  /// Runs immediately at startup in background worker isolates so every page is 100% in RAM.
  static Future<void> preloadAllFonts() async {
    for (int part = 1; part <= 3; part++) {
      if (!_extractedPartFonts.containsKey(part)) {
        await _initArchive(part);
      }

      final fontMap = _extractedPartFonts[part];
      if (fontMap == null) continue;

      for (final entry in fontMap.entries) {
        final fontName = entry.key;
        if (_loadedFonts.contains(fontName)) continue;
        final fontBytes = entry.value;

        try {
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
        } catch (e) {
          debugPrint("Failed to register font $fontName: $e");
        }
      }
      loadedFontsNotifier.value = Set<String>.unmodifiable(_loadedFonts);
    }
  }

  /// Preloads and extracts all font archives in background worker isolates.
  /// Runs asynchronously at startup so rootBundle disk loading never blocks active scrolling.
  static void preloadArchivesInBackground() {
    unawaited(preloadAllFonts());
  }

  /// Reactive notifier that updates whenever a new QCF font is loaded into the Flutter engine.
  static final ValueNotifier<Set<String>> loadedFontsNotifier =
      ValueNotifier<Set<String>>({});

  static int _getPartIndex(int pageNumber) {
    if (pageNumber <= 200) return 1;
    if (pageNumber <= 400) return 2;
    return 3;
  }

  /// Extracts all font files from a zip archive in a background worker isolate.
  static Map<String, Uint8List> _decodeArchiveInWorker(Uint8List rawBytes) {
    final archive = ZipDecoder().decodeBytes(rawBytes, verify: false);
    final map = <String, Uint8List>{};
    for (final file in archive.files) {
      if (file.isFile && file.name.endsWith('.ttf')) {
        final fontName = file.name.split('/').last.replaceAll('.ttf', '');
        map[fontName] = file.content;
      }
    }
    return map;
  }

  static Future<void> _initArchive(int part) async {
    if (_extractedPartFonts.containsKey(part)) return;
    if (_initFutures.containsKey(part)) return _initFutures[part];

    final future = () async {
      try {
        final zipBytes = await rootBundle.load(
          'assets/fonts/quran_fonts/quran_fonts_part$part.zip',
        );
        final rawUint8 = zipBytes.buffer.asUint8List();

        final Map<String, Uint8List> extractedFonts;
        if (kIsWeb) {
          extractedFonts = _decodeArchiveInWorker(rawUint8);
        } else {
          // Offload 40MB zip decompression completely to a background Isolate
          // so the UI Root Isolate stays at locked 120 FPS / 60 FPS.
          extractedFonts = await Isolate.run(
            () => _decodeArchiveInWorker(rawUint8),
          );
        }

        _extractedPartFonts[part] = extractedFonts;
      } catch (e) {
        debugPrint("Failed to load or extract quran_fonts_part$part.zip: $e");
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
        if (!_extractedPartFonts.containsKey(part)) {
          await _initArchive(part);
        }

        final fontMap = _extractedPartFonts[part];
        if (fontMap == null) return;

        final fontBytes = fontMap[fontName];
        if (fontBytes != null) {
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
          loadedFontsNotifier.value = Set<String>.unmodifiable(_loadedFonts);
        }
      } catch (e) {
        debugPrint("Failed to load font $fontName: $e");
      }
    }();

    _loadingTasks[fontName] = loadTask;
    await loadTask;
    _loadingTasks.remove(fontName);
  }

  /// Concurrently preloads and registers fonts for pages within [window] of [currentPage].
  static Future<void> preloadSurroundingFonts(
    int currentPage, {
    int window = 5,
  }) async {
    final start = (currentPage - window).clamp(1, 604);
    final end = (currentPage + window).clamp(1, 604);
    final pages = [for (int p = start; p <= end; p++) p];
    await Future.wait(pages.map((p) => loadFontForPage(p)));
  }
}
