import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/database_helper.dart';
import '../database/sqlite_helper.dart';
import '../models/tree_model.dart';

class TreeRepository {
  final DatabaseHelper _remoteDb;
  final SQLiteHelper _localDb;
  final Connectivity _connectivity;
  bool _isSyncing = false;
  bool _isOnline = true;

  TreeRepository({
    DatabaseHelper? remoteDb,
    SQLiteHelper? localDb,
    Connectivity? connectivity,
  }) : _remoteDb = remoteDb ?? DatabaseHelper(),
       _localDb = localDb ?? SQLiteHelper(),
       _connectivity = connectivity ?? Connectivity();

  // Kiểm tra kết nối
Future<bool> hasInternetConnection() async {
  try {
    // Kiểm tra kết nối internet trước
    final result = await _connectivity.checkConnectivity();
    if (result == ConnectivityResult.none) {
      print('Không có kết nối mạng');
      _isOnline = false;
      return false;
    }
    
    // Nếu có internet thì kiểm tra kết nối database
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

  Future<TreeDetails?> getLocalTreeDetails(int id) async {
    try {
      print('Tìm kiếm cây ID $id trong local database...');
      return await _localDb.getTreeDetailsById(id);
    } catch (e) {
      print('Lỗi khi tìm kiếm trong local: $e');
      return null;
    }
  }

  // Lấy danh sách cây mẫu
Future<List<MasterTreeInfo>> getAllMasterTreeInfo() async {
  try {
    // Lấy dữ liệu local trước 
    final localData = await getLocalMasterTreeInfo();
    
    // Nếu có dữ liệu local, trả về luôn
    if (localData.isNotEmpty) {
      print('Đã có ${localData.length} master trees trong local');
      return localData;
    }
    
    // Nếu không có dữ liệu local và online thì tải từ server
    if (await hasInternetConnection()) {
      print('Đang lấy danh sách cây từ server...');
      final remoteData = await _remoteDb.getMasterTreeInfo();
      
      // Lưu vào local ngay sau khi lấy được
      await _localDb.insertMasterTreeInfo(remoteData);
      print('Đã lưu ${remoteData.length} loại cây vào local');
      
      await getAllTreeDetailsAndSaveLocal();
      
      return remoteData.map((json) => MasterTreeInfo.fromJson(json)).toList();
    }
  } catch (e) {
    print('Lỗi khi lấy dữ liệu từ server: $e');
    _isOnline = false;
  }
  
  // Nếu có lỗi, thử lấy từ local một lần nữa
  return await getLocalMasterTreeInfo();
}

  // Lấy danh sách cây mẫu từ local
Future<List<MasterTreeInfo>> getLocalMasterTreeInfo() async {
  try {
    print('Lấy danh sách cây từ local...');
    final localData = await _localDb.getAllMasterTreeInfo();
    
    // Log chi tiết số lượng và danh sách cây
    if (localData.isNotEmpty) {
      print('Tìm thấy ${localData.length} master trees trong local:');
      for (var tree in localData) {
        print('- ID: ${tree['id']}, Tên: ${tree['tree_type']}');
      }
    } else {
      print('Không có master trees trong local');
    }
    
    return localData.map((json) => MasterTreeInfo.fromJson(json)).toList();
  } catch (e) {
    print('Lỗi khi lấy dữ liệu từ local: $e');
    return [];
  }
}

  // Lấy chi tiết cây theo ID
Future<TreeDetails?> getTreeDetailsById(int id) async {
  try {
    // Kiểm tra kết nối trước
    final hasConnection = await hasInternetConnection();
    
    if (!hasConnection) {
      print('Không có kết nối mạng - Tìm kiếm trong local...');
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
    print('Thử tìm trong local...');
    return await _localDb.getTreeDetailsById(id);
  }
}

  // Lấy và lưu tất cả chi tiết cây vào local
  Future<void> getAllTreeDetailsAndSaveLocal() async {
    try {
      if (!await hasInternetConnection()) return;
      
      print('\n=== BẮT ĐẦU CẬP NHẬT CHI TIẾT CÂY ===');
      
      final treeDetails = await _remoteDb.getTreeDetails();
      print('Đã lấy được ${treeDetails.length} chi tiết cây từ server');

      // Chỉ xóa tree_details, giữ lại master_tree_info
      await _localDb.clearTreeDetails();
      print('Đã xóa dữ liệu chi tiết cây trong local database');

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

Future<bool> saveTreeDetails(TreeDetails details) async {
    try {
      print('\n=== BẮT ĐẦU LƯU THÔNG TIN CÂY ===');
      final id = details.id;
      
      if (id != null) {
        print('Cập nhật cây ID: $id');
      } else {
        print('Thêm cây mới');
      }

      // Luôn lưu vào local trước
      final localSuccess = await saveTreeToLocal(details);
      if (!localSuccess) {
        print('Lỗi lưu local database');
        return false;
      }

      print('Đã lưu thành công vào local database');

      // Nếu online thì đồng bộ luôn
      if (await hasInternetConnection()) {
        print('Đang đồng bộ lên server...');
        final success = await _remoteDb.saveTreeDetails(details);
        
        if (success && id != null) {
          await _localDb.markAsSynced(id);
          print('Đã đồng bộ server thành công');
        }
        return success;
      } else {
        print('Offline - Đã lưu vào local, sẽ đồng bộ sau');
        return true;
      }

    } catch (e) {
      print('Lỗi khi lưu thông tin cây:');
      print(e.toString());
      print('Stack trace:');
      print(StackTrace.current);
      return false;
    }
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

    // Lưu trữ các bản ghi pending
    final pendingDetails = await _localDb.getPendingSyncTreeDetails();
    
    // Chỉ xóa các tree_details đã đồng bộ
    await _localDb.clearSyncedTreeDetails();
    
    // Đồng bộ dữ liệu mới từ server
    final treeDetails = await _remoteDb.getTreeDetails();
    print('Đã lấy ${treeDetails.length} chi tiết cây từ server');

    // Khôi phục lại các bản ghi pending
    for (var detail in pendingDetails) {
      await _localDb.insertTreeDetail({
        ...detail,
        'sync_status': 'pending',
      });
    }

    // Lưu dữ liệu mới
    for (var detail in treeDetails) {
      await _localDb.insertTreeDetail({
        ...detail,
        'sync_status': 'synced',
      });
    }
    
    print('=== HOÀN THÀNH ĐỒNG BỘ DỮ LIỆU ===\n');
    await _localDb.checkLocalData();
    
  } catch (e) {
    print('Lỗi trong quá trình đồng bộ: $e');
    _isOnline = false;
  } finally {
    _isSyncing = false;
  }
}

Future<bool> saveTreeToLocal(TreeDetails tree) async {
    try {
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
        'sync_status': 'pending'
      };

      if (tree.id != null) {
        return await _localDb.updateTreeDetail(tree.id!, data);
      } else {
        final id = await _localDb.insertTreeDetail(data);
        return id > 0;
      }
    } catch (e) {
      print('Lỗi khi lưu vào local: $e');
      return false;
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
        print('Offline - Chờ xóa cây $id khi online...');
        // Đánh dấu để xóa khi online
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

  // Kiểm tra trạng thái
  Future<bool> hasLocalData() async {
    return await _localDb.hasData();
  }

  // In thông tin dữ liệu đã lưu
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

  // In thông tin debug  
  Future<void> printDebugInfo() async {
    print('\n=== THÔNG TIN DEBUG ===');
    print('Trạng thái online: $_isOnline');
    print('Đang đồng bộ: $_isSyncing');
    await _localDb.checkLocalData();
    await _localDb.printTableInfo();
    print('=== KẾT THÚC DEBUG ===\n');
  }

  // Xóa dữ liệu local
  Future<void> clearLocalData() async {
    await _localDb.clearAllData();
  }

  // Getters
  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;

  // Đóng kết nối
  Future<void> dispose() async {
    await _remoteDb.close();
    await _localDb.close();
  }
}