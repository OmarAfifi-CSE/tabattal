import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

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
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

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
    const currentDbVersion = 6; // bumped to 6 to force overwrite on Web

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

      // Copy from asset. ALWAYS use forward slashes for rootBundle paths!
      ByteData data = await rootBundle.load('assets/data/quran.db');
      List<int> bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      // Write bytes via databaseFactory (supports native)
      await databaseFactory.writeDatabaseBytes(path, Uint8List.fromList(bytes));
      
      await prefs.setInt('db_version', currentDbVersion);
    }

    // Open the database
    return await databaseFactory.openDatabase(path, options: OpenDatabaseOptions(readOnly: false));
  }
}

