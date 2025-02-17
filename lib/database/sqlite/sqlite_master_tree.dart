import 'package:sqflite/sqflite.dart';
import 'sqlite_core.dart';

class SQLiteMasterTree {
  final SQLiteCore _core;

  SQLiteMasterTree(this._core);

  Future<void> insertMasterTreeInfo(List<Map<String, dynamic>> trees) async {
    final db = await _core.database;
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
      final db = await _core.database;
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
      final db = await _core.database;
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
}