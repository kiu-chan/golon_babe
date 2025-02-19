import 'package:golon_babe/database/sqlite/sqlite_additional_images.dart';
import 'package:golon_babe/database/sqlite/sqlite_core.dart';
import 'package:golon_babe/database/sqlite/sqlite_master_tree.dart';
import 'package:golon_babe/database/sqlite/sqlite_tree_details.dart';
import 'package:sqflite/sqflite.dart';

class SQLiteHelper {
  static final SQLiteHelper _instance = SQLiteHelper._internal();
  final SQLiteCore _core = SQLiteCore();
  late final SQLiteMasterTree masterTree;
  late final SQLiteTreeDetails treeDetails;
  late final SQLiteAdditionalImages additionalImages;
  
  factory SQLiteHelper() => _instance;
  
  SQLiteHelper._internal() {
    masterTree = SQLiteMasterTree(_core);
    treeDetails = SQLiteTreeDetails(_core);
    additionalImages = SQLiteAdditionalImages(_core);
  }

  // Kiểm tra database đã có dữ liệu chưa
  Future<bool> hasData() async {
    try {
      final db = await _core.database;
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

  // Kiểm tra dữ liệu trong database
  Future<void> checkLocalData() async {
    try {
      final db = await _core.database;
      
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
      
      await treeDetails.checkTreeDetails();
      
      print('=== KẾT THÚC KIỂM TRA ===\n');
    } catch (e) {
      print('Lỗi khi kiểm tra dữ liệu local: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  // Các phương thức wrapper cho master tree info
  Future<List<Map<String, dynamic>>> getAllMasterTreeInfo() async {
    return await masterTree.getAllMasterTreeInfo();
  }

  Future<Map<String, dynamic>?> getMasterTreeInfoById(int id) async {
    return await masterTree.getMasterTreeInfoById(id);
  }

  Future<void> insertMasterTreeInfo(List<Map<String, dynamic>> trees) async {
    await masterTree.insertMasterTreeInfo(trees);
  }

  // Các phương thức wrapper cho tree details
  Future<int> insertTreeDetail(Map<String, dynamic> detail) async {
    return await treeDetails.insertTreeDetail(detail);
  }

  Future<bool> updateTreeDetail(int id, Map<String, dynamic> detail) async {
    return await treeDetails.updateTreeDetail(id, detail);
  }

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
      return results.first;

    } catch (e) {
      print('Lỗi khi truy vấn SQLite:');
      print(e.toString());
      print('Stack trace:');
      print(StackTrace.current);
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllTreeDetails() async {
    return await treeDetails.getAllTreeDetails();
  }

  Future<List<Map<String, dynamic>>> getPendingSyncTreeDetails() async {
    return await treeDetails.getPendingSyncTreeDetails();
  }

  Future<void> markAsSynced(int id) async {
    await treeDetails.markAsSynced(id);
  }

  Future<bool> deleteTreeDetail(int id) async {
    return await treeDetails.deleteTreeDetail(id);
  }

  Future<void> clearTreeDetails() async {
    await treeDetails.clearTreeDetails();
  }

  Future<void> clearSyncedTreeDetails() async {
    await treeDetails.clearSyncedTreeDetails();
  }

  // Xóa toàn bộ dữ liệu
  Future<void> clearAllData() async {
    try {
      final db = await _core.database;
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

  // In thông tin cấu trúc database
  Future<void> printTableInfo() async {
    try {
      final db = await _core.database;
      
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

  Future<List<Map<String, dynamic>>> getPendingSyncImages() async {
    return await additionalImages.getPendingSyncImages();
  }

  Future<void> markImageAsSynced(int id) async {
    await additionalImages.markAsSynced(id);
  }

  Future<bool> deleteAdditionalImage(int id) async {
  return await additionalImages.deleteImage(id);
}

  // Đóng kết nối database
  Future<void> close() async {
    await _core.close();
  }
}