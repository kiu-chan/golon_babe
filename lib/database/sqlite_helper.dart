import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/tree_model.dart';

class SQLiteHelper {
  static Database? _database;
  static final SQLiteHelper _instance = SQLiteHelper._internal();
  
  factory SQLiteHelper() => _instance;
  SQLiteHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = await getDatabasesPath();
    String dbPath = join(path, 'trees_database.db');
    
    print('Khởi tạo database tại: $dbPath');

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (Database db, int version) async {
        print('Tạo các bảng database...');
        
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
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
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
              ON DELETE CASCADE
              ON UPDATE CASCADE
          )
        ''');

        // Tạo các indexes để tối ưu truy vấn
        await db.execute('CREATE INDEX idx_master_tree_id ON tree_details(master_tree_id)');
        await db.execute('CREATE INDEX idx_sync_status ON tree_details(sync_status)');
        await db.execute('CREATE INDEX idx_created_at ON tree_details(created_at)');
        
        print('Đã tạo xong cấu trúc database');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print('Nâng cấp database từ version $oldVersion lên $newVersion');
      },
      onOpen: (db) {
        print('Đã mở database thành công');
      },
    );
  }

  // CRUD cho master_tree_info
Future<void> insertMasterTreeInfo(List<Map<String, dynamic>> trees) async {
  final db = await database;
  await db.transaction((txn) async {
    try {
      print('Bắt đầu thêm ${trees.length} master trees...');
      
      // KHÔNG xóa dữ liệu cũ nếu danh sách mới trống
      if (trees.isEmpty) {
        print('Danh sách master trees trống, giữ lại dữ liệu cũ');
        return;
      }
      
      // Xóa dữ liệu cũ chỉ khi có dữ liệu mới
      await txn.delete('master_tree_info');
      print('Đã xóa dữ liệu master trees cũ');
      
      // Thêm từng cây mới
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
      
      // Kiểm tra số lượng sau khi thêm
      final count = Sqflite.firstIntValue(
        await txn.rawQuery('SELECT COUNT(*) FROM master_tree_info')
      );
      print('Số lượng master trees sau khi thêm: $count');
      
    } catch (e) {
      print('Lỗi khi thêm master trees: $e');
      print('Stack trace: ${StackTrace.current}');
      throw e;
    }
  });
}

  Future<List<Map<String, dynamic>>> getAllMasterTreeInfo() async {
    try {
      final db = await database;
      final results = await db.query(
        'master_tree_info',
        orderBy: 'tree_type ASC',
      );
      print('Đã lấy ${results.length} master trees từ local');
      return results;
    } catch (e) {
      print('Lỗi khi lấy master trees: $e');
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
      if (results.isNotEmpty) {
        print('Đã tìm thấy master tree ID $id');
      } else {
        print('Không tìm thấy master tree ID $id');
      }
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      print('Lỗi khi lấy master tree by id: $e');
      return null;
    }
  }

  // CRUD cho tree_details
  Future<int> insertTreeDetail(Map<String, dynamic> detail) async {
    try {
      final db = await database;
      int id = 0;
      
      await db.transaction((txn) async {
        print('Đang thêm chi tiết cây mới...');

        // Xử lý ảnh base64
        String? imageBase64 = detail['image_base64'];
        if (imageBase64 != null && imageBase64.contains(',')) {
          imageBase64 = imageBase64.split(',')[1];
        }

        final insertData = {
          if (detail['id'] != null) 'id': detail['id'],
          'master_tree_id': detail['master_tree_id'],
          'coordinate_x': detail['coordinate_x'],
          'coordinate_y': detail['coordinate_y'],
          'height': detail['height'],
          'trunk_diameter': detail['trunk_diameter'],
          'canopy_coverage': detail['canopy_coverage'],
          'sea_level_height': detail['sea_level_height'],
          'image_base64': imageBase64,
          'notes': detail['notes'],
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'sync_status': detail['sync_status'] ?? 'pending',
        };

        id = await txn.insert(
          'tree_details',
          insertData,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });

      print('Đã thêm chi tiết cây với ID: $id');
      return id;
    } catch (e) {
      print('Lỗi khi thêm chi tiết cây: $e');
      print('Stack trace: ${StackTrace.current}');
      throw e;
    }
  }

Future<bool> updateTreeDetail(int id, Map<String, dynamic> detail) async {
  try {
    final db = await database;
    print('\n=== CẬP NHẬT CÂY TRONG SQLITE ===');
    print('ID cây cần cập nhật: $id');

    // Kiểm tra sự tồn tại của bản ghi
    final exists = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM tree_details WHERE id = ?', [id]
    ));
    
    if (exists == 0) {
      print('Cây ID $id không tồn tại trong SQLite, thử thêm mới...');
      detail['id'] = id;
      final insertId = await insertTreeDetail(detail);
      return insertId > 0;
    }

    print('Cây ID $id tồn tại, tiến hành cập nhật...');
    
    // Đảm bảo dữ liệu cập nhật có đầy đủ thông tin
    final updateData = Map<String, dynamic>.from(detail);
    updateData['updated_at'] = DateTime.now().toIso8601String();
    updateData['sync_status'] = 'pending'; // Đánh dấu cần đồng bộ

    // Xử lý ảnh base64
    if (updateData['image_base64'] != null && 
        updateData['image_base64'].toString().contains(',')) {
      updateData['image_base64'] = 
        updateData['image_base64'].toString().split(',')[1];
    }

    // Loại bỏ các trường null để tránh ghi đè giá trị cũ bằng null
    updateData.removeWhere((key, value) => value == null);

    print('Dữ liệu cập nhật đã xử lý:');
    updateData.forEach((key, value) {
      if (key != 'image_base64') {
        print('$key: $value');
      } else {
        print('image_base64: [${value != null ? 'Có ảnh' : 'Không có ảnh'}]');
      }
    });

    int count = await db.transaction((txn) async {
      return await txn.update(
        'tree_details',
        updateData,
        where: 'id = ?',
        whereArgs: [id],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    print('Kết quả cập nhật: ${count > 0 ? "thành công" : "thất bại"}');
    return count > 0;

  } catch (e) {
    print('Lỗi khi cập nhật SQLite:');
    print(e.toString());
    print('Stack trace:');
    print(StackTrace.current);
    return false;
  }
}

  Future<TreeDetails?> getTreeDetailsById(int id) async {
    try {
      final db = await database;
      print('Truy vấn chi tiết cây ID $id từ SQLite...');
      
      final results = await db.rawQuery('''
        SELECT td.*, mti.*
        FROM tree_details td
        LEFT JOIN master_tree_info mti ON td.master_tree_id = mti.id
        WHERE td.id = ?
      ''', [id]);

      if (results.isEmpty) {
        print('Không tìm thấy cây ID $id trong SQLite');
        return null;
      }

      final row = results.first;
      print('Đã tìm thấy cây ID $id trong SQLite');

      // Tạo đối tượng MasterTreeInfo
      final masterInfo = row['master_tree_id'] != null ? MasterTreeInfo(
        id: row['master_tree_id'] as int,
        treeType: row['tree_type'] as String? ?? '',
        scientificName: row['scientific_name'] as String?,
        tayName: row['tay_name'] as String?,
        branch: row['branch'] as String?,
        treeClass: row['class'] as String?,
        division: row['division'] as String?,
        family: row['family'] as String?,
        genus: row['genus'] as String?,
      ) : null;

      // Tạo đối tượng TreeDetails
      return TreeDetails(
        id: row['id'] as int,
        masterTreeId: row['master_tree_id'] as int,
        coordinateX: row['coordinate_x'] != null ? 
          double.parse(row['coordinate_x'].toString()) : null,
        coordinateY: row['coordinate_y'] != null ? 
          double.parse(row['coordinate_y'].toString()) : null,
        height: row['height'] != null ? 
          double.parse(row['height'].toString()) : null,
        diameter: row['trunk_diameter'] != null ? 
          double.parse(row['trunk_diameter'].toString()) : null,
        coverLevel: row['canopy_coverage'] as String?,
        seaLevel: row['sea_level_height'] != null ? 
          double.parse(row['sea_level_height'].toString()) : null,
        imageBase64: row['image_base64'] as String?,
        note: row['notes'] as String?,
        masterInfo: masterInfo,
      );
    } catch (e) {
      print('Lỗi khi truy vấn SQLite:');
      print(e.toString());
      print('Stack trace:');
      print(StackTrace.current);
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
      
      print('Đã lấy ${results.length} chi tiết cây từ local');
      return results;
    } catch (e) {
      print('Lỗi khi lấy tất cả chi tiết cây: $e');
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
      print('Có ${results.length} chi tiết cây đang chờ đồng bộ');
      return results;
    } catch (e) {
      print('Lỗi khi lấy danh sách cây chờ đồng bộ: $e');
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
      print('Đã đánh dấu đồng bộ cho cây ID $id');
    } catch (e) {
      print('Lỗi khi đánh dấu đồng bộ: $e');
      throw e;
    }
  }

  Future<bool> deleteTreeDetail(int id) async {
    try {
      final db = await database;
      final count = await db.delete(
        'tree_details',
        where: 'id = ?',
        whereArgs: [id],
      );
      print('Đã xóa chi tiết cây ID $id: ${count > 0 ? "thành công" : "thất bại"}');
      return count > 0;
    } catch (e) {
      print('Lỗi khi xóa chi tiết cây: $e');
      return false;
    }
  }

  // Clear data methods
  Future<void> clearAllData() async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        await txn.delete('tree_details');
        await txn.delete('master_tree_info');
      });
      print('Đã xóa toàn bộ dữ liệu local');
    } catch (e) {
      print('Lỗi khi xóa dữ liệu: $e');
      throw e;
    }
  }

  Future<void> clearTreeDetails() async {
    try {
      final db = await database;
      await db.delete('tree_details');
      print('Đã xóa dữ liệu chi tiết cây');
    } catch (e) {
      print('Lỗi khi xóa chi tiết cây: $e');
      throw e;
    }
  }

  Future<void> clearSyncedTreeDetails() async {
    try {
      final db = await database;
      await db.delete(
        'tree_details',
        where: 'sync_status = ?',
        whereArgs: ['synced']
      );
      print('Đã xóa các chi tiết cây đã đồng bộ');
    } catch (e) {
      print('Lỗi khi xóa chi tiết cây đã đồng bộ: $e');
      throw e;
    }
  }

  // Utility methods
  Future<bool> hasData() async {
    try {
      final db = await database;
      final masterCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM master_tree_info')
      ) ?? 0;
      final detailCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM tree_details')
      ) ?? 0;
      
      print('Số lượng master trees: $masterCount');
      print('Số lượng chi tiết cây: $detailCount');
      
      return masterCount > 0 || detailCount > 0;
    } catch (e) {
      print('Lỗi khi kiểm tra dữ liệu: $e');
      return false;
    }
  }

  Future<void> checkLocalData() async {
    try {
      final db = await database;
      
      // Kiểm tra master trees
      final masterCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM master_tree_info')
      );
      print('\n=== THÔNG TIN DỮ LIỆU LOCAL ===');
      print('Số lượng master trees: $masterCount');
      
      // In ra một số master trees đầu tiên
      if (masterCount! > 0) {
        final masterTrees = await db.query('master_tree_info', limit: 3);
        print('\nMẫu master trees:');
        for (var tree in masterTrees) {
          print('''
            ID: ${tree['id']}
            Loại: ${tree['tree_type']}
            Tên KH: ${tree['scientific_name']}
            Tên Tày: ${tree['tay_name']}
          ''');
        }
      }
      
      // Kiểm tra tree details
      final detailCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM tree_details')
      );
      print('\nSố lượng chi tiết cây: $detailCount');
      
      // In ra một số chi tiết cây đầu tiên
      if (detailCount! > 0) {
        final details = await db.rawQuery('''
          SELECT td.*, mti.tree_type
          FROM tree_details td
          JOIN master_tree_info mti ON td.master_tree_id = mti.id
          LIMIT 3
        ''');
        print('\nMẫu chi tiết cây:');
        for (var detail in details) {
          print('''
            ID: ${detail['id']}
            Loại cây: ${detail['tree_type']}
            Tọa độ: (${detail['coordinate_x']}, ${detail['coordinate_y']})
            Chiều cao: ${detail['height']}m
            Đường kính: ${detail['trunk_diameter']}cm
            Độ che phủ: ${detail['canopy_coverage']}
            Độ cao mặt biển: ${detail['sea_level_height']}m
            Trạng thái đồng bộ: ${detail['sync_status']}
          ''');
        }
      }
      
      // Kiểm tra trạng thái đồng bộ
      final pendingCount = Sqflite.firstIntValue(
        await db.rawQuery(
          "SELECT COUNT(*) FROM tree_details WHERE sync_status = 'pending'"
        )
      );
      print('\nSố lượng cây chờ đồng bộ: $pendingCount');
      
      print('=== KẾT THÚC KIỂM TRA ===\n');
    } catch (e) {
      print('Lỗi khi kiểm tra dữ liệu local: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> printTableInfo() async {
    try {
      final db = await database;
      
      print('\n=== THÔNG TIN CẤU TRÚC DATABASE ===');
      
      // In thông tin bảng master_tree_info
      final masterInfo = await db.rawQuery('''
        SELECT sql FROM sqlite_master 
        WHERE type='table' AND name='master_tree_info'
      ''');
      print('\nCấu trúc bảng master_tree_info:');
      print(masterInfo.first['sql']);
      
      // In thông tin bảng tree_details  
      final detailsInfo = await db.rawQuery('''
        SELECT sql FROM sqlite_master 
        WHERE type='table' AND name='tree_details'
      ''');
      print('\nCấu trúc bảng tree_details:');
      print(detailsInfo.first['sql']);
      
      // In thông tin các indexes
      final indexes = await db.rawQuery('''
        SELECT name, sql FROM sqlite_master 
        WHERE type='index' AND sql IS NOT NULL
      ''');
      print('\nDanh sách indexes:');
      for (var idx in indexes) {
        print('- ${idx['name']}: ${idx['sql']}');
      }
      
      print('\n=== KẾT THÚC THÔNG TIN CẤU TRÚC ===\n');
    } catch (e) {
      print('Lỗi khi in thông tin cấu trúc: $e');
    }
  }

  Future<void> vacuum() async {
    try {
      final db = await database;
      await db.execute('VACUUM');
      print('Đã dọn dẹp database');
    } catch (e) {
      print('Lỗi khi dọn dẹp database: $e');
    }
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      print('Đã đóng kết nối database');
    }
  }
  }