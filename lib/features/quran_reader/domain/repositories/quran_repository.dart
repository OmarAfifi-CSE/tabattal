import 'dart:async';
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
  Future<void> clearDatabase();
  Future<void> downloadSingleVerseTafsir(int resourceId, String verseKey);
  Stream<double> downloadTafsir(int resourceId);
  Future<double> getTafsirDownloadProgress(int resourceId);
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

  @override
  Future<void> clearDatabase() async {
    // Left unimplemented or remove entirely
  }

  @override
  Future<void> downloadSingleVerseTafsir(int resourceId, String verseKey) async {
    try {
      final response = await remoteDataSource.getTafsirByVerse(resourceId, verseKey);
      final Map<String, dynamic>? t = response['tafsir'];
      
      if (t != null) {
        final rows = [{
          'verse_key': t['verse_key'] ?? verseKey,
          'resource_id': resourceId,
          'text': t['text'],
        }];
        
        await localDataSource.insertTafsirs(rows);
      }
    } catch (e) {
      // We log but don't fail hard, as the main background download might handle it later.
      print('Failed to download single verse tafsir: $e');
    }
  }

  @override
  Future<double> getTafsirDownloadProgress(int resourceId) async {
    // 16, 14, 91 are always available since they came bundled
    if (resourceId == 16 || resourceId == 14 || resourceId == 91) return 1.0;
    return await localDataSource.getTafsirDownloadProgress(resourceId);
  }

  @override
  Stream<double> downloadTafsir(int resourceId) {
    const totalVerses = 6236;
    const concurrency = 2; // Reduced for weak connections
    
    final controller = StreamController<double>();
    bool hasError = false;

    // We use a self-executing async block to start the process while returning the stream immediately
    () async {
      try {
        // Figure out where to resume
        int maxChapter = await localDataSource.getMaxDownloadedChapter(resourceId);
        int safeStartChapter = maxChapter > concurrency ? maxChapter - concurrency : 1;

        // Send initial progress
        int completedVerses = await localDataSource.getDownloadedVerseCount(resourceId);
        controller.add(completedVerses / totalVerses);

        Future<void> worker(int workerId) async {
          for (int i = workerId; i <= 114; i += concurrency) {
            if (hasError) return;
            if (i < safeStartChapter) continue; // Skip chapters that are definitely fully downloaded
            
            try {
              int page = 1;
              bool hasNext = true;
              
              while (hasNext) {
                if (hasError) return;
                
                // Bulletproof Retry Mechanism
                int retries = 0;
                const maxRetries = 3;
                Map<String, dynamic>? response;
                
                while (retries <= maxRetries) {
                  try {
                    response = await remoteDataSource.getTafsirByChapter(
                      resourceId, 
                      i,
                      page: page,
                      perPage: 20, // Smaller chunks for weak connections
                    );
                    break; // Success, break retry loop
                  } catch (e) {
                    retries++;
                    if (retries > maxRetries) rethrow; // Out of retries
                    await Future.delayed(Duration(seconds: retries * 2)); // Exponential backoff (2s, 4s, 6s)
                  }
                }
                
                if (hasError || response == null) return;

                final List tafsirs = response['tafsirs'] ?? [];
                if (tafsirs.isNotEmpty) {
                  final rows = tafsirs.map((t) => {
                    'verse_key': t['verse_key'],
                    'resource_id': resourceId,
                    'text': t['text'],
                  }).toList();
                  
                  await localDataSource.insertTafsirs(rows);
                  
                  // Recalculate exact progress from DB
                  completedVerses = await localDataSource.getDownloadedVerseCount(resourceId);
                  
                  double progress = completedVerses / totalVerses;
                  if (progress > 1.0) progress = 1.0;
                  if (!controller.isClosed) {
                    controller.add(progress);
                  }
                }
                
                final pagination = response['pagination'];
                hasNext = pagination != null && pagination['next_page'] != null;
                page++;
              }
            } catch (e) {
              if (!hasError) {
                hasError = true;
                if (!controller.isClosed) controller.addError(e);
              }
              return;
            }
          }
        }

        final workers = List.generate(concurrency, (index) => worker(index + 1));
        await Future.wait(workers);
        
        if (!hasError && !controller.isClosed) {
          controller.add(1.0);
          controller.close();
        }
      } catch (e) {
        if (!hasError && !controller.isClosed) {
          hasError = true;
          controller.addError(e);
          controller.close();
        }
      }
    }();

    return controller.stream;
  }
}
