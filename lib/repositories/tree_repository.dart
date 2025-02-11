import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:golon_babe/database/database_helper.dart';
import 'package:golon_babe/database/sqlite_helper.dart';
import '../models/tree_model.dart';

class TreeRepository {
  final DatabaseHelper _remoteDb = DatabaseHelper();
  final SQLiteHelper _localDb = SQLiteHelper();
  final Connectivity _connectivity = Connectivity();
  bool _isSyncing = false;
  bool _isOnline = true;

  Future<bool> hasInternetConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      if (result == ConnectivityResult.none) {
        _isOnline = false;
        return false;
      }
      
      final isConnected = await _remoteDb.testConnection();
      _isOnline = isConnected;
      return isConnected;
      
    } catch (e) {
      print('Lỗi kiểm tra kết nối mạng: $e');
      _isOnline = false;
      return false;
    }
  }

  Future<void> printSavedData() async {
    try {
      print('\n=== THÔNG TIN DỮ LIỆU ĐÃ LƯU ===');
      
      final masterTrees = await _localDb.getAllMasterTreeInfo();
      print('\n-> Danh sách loại cây (${masterTrees.length} bản ghi):');
      for (var tree in masterTrees) {
        print('ID: ${tree['id']}, Tên: ${tree['tree_type']}');
      }

      final treeDetails = await _localDb.getAllTreeDetails();
      print('\n-> Chi tiết các cây (${treeDetails.length} bản ghi):');
      for (var detail in treeDetails) {
        print('''
          ID: ${detail['id']}
          Loại cây: ${detail['tree_type']}
          Tọa độ: (${detail['coordinate_x']}, ${detail['coordinate_y']})
          Chiều cao: ${detail['height']}m
          Đường kính: ${detail['trunk_diameter']}cm
          Độ che phủ: ${detail['canopy_coverage']}
          Cao so với mực nước biển: ${detail['sea_level_height']}m
          Trạng thái đồng bộ: ${detail['sync_status']}
          ===================
        ''');
      }
      print('=== KẾT THÚC THÔNG TIN ===\n');
    } catch (e) {
      print('Lỗi khi in dữ liệu đã lưu: $e');
    }
  }

Future<void> getAllTreeDetailsAndSaveLocal() async {
  try {
    if (await hasInternetConnection()) {
      print('\n=== BẮT ĐẦU CẬP NHẬT CHI TIẾT CÂY ===');
      
      // Lấy dữ liệu từ PostgreSQL
      final treeDetails = await _remoteDb.getTreeDetails();
      print('Đã lấy được ${treeDetails.length} chi tiết cây từ server');

      // Xóa dữ liệu tree_details cũ trong SQLite
      await _localDb.clearAllData();
      print('Đã xóa dữ liệu cũ trong local database');

      // Lưu từng chi tiết cây vào SQLite
      int savedCount = 0;
      for (var detail in treeDetails) {
        try {
          await _localDb.insertTreeDetail({
            'id': detail['id'],
            'master_tree_id': detail['master_tree_id'],
            'coordinate_x': detail['coordinate_x'],
            'coordinate_y': detail['coordinate_y'],
            'height': detail['height'],
            'trunk_diameter': detail['trunk_diameter'],
            'canopy_coverage': detail['canopy_coverage'],
            'sea_level_height': detail['sea_level_height'],
            'notes': detail['notes'],
            'created_at': detail['created_at'],
            'sync_status': 'synced',
          });
          savedCount++;
          
          // In thông tin chi tiết của cây vừa lưu
          print('''
          === Đã lưu cây ${detail['id']} ===
          Loại cây ID: ${detail['master_tree_id']}
          Tọa độ: (${detail['coordinate_x']}, ${detail['coordinate_y']})
          Chiều cao: ${detail['height']}m
          Đường kính: ${detail['trunk_diameter']}cm
          Độ che phủ: ${detail['canopy_coverage']}
          Cao so với mực nước biển: ${detail['sea_level_height']}m
          Ghi chú: ${detail['notes']}
          Thời gian tạo: ${detail['created_at']}
          ''');
        } catch (e) {
          print('Lỗi khi lưu cây ${detail['id']}: $e');
        }
      }

      print('Đã lưu thành công $savedCount/${treeDetails.length} chi tiết cây vào local');
      print('=== KẾT THÚC CẬP NHẬT CHI TIẾT CÂY ===\n');
    }
  } catch (e) {
    print('Lỗi khi lấy và lưu chi tiết cây: $e');
    _isOnline = false;
  }
}

  Future<List<MasterTreeInfo>> getAllMasterTreeInfo() async {
    try {
      if (await hasInternetConnection()) {
        print('Đang lấy dữ liệu từ server...');
        final remoteData = await _remoteDb.getMasterTreeInfo();
        await _localDb.insertMasterTreeInfo(remoteData);
        print('Đã lưu ${remoteData.length} bản ghi master tree vào local');
        
        await getAllTreeDetailsAndSaveLocal();
        
        return remoteData.map((json) => MasterTreeInfo.fromJson(json)).toList();
      }
    } catch (e) {
      print('Lỗi khi lấy dữ liệu từ server: $e');
      _isOnline = false;
    }
    return await getLocalMasterTreeInfo();
  }

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

  Future<TreeDetails?> getTreeDetailsById(int id) async {
    try {
      final isOnline = await hasInternetConnection();
      
      if (!isOnline) {
        print('Offline - Lấy chi tiết cây $id từ local...');
        return await _localDb.getTreeDetailsById(id);
      }

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
        _isOnline = false;
        print('Chuyển sang lấy dữ liệu từ local...');
        return await _localDb.getTreeDetailsById(id);
      }

      print('Không có dữ liệu từ server - Lấy từ local...');
      return await _localDb.getTreeDetailsById(id);
      
    } catch (e) {
      print('Lỗi khi lấy chi tiết cây: $e');
      return await _localDb.getTreeDetailsById(id);
    }
  }

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

  Future<void> syncData() async {
    if (_isSyncing || !await hasInternetConnection()) {
      print('Đang đồng bộ hoặc không có mạng, bỏ qua');
      return;
    }

    _isSyncing = true;
    try {
      print('Bắt đầu đồng bộ dữ liệu...');
      
      final remoteMasterTrees = await _remoteDb.getMasterTreeInfo();
      await _localDb.insertMasterTreeInfo(remoteMasterTrees);
      print('Đã đồng bộ ${remoteMasterTrees.length} master tree');

      await getAllTreeDetailsAndSaveLocal();

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
      await printSavedData();
      
    } catch (e) {
      print('Lỗi trong quá trình đồng bộ: $e');
      _isOnline = false;
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

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
      _isOnline = false;
    }
    return false;
  }

  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;

  Future<bool> hasLocalData() async {
    return await _localDb.hasData();
  }

  Future<void> clearLocalData() async {
    await _localDb.clearAllData();
  }

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
      _isOnline = false;
    }
    return false;
  }

  Future<void> dispose() async {
    await _remoteDb.close();
    await _localDb.close();
  }
}