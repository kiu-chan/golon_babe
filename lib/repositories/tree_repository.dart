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

  // Kiểm tra kết nối internet và kết nối database
  Future<bool> hasInternetConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      if (result == ConnectivityResult.none) {
        print('Không có kết nối mạng');
        _isOnline = false;
        return false;
      }
      
      // Test kết nối database
      final isConnected = await _remoteDb.testConnection();
      _isOnline = isConnected;
      print('Kết nối database: ${isConnected ? "thành công" : "thất bại"}');
      return isConnected;
      
    } catch (e) {
      print('Lỗi kiểm tra kết nối: $e');
      _isOnline = false;
      return false;
    }
  }

  // In thông tin dữ liệu đã lưu để debug
  Future<void> printSavedData() async {
    try {
      print('\n=== THÔNG TIN DỮ LIỆU ĐÃ LƯU ===');
      
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
      print('=== KẾT THÚC THÔNG TIN ===\n');
    } catch (e) {
      print('Lỗi khi in thông tin dữ liệu: $e');
    }
  }

  // Lấy và lưu chi tiết cây vào local
  Future<void> getAllTreeDetailsAndSaveLocal() async {
    try {
      if (!await hasInternetConnection()) return;
      
      print('\n=== BẮT ĐẦU CẬP NHẬT CHI TIẾT CÂY ===');
      
      final treeDetails = await _remoteDb.getTreeDetails();
      print('Đã lấy được ${treeDetails.length} chi tiết cây từ server');

      // Xóa dữ liệu cũ trong SQLite
      await _localDb.clearAllData();
      print('Đã xóa dữ liệu cũ trong local database');

      int savedCount = 0;
      for (var detail in treeDetails) {
        try {
          final savedId = await _localDb.insertTreeDetail({
            ...detail,
            'sync_status': 'synced',
          });
          
          if (savedId > 0) {
            savedCount++;
            print('''
            === Đã lưu cây ${detail['id']} ===
            Loại cây ID: ${detail['master_tree_id']}
            Tọa độ: (${detail['coordinate_x']}, ${detail['coordinate_y']})
            Có ảnh: ${detail['image_base64'] != null}
            ''');
          }
        } catch (e) {
          print('Lỗi khi lưu cây ${detail['id']}: $e');
        }
      }

      print('Đã lưu thành công $savedCount/${treeDetails.length} chi tiết cây');
      print('=== KẾT THÚC CẬP NHẬT CHI TIẾT CÂY ===\n');
    } catch (e) {
      print('Lỗi khi lấy và lưu chi tiết cây: $e');
      _isOnline = false;
    }
  }

  // Lấy danh sách cây master
  Future<List<MasterTreeInfo>> getAllMasterTreeInfo() async {
    try {
      if (await hasInternetConnection()) {
        print('Đang lấy danh sách cây từ server...');
        final remoteData = await _remoteDb.getMasterTreeInfo();
        await _localDb.insertMasterTreeInfo(remoteData);
        print('Đã lưu ${remoteData.length} loại cây vào local');
        
        await getAllTreeDetailsAndSaveLocal();
        
        return remoteData.map((json) => MasterTreeInfo.fromJson(json)).toList();
      }
    } catch (e) {
      print('Lỗi khi lấy dữ liệu từ server: $e');
      _isOnline = false;
    }
    return await getLocalMasterTreeInfo();
  }

  // Lấy danh sách cây master từ local
  Future<List<MasterTreeInfo>> getLocalMasterTreeInfo() async {
    try {
      print('Lấy danh sách cây từ local...');
      final localData = await _localDb.getAllMasterTreeInfo();
      return localData.map((json) => MasterTreeInfo.fromJson(json)).toList();
    } catch (e) {
      print('Lỗi khi lấy dữ liệu từ local: $e');
      return [];
    }
  }

  // Lấy chi tiết cây theo ID
  Future<TreeDetails?> getTreeDetailsById(int id) async {
    try {
      if (!_isOnline) {
        print('Offline - Lấy chi tiết cây $id từ local...');
        return await _localDb.getTreeDetailsById(id);
      }

      print('Online - Lấy chi tiết cây $id từ server...');
      final remoteData = await _remoteDb.getTreeDetailsById(id);
      
      if (remoteData != null) {
        print('Đã tìm thấy cây trên server');
        final treeDetails = TreeDetails.fromJson(remoteData);
        
        // Cập nhật vào local database
        await _localDb.updateTreeDetail(id, {
          ...remoteData,
          'sync_status': 'synced',
        });
        
        return treeDetails;
      }

      print('Không tìm thấy trên server - Thử tìm trong local...');
      return await _localDb.getTreeDetailsById(id);
      
    } catch (e) {
      print('Lỗi khi lấy chi tiết cây: $e');
      return await _localDb.getTreeDetailsById(id);
    }
  }

  // Lưu thông tin cây
  Future<bool> saveTreeDetails(TreeDetails details) async {
    try {
      if (await hasInternetConnection()) {
        print('Đang lưu chi tiết cây lên server...');
        final success = await _remoteDb.saveTreeDetails(details);
        
        if (success) {
          print('Lưu thành công lên server, cập nhật local...');
          if (details.id != null) {
            return await _localDb.updateTreeDetail(details.id!, {
              ...details.toJson(),
              'sync_status': 'synced',
            });
          } else {
            final localId = await _localDb.insertTreeDetail({
              ...details.toJson(),
              'sync_status': 'synced',
            });
            return localId > 0;
          }
        }
      } else {
        print('Offline - Lưu vào local...');
        if (details.id != null) {
          return await _localDb.updateTreeDetail(details.id!, details.toJson());
        } else {
          final localId = await _localDb.insertTreeDetail(details.toJson());
          return localId > 0;
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
      print('\n=== BẮT ĐẦU ĐỒNG BỘ DỮ LIỆU ===');
      
      // Đồng bộ master tree
      final remoteMasterTrees = await _remoteDb.getMasterTreeInfo();
      await _localDb.insertMasterTreeInfo(remoteMasterTrees);
      print('Đã đồng bộ ${remoteMasterTrees.length} loại cây');

      // Đồng bộ chi tiết cây
      await getAllTreeDetailsAndSaveLocal();

      // Đồng bộ dữ liệu pending
      final pendingDetails = await _localDb.getPendingSyncTreeDetails();
      print('Có ${pendingDetails.length} cây cần đồng bộ lên server');
      
      for (var detail in pendingDetails) {
        try {
          final success = await _remoteDb.saveTreeDetails(
            TreeDetails.fromJson(detail)
          );
          if (success) {
            await _localDb.markAsSynced(detail['id']);
            print('Đã đồng bộ cây ${detail['id']} lên server');
          }
        } catch (e) {
          print('Lỗi đồng bộ cây ${detail['id']}: $e');
        }
      }
      
      print('=== HOÀN THÀNH ĐỒNG BỘ DỮ LIỆU ===\n');
      await printSavedData();
      
    } catch (e) {
      print('Lỗi trong quá trình đồng bộ: $e');
      _isOnline = false;
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  // Đồng bộ một cây cụ thể
  Future<bool> syncTreeDetail(int id) async {
    if (!await hasInternetConnection()) return false;

    try {
      print('Đồng bộ cây $id lên server...');
      final localData = await _localDb.getTreeDetailsById(id);
      if (localData == null) return false;

      final success = await _remoteDb.saveTreeDetails(localData);
      if (success) {
        await _localDb.markAsSynced(id);
        print('Đã đồng bộ cây $id thành công');
        return true;
      }
    } catch (e) {
      print('Lỗi đồng bộ cây $id: $e');
      _isOnline = false;
    }
    return false;
  }

  // Xóa cây
  Future<bool> deleteTreeDetail(int id) async {
    try {
      if (await hasInternetConnection()) {
        print('Xóa cây $id từ server...');
        final success = await _remoteDb.deleteTreeDetail(id);
        if (success) {
          await _localDb.deleteTreeDetail(id);
          return true;
        }
      } else {
        print('Offline - Đánh dấu xóa cây $id khi online...');
        await _localDb.updateTreeDetail(id, {
          'sync_status': 'delete_pending',
        });
        return true;
      }
    } catch (e) {
      print('Lỗi xóa cây $id: $e');
      _isOnline = false;
    }
    return false;
  }

  // Kiểm tra có dữ liệu local
  Future<bool> hasLocalData() async {
    return await _localDb.hasData();
  }

  // Xóa toàn bộ dữ liệu local
  Future<void> clearLocalData() async {
    await _localDb.clearAllData();
  }

  // Getters
  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;

  // Giải phóng tài nguyên
  Future<void> dispose() async {
    await _remoteDb.close();
    await _localDb.close();
  }
}