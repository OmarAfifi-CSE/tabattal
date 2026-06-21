import 'package:equatable/equatable.dart';

abstract class QuranEvent extends Equatable {
  const QuranEvent();

  @override
  List<Object> get props => [];
}

class LoadSurah extends QuranEvent {
  final int surahId;

  const LoadSurah(this.surahId);

  @override
  List<Object> get props => [surahId];
}

class LoadPage extends QuranEvent {
  final int pageNumber;

  const LoadPage(this.pageNumber);

  @override
  List<Object> get props => [pageNumber];
}

class FetchTafsir extends QuranEvent {
  final String verseKey;
  final int resourceId;

  const FetchTafsir(this.verseKey, {this.resourceId = 16});

  @override
  List<Object> get props => [verseKey, resourceId];
}

class FetchTranslation extends QuranEvent {
  final String verseKey;

  const FetchTranslation(this.verseKey);

  @override
  List<Object> get props => [verseKey];
}
