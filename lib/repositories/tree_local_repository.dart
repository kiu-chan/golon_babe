import '../database/sqlite_helper.dart';
import '../models/tree_model.dart';

class TreeLocalRepository {
  final SQLiteHelper _localDb;

  TreeLocalRepository(this._localDb);

  // Lấy danh sách cây mẫu từ local
  Future<List<MasterTreeInfo>> getLocalMasterTreeInfo() async {
    try {
      print('\n=== LẤY DANH SÁCH CÂY MẪU TỪ LOCAL ===');
      final localData = await _localDb.getAllMasterTreeInfo();
      
      if (localData.isNotEmpty) {
        print('Tìm thấy ${localData.length} master trees trong local');
      } else {
        print('Không có master trees trong local');
      }
      
      return localData.map((json) => MasterTreeInfo.fromJson(json)).toList();
    } catch (e) {
      print('Lỗi khi lấy dữ liệu từ local: $e');
      return [];
    }
  }

  // Lưu danh sách cây mẫu vào local
  Future<void> saveMasterTreeInfo(List<Map<String, dynamic>> trees) async {
    try {
      print('\n=== LƯU DANH SÁCH CÂY MẪU VÀO LOCAL ===');
      await _localDb.insertMasterTreeInfo(trees);
      print('Đã lưu ${trees.length} loại cây vào local');
    } catch (e) {
      print('Lỗi khi lưu master trees: $e');
    }
  }

  // Lấy chi tiết cây theo ID từ local
  Future<TreeDetails?> getTreeDetailsById(int id) async {
    try {
      print('\n=== LẤY CHI TIẾT CÂY TỪ LOCAL ===');
      final localData = await _localDb.getTreeDetailsById(id);
      if (localData != null) {
        print('Đã tìm thấy cây ID: $id trong local');
        return TreeDetails.fromJson(localData);
      }
      print('Không tìm thấy cây ID: $id trong local');
      return null;
    } catch (e) {
      print('Lỗi khi lấy chi tiết cây từ local: $e');
      return null;
    }
  }

  // Lưu chi tiết cây vào local
  Future<bool> saveTreeDetail(TreeDetails tree, {String syncStatus = 'pending'}) async {
    try {
      print('\n=== LƯU CHI TIẾT CÂY VÀO LOCAL ===');
      final data = {
        'id': tree.id,
        'master_tree_id': tree.masterTreeId,
        'coordinate_x': tree.coordinateX,
        'coordinate_y': tree.coordinateY,
        'height': tree.height,
        'trunk_diameter': tree.diameter,
        'canopy_coverage': tree.coverLevel,
        'sea_level_height': tree.seaLevel,
        'image_base64': tree.imageBase64,
        'notes': tree.note,
        'sync_status': syncStatus
      };

      if (tree.id != null) {
        print('Cập nhật cây ID: ${tree.id}');
        return await _localDb.updateTreeDetail(tree.id!, data);
      } else {
        print('Thêm cây mới');
        final id = await _localDb.insertTreeDetail(data);
        return id > 0;
      }
    } catch (e) {
      print('Lỗi khi lưu chi tiết cây vào local: $e');
      return false;
    }
  }

  // Lấy các bản ghi chưa đồng bộ
  Future<List<Map<String, dynamic>>> getPendingSyncDetails() async {
    try {
      return await _localDb.getPendingSyncTreeDetails();
    } catch (e) {
      print('Lỗi khi lấy bản ghi chưa đồng bộ: $e');
      return [];
    }
  }

  // Đánh dấu đã đồng bộ
  Future<void> markAsSynced(int id) async {
    try {
      await _localDb.updateTreeDetail(id, {'sync_status': 'synced'});
    } catch (e) {
      print('Lỗi khi đánh dấu đã đồng bộ: $e');
    }
  }

  // Đánh dấu để xóa
  Future<void> markForDeletion(int id) async {
    try {
      await _localDb.updateTreeDetail(id, {'sync_status': 'delete_pending'});
    } catch (e) {
      print('Lỗi khi đánh dấu xóa: $e');
    }
  }

  // Xóa chi tiết cây
  Future<void> deleteTreeDetail(int id) async {
    try {
      await _localDb.deleteTreeDetail(id);
    } catch (e) {
      print('Lỗi khi xóa cây từ local: $e');
    }
  }

  // Xóa các bản ghi đã đồng bộ
  Future<void> clearSyncedDetails() async {
    try {
      await _localDb.clearSyncedTreeDetails();
    } catch (e) {
      print('Lỗi khi xóa bản ghi đã đồng bộ: $e');
    }
  }

  // Xóa tất cả dữ liệu
  Future<void> clearAllData() async {
    try {
      await _localDb.clearAllData();
      print('Đã xóa tất cả dữ liệu local');
    } catch (e) {
      print('Lỗi khi xóa dữ liệu local: $e');
    }
  }

  // In thông tin dữ liệu đã lưu
  Future<void> printSavedData() async {
    try {
      final masterTrees = await _localDb.getAllMasterTreeInfo();
      print('\n-> Danh sách loại cây (${masterTrees.length} loại):');
      for (var tree in masterTrees) {
        print('''
          ID: ${tree['id']}
          Tên: ${tree['tree_type']}
          Tên KH: ${tree['scientific_name']}
          Tên Tày: ${tree['tay_name']}
        ''');
      }

      final treeDetails = await _localDb.getAllTreeDetails();
      print('\n-> Chi tiết các cây (${treeDetails.length} cây):');
      for (var detail in treeDetails) {
        print('''
          ID: ${detail['id']}
          Loại cây: ${detail['tree_type']}
          Tọa độ: (${detail['coordinate_x']}, ${detail['coordinate_y']})
          Kích thước: ${detail['height']}m cao, ${detail['trunk_diameter']}cm đường kính
          Độ che phủ: ${detail['canopy_coverage']}
          Cao so với mực nước biển: ${detail['sea_level_height']}m
          Trạng thái đồng bộ: ${detail['sync_status']}
          Có ảnh: ${detail['image_base64'] != null}
          ===================
        ''');
      }
    } catch (e) {
      print('Lỗi khi in thông tin dữ liệu: $e');
    }
  }

  // In thông tin debug
  Future<void> printDebugInfo() async {
    try {
      await _localDb.checkLocalData();
      await _localDb.printTableInfo();
    } catch (e) {
      print('Lỗi khi in thông tin debug: $e');
    }
  }

  // Kiểm tra có dữ liệu
  Future<bool> hasData() async {
    return await _localDb.hasData();
  }
}