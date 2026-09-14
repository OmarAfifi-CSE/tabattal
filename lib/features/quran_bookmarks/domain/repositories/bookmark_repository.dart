import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

abstract class BookmarkRepository {
  Future<List<String>> loadBookmarks();
  Future<List<String>> toggle(String verseKey);
}

class BookmarkRepositoryImpl implements BookmarkRepository {
  static const String _bookmarksKey = 'quran_bookmarks';

  final SharedPreferences _prefs;
  Future<void> _lock = Future.value();

  BookmarkRepositoryImpl(this._prefs);

  @override
  Future<List<String>> loadBookmarks() async {
    return _prefs.getStringList(_bookmarksKey) ?? [];
  }

  @override
  Future<List<String>> toggle(String verseKey) async {
    final completer = Completer<List<String>>();
    final previousLock = _lock;
    _lock = completer.future.then((_) {}).catchError((_) {});

    try {
      await previousLock;
      final bookmarks = List<String>.from(await loadBookmarks());
      if (bookmarks.contains(verseKey)) {
        bookmarks.remove(verseKey);
      } else {
        bookmarks.add(verseKey);
      }
      await _prefs.setStringList(_bookmarksKey, bookmarks);
      completer.complete(bookmarks);
      return bookmarks;
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    }
  }
}
