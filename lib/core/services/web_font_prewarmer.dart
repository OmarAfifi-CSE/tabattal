import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Lightweight background font prewarmer specifically for Flutter Web.
///
/// On Mobile / Desktop (where all 604 fonts reside locally in the app bundle),
/// every operation is a pure NO-OP with zero overhead.
///
/// On Web, this service prefetches upcoming Quran page fonts in the background
/// to warm up the browser's HTTP cache and prevent Flash of Unstyled Text (FOUT).
class WebFontPrewarmer {
  static final Set<int> _prewarmedPages = <int>{1, 2};

  /// Prewarms a specific Quran page font if running on Web.
  static void prewarmPage(int pageNumber) {
    if (!kIsWeb || pageNumber < 1 || pageNumber > 604) return;
    if (_prewarmedPages.contains(pageNumber)) return;
    _prewarmedPages.add(pageNumber);

    final pageStr = pageNumber.toString().padLeft(3, '0');
    final assetPath = 'assets/fonts/quran/QCF_P$pageStr.ttf';

    // Non-blocking background fetch into browser HTTP cache
    rootBundle.load(assetPath).then((_) {}, onError: (_) {});
  }

  /// Prewarms neighboring page fonts around [currentPage] within [distance].
  static void prewarmAround(int currentPage, {int distance = 3}) {
    if (!kIsWeb) return;
    for (int i = 1; i <= distance; i++) {
      final next = currentPage + i;
      final prev = currentPage - i;
      if (next <= 604) prewarmPage(next);
      if (prev >= 1) prewarmPage(prev);
    }
  }

  /// Returns true if the page font is known to be prewarmed or if running natively.
  static bool isPageReady(int pageNumber) {
    if (!kIsWeb) return true;
    return _prewarmedPages.contains(pageNumber);
  }
}
