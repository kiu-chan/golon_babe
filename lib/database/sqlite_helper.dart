import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/tree_model.dart';

class SQLiteHelper {
  static Database? _database;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = await getDatabasesPath();
    return await openDatabase(
      join(path, 'tree_database.db'),
      onCreate: (db, version) async {
        // Bảng master_tree_info
        await db.execute('''
          CREATE TABLE master_tree_info (
            id INTEGER PRIMARY KEY,
            tree_type TEXT NOT NULL,
            scientific_name TEXT,
            tay_name TEXT,
            branch TEXT,
            class TEXT,
            division TEXT,
            family TEXT,
            genus TEXT,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        // Bảng tree_details
        await db.execute('''
          CREATE TABLE tree_details (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            master_tree_id INTEGER NOT NULL,
            coordinate_x REAL,
            coordinate_y REAL,
            height REAL,
            trunk_diameter REAL,
            canopy_coverage TEXT,
            sea_level_height REAL,
            image_base64 TEXT,
            notes TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
            sync_status TEXT DEFAULT 'pending',
            FOREIGN KEY (master_tree_id) REFERENCES master_tree_info (id)
          )
        ''');

        await db.execute('CREATE INDEX idx_master_tree_id ON tree_details(master_tree_id)');
        await db.execute('CREATE INDEX idx_sync_status ON tree_details(sync_status)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Xử lý nâng cấp database nếu cần
      },
      version: 1,
    );
  }

  // CRUD cho master_tree_info
  Future<void> insertMasterTreeInfo(List<Map<String, dynamic>> trees) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        // Xóa dữ liệu cũ
        await txn.delete('master_tree_info');
        
        // Thêm dữ liệu mới
        for (var tree in trees) {
          await txn.insert(
            'master_tree_info',
            {
              'id': tree['id'],
              'tree_type': tree['tree_type'],
              'scientific_name': tree['scientific_name'],
              'tay_name': tree['tay_name'],
              'branch': tree['branch'],
              'class': tree['class'],
              'division': tree['division'],
              'family': tree['family'],
              'genus': tree['genus'],
              'updated_at': DateTime.now().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
      print('Đã lưu ${trees.length} bản ghi master tree vào local');
    } catch (e) {
      print('Lỗi khi lưu master tree vào local: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllMasterTreeInfo() async {
    try {
      final db = await database;
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM master_tree_info')
      );
      print('Số lượng master tree trong local: $count');
      
      final results = await db.query('master_tree_info', orderBy: 'tree_type');
      return results;
    } catch (e) {
      print('Lỗi khi lấy master tree từ local: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getMasterTreeInfoById(int id) async {
    try {
      final db = await database;
      final results = await db.query(
        'master_tree_info',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      print('Lỗi khi lấy master tree by id từ local: $e');
      return null;
    }
  }

  // CRUD cho tree_details
  Future<int> insertTreeDetail(Map<String, dynamic> detail) async {
    try {
      final db = await database;
      return await db.insert(
        'tree_details',
        {
          ...detail,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'sync_status': 'pending',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Lỗi khi thêm tree detail vào local: $e');
      rethrow;
    }
  }

  Future<bool> updateTreeDetail(int id, Map<String, dynamic> detail) async {
    try {
      final db = await database;
      final count = await db.update(
        'tree_details',
        {
          ...detail,
          'updated_at': DateTime.now().toIso8601String(),
          'sync_status': 'pending',
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      return count > 0;
    } catch (e) {
      print('Lỗi khi cập nhật tree detail trong local: $e');
      return false;
    }
  }

  Future<TreeDetails?> getTreeDetailsById(int id) async {
    try {
      final db = await database;
      
      // Lấy chi tiết cây
      final detailsResult = await db.query(
        'tree_details',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (detailsResult.isEmpty) return null;

      // Lấy thông tin master tree
      final masterResult = await db.query(
        'master_tree_info',
        where: 'id = ?',
        whereArgs: [detailsResult.first['master_tree_id']],
      );

      final combinedData = {
        ...detailsResult.first,
        if (masterResult.isNotEmpty) ...masterResult.first,
      };
      print('Lấy chi tiết cây từ local...');

      return TreeDetails.fromJson(combinedData);
    } catch (e) {
      print('Lỗi khi lấy tree detail từ local: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllTreeDetails() async {
    try {
      final db = await database;
      final results = await db.rawQuery('''
        SELECT td.*, mti.*
        FROM tree_details td
        LEFT JOIN master_tree_info mti ON td.master_tree_id = mti.id
        ORDER BY td.created_at DESC
      ''');
      return results;
    } catch (e) {
      print('Lỗi khi lấy tất cả tree details từ local: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPendingSyncTreeDetails() async {
    try {
      final db = await database;
      final results = await db.query(
        'tree_details',
        where: 'sync_status = ?',
        whereArgs: ['pending'],
        orderBy: 'created_at ASC',
      );
      print('Số lượng tree details cần đồng bộ: ${results.length}');
      return results;
    } catch (e) {
      print('Lỗi khi lấy pending tree details từ local: $e');
      return [];
    }
  }

  Future<void> markAsSynced(int id) async {
    try {
      final db = await database;
      await db.update(
        'tree_details',
        {
          'sync_status': 'synced',
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('Lỗi khi đánh dấu đã sync: $e');
      rethrow;
    }
  }

  Future<void> deleteTreeDetail(int id) async {
    try {
      final db = await database;
      await db.delete(
        'tree_details',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('Lỗi khi xóa tree detail từ local: $e');
      rethrow;
    }
  }

  // Utility methods
  Future<void> clearAllData() async {
    try {
      final db = await database;
      await db.delete('tree_details');
      await db.delete('master_tree_info');
      print('Đã xóa tất cả dữ liệu local');
    } catch (e) {
      print('Lỗi khi xóa dữ liệu local: $e');
      rethrow;
    }
  }

  Future<bool> hasData() async {
    try {
      final db = await database;
      final masterCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM master_tree_info')
      ) ?? 0;
      return masterCount > 0;
    } catch (e) {
      print('Lỗi khi kiểm tra dữ liệu local: $e');
      return false;
    }
  }

  Future<void> vacuum() async {
    try {
      final db = await database;
      await db.execute('VACUUM');
    } catch (e) {
      print('Lỗi khi vacuum database: $e');
    }
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}