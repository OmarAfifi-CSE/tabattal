import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import '../../../domain/repositories/quran_repository.dart';
import '../../../../../core/error/exceptions.dart';
import 'quran_event.dart';
import 'quran_state.dart';

class QuranBloc extends Bloc<QuranEvent, QuranState> {
  final QuranRepository repository;
  
  QuranLoaded? _lastLoadedState;

  QuranBloc({required this.repository}) : super(QuranInitial()) {
    on<LoadSurah>(_onLoadSurah, transformer: restartable());
    on<LoadPage>(_onLoadPage, transformer: restartable());
    on<FetchTafsir>(_onFetchTafsir, transformer: restartable());
    on<FetchTranslation>(_onFetchTranslation, transformer: restartable());
  }

  String _mapExceptionToMessage(Object e) {
    if (e is NetworkException) return e.message;
    if (e is ServerException) return e.message;
    return 'Unexpected Error Occurred';
  }

  Future<void> _onLoadSurah(LoadSurah event, Emitter<QuranState> emit) async {
    emit(QuranLoading());
    try {
      final lines = await repository.getLinesByPage(1); // Fallback or handle surah differently if needed offline
      _lastLoadedState = QuranLoaded(lines: lines, currentSurahId: event.surahId);
      emit(_lastLoadedState!);
    } catch (e) {
      emit(QuranError(_mapExceptionToMessage(e)));
    }
  }

  Future<void> _onLoadPage(LoadPage event, Emitter<QuranState> emit) async {
    emit(QuranLoading());
    try {
      final lines = await repository.getLinesByPage(event.pageNumber);
      _lastLoadedState = QuranLoaded(lines: lines, currentPage: event.pageNumber);
      emit(_lastLoadedState!);
    } catch (e) {
      emit(QuranError(_mapExceptionToMessage(e)));
    }
  }

  Future<void> _onFetchTafsir(FetchTafsir event, Emitter<QuranState> emit) async {
    emit(QuranOverlayLoading());
    try {
      final tafsir = await repository.getTafsir(event.verseKey, resourceId: event.resourceId);
      if (tafsir.text.isEmpty || tafsir.text == 'Tafsir not found.') {
         emit(const QuranOverlayError('Content temporarily unavailable'));
      } else {
         emit(TafsirLoaded(tafsir));
      }
    } catch (e) {
      emit(QuranOverlayError(_mapExceptionToMessage(e)));
    }
  }

  Future<void> _onFetchTranslation(FetchTranslation event, Emitter<QuranState> emit) async {
    emit(QuranOverlayLoading());
    try {
      final translation = await repository.getTranslation(event.verseKey);
      if (translation.text.isEmpty || translation.text == 'Translation not found.') {
         emit(const QuranOverlayError('Content temporarily unavailable'));
      } else {
         emit(TranslationLoaded(translation));
      }
    } catch (e) {
      emit(QuranOverlayError(_mapExceptionToMessage(e)));
    }
  }
}
