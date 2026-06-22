import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    on<DownloadTafsir>(_onDownloadTafsir, transformer: restartable());
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
      final prefs = await SharedPreferences.getInstance();
      int currentId = event.resourceId ?? prefs.getInt('tafsir_id') ?? 16;
      if (event.resourceId != null) {
        await prefs.setInt('tafsir_id', currentId);
      }

      final tafsir = await repository.getTafsir(event.verseKey, resourceId: currentId);
      if (tafsir.text.isEmpty || 
          tafsir.text == 'Tafsir not found.' || 
          tafsir.text.contains('تفسير هذه الآية غير متوفر') ||
          tafsir.text.contains('حدث خطأ')) {
         final progress = await repository.getTafsirDownloadProgress(currentId);
         if (progress < 1.0) {
           // Fetch the specific verse dynamically
           await repository.downloadSingleVerseTafsir(currentId, event.verseKey);
           final fetchedTafsir = await repository.getTafsir(event.verseKey, resourceId: currentId);
           
           if (fetchedTafsir.text.isNotEmpty && 
               fetchedTafsir.text != 'Tafsir not found.' && 
               !fetchedTafsir.text.contains('تفسير هذه الآية غير متوفر') &&
               !fetchedTafsir.text.contains('حدث خطأ')) {
             emit(TafsirLoaded(fetchedTafsir, isDownloading: true, downloadProgress: progress));
             // Start background download automatically
             add(DownloadTafsir(currentId));
           } else {
             emit(TafsirPartialDownloadError(currentId, progress));
           }
         } else {
           emit(const QuranOverlayError('Content temporarily unavailable'));
         }
      } else {
         final progress = await repository.getTafsirDownloadProgress(currentId);
         emit(TafsirLoaded(tafsir, isDownloading: progress < 1.0, downloadProgress: progress));
      }
    } catch (e) {
      emit(QuranOverlayError(_mapExceptionToMessage(e)));
    }
  }

  Future<void> _onDownloadTafsir(DownloadTafsir event, Emitter<QuranState> emit) async {
    try {
      final progress = await repository.getTafsirDownloadProgress(event.resourceId);
      if (progress == 1.0) {
        emit(TafsirDownloaded(event.resourceId));
        return;
      }

      // Emit initial progress to provide immediate UI feedback
      if (state is TafsirLoaded) {
        emit(TafsirLoaded((state as TafsirLoaded).tafsir, isDownloading: true, downloadProgress: progress));
      } else {
        emit(TafsirDownloading(event.resourceId, progress));
      }

      bool hasError = false;
      await emit.forEach<double>(
        repository.downloadTafsir(event.resourceId),
        onData: (streamProgress) {
          if (state is TafsirLoaded) {
            return TafsirLoaded((state as TafsirLoaded).tafsir, isDownloading: true, downloadProgress: streamProgress);
          }
          return TafsirDownloading(event.resourceId, streamProgress);
        },
        onError: (error, stackTrace) {
          hasError = true;
          return TafsirDownloadError(_mapExceptionToMessage(error), event.resourceId);
        },
      );

      if (!hasError) {
        if (state is TafsirLoaded) {
          emit(TafsirLoaded((state as TafsirLoaded).tafsir, isDownloading: false, downloadProgress: 1.0));
        } else {
          emit(TafsirDownloaded(event.resourceId));
        }
      }
    } catch (e) {
      emit(TafsirDownloadError(_mapExceptionToMessage(e), event.resourceId));
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
