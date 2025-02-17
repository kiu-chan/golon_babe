import 'package:golon_babe/models/tree_model.dart';
import 'package:sqflite/sqflite.dart';
import 'sqlite_core.dart';

class SQLiteTreeDetails {
  final SQLiteCore _core;

  SQLiteTreeDetails(this._core);

  // Thêm chi tiết cây mới
  Future<int> insertTreeDetail(Map<String, dynamic> detail) async {
    try {
      final db = await _core.database;
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

  // Cập nhật chi tiết cây
  Future<bool> updateTreeDetail(int id, Map<String, dynamic> detail) async {
    try {
      final db = await _core.database;
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

  // Lấy chi tiết cây theo ID
Future<Map<String, dynamic>?> getTreeDetailsById(int id) async {
  try {
    final db = await _core.database;
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

    print('Đã tìm thấy cây ID $id trong SQLite');
    return results.first; // Trả về Map trực tiếp thay vì TreeDetails

  } catch (e) {
    print('Lỗi khi truy vấn SQLite:');
    print(e.toString());
    print('Stack trace:');
    print(StackTrace.current);
    return null;
  }
}

  // Lấy tất cả chi tiết cây
  Future<List<Map<String, dynamic>>> getAllTreeDetails() async {
    try {
      final db = await _core.database;
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

  // Lấy danh sách cây chờ đồng bộ
  Future<List<Map<String, dynamic>>> getPendingSyncTreeDetails() async {
    try {
      final db = await _core.database;
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

  // Đánh dấu cây đã đồng bộ
  Future<void> markAsSynced(int id) async {
    try {
      final db = await _core.database;
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

  // Xóa chi tiết cây
  Future<bool> deleteTreeDetail(int id) async {
    try {
      final db = await _core.database;
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

  // Xóa tất cả chi tiết cây
  Future<void> clearTreeDetails() async {
    try {
      final db = await _core.database;
      await db.delete('tree_details');
      print('Đã xóa dữ liệu chi tiết cây');
    } catch (e) {
      print('Lỗi khi xóa chi tiết cây: $e');
      throw e;
    }
  }

  // Xóa các chi tiết cây đã đồng bộ
  Future<void> clearSyncedTreeDetails() async {
    try {
      final db = await _core.database;
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

  // Kiểm tra dữ liệu
  Future<void> checkTreeDetails() async {
    try {
      final db = await _core.database;
      
      final detailCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM tree_details')
      );
      print('\nSố lượng chi tiết cây: $detailCount');
      
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
      
      final pendingCount = Sqflite.firstIntValue(
        await db.rawQuery(
          "SELECT COUNT(*) FROM tree_details WHERE sync_status = 'pending'"
        )
      );
      print('\nSố lượng cây chờ đồng bộ: $pendingCount');
      
    } catch (e) {
      print('Lỗi khi kiểm tra chi tiết cây: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }
}