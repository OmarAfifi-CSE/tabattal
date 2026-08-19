import 'quran_state.dart';

/// App-wide LRU cache for already-loaded Quran page data.
/// Keeps the last [_maxSize] pages so re-visiting a page is instant
/// and never triggers a [QuranLoading] state again.
class QuranPageCache {
  QuranPageCache._();

  static const int _maxSize = 30;

  static final Map<int, QuranLoaded> _cache = {};
  static final List<int> _lruOrder = [];

  static QuranLoaded? get(int pageNumber) {
    final state = _cache[pageNumber];
    if (state != null) _touch(pageNumber);
    return state;
  }

  static void put(int pageNumber, QuranLoaded state) {
    if (_cache.containsKey(pageNumber)) {
      _touch(pageNumber);
      return;
    }
    _cache[pageNumber] = state;
    _lruOrder.add(pageNumber);
    while (_lruOrder.length > _maxSize) {
      final evicted = _lruOrder.removeAt(0);
      _cache.remove(evicted);
    }
  }

  static void _touch(int pageNumber) {
    _lruOrder.remove(pageNumber);
    _lruOrder.add(pageNumber);
  }

  static final Map<int, double> _lineWidthCache = {};

  static double? getCachedLineWidth(int pageNumber) =>
      _lineWidthCache[pageNumber];

  static void cacheLineWidth(int pageNumber, double width) =>
      _lineWidthCache[pageNumber] = width;

  /// Clears the entire cache (e.g. after a settings change that affects rendering).
  static void clear() {
    _cache.clear();
    _lruOrder.clear();
    _lineWidthCache.clear();
  }
}