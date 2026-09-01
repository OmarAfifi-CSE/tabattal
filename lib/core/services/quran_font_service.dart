import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Central Quran Font Management Service with On-Demand Streaming.
///
/// - On Mobile / Desktop: All 604 fonts are statically bundled and natively
///   registered at compile time. Operations here are zero-cost NO-OPs.
///
/// - On Web: Prevents downloading 134MB of fonts at boot time. Only the 4 base
///   fonts load at startup (100/100 performance score), and page fonts (~240KB each)
///   are dynamically loaded via [FontLoader] as the user browses the Mushaf.
class QuranFontService {
  static final Set<int> _loadedPages = <int>{};
  static final Map<int, Future<void>> _inFlightLoads = <int, Future<void>>{};
  static final Dio _dio = Dio();

  /// Checks whether the font for [pageNumber] is ready in Flutter's font manager.
  static bool isPageFontLoaded(int pageNumber) {
    if (!kIsWeb) return true;
    if (pageNumber < 1 || pageNumber > 604) return true;
    return _loadedPages.contains(pageNumber);
  }

  /// Dynamically loads and registers the font for [pageNumber] into Flutter's engine.
  static Future<void> ensurePageFontLoaded(int pageNumber) async {
    if (!kIsWeb || pageNumber < 1 || pageNumber > 604) return;
    if (_loadedPages.contains(pageNumber)) return;

    if (_inFlightLoads.containsKey(pageNumber)) {
      return _inFlightLoads[pageNumber]!;
    }

    final future = _loadFont(pageNumber);
    _inFlightLoads[pageNumber] = future;
    try {
      await future;
    } finally {
      _inFlightLoads.remove(pageNumber);
    }
  }

  static Future<void> _loadFont(int pageNumber) async {
    final pageStr = pageNumber.toString().padLeft(3, '0');
    final fontFamily = 'QCF_P$pageStr';
    final primaryAssetPath = 'assets/fonts/quran/QCF_P$pageStr.ttf';
    final fallbackAssetPath = 'assets/assets/fonts/quran/QCF_P$pageStr.ttf';

    try {
      ByteData? byteData;

      // 1. Try rootBundle first
      try {
        byteData = await rootBundle.load(primaryAssetPath);
      } catch (_) {
        try {
          byteData = await rootBundle.load(fallbackAssetPath);
        } catch (_) {}
      }

      // 2. If rootBundle is unavailable, fetch directly via HTTP
      if (byteData == null && kIsWeb) {
        final candidateUrls = [
          'assets/fonts/quran/QCF_P$pageStr.ttf',
          'assets/assets/fonts/quran/QCF_P$pageStr.ttf',
          'app/assets/fonts/quran/QCF_P$pageStr.ttf',
        ];

        for (final url in candidateUrls) {
          try {
            final response = await _dio.get<List<int>>(
              url,
              options: Options(responseType: ResponseType.bytes),
            );
            if (response.statusCode == 200 && response.data != null) {
              final uint8List = Uint8List.fromList(response.data!);
              byteData = ByteData.view(uint8List.buffer);
              break;
            }
          } catch (_) {}
        }
      }

      if (byteData != null) {
        final fontLoader = FontLoader(fontFamily);
        fontLoader.addFont(Future.value(byteData));
        await fontLoader.load();
        _loadedPages.add(pageNumber);
      } else {
        debugPrint('QuranFontService: Could not retrieve font bytes for $fontFamily');
      }
    } catch (e) {
      debugPrint('QuranFontService: Error loading font for page $pageNumber: $e');
    }
  }

  /// Non-blocking background prewarming for adjacent pages around [currentPage].
  static void prewarmAround(int currentPage, {int distance = 3}) {
    if (!kIsWeb) return;
    for (int i = 1; i <= distance; i++) {
      final next = currentPage + i;
      final prev = currentPage - i;
      if (next <= 604 && !_loadedPages.contains(next) && !_inFlightLoads.containsKey(next)) {
        ensurePageFontLoaded(next);
      }
      if (prev >= 1 && !_loadedPages.contains(prev) && !_inFlightLoads.containsKey(prev)) {
        ensurePageFontLoaded(prev);
      }
    }
  }
}
