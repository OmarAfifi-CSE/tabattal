import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:archive/archive.dart';
import '../../features/quran_audio/data/services/surah_audio_timing_service.dart';
import 'database_platform_helper.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  @visibleForTesting
  static void setTestDatabase(Database? db) {
    _database = db;
  }

  @visibleForTesting
  static Future<void> ensureAudioTimingsTable(Database db) => _ensureAudioTimingsTable(db);


  Future<Database> _initDatabase() async {
    initDatabasePlatform();

    String path;
    if (kIsWeb) {
      path = 'quran.db';
    } else {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      path = join(documentsDirectory.path, 'quran.db');
    }

    // Check if the database exists (Mobile/Desktop/Web)
    bool exists = await databaseFactory.databaseExists(path);

    // Check version to force update if we ship a new DB
    final prefs = await SharedPreferences.getInstance();
    final dbVersion = prefs.getInt('db_version') ?? 0;

    // Increment this whenever we update quran.db in assets
    const currentDbVersion = 32;

    if (!exists || dbVersion < currentDbVersion) {
      if (!kIsWeb) {
        // Make sure the parent directory exists
        try {
          await Directory(dirname(path)).create(recursive: true);
        } catch (_) {}
      } else {
        // On Web, clear the corrupted database first just in case
        await databaseFactory.deleteDatabase(path);
      }

      final ByteData data = await rootBundle.load('assets/data/quran.db');
      final rawBytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      Uint8List dbBytes;
      try {
        // Try decoding GZip compressed database (3.85 MB instead of 13.1 MB - immune to IDM interception)
        dbBytes = const GZipDecoder().decodeBytes(rawBytes);
      } catch (_) {
        // Fallback to raw bytes if the database asset is not compressed
        dbBytes = rawBytes;
      }

      // Write bytes via databaseFactory (zero redundant allocations)
      await databaseFactory.writeDatabaseBytes(path, dbBytes);

      // The shipped DB replaces the working copy wholesale — any rows the user
      // downloaded before (e.g. tafsir) are gone with it. Completion flags
      // live in SharedPreferences, OUTSIDE the DB, so they must be cleared in
      // the same step or progress would report 100% over an empty table.
      try {
        final keys = prefs
            .getKeys()
            .where((k) => k.startsWith('tafsir_completed_'))
            .toList();
        for (final k in keys) {
          await prefs.remove(k);
        }
      } catch (_) {}

      await prefs.setInt('db_version', currentDbVersion);
    }

    // Open the database
    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(readOnly: false),
    );

    await _ensureAudioTimingsTable(db);
    await _ensureTafsirChaptersTable(db);
    await _seedAudioTimingsIfNeeded(db, prefs);

    return db;
  }

  static Future<void> _ensureAudioTimingsTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS surah_audio_timings (
          reciter_path TEXT NOT NULL,
          surah_number INTEGER NOT NULL,
          audio_url TEXT NOT NULL,
          verse_timings TEXT NOT NULL,
          created_at INTEGER,
          PRIMARY KEY (reciter_path, surah_number)
        );
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_surah_audio_timings_reciter 
        ON surah_audio_timings (reciter_path, surah_number);
      ''');
    } catch (_) {}
  }

  static Future<void> _ensureTafsirChaptersTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tafsir_completed_chapters (
          resource_id INTEGER NOT NULL,
          chapter_id INTEGER NOT NULL,
          completed_at INTEGER,
          PRIMARY KEY (resource_id, chapter_id)
        );
      ''');
    } catch (_) {}
  }

  static Future<void> _seedAudioTimingsIfNeeded(
    Database db,
    SharedPreferences prefs,
  ) async {
    try {
      final seeded = prefs.getBool('audio_timings_all_seeded_v1') ?? false;
      if (!seeded) {
        await SurahAudioTimingService.seedAllSurahs(db);
        await prefs.setBool('audio_timings_all_seeded_v1', true);
      }
    } catch (_) {}
  }
}
