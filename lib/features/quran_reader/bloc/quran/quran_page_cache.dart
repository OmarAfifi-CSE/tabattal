import 'quran_state.dart';

/// App-wide LRU cache for already-loaded Quran page data.
/// Keeps the last [_maxSize] pages so re-visiting a page is instant
/// and never triggers a [QuranLoading] state again.
class QuranPageCache {
  QuranPageCache._();

  static final Map<int, QuranLoaded> _cache = {};
  static const int _maxSize = 20;

  // Persists max line widths across widget recreations to avoid re-running
  // TextPainter measurements (expensive) every time a page widget is rebuilt.
  // Since TextPainter cannot run on a background isolate, this is the only
  // way to guarantee the computation never blocks the UI thread twice.
  static final Map<int, double> _lineWidthCache = {};

  static QuranLoaded? get(int pageNumber) => _cache[pageNumber];

  static void put(int pageNumber, QuranLoaded state) {
    // Move to end (most-recently-used) if already present.
    _cache.remove(pageNumber);
    _cache[pageNumber] = state;
    // Evict the least-recently-used entry when over capacity.
    if (_cache.length > _maxSize) {
      _cache.remove(_cache.keys.first);
    }
  }

  static double? getCachedLineWidth(int pageNumber) =>
      _lineWidthCache[pageNumber];

  static void cacheLineWidth(int pageNumber, double width) =>
      _lineWidthCache[pageNumber] = width;

  /// Clears the entire cache (e.g. after a settings change that affects rendering).
  static void clear() {
    _cache.clear();
    _lineWidthCache.clear();
  }
}
