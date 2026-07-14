import 'package:equatable/equatable.dart';

class BookmarkState extends Equatable {
  final List<String> bookmarkedVerseKeys;

  const BookmarkState({this.bookmarkedVerseKeys = const []});

  bool isBookmarked(String verseKey) => bookmarkedVerseKeys.contains(verseKey);

  @override
  List<Object> get props => [bookmarkedVerseKeys];
}
