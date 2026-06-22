import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

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

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'quran.db');

    // Check if the database exists
    bool exists = await databaseExists(path);
    
    // Check version to force update if we ship a new DB
    final prefs = await SharedPreferences.getInstance();
    final dbVersion = prefs.getInt('db_version') ?? 0;
    
    // Increment this whenever we update quran.db in assets
    const currentDbVersion = 4;

    if (!exists || dbVersion < currentDbVersion) {
      // Should happen only the first time you launch your application or when DB is updated

      // Make sure the parent directory exists
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}

      // Copy from asset
      ByteData data = await rootBundle.load(join('assets', 'data', 'quran.db'));
      List<int> bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      // Write and flush the bytes written
      await File(path).writeAsBytes(bytes, flush: true);
      await prefs.setInt('db_version', currentDbVersion);
    }

    // Open the database
    return await openDatabase(path, readOnly: false);
  }
}
