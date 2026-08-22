import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/database/database_helper.dart';
import '../models/verse_model.dart';
import '../models/search_verse_model.dart';
import '../models/tafsir_model.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/arabic_text_utils.dart';
import '../../../../core/constants/quran_constants.dart';
import '../../../../core/constants/quran_topics.dart';

import '../../bloc/quran/quran_page_cache.dart';

abstract class QuranLocalDataSource {
  Future<List<WordModel>> getWordsByPage(int pageNumber);
  Future<List<WordModel>> getWordsByVerse(String verseKey);
  Future<String?> getGhareebByVerse(String verseKey);
  Future<String> getTafsirForVerse(String verseKey, int resourceId);
  Future<TafsirModel> getTafsirModelForVerse(String verseKey, int resourceId);
  Future<String> getTranslationForVerse(String verseKey, int resourceId);
  Future<List<SearchVerseModel>> searchQuran(String query);
  Future<List<Map<String, dynamic>>> getSurahsIndex();
  Future<int> getPageForVerse(String verseKey);
  Future<List<SearchVerseModel>> getVersesBySurah(int surahId);
  Future<List<SearchVerseModel>> getVersesByRanges(List<VerseRange> ranges);
  Future<List<Map<String, dynamic>>> getTafsirsBySurah(
    int surahId,
    int resourceId,
  );
  Future<List<Map<String, dynamic>>> getTranslationsBySurah(
    int surahId,
    int resourceId,
  );
  Future<void> insertTafsirs(List<Map<String, dynamic>> tafsirs);
  Future<double> getTafsirDownloadProgress(int resourceId);
  Future<int> getMaxDownloadedChapter(int resourceId);
  Future<int> getDownloadedVerseCount(int resourceId);
  Future<void> markTafsirAsCompleted(int resourceId);
}

class QuranLocalDataSourceImpl implements QuranLocalDataSource {
  final DatabaseHelper databaseHelper;

  final Map<String, String> _ghareebCache = {};
  final Map<String, TafsirModel> _tafsirCache = {};
  final Map<String, String> _translationCache = {};
  final Map<String, int> _pageForVerseCache = {};

  QuranLocalDataSourceImpl({required this.databaseHelper});

