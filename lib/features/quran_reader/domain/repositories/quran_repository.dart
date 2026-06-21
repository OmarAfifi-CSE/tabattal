import '../../data/datasources/quran_local_data_source.dart';
import '../../data/models/verse_model.dart';
import '../../data/models/tafsir_model.dart';
import '../../data/models/translation_model.dart';

abstract class QuranRepository {
  Future<List<LineData>> getLinesByPage(int pageNumber);
  Future<TafsirModel> getTafsir(String verseKey, {int resourceId = 16}); // Default Al-Muyassar
  Future<TranslationModel> getTranslation(String verseKey, {int resourceId = 20}); // Default English
}

class QuranRepositoryImpl implements QuranRepository {
  final QuranLocalDataSource localDataSource;

  QuranRepositoryImpl({required this.localDataSource});

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
}
