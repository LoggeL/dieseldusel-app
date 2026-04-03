import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/fuel_log.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'dieseldusel.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE fuel_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT,
            total_km INTEGER,
            trip_km REAL,
            liters REAL,
            costs REAL,
            euro_per_liter REAL,
            consumption REAL,
            note TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        ''');
      },
    );
  }

  Future<int> insertLog(FuelLog log) async {
    final db = await database;
    return await db.insert('fuel_logs', log.toMap());
  }

  Future<int> updateLog(FuelLog log) async {
    final db = await database;
    return await db.update(
      'fuel_logs',
      log.toMap(),
      where: 'id = ?',
      whereArgs: [log.id],
    );
  }

  Future<int> deleteLog(int id) async {
    final db = await database;
    return await db.delete('fuel_logs', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<FuelLog>> getAllLogs() async {
    final db = await database;
    final maps = await db.query('fuel_logs', orderBy: 'date DESC, id DESC');
    return maps.map((map) => FuelLog.fromMap(map)).toList();
  }

  Future<FuelLog?> getLastLog() async {
    final db = await database;
    final maps = await db.query('fuel_logs', orderBy: 'date DESC, id DESC', limit: 1);
    if (maps.isEmpty) return null;
    return FuelLog.fromMap(maps.first);
  }

  Future<Map<String, double>> getStats() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        COALESCE(SUM(costs), 0) as total_costs,
        COALESCE(SUM(liters), 0) as total_liters,
        COALESCE(AVG(consumption), 0) as avg_consumption,
        COALESCE(AVG(euro_per_liter), 0) as avg_price,
        COALESCE(SUM(trip_km), 0) as total_km
      FROM fuel_logs
    ''');
    final row = result.first;
    return {
      'total_costs': (row['total_costs'] as num).toDouble(),
      'total_liters': (row['total_liters'] as num).toDouble(),
      'avg_consumption': (row['avg_consumption'] as num).toDouble(),
      'avg_price': (row['avg_price'] as num).toDouble(),
      'total_km': (row['total_km'] as num).toDouble(),
    };
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('fuel_logs');
  }
}
