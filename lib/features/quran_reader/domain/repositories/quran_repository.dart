import '../../data/datasources/quran_remote_data_source.dart';
import '../../data/models/verse_model.dart';
import '../../data/models/tafsir_model.dart';
import '../../data/models/translation_model.dart';

abstract class QuranRepository {
  Future<List<VerseModel>> getVersesByPage(int pageNumber);
  Future<List<VerseModel>> getVersesBySurah(int surahId);
  Future<TafsirModel> getTafsir(String verseKey);
  Future<TranslationModel> getTranslation(String verseKey);
}

class QuranRepositoryImpl implements QuranRepository {
  final QuranRemoteDataSource remoteDataSource;

  QuranRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<VerseModel>> getVersesByPage(int pageNumber) {
    return remoteDataSource.getVersesByPage(pageNumber);
  }

  @override
  Future<List<VerseModel>> getVersesBySurah(int surahId) {
    return remoteDataSource.getVersesBySurah(surahId);
  }

  @override
  Future<TafsirModel> getTafsir(String verseKey) {
    return remoteDataSource.getTafsirByVerse(verseKey);
  }

  @override
  Future<TranslationModel> getTranslation(String verseKey) {
    return remoteDataSource.getTranslationByVerse(verseKey);
  }
}
