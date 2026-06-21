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
      final List<Map<String, dynamic>> maps = await db.query(
        'tafsir',
        where: 'verse_key = ? AND resource_id = ?',
        whereArgs: [verseKey, resourceId],
        limit: 1,
      );
      if (maps.isNotEmpty && maps.first['text'] != null) {
        return maps.first['text'] as String;
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
      // We group by surah to get the first page of each surah
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
}
