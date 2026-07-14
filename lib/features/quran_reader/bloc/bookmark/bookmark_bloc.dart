import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/bookmark_repository.dart';
import 'bookmark_event.dart';
import 'bookmark_state.dart';

class BookmarkBloc extends Bloc<BookmarkEvent, BookmarkState> {
  final BookmarkRepository repository;

  BookmarkBloc({required this.repository}) : super(const BookmarkState()) {
    on<LoadBookmarks>(_onLoadBookmarks);
    on<ToggleBookmark>(_onToggleBookmark);
  }

  Future<void> _onLoadBookmarks(LoadBookmarks event, Emitter<BookmarkState> emit) async {
    final bookmarks = await repository.loadBookmarks();
    emit(BookmarkState(bookmarkedVerseKeys: bookmarks));
  }

  Future<void> _onToggleBookmark(ToggleBookmark event, Emitter<BookmarkState> emit) async {
    final bookmarks = await repository.toggle(event.verseKey);
    emit(BookmarkState(bookmarkedVerseKeys: bookmarks));
  }
}



