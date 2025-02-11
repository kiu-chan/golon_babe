import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:golon_babe/database/database_helper.dart';
import 'package:golon_babe/database/sqlite_helper.dart';
import '../models/tree_model.dart';

class TreeRepository {
  final DatabaseHelper _remoteDb = DatabaseHelper();
  final SQLiteHelper _localDb = SQLiteHelper();
  final Connectivity _connectivity = Connectivity();
  bool _isSyncing = false;

  // Kiểm tra kết nối mạng
  Future<bool> hasInternetConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      print('Lỗi kiểm tra kết nối mạng: $e');
      return false;
    }
  }

  // Lấy tất cả master tree info (ưu tiên online)
  Future<List<MasterTreeInfo>> getAllMasterTreeInfo() async {
    try {
      if (await hasInternetConnection()) {
        print('Đang lấy dữ liệu từ server...');
        final remoteData = await _remoteDb.getMasterTreeInfo();
        await _localDb.insertMasterTreeInfo(remoteData);
        print('Đã lưu ${remoteData.length} bản ghi vào local');
        return remoteData.map((json) => MasterTreeInfo.fromJson(json)).toList();
      }
    } catch (e) {
      print('Lỗi khi lấy dữ liệu từ server: $e');
    }
    return await getLocalMasterTreeInfo();
  }

  // Lấy dữ liệu từ local
  Future<List<MasterTreeInfo>> getLocalMasterTreeInfo() async {
    try {
      print('Lấy dữ liệu trực tiếp từ local...');
      final localData = await _localDb.getAllMasterTreeInfo();
      return localData.map((json) => MasterTreeInfo.fromJson(json)).toList();
    } catch (e) {
      print('Lỗi khi lấy dữ liệu từ local: $e');
      return [];
    }
  }

  // Lấy chi tiết cây theo id

Future<TreeDetails?> getTreeDetailsById(int id) async {
  try {
    // Kiểm tra kết nối ngay từ đầu
    final isOnline = await hasInternetConnection();
    
    // Nếu offline thì lấy từ local ngay
    if (!isOnline) {
      print('Offline - Lấy chi tiết cây $id từ local...');
      return await _localDb.getTreeDetailsById(id);
    }

    // Chỉ thực hiện request server khi online
    print('Online - Đang lấy chi tiết cây $id từ server...');
    try {
      final remoteData = await _remoteDb.getTreeDetailsById(id);
      if (remoteData != null) {
        final treeDetails = TreeDetails.fromJson(remoteData);
        if (treeDetails.id != null) {
          await _localDb.updateTreeDetail(treeDetails.id!, {
            ...remoteData,
            'sync_status': 'synced',
          });
        }
        return treeDetails;
      }
    } catch (e) {
      print('Lỗi kết nối server: $e');
      print('Chuyển sang lấy dữ liệu từ local...');
      return await _localDb.getTreeDetailsById(id);
    }

    // Nếu không có dữ liệu từ server thì lấy từ local
    print('Không có dữ liệu từ server - Lấy từ local...');
    return await _localDb.getTreeDetailsById(id);
    
  } catch (e) {
    print('Lỗi khi lấy chi tiết cây: $e');
    return await _localDb.getTreeDetailsById(id);
  }
}

  // Lưu chi tiết cây
  Future<bool> saveTreeDetails(TreeDetails details) async {
    try {
      if (await hasInternetConnection()) {
        print('Đang lưu chi tiết cây lên server...');
        final success = await _remoteDb.saveTreeDetails(details);
        if (success) {
          print('Lưu thành công lên server, cập nhật local...');
          if (details.id != null) {
            await _localDb.updateTreeDetail(details.id!, {
              ...details.toJson(),
              'sync_status': 'synced',
            });
          } else {
            await _localDb.insertTreeDetail({
              ...details.toJson(),
              'sync_status': 'synced',
            });
          }
          return true;
        }
      } else {
        print('Không có mạng, lưu vào local...');
        if (details.id != null) {
          return await _localDb.updateTreeDetail(details.id!, details.toJson());
        } else {
          final id = await _localDb.insertTreeDetail(details.toJson());
          return id > 0;
        }
      }
    } catch (e) {
      print('Lỗi khi lưu chi tiết cây: $e');
    }
    return false;
  }

  // Đồng bộ dữ liệu
  Future<void> syncData() async {
    if (_isSyncing || !await hasInternetConnection()) {
      print('Đang đồng bộ hoặc không có mạng, bỏ qua');
      return;
    }

    _isSyncing = true;
    try {
      print('Bắt đầu đồng bộ dữ liệu...');
      
      // Đồng bộ master tree info
      final remoteMasterTrees = await _remoteDb.getMasterTreeInfo();
      await _localDb.insertMasterTreeInfo(remoteMasterTrees);
      print('Đã đồng bộ ${remoteMasterTrees.length} master tree');

      // Đồng bộ pending details lên server
      final pendingDetails = await _localDb.getPendingSyncTreeDetails();
      print('Có ${pendingDetails.length} chi tiết cây cần đồng bộ');
      
      for (var detail in pendingDetails) {
        try {
          final success = await _remoteDb.saveTreeDetails(TreeDetails.fromJson(detail));
          if (success) {
            await _localDb.markAsSynced(detail['id']);
            print('Đã đồng bộ chi tiết cây ${detail['id']}');
          }
        } catch (e) {
          print('Lỗi đồng bộ chi tiết cây ${detail['id']}: $e');
          continue;
        }
      }
      
      print('Hoàn thành đồng bộ dữ liệu');
    } catch (e) {
      print('Lỗi trong quá trình đồng bộ: $e');
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  // Đồng bộ một bản ghi cụ thể
  Future<bool> syncTreeDetail(int id) async {
    if (!await hasInternetConnection()) return false;

    try {
      print('Đồng bộ chi tiết cây $id...');
      final localData = await _localDb.getTreeDetailsById(id);
      if (localData == null) return false;

      final success = await _remoteDb.saveTreeDetails(localData);
      if (success) {
        await _localDb.markAsSynced(id);
        print('Đã đồng bộ chi tiết cây $id');
        return true;
      }
    } catch (e) {
      print('Lỗi đồng bộ chi tiết cây $id: $e');
    }
    return false;
  }

  // Kiểm tra trạng thái đồng bộ
  bool get isSyncing => _isSyncing;

  // Kiểm tra có dữ liệu local
  Future<bool> hasLocalData() async {
    return await _localDb.hasData();
  }

  // Xóa dữ liệu local
  Future<void> clearLocalData() async {
    await _localDb.clearAllData();
  }

  // Xóa chi tiết cây
  Future<bool> deleteTreeDetail(int id) async {
    try {
      if (await hasInternetConnection()) {
        print('Xóa chi tiết cây $id từ server...');
        final success = await _remoteDb.deleteTreeDetail(id);
        if (success) {
          await _localDb.deleteTreeDetail(id);
          return true;
        }
      } else {
        print('Đánh dấu xóa chi tiết cây $id khi có mạng...');
        await _localDb.updateTreeDetail(id, {
          'sync_status': 'delete_pending',
        });
        return true;
      }
    } catch (e) {
      print('Lỗi xóa chi tiết cây $id: $e');
    }
    return false;
  }

  // Giải phóng tài nguyên
  Future<void> dispose() async {
    await _remoteDb.close();
    await _localDb.close();
  }
}