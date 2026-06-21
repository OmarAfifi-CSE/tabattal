import 'package:equatable/equatable.dart';
import '../../../data/models/verse_model.dart';
import '../../../data/models/tafsir_model.dart';
import '../../../data/models/translation_model.dart';

abstract class QuranState extends Equatable {
  const QuranState();
  
  @override
  List<Object?> get props => [];
}

class QuranInitial extends QuranState {}

class QuranLoading extends QuranState {}

class QuranLoaded extends QuranState {
  final List<LineData> lines;
  // We can keep track of currently viewed surah/juz or page in the state if needed
  final int? currentSurahId;
  final int? currentPage;

  const QuranLoaded({required this.lines, this.currentSurahId, this.currentPage});

  @override
  List<Object?> get props => [lines, currentSurahId, currentPage];
}

class QuranError extends QuranState {
  final String message;

  const QuranError(this.message);

  @override
  List<Object> get props => [message];
}

// Separate states for Tafsir/Translation overlays
class QuranOverlayLoading extends QuranState {}

class TafsirLoaded extends QuranState {
  final TafsirModel tafsir;

  const TafsirLoaded(this.tafsir);

  @override
  List<Object> get props => [tafsir];
}

class TranslationLoaded extends QuranState {
  final TranslationModel translation;

  const TranslationLoaded(this.translation);

  @override
  List<Object> get props => [translation];
}

class QuranOverlayError extends QuranState {
  final String message;

  const QuranOverlayError(this.message);

  @override
  List<Object> get props => [message];
}
