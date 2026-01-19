import 'package:e_repairkit/models/repair_suggestion.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class OfflineSearchService {
  static const _dbName = 'solutions.db';
  static const _tableName = 'suggestions';
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(_dbName);
    return _database!;
  }

  // Initialize the database and create the table
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // <--- 1. INCREMENT THIS (e.g., from 1 to 2)

      onCreate: (db, version) async {
        // This runs only for NEW installs
        await db.execute('''
          CREATE TABLE suggestions(
            id TEXT PRIMARY KEY, 
            query TEXT, 
            title TEXT, 
            deviceType TEXT,  -- <--- Ensure this is here for new users
            steps TEXT, 
            tools TEXT, 
            confidence REAL, 
            estimatedTimeMinutes INTEGER, 
            safetyNotes TEXT,
            keywords TEXT,
            tryCount INTEGER DEFAULT 0,
            avgRating REAL DEFAULT 0.0,
            ratingCount INTEGER DEFAULT 0,
            commentCount INTEGER DEFAULT 0
          )
        ''');
      },

      onUpgrade: (db, oldVersion, newVersion) async {
        // This runs for EXISTING users (Migration)
        if (oldVersion < 2) {
          // 2. ADD THE MISSING COLUMN
          await db.execute(
            "ALTER TABLE suggestions ADD COLUMN deviceType TEXT DEFAULT 'Other'",
          );
        }
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
      where: 'LOWER(title) LIKE ? OR keywords LIKE ? OR LOWER("query") LIKE ?',
      whereArgs: ['%$cleanQuery%', '%"$cleanQuery"%', '%$cleanQuery%'],
      orderBy: 'tryCount DESC',
    );

    return List.generate(maps.length, (i) {
      return RepairSuggestion.fromJson(maps[i]);
    });
  }

  Future<int> downloadTargetedSolutions(
    List<RepairSuggestion> forumSuggestions,
    List<String> userDeviceTypes,
  ) async {
    final db = await database;
    int saveCount = 0;
    final Batch batch = db.batch();

    // Convert user list to lowercase for easy comparison
    final selectedTypes = userDeviceTypes.map((e) => e.toLowerCase()).toList();

    for (var suggestion in forumSuggestions) {
      // 1. THE FILTER: Check if suggestion type is in the user's list
      bool isMatch = selectedTypes.contains(
        suggestion.deviceType.toLowerCase(),
      );

      if (isMatch) {
        batch.insert(
          _tableName,
          suggestion.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        saveCount++;
      }
    }

    await batch.commit(noResult: true);
    return saveCount;
  }
}
