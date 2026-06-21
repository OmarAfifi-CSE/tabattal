import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bookmark_event.dart';
import 'bookmark_state.dart';

class BookmarkBloc extends Bloc<BookmarkEvent, BookmarkState> {
  static const String _bookmarksKey = 'bookmarked_verses';

  BookmarkBloc() : super(const BookmarkState()) {
    on<LoadBookmarks>(_onLoadBookmarks);
    on<ToggleBookmark>(_onToggleBookmark);
  }

  Future<void> _onLoadBookmarks(LoadBookmarks event, Emitter<BookmarkState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList(_bookmarksKey) ?? [];
    emit(BookmarkState(bookmarkedVerseKeys: bookmarks));
  }

  Future<void> _onToggleBookmark(ToggleBookmark event, Emitter<BookmarkState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    final currentBookmarks = List<String>.from(state.bookmarkedVerseKeys);

    if (currentBookmarks.contains(event.verseKey)) {
      currentBookmarks.remove(event.verseKey);
    } else {
      currentBookmarks.add(event.verseKey);
    }

    await prefs.setStringList(_bookmarksKey, currentBookmarks);
    emit(BookmarkState(bookmarkedVerseKeys: currentBookmarks));
  }
}
