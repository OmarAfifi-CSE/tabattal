import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../models/verse_model.dart';
import '../models/search_verse_model.dart';
import '../../../../core/error/exceptions.dart';

abstract class QuranLocalDataSource {
  Future<List<WordModel>> getWordsByPage(int pageNumber);
  Future<String> getTafsirForVerse(String verseKey, int resourceId);
  Future<String> getTranslationForVerse(String verseKey, int resourceId);
  Future<List<SearchVerseModel>> searchQuran(String query);
  Future<List<Map<String, dynamic>>> getSurahsIndex();
  Future<List<SearchVerseModel>> getVersesBySurah(int surahId);
  Future<List<Map<String, dynamic>>> getTafsirsBySurah(int surahId, int resourceId);
  Future<List<Map<String, dynamic>>> getTranslationsBySurah(int surahId, int resourceId);
  Future<void> insertTafsirs(List<Map<String, dynamic>> tafsirs);
  Future<double> getTafsirDownloadProgress(int resourceId);
  Future<int> getMaxDownloadedChapter(int resourceId);
  Future<int> getDownloadedVerseCount(int resourceId);
}

class QuranLocalDataSourceImpl implements QuranLocalDataSource {
  final DatabaseHelper databaseHelper;

  QuranLocalDataSourceImpl({required this.databaseHelper});

