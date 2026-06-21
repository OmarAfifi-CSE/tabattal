import '../../data/datasources/quran_local_data_source.dart';
import '../../data/datasources/quran_remote_data_source.dart';
import '../../data/models/verse_model.dart';
import '../../data/models/tafsir_model.dart';
import '../../data/models/translation_model.dart';
import '../../data/models/search_verse_model.dart';

abstract class QuranRepository {
  Future<List<LineData>> getLinesByPage(int pageNumber);
  Future<TafsirModel> getTafsir(String verseKey, {int resourceId = 16}); // Default Al-Muyassar
  Future<TranslationModel> getTranslation(String verseKey, {int resourceId = 20}); // Default English
  Future<List<TafsirModel>> getTafsirsByChapter(int chapterId, {int resourceId = 16, int page = 1});
  Future<List<TranslationModel>> getTranslationsByChapter(int chapterId, {int resourceId = 20});
  Future<List<SearchVerseModel>> searchQuran(String query);
  Future<List<Map<String, dynamic>>> getSurahsIndex();
  Future<List<SearchVerseModel>> getVersesBySurah(int surahId);
}

class QuranRepositoryImpl implements QuranRepository {
  final QuranLocalDataSource localDataSource;
  final QuranRemoteDataSource remoteDataSource;

  QuranRepositoryImpl({required this.localDataSource, required this.remoteDataSource});

  @override
  Future<List<LineData>> getLinesByPage(int pageNumber) async {
    final words = await localDataSource.getWordsByPage(pageNumber);
    
    // Group words by line_number (1 to 15)
    final Map<int, List<WordModel>> groupedByLine = {};
    for (var word in words) {
      if (!groupedByLine.containsKey(word.lineNumber)) {
        groupedByLine[word.lineNumber] = [];
      }
      groupedByLine[word.lineNumber]!.add(word);
    }

    final List<LineData> lines = [];
    for (int i = 1; i <= 15; i++) {
      if (groupedByLine.containsKey(i)) {
        lines.add(LineData(lineNumber: i, words: groupedByLine[i]!));
      }
    }

    return lines;
  }

  @override
  Future<TafsirModel> getTafsir(String verseKey, {int resourceId = 16}) async {
    final text = await localDataSource.getTafsirForVerse(verseKey, resourceId);
    return TafsirModel(
      id: 1,
      tafsirId: resourceId,
      text: text,
    );
  }

  @override
  Future<TranslationModel> getTranslation(String verseKey, {int resourceId = 20}) async {
    final text = await localDataSource.getTranslationForVerse(verseKey, resourceId);
    return TranslationModel(
      resourceId: resourceId,
      text: text,
    );
  }

  @override
  Future<List<TafsirModel>> getTafsirsByChapter(int chapterId, {int resourceId = 16, int page = 1}) async {
    return await remoteDataSource.getTafsirsByChapter(chapterId, tafsirId: resourceId, page: page);
  }

  @override
  Future<List<TranslationModel>> getTranslationsByChapter(int chapterId, {int resourceId = 20}) async {
    return await remoteDataSource.getTranslationsByChapter(chapterId, translationId: resourceId);
  }

  @override
  Future<List<SearchVerseModel>> searchQuran(String query) async {
    return await localDataSource.searchQuran(query);
  }

  @override
  Future<List<Map<String, dynamic>>> getSurahsIndex() async {
    return await localDataSource.getSurahsIndex();
  }

  @override
  Future<List<SearchVerseModel>> getVersesBySurah(int surahId) async {
    return await localDataSource.getVersesBySurah(surahId);
  }
}
