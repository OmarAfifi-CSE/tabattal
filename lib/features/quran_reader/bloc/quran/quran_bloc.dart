import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/repositories/quran_repository.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/download_state.dart';
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

  String _failureMessage(Failure f) {
    if (f is NetworkFailure) return 'Network connection error. Please try again.';
    if (f is ServerFailure) return 'Failed to fetch content from the server. Please try again later.';
    if (f is CacheFailure) return 'Failed to load local data. Please try again.';
    return 'An unexpected error occurred.';
  }

  Future<void> _onLoadSurah(LoadSurah event, Emitter<QuranState> emit) async {
    emit(QuranLoading());
    final result = await repository.getLinesByPage(1); // Fallback or handle surah differently if needed offline
    result.fold(
      (f) => emit(QuranError(_failureMessage(f))),
      (lines) {
        _lastLoadedState = QuranLoaded(lines: lines, currentSurahId: event.surahId);
        emit(_lastLoadedState!);
      },
    );
  }

  Future<void> _onLoadPage(LoadPage event, Emitter<QuranState> emit) async {
    emit(QuranLoading());
    final result = await repository.getLinesByPage(event.pageNumber);
    result.fold(
      (f) => emit(QuranError(_failureMessage(f))),
      (lines) {
        _lastLoadedState = QuranLoaded(lines: lines, currentPage: event.pageNumber);
        emit(_lastLoadedState!);
      },
    );
  }

  Future<int> _resolveResourceId(int? eventResourceId, String? languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    int savedId = prefs.getInt('tafsir_id') ?? (languageCode == 'en' ? 169 : 16);
    
    if (languageCode == 'en' && ![169, 168, 817].contains(savedId)) {
      savedId = 169;
    } else if (languageCode == 'ar' && ![16, 14, 91, 15, 90, 93, 94].contains(savedId)) {
      savedId = 16;
    }

    int currentId = eventResourceId ?? savedId;
    if (currentId != prefs.getInt('tafsir_id')) {
      await prefs.setInt('tafsir_id', currentId);
    }
    return currentId;
  }

  Future<void> _handleTafsirMiss(String verseKey, int currentId, Emitter<QuranState> emit) async {
    final progressResult = await repository.getTafsirDownloadProgress(currentId);
    final progress = progressResult.getOrNull() ?? 0.0;
    
    // Always try to fetch via API backward-lookup, regardless of progress.
    // The local DB may be missing grouped verses that require fetching a previous verse.
    await repository.downloadSingleVerseTafsir(currentId, verseKey);
    
    // Re-try local lookup — getTafsirForVerse uses backward search so it finds grouped tafsirs.
    final retry = await repository.getTafsir(verseKey, resourceId: currentId);
    
    retry.fold(
      (f) {
        if (progress < 1.0) {
          emit(TafsirPartialDownloadError(currentId, progress));
        } else {
          emit(const QuranOverlayError('Content temporarily unavailable'));
        }
      },
      (tafsir) {
        emit(TafsirLoaded(tafsir, isDownloading: progress < 1.0, downloadProgress: progress));
        if (progress < 1.0) {
          add(DownloadTafsir(currentId));
        }
      },
    );
  }

  Future<void> _onFetchTafsir(FetchTafsir event, Emitter<QuranState> emit) async {
    emit(QuranOverlayLoading());
    final currentId = await _resolveResourceId(event.resourceId, event.languageCode);
    final result = await repository.getTafsir(event.verseKey, resourceId: currentId);
    
    await result.fold(
      (f) async => await _handleTafsirMiss(event.verseKey, currentId, emit),
      (tafsir) async {
        final progressResult = await repository.getTafsirDownloadProgress(currentId);
        final progress = progressResult.getOrNull() ?? 0.0;
        emit(TafsirLoaded(tafsir, isDownloading: progress < 1.0, downloadProgress: progress));
      },
    );
  }

  Future<void> _onDownloadTafsir(DownloadTafsir event, Emitter<QuranState> emit) async {
    final progressResult = await repository.getTafsirDownloadProgress(event.resourceId);
    final initialProgress = progressResult.getOrNull() ?? 0.0;
    
    if (initialProgress == 1.0) {
      emit(TafsirDownloaded(event.resourceId));
      return;
    }

    // Emit initial progress to provide immediate UI feedback
    if (state is TafsirLoaded) {
      emit(TafsirLoaded((state as TafsirLoaded).tafsir, isDownloading: true, downloadProgress: initialProgress));
    } else {
      emit(TafsirDownloading(event.resourceId, initialProgress));
    }

    await emit.forEach<DownloadState>(
      repository.downloadTafsir(event.resourceId),
      onData: (downloadState) {
        switch (downloadState) {
          case Progressing(:final progress):
            if (state is TafsirLoaded) {
              return TafsirLoaded((state as TafsirLoaded).tafsir, isDownloading: true, downloadProgress: progress);
            }
            return TafsirDownloading(event.resourceId, progress);
          case Completed():
            if (state is TafsirLoaded) {
              return TafsirLoaded((state as TafsirLoaded).tafsir, isDownloading: false, downloadProgress: 1.0);
            }
            return TafsirDownloaded(event.resourceId);
          case Failed(:final failure):
            return TafsirDownloadError(_failureMessage(failure), event.resourceId);
        }
      },
      onError: (error, stackTrace) => TafsirDownloadError('Unexpected Error', event.resourceId),
    );
  }

  Future<void> _onFetchTranslation(FetchTranslation event, Emitter<QuranState> emit) async {
    emit(QuranOverlayLoading());
    final result = await repository.getTranslation(event.verseKey);
    result.fold(
      (f) => emit(const QuranOverlayError('Content temporarily unavailable')),
      (translation) => emit(TranslationLoaded(translation)),
    );
  }
}