  @override
  Future<List<WordModel>> getWordsByPage(int pageNumber) async {
    try {
      final db = await databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'quran_words',
        where: 'page = ?',
        whereArgs: [pageNumber],
        orderBy: 'id ASC',
      );

      if (maps.isEmpty) {
        throw CacheException('No data found for page $pageNumber');
      }

      return maps.map((map) => WordModel(
        id: map['id'] as int,
        position: map['id'] as int, // approximate position
        textUthmani: map['text_uthmani'] as String,
        lineNumber: map['line_number'] as int,
        charTypeName: map['char_type_name'] as String,
        verseKey: map['verse_key'] as String,
      )).toList();
    } catch (e) {
      throw CacheException('Database error: ${e.toString()}');
    }
  }

  @override
  Future<String> getTafsirForVerse(String verseKey, int resourceId) async {
    try {
      final db = await databaseHelper.database;
      final parts = verseKey.split(':');
      if (parts.length != 2) return 'تفسير هذه الآية غير متوفر. الرجاء التأكد من تحديث قاعدة البيانات.';
      
      final chapterId = int.tryParse(parts[0]) ?? 1;
      int verseNumber = int.tryParse(parts[1]) ?? 1;
      
      // Look backwards up to 15 verses to find grouped tafsir
      for (int i = 0; i < 15 && verseNumber > 0; i++) {
        final searchKey = '$chapterId:$verseNumber';
        final List<Map<String, dynamic>> maps = await db.query(
          'tafsir',
          where: 'verse_key = ? AND resource_id = ?',
          whereArgs: [searchKey, resourceId],
          limit: 1,
        );
        if (maps.isNotEmpty && maps.first['text'] != null) {
          return maps.first['text'] as String;
        }
        verseNumber--;
      }
      
      return 'تفسير هذه الآية غير متوفر. الرجاء التأكد من تحديث قاعدة البيانات.';
    } catch (e) {
      return 'حدث خطأ أثناء جلب التفسير.';
    }
  }

  @override
  Future<String> getTranslationForVerse(String verseKey, int resourceId) async {
    try {
      final db = await databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'translation',
        where: 'verse_key = ? AND resource_id = ?',
        whereArgs: [verseKey, resourceId],
        limit: 1,
      );
      if (maps.isNotEmpty && maps.first['text'] != null) {
        return maps.first['text'] as String;
      }
      return 'Translation is not available. Please update the database.';
    } catch (e) {
      return 'Error fetching translation.';
    }
  }

  List<SearchVerseModel>? _allVersesCache;

  Future<List<SearchVerseModel>> _getAllVerses(Database db) async {
    if (_allVersesCache != null) return _allVersesCache!;
    final List<Map<String, dynamic>> maps = await db.query('quran_search');
    _allVersesCache = maps.map((map) => SearchVerseModel.fromMap(map)).toList();
    return _allVersesCache!;
  }

  String _smartNormalize(String text) {
    var c = text.replaceAll(RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E8\u06EA-\u06ED\u0640]'), '');
    c = c.replaceAll('ـ', ''); // Remove Tatweel explicitly just in case
    c = c.replaceAll(RegExp(r'[اأإآٱى]'), '');
    c = c.replaceAll(RegExp(r'ة'), 'ه');
    c = c.replaceAll(RegExp(r'[ئ]'), 'ي');
    c = c.replaceAll(RegExp(r'ؤ'), 'و');
    return c;
  }

  @override
  Future<List<SearchVerseModel>> searchQuran(String query) async {
    try {
      final db = await databaseHelper.database;
      final allVerses = await _getAllVerses(db);
      
      final smartQuery = _smartNormalize(query).replaceAll(' ', '');
      if (smartQuery.isEmpty) return [];

      final results = <SearchVerseModel>[];
      for (final verse in allVerses) {
        final smartVerse = _smartNormalize(verse.textClean);
        // Remove spaces from verse just for matching substrings across words
        if (smartVerse.replaceAll(' ', '').contains(smartQuery)) {
          results.add(verse);
          if (results.length >= 100) break;
        }
      }

      return results;
    } catch (e) {
      throw CacheException('Search database error: ${e.toString()}');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getSurahsIndex() async {
    try {
      final db = await databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'quran_search',
        columns: ['surah', 'MIN(page) as start_page'],
        groupBy: 'surah',
        orderBy: 'surah ASC',
      );
      return maps;
    } catch (e) {
      throw CacheException('Failed to fetch surah index: ${e.toString()}');
    }
  }

  @override
  Future<List<SearchVerseModel>> getVersesBySurah(int surahId) async {
    try {
      final db = await databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'quran_search',
        where: 'surah = ?',
        whereArgs: [surahId],
        orderBy: 'ayah ASC',
      );
      return maps.map((map) => SearchVerseModel.fromMap(map)).toList();
    } catch (e) {
      throw CacheException('Failed to fetch verses by surah: ${e.toString()}');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getTafsirsBySurah(int surahId, int resourceId) async {
    try {
      final db = await databaseHelper.database;
      // Build verse keys for the surah: "surahId:1", "surahId:2", ...
      // We use a LIKE query: verse_key LIKE 'surahId:%'
      return await db.query(
        'tafsir',
        where: 'verse_key LIKE ? AND resource_id = ?',
        whereArgs: ['$surahId:%', resourceId],
        orderBy: 'rowid ASC',
      );
    } catch (e) {
      return []; // Return empty on error, caller falls back to 'not available'
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getTranslationsBySurah(int surahId, int resourceId) async {
    try {
      final db = await databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'translation',
        where: 'CAST(substr(verse_key, 1, instr(verse_key, ":") - 1) AS INTEGER) = ? AND resource_id = ?',
        whereArgs: [surahId, resourceId],
        orderBy: 'CAST(substr(verse_key, instr(verse_key, ":") + 1) AS INTEGER) ASC',
      );
      return maps;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> insertTafsirs(List<Map<String, dynamic>> rows) async {
    final db = await databaseHelper.database;
    final batch = db.batch();
    for (var row in rows) {
      batch.insert(
        'tafsir', 
        row, 
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<double> getTafsirDownloadProgress(int resourceId) async {
    try {
      final db = await databaseHelper.database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM tafsir WHERE resource_id = ?', [resourceId]);
      final count = Sqflite.firstIntValue(result) ?? 0;
      final progress = count / 6236; // Total verses in Quran
      return progress > 1.0 ? 1.0 : progress;
    } catch (e) {
      return 0.0;
    }
  }

  @override
  Future<int> getMaxDownloadedChapter(int resourceId) async {
    try {
      final db = await databaseHelper.database;
      final result = await db.rawQuery(
        'SELECT MAX(CAST(substr(verse_key, 1, instr(verse_key, ":") - 1) AS INTEGER)) as max_chap FROM tafsir WHERE resource_id = ?', 
        [resourceId]
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  @override
  Future<int> getDownloadedVerseCount(int resourceId) async {
    try {
      final db = await databaseHelper.database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM tafsir WHERE resource_id = ?', [resourceId]);
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
