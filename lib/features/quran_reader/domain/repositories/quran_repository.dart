import 'dart:async';
import '../../../../core/error/either.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/constants/quran_constants.dart';
import '../../../../core/network/tafsir_download_service.dart';
import '../entities/download_state.dart';
import '../../data/datasources/quran_local_data_source.dart';
import '../../data/datasources/quran_remote_data_source.dart';
import '../../data/models/verse_model.dart';
import '../../data/models/tafsir_model.dart';
import '../../data/models/translation_model.dart';
import '../../data/models/search_verse_model.dart';

abstract class QuranRepository {
  Future<Either<Failure, List<LineData>>> getLinesByPage(int pageNumber);
  Future<Either<Failure, TafsirModel>> getTafsir(String verseKey, {int resourceId = 16});
  Future<Either<Failure, TranslationModel>> getTranslation(String verseKey, {int resourceId = 20});
  Future<Either<Failure, List<TafsirModel>>> getTafsirsByChapter(int chapterId, {int resourceId = 16, int page = 1});
  Future<Either<Failure, List<TranslationModel>>> getTranslationsByChapter(int chapterId, {int resourceId = 20});
  Future<Either<Failure, List<SearchVerseModel>>> searchQuran(String query);
  Future<Either<Failure, List<Map<String, dynamic>>>> getSurahsIndex();
  Future<Either<Failure, List<SearchVerseModel>>> getVersesBySurah(int surahId);
  Future<Either<Failure, void>> downloadSingleVerseTafsir(int resourceId, String verseKey);
  Stream<DownloadState> downloadTafsir(int resourceId);
  Future<Either<Failure, double>> getTafsirDownloadProgress(int resourceId);
}

class QuranRepositoryImpl implements QuranRepository {
  final QuranLocalDataSource localDataSource;
  final QuranRemoteDataSource remoteDataSource;
  final TafsirDownloadService tafsirDownloadService;

  QuranRepositoryImpl({
    required this.localDataSource, 
    required this.remoteDataSource,
    required this.tafsirDownloadService,
  });

  Future<Either<Failure, T>> _execute<T>(Future<T> Function() action) async {
    try {
      final result = await action();
      return Right(result);
    } catch (e) {
      return Left(Failure.fromException(e));
    }
  }

  @override
  Future<Either<Failure, List<LineData>>> getLinesByPage(int pageNumber) {
    return _execute(() async {
      final words = await localDataSource.getWordsByPage(pageNumber);
      
      final Map<int, List<WordModel>> groupedByLine = {};
      for (var word in words) {
        if (!groupedByLine.containsKey(word.lineNumber)) {
          groupedByLine[word.lineNumber] = [];
        }
        groupedByLine[word.lineNumber]!.add(word);
      }

      final List<LineData> lines = [];
      for (int i = 1; i <= QuranConstants.linesPerPage; i++) {
        if (groupedByLine.containsKey(i)) {
          lines.add(LineData(lineNumber: i, words: groupedByLine[i]!));
        }
      }

      return lines;
    });
  }

  @override
  Future<Either<Failure, TafsirModel>> getTafsir(String verseKey, {int resourceId = 16}) {
    return _execute(() async {
      final text = await localDataSource.getTafsirForVerse(verseKey, resourceId);
      if (text.isEmpty) throw CacheException('Tafsir not found locally');
      return TafsirModel(id: 1, tafsirId: resourceId, text: text);
    });
  }

  @override
  Future<Either<Failure, TranslationModel>> getTranslation(String verseKey, {int resourceId = 20}) {
    return _execute(() async {
      final text = await localDataSource.getTranslationForVerse(verseKey, resourceId);
      if (text.isEmpty) throw CacheException('Translation not found locally');
      return TranslationModel(resourceId: resourceId, text: text);
    });
  }

  @override
  Future<Either<Failure, List<TafsirModel>>> getTafsirsByChapter(int chapterId, {int resourceId = 16, int page = 1}) {
    return _execute(() => remoteDataSource.getTafsirsByChapter(chapterId, tafsirId: resourceId, page: page));
  }

  @override
  Future<Either<Failure, List<TranslationModel>>> getTranslationsByChapter(int chapterId, {int resourceId = 20}) {
    return _execute(() => remoteDataSource.getTranslationsByChapter(chapterId, translationId: resourceId));
  }

  @override
  Future<Either<Failure, List<SearchVerseModel>>> searchQuran(String query) {
    return _execute(() => localDataSource.searchQuran(query));
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getSurahsIndex() {
    return _execute(() => localDataSource.getSurahsIndex());
  }

  @override
  Future<Either<Failure, List<SearchVerseModel>>> getVersesBySurah(int surahId) {
    return _execute(() => localDataSource.getVersesBySurah(surahId));
  }

  @override
  Future<Either<Failure, void>> downloadSingleVerseTafsir(int resourceId, String verseKey) {
    return _execute(() async {
      final response = await remoteDataSource.getTafsirByVerse(resourceId, verseKey);
      final Map<String, dynamic>? t = response['tafsir'];
      
      if (t != null) {
        final rows = [<String, dynamic>{
          'verse_key': t['verse_key'] ?? verseKey,
          'resource_id': resourceId,
          'text': t['text'],
        }];
        
        await localDataSource.insertTafsirs(rows);
      }
    });
  }

  @override
  Future<Either<Failure, double>> getTafsirDownloadProgress(int resourceId) {
    return _execute(() async {
      if (QuranConstants.bundledTafsirIds.contains(resourceId)) return 1.0;
      return await localDataSource.getTafsirDownloadProgress(resourceId);
    });
  }

  @override
  Stream<DownloadState> downloadTafsir(int resourceId) {
    return tafsirDownloadService.downloadTafsir(resourceId);
  }
}
