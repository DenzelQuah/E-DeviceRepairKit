import 'package:e_repairkit/models/repair_suggestion.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class OfflineSearchService {
  static const _dbName = 'solutions.db';
  static const _tableName = 'suggestions';
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  // Initialize the database and create the table
  Future<Database> _initDB() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _dbName);
    return await openDatabase(
      path,
      version: 1, // You MUST "Cold Boot" or "Uninstall" the app
      onCreate: (db, version) async {
        // --- THIS IS THE CRITICAL FIX ---
        // Added all the new community fields
        await db.execute('''
          CREATE TABLE $_tableName(
            id TEXT PRIMARY KEY,
            title TEXT,
            steps TEXT,
            tools TEXT,
            confidence REAL,
            estimatedTimeMinutes INTEGER,
            safetyNotes TEXT,
            "query" TEXT,
            keywords TEXT,
            tryCount INTEGER,
            avgRating REAL,
            ratingCount INTEGER,
            commentCount INTEGER
          )
        ''');
      },
    );
  }

  // Add a new suggestion to the local database
  Future<void> cacheSuggestion(RepairSuggestion suggestion) async {
    final db = await database;
    await db.insert(
      _tableName,
      suggestion.toJson(), // This will now work
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Fetches all saved suggestions from the database.
  Future<List<RepairSuggestion>> getAllSuggestions() async {
    final db = await database;
    // Order by tryCount, just like the forum
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'tryCount DESC',
    );
    return List.generate(maps.length, (i) {
      return RepairSuggestion.fromJson(maps[i]);
    });
  }

  // The powerful search function
  Future<List<RepairSuggestion>> searchOffline(String query) async {
    final db = await database;
    final cleanQuery = query.toLowerCase().trim();

    if (cleanQuery.isEmpty) {
      return getAllSuggestions();
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where:
          'LOWER(title) LIKE ? OR keywords LIKE ? OR LOWER("query") LIKE ?',
      whereArgs: [
        '%$cleanQuery%',
        '%"$cleanQuery"%',
        '%$cleanQuery%'
      ],
      orderBy: 'tryCount DESC',
    );

    return List.generate(maps.length, (i) {
      return RepairSuggestion.fromJson(maps[i]);
    });
  }
}
