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
      version: 4,
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
            consumption_bordcomputer REAL,
            note TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_fuel_logs_date ON fuel_logs(date)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE fuel_logs ADD COLUMN consumption_bordcomputer REAL',
          );
        }
        // Version 3: consumption column removed (not read/written anymore).
        // SQLite doesn't support DROP COLUMN — we simply stop using it.
        if (oldVersion < 4) {
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_fuel_logs_date ON fuel_logs(date)',
          );
        }
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
        -- BC weighted: sum(bc * trip_km) / sum(trip_km) for rows with BC
        COALESCE(
          CASE WHEN SUM(CASE WHEN consumption_bordcomputer IS NOT NULL THEN trip_km END) > 0
          THEN SUM(CASE WHEN consumption_bordcomputer IS NOT NULL THEN consumption_bordcomputer * trip_km END)
               / SUM(CASE WHEN consumption_bordcomputer IS NOT NULL THEN trip_km END)
          ELSE 0 END, 0) as avg_consumption_bc,
        COALESCE(AVG(euro_per_liter), 0) as avg_price,
        COALESCE(SUM(trip_km), 0) as total_km,
        COALESCE(SUM(liters), 0) as sum_liters,
        COALESCE(SUM(trip_km), 0) as sum_trip_km
      FROM fuel_logs
    ''');
    final row = result.first;
    final sumLiters = (row['sum_liters'] as num).toDouble();
    final sumTripKm = (row['sum_trip_km'] as num).toDouble();
    final avgConsumption = sumTripKm > 0 ? sumLiters / sumTripKm * 100 : 0.0;
    return {
      'total_costs': (row['total_costs'] as num).toDouble(),
      'total_liters': (row['total_liters'] as num).toDouble(),
      'avg_consumption': avgConsumption,
      'avg_consumption_bc': (row['avg_consumption_bc'] as num).toDouble(),
      'avg_price': (row['avg_price'] as num).toDouble(),
      'total_km': (row['total_km'] as num).toDouble(),
    };
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('fuel_logs');
  }
}
