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
    print('Đang thêm chi tiết cây vào local:');
    
    // Kiểm tra và xử lý image_base64
    String? imageBase64 = detail['image_base64'];
    if (imageBase64 != null && imageBase64.contains(',')) {
      // Nếu base64 có định dạng "data:image/xxx;base64,..." thì chỉ lấy phần base64
      imageBase64 = imageBase64.split(',')[1];
    }
    
    final insertData = {
      'id': detail['id'],
      'master_tree_id': detail['master_tree_id'],
      'coordinate_x': detail['coordinate_x'],
      'coordinate_y': detail['coordinate_y'],
      'height': detail['height'],
      'trunk_diameter': detail['trunk_diameter'],
      'canopy_coverage': detail['canopy_coverage'],
      'sea_level_height': detail['sea_level_height'], 
      'image_base64': imageBase64, // Lưu base64 đã được xử lý
      'notes': detail['notes'],
      'created_at': detail['created_at']?.toString(),
      'updated_at': detail['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
      'sync_status': detail['sync_status'] ?? 'pending',
    };

    print('Dữ liệu ảnh sẽ lưu: ${imageBase64?.substring(0, 50)}... (${imageBase64?.length} ký tự)');

    final id = await db.insert(
      'tree_details',
      insertData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print('Đã thêm chi tiết cây với id: $id');
    return id;
  } catch (e) {
    print('Lỗi khi thêm tree detail vào local: $e');
    print('Stack trace: ${StackTrace.current}');
    throw e;
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
    
    // Sửa lại câu query để JOIN đúng cách và lấy đầy đủ thông tin
    final results = await db.rawQuery('''
      SELECT td.*, mti.*
      FROM tree_details td
      INNER JOIN master_tree_info mti ON td.master_tree_id = mti.id
      WHERE td.id = ?
    ''', [id]);

    if (results.isEmpty) {
      print('Không tìm thấy chi tiết cây $id trong local database');
      return null;
    }

    print('Dữ liệu từ local database cho cây $id:');
    print(results.first);

    // Tạo MasterTreeInfo trước
    final masterInfo = MasterTreeInfo(
      id: results.first['master_tree_id'] as int,
      treeType: results.first['tree_type'] as String,
      scientificName: results.first['scientific_name'] as String?,
      tayName: results.first['tay_name'] as String?,
      branch: results.first['branch'] as String?,
      treeClass: results.first['class'] as String?,
      division: results.first['division'] as String?,
      family: results.first['family'] as String?,
      genus: results.first['genus'] as String?,
    );

    // Sau đó tạo TreeDetails với masterInfo
    return TreeDetails(
      id: results.first['id'] as int,
      masterTreeId: results.first['master_tree_id'] as int,
      coordinateX: results.first['coordinate_x'] != null ? 
        double.parse(results.first['coordinate_x'].toString()) : null,
      coordinateY: results.first['coordinate_y'] != null ? 
        double.parse(results.first['coordinate_y'].toString()) : null,
      height: results.first['height'] != null ? 
        double.parse(results.first['height'].toString()) : null,
      diameter: results.first['trunk_diameter'] != null ? 
        double.parse(results.first['trunk_diameter'].toString()) : null,
      coverLevel: results.first['canopy_coverage'] as String?,
      seaLevel: results.first['sea_level_height'] != null ? 
        double.parse(results.first['sea_level_height'].toString()) : null,
      imageBase64: results.first['image_base64'] as String?,
      note: results.first['notes'] as String?,
      masterInfo: masterInfo,
    );
  } catch (e) {
    print('Lỗi khi lấy chi tiết cây từ local database: $e');
    print('Stack trace: ${StackTrace.current}');
    return null;
  }
}


Future<List<Map<String, dynamic>>> getAllTreeDetails() async {
  try {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT td.*, mti.tree_type, mti.scientific_name, mti.tay_name,
             mti.branch, mti.class, mti.division, mti.family, mti.genus
      FROM tree_details td
      INNER JOIN master_tree_info mti ON td.master_tree_id = mti.id 
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