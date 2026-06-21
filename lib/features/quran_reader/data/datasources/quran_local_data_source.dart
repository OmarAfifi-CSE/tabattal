import '../../../../core/database/database_helper.dart';
import '../models/verse_model.dart';
import '../../../../core/error/exceptions.dart';

abstract class QuranLocalDataSource {
  Future<List<WordModel>> getWordsByPage(int pageNumber);
  Future<String> getTafsirForVerse(String verseKey, int resourceId);
  Future<String> getTranslationForVerse(String verseKey, int resourceId);
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
}
