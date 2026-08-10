import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../features/quran_reader/data/models/hifz_plan_model.dart';
import 'database_helper.dart';

class HifzDatabaseHelper {
  static final HifzDatabaseHelper _instance = HifzDatabaseHelper._internal();
  factory HifzDatabaseHelper() => _instance;
  HifzDatabaseHelper._internal();

  bool _initialized = false;

  Future<Database> _getDb() async {
    final db = await DatabaseHelper().database;
    if (!_initialized) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS hifz_plans (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          surahNumber INTEGER NOT NULL,
          startPage INTEGER NOT NULL,
          endPage INTEGER NOT NULL,
          targetVersesCount INTEGER NOT NULL,
          memorizedVersesCount INTEGER NOT NULL DEFAULT 0,
          createdAt TEXT NOT NULL,
          lastStudiedAt TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS hifz_items (
          verseKey TEXT PRIMARY KEY,
          surahNumber INTEGER NOT NULL,
          ayahNumber INTEGER NOT NULL,
          pageNumber INTEGER NOT NULL,
          status TEXT NOT NULL,
          lastReviewedAt TEXT,
          nextReviewAt TEXT,
          reviewCount INTEGER NOT NULL DEFAULT 0
        )
      ''');

      _initialized = true;
    }
    return db;
  }

  // --- Plans CRUD ---

  Future<List<HifzPlanModel>> getPlans() async {
    final db = await _getDb();
    final maps = await db.query('hifz_plans', orderBy: 'id DESC');
    return maps.map((m) => HifzPlanModel.fromMap(m)).toList();
  }

  Future<int> insertPlan(HifzPlanModel plan) async {
    final db = await _getDb();
    final map = plan.toMap();
    map.remove('id'); // AUTOINCREMENT
    return await db.insert('hifz_plans', map);
  }

  Future<int> updatePlan(HifzPlanModel plan) async {
    final db = await _getDb();
    return await db.update(
      'hifz_plans',
      plan.toMap(),
      where: 'id = ?',
      whereArgs: [plan.id],
    );
  }

  Future<int> deletePlan(int planId) async {
    final db = await _getDb();
    return await db.delete(
      'hifz_plans',
      where: 'id = ?',
      whereArgs: [planId],
    );
  }

  // --- Hifz Items CRUD ---

  Future<List<HifzItemModel>> getHifzItems() async {
    final db = await _getDb();
    final maps = await db.query('hifz_items');
    return maps.map((m) => HifzItemModel.fromMap(m)).toList();
  }

  Future<HifzItemModel?> getHifzItem(String verseKey) async {
    final db = await _getDb();
    final maps = await db.query(
      'hifz_items',
      where: 'verseKey = ?',
      whereArgs: [verseKey],
    );
    if (maps.isEmpty) return null;
    return HifzItemModel.fromMap(maps.first);
  }

  Future<void> upsertHifzItem(HifzItemModel item) async {
    final db = await _getDb();
    await db.insert(
      'hifz_items',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteHifzItem(String verseKey) async {
    final db = await _getDb();
    await db.delete(
      'hifz_items',
      where: 'verseKey = ?',
      whereArgs: [verseKey],
    );
  }
}