  @override
  Future<List<WordModel>> getWordsByPage(int pageNumber) async {
    final cached = QuranPageCache.get(pageNumber);
    if (cached != null) {
      final words = <WordModel>[];
      for (final line in cached.lines) {
        words.addAll(line.words);
      }
      if (words.isNotEmpty) return words;
    }

    try {
      final db = await databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'quran_words',
        columns: [
          'id',
          'page',
          'line_number',
          'verse_key',
          'text_uthmani',
          'char_type_name',
          'code_v2',
        ],
        where: 'page = ?',
        whereArgs: [pageNumber],
        orderBy: 'id ASC',
      );

      if (maps.isEmpty) {
        throw CacheException('No data found for page $pageNumber');
      }

      return maps
          .map(
            (map) => WordModel(
              id: map['id'] as int,
              textUthmani: map['text_uthmani'] as String,
              codeV2: map['code_v2'] as String? ?? '',
              lineNumber: map['line_number'] as int,
              charTypeName: map['char_type_name'] as String,
              verseKey: map['verse_key'] as String,
              pageNumber: (map['page'] as int?) ?? pageNumber,
            ),
          )
          .toList();
    } catch (e) {
      throw CacheException('Database error: ${e.toString()}');
    }
  }

  @override
  Future<List<WordModel>> getWordsByVerse(String verseKey) async {
    final cachedPageNumber = _pageForVerseCache[verseKey];
    if (cachedPageNumber != null) {
      final cachedPage = QuranPageCache.get(cachedPageNumber);
      if (cachedPage != null) {
        final words = <WordModel>[];
        for (final line in cachedPage.lines) {
          for (final w in line.words) {
            if (w.verseKey == verseKey) words.add(w);
          }
        }
        if (words.isNotEmpty) return words;
      }
    }

    try {
      final db = await databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'quran_words',
        columns: [
          'id',
          'page',
          'line_number',
          'verse_key',
          'text_uthmani',
          'char_type_name',
          'code_v2',
        ],
        where: 'verse_key = ?',
        whereArgs: [verseKey],
        orderBy: 'id ASC',
      );

      return maps
          .map(
            (map) => WordModel(
              id: map['id'] as int,
              textUthmani: map['text_uthmani'] as String,
              codeV2: map['code_v2'] as String? ?? '',
              lineNumber: map['line_number'] as int,
              charTypeName: map['char_type_name'] as String,
              verseKey: map['verse_key'] as String,
              pageNumber: (map['page'] as int?) ?? 1,
            ),
          )
          .toList();
    } catch (e) {
      throw CacheException('Database error: ${e.toString()}');
    }
  }

  @override
  Future<String?> getGhareebByVerse(String verseKey) async {
    if (_ghareebCache.containsKey(verseKey)) {
      return _ghareebCache[verseKey];
    }

    try {
      final db = await databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'ghareeb',
        columns: ['text'],
        where: 'verse_key = ?',
        whereArgs: [verseKey],
        limit: 1,
      );
      if (maps.isNotEmpty && maps.first['text'] != null) {
        final text = maps.first['text'] as String;
        _ghareebCache[verseKey] = text;
        return text;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int> getPageForVerse(String verseKey) async {
    if (_pageForVerseCache.containsKey(verseKey)) {
      return _pageForVerseCache[verseKey]!;
    }

    try {
      final db = await databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'quran_words',
        columns: ['page'],
        where: 'verse_key = ?',
        whereArgs: [verseKey],
        limit: 1,
      );
      if (maps.isNotEmpty) {
        final p = maps.first['page'] as int;
        _pageForVerseCache[verseKey] = p;
        return p;
      }
      return 1;
    } catch (e) {
      return 1;
    }
  }

  @override
  Future<String> getTafsirForVerse(String verseKey, int resourceId) async {
    final model = await getTafsirModelForVerse(verseKey, resourceId);
    return model.text;
  }

  @override
  Future<TafsirModel> getTafsirModelForVerse(
    String verseKey,
    int resourceId,
  ) async {
    final cacheKey = '$resourceId:$verseKey';
    if (_tafsirCache.containsKey(cacheKey)) {
      return _tafsirCache[cacheKey]!;
    }

    try {
      final db = await databaseHelper.database;
      final parts = verseKey.split(':');
      if (parts.length != 2) {
        return TafsirModel(id: 0, tafsirId: resourceId, text: '');
      }

      final chapterId = int.tryParse(parts[0]) ?? 1;
      final requestedAyah = int.tryParse(parts[1]) ?? 1;
      int verseNumber = requestedAyah;

      int rootAyah = requestedAyah;
      String tafsirText = '';

      // Look backwards to find grouped tafsir
      for (
        int i = 0;
        i < QuranConstants.tafsirGroupLookbackWindow && verseNumber > 0;
        i++
      ) {
        final searchKey = '$chapterId:$verseNumber';
        final List<Map<String, dynamic>> maps = await db.query(
          'tafsir',
          where: 'verse_key = ? AND resource_id = ?',
          whereArgs: [searchKey, resourceId],
          limit: 1,
        );
        if (maps.isNotEmpty && maps.first['text'] != null) {
          final textStr = maps.first['text'] as String;
          if (textStr.trim().isNotEmpty) {
            tafsirText = textStr;
            rootAyah = verseNumber;
            break;
          }
        }
        verseNumber--;
      }

      if (tafsirText.trim().isEmpty) {
        final emptyModel = TafsirModel(id: 0, tafsirId: resourceId, text: '');
        _tafsirCache[cacheKey] = emptyModel;
        return emptyModel;
      }

      String? groupVerseRange;
      bool isGroupContinuation = requestedAyah > rootAyah;

      final List<Map<String, dynamic>> nextEntries = await db.query(
        'tafsir',
        where:
            "CAST(substr(verse_key, 1, instr(verse_key, ':') - 1) AS INTEGER) = ? AND CAST(substr(verse_key, instr(verse_key, ':') + 1) AS INTEGER) > ? AND resource_id = ? AND TRIM(text) != ''",
        whereArgs: [chapterId, rootAyah, resourceId],
        orderBy:
            "CAST(substr(verse_key, instr(verse_key, ':') + 1) AS INTEGER) ASC",
        limit: 1,
      );

      int endAyah = rootAyah;
      if (nextEntries.isNotEmpty) {
        final nextKey = nextEntries.first['verse_key'] as String;
        final nextAyah = int.tryParse(nextKey.split(':')[1]) ?? (rootAyah + 1);
        endAyah = nextAyah - 1;
      } else {
        final List<Map<String, dynamic>> maxAyahRes = await db.query(
          'quran_search',
          columns: ['MAX(ayah) as max_a'],
          where: 'surah = ?',
          whereArgs: [chapterId],
        );
        endAyah =
            (maxAyahRes.isNotEmpty
                ? maxAyahRes.first['max_a'] as int?
                : null) ??
            rootAyah;
      }

      if (endAyah > rootAyah) {
        groupVerseRange = '$rootAyah - $endAyah';
      }

      final resultModel = TafsirModel(
        id: 0,
        tafsirId: resourceId,
        verseKey: verseKey,
        text: tafsirText,
        groupVerseRange: groupVerseRange,
        isGroupContinuation: isGroupContinuation,
      );
      _tafsirCache[cacheKey] = resultModel;
      return resultModel;
    } catch (e) {
      throw CacheException('Error fetching tafsir: ${e.toString()}');
    }
  }

  @override
  Future<String> getTranslationForVerse(String verseKey, int resourceId) async {
    final cacheKey = '$resourceId:$verseKey';
    if (_translationCache.containsKey(cacheKey)) {
      return _translationCache[cacheKey]!;
    }

    try {
      final db = await databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'translation',
        where: 'verse_key = ? AND resource_id = ?',
        whereArgs: [verseKey, resourceId],
        limit: 1,
      );
      if (maps.isNotEmpty && maps.first['text'] != null) {
        final text = maps.first['text'] as String;
        _translationCache[cacheKey] = text;
        return text;
      }
      return '';
    } catch (e) {
      throw CacheException('Error fetching translation: ${e.toString()}');
    }
  }

  List<SearchVerseModel>? _allVersesCache;

  Future<List<SearchVerseModel>> _getAllVerses(Database db) async {
    if (_allVersesCache != null) return _allVersesCache!;
    final List<Map<String, dynamic>> maps = await db.query('quran_search');
    _allVersesCache = maps.map((map) => SearchVerseModel.fromMap(map)).toList();
    return _allVersesCache!;
  }

  @override
  Future<List<SearchVerseModel>> searchQuran(String query) async {
    try {
      final db = await databaseHelper.database;
      final allVerses = await _getAllVerses(db);

      String cleaned = query.trim();
      cleaned = cleaned.replaceAll(
        RegExp(r'^(سورة|سوره|surah)\s*', caseSensitive: false),
        '',
      );
      if (cleaned.isEmpty) cleaned = query.trim();

      final rawKeywords = cleaned.split(RegExp(r'[,،|]+'));
      final keywords = rawKeywords
          .map(
            (k) => ArabicTextUtils.normalizeArabicDiacritics(
              k.trim(),
            ).replaceAll(' ', ''),
          )
          .where((k) => k.isNotEmpty)
          .toList();

      if (keywords.isEmpty) return [];

      final results = <SearchVerseModel>[];
      for (final verse in allVerses) {
        final smartVerse = ArabicTextUtils.normalizeArabicDiacritics(
          verse.textClean,
        ).replaceAll(' ', '');

        bool matches = false;
        for (final kw in keywords) {
          if (smartVerse.contains(kw)) {
            matches = true;
            break;
          }
        }

        if (matches) {
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
  Future<List<SearchVerseModel>> getVersesByRanges(
    List<VerseRange> ranges,
  ) async {
    try {
      final db = await databaseHelper.database;
      final allVerses = await _getAllVerses(db);

      final results = <SearchVerseModel>[];
      for (final verse in allVerses) {
        for (final range in ranges) {
          if (range.contains(verse.surah, verse.ayah)) {
            results.add(verse);
            break;
          }
        }
      }
      return results;
    } catch (e) {
      throw CacheException('Get topic verses error: ${e.toString()}');
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
  Future<List<Map<String, dynamic>>> getTafsirsBySurah(
    int surahId,
    int resourceId,
  ) async {
    try {
      final db = await databaseHelper.database;
      return await db.query(
        'tafsir',
        where: 'verse_key LIKE ? AND resource_id = ?',
        whereArgs: ['$surahId:%', resourceId],
        orderBy: 'rowid ASC',
      );
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getTranslationsBySurah(
    int surahId,
    int resourceId,
  ) async {
    try {
      final db = await databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'translation',
        where:
            "CAST(substr(verse_key, 1, instr(verse_key, ':') - 1) AS INTEGER) = ? AND resource_id = ?",
        whereArgs: [surahId, resourceId],
        orderBy:
            "CAST(substr(verse_key, instr(verse_key, ':') + 1) AS INTEGER) ASC",
      );
      return maps;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> insertTafsirs(List<Map<String, dynamic>> rows) async {
    _tafsirCache.clear();
    final db = await databaseHelper.database;
    final batch = db.batch();
    for (var row in rows) {
      batch.insert('tafsir', row, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<double> getTafsirDownloadProgress(int resourceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('tafsir_completed_$resourceId') == true) {
        return 1.0;
      }

      final maxChapter = await getMaxDownloadedChapter(resourceId);
      final progress = maxChapter / QuranConstants.totalSurahs;
      return progress > 1.0 ? 1.0 : progress;
    } catch (e) {
      return 0.0;
    }
  }

  @override
  Future<void> markTafsirAsCompleted(int resourceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tafsir_completed_$resourceId', true);
  }

  @override
  Future<int> getMaxDownloadedChapter(int resourceId) async {
    try {
      final db = await databaseHelper.database;
      final result = await db.rawQuery(
        "SELECT MAX(CAST(substr(verse_key, 1, instr(verse_key, ':') - 1) AS INTEGER)) as max_chap FROM tafsir WHERE resource_id = ?",
        [resourceId],
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
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM tafsir WHERE resource_id = ?',
        [resourceId],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
