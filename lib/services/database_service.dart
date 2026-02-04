import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/activity_log.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'smart_garage.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE activity_logs (
        id TEXT PRIMARY KEY,
        message TEXT NOT NULL,
        source TEXT NOT NULL,
        type TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  // Insert a new activity log
  Future<void> insertLog(ActivityLog log) async {
    final db = await database;
    await db.insert(
      'activity_logs',
      log.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all logs (sorted by newest first)
  Future<List<ActivityLog>> getAllLogs({int? limit}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'activity_logs',
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return List.generate(maps.length, (i) {
      return ActivityLog(
        id: maps[i]['id'],
        message: maps[i]['message'],
        source: maps[i]['source'],
        type: maps[i]['type'],
        timestamp: DateTime.parse(maps[i]['timestamp']),
      );
    });
  }

  // Get logs by date range
  Future<List<ActivityLog>> getLogsByDateRange(DateTime start, DateTime end) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'activity_logs',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) {
      return ActivityLog(
        id: maps[i]['id'],
        message: maps[i]['message'],
        source: maps[i]['source'],
        type: maps[i]['type'],
        timestamp: DateTime.parse(maps[i]['timestamp']),
      );
    });
  }

  // Delete old logs (keep only last N days)
  Future<void> deleteOldLogs(int daysToKeep) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    await db.delete(
      'activity_logs',
      where: 'timestamp < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  // Clear all logs
  Future<void> clearAllLogs() async {
    final db = await database;
    await db.delete('activity_logs');
  }

  // Get log count
  Future<int> getLogCount() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM activity_logs'),
    );
    return count ?? 0;
  }
}
