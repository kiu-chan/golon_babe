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
    print('\n=== KIỂM TRA KẾT NỐI ===');
    // Kiểm tra kết nối internet trước
    final result = await _connectivity.checkConnectivity();
    if (result == ConnectivityResult.none) {
      print('Không có kết nối mạng');
      _isOnline = false;
      return false;
    }
    
    print('Có kết nối mạng - Kiểm tra kết nối database...');
    // Nếu có internet thì kiểm tra kết nối database với timeout
    bool isConnected = false;
    try {
      isConnected = await _remoteDb.testConnection();
    } catch (e) {
      print('Lỗi kiểm tra kết nối database: $e');
      isConnected = false;
    }
    
    _isOnline = isConnected;
    print('Kết nối database: ${isConnected ? "thành công" : "thất bại"}');
    return isConnected;
    
  } catch (e) {
    print('Lỗi kiểm tra kết nối: $e');
    _isOnline = false;
    return false;
  }
}

  // Lấy danh sách cây mẫu
  Future<List<MasterTreeInfo>> getAllMasterTreeInfo() async {
    try {
      print('\n=== LẤY DANH SÁCH CÂY MẪU ===');
      
      // Kiểm tra kết nối
      final isConnected = await hasInternetConnection();
      
      if (isConnected) {
        print('Online - Lấy dữ liệu từ server...');
        final remoteData = await _remoteDb.getMasterTreeInfo();
        
        // Lưu vào local ngay sau khi lấy được
        await _localDb.insertMasterTreeInfo(remoteData);
        print('Đã lưu ${remoteData.length} loại cây vào local');
        
        await getAllTreeDetailsAndSaveLocal();
        
        return remoteData.map((json) => MasterTreeInfo.fromJson(json)).toList();
      }
      
      print('Offline - Lấy dữ liệu từ local...');
      return await getLocalMasterTreeInfo();
      
    } catch (e) {
      print('Lỗi khi lấy danh sách cây mẫu: $e');
      _isOnline = false;
      return await getLocalMasterTreeInfo();
    }
  }

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

  // Lấy chi tiết cây theo ID
  Future<TreeDetails?> getTreeDetailsById(int id) async {
    try {
      print('\n=== TÌM KIẾM CHI TIẾT CÂY ID: $id ===');
      
      // Kiểm tra kết nối
      final isConnected = await hasInternetConnection();
      
      if (isConnected) {
        print('Online - Tìm kiếm trên server...');
        final remoteData = await _remoteDb.getTreeDetailsById(id);
        
        if (remoteData != null) {
          print('Đã tìm thấy cây trên server');
          final treeDetails = TreeDetails.fromJson(remoteData);
          
          // Cập nhật vào local database
          await _localDb.updateTreeDetail(id, {
            ...remoteData,
            'sync_status': 'synced',
          });
          print('Đã cập nhật dữ liệu vào local');
          
          return treeDetails;
        }
        
        print('Không tìm thấy trên server - Thử tìm trong local...');
      } else {
        print('Offline - Tìm kiếm trong local...');
      }

      return await _localDb.getTreeDetailsById(id);
      
    } catch (e) {
      print('Lỗi khi tìm kiếm cây: $e');
      print('Thử tìm trong local...');
      return await _localDb.getTreeDetailsById(id);
    }
  }

  // Lấy và lưu tất cả chi tiết cây vào local
  Future<void> getAllTreeDetailsAndSaveLocal() async {
    try {
      if (!await hasInternetConnection()) {
        print('Không có kết nối - Bỏ qua đồng bộ');
        return;
      }
      
      print('\n=== ĐỒNG BỘ CHI TIẾT CÂY ===');
      
      final treeDetails = await _remoteDb.getTreeDetails();
      print('Đã lấy ${treeDetails.length} chi tiết cây từ server');

      // Lưu trữ các bản ghi pending
      final pendingDetails = await _localDb.getPendingSyncTreeDetails();
      print('Có ${pendingDetails.length} bản ghi đang chờ đồng bộ');

      // Chỉ xóa tree_details đã đồng bộ
      await _localDb.clearSyncedTreeDetails();
      print('Đã xóa các bản ghi đã đồng bộ');

      // Khôi phục lại các bản ghi pending
      for (var detail in pendingDetails) {
        await _localDb.insertTreeDetail({
          ...detail,
          'sync_status': 'pending',
        });
      }
      print('Đã khôi phục ${pendingDetails.length} bản ghi pending');

      // Lưu dữ liệu mới
      int savedCount = 0;
      for (var detail in treeDetails) {
        try {
          await _localDb.insertTreeDetail({
            ...detail,
            'sync_status': 'synced',
          });
          savedCount++;
        } catch (e) {
          print('Lỗi khi lưu cây ${detail['id']}: $e');
        }
      }
      
      print('Đã lưu thành công $savedCount/${treeDetails.length} chi tiết cây');
      
    } catch (e) {
      print('Lỗi khi đồng bộ chi tiết cây: $e');
      _isOnline = false;
    }
  }

  // Lưu thông tin cây
  Future<bool> saveTreeDetails(TreeDetails details) async {
    try {
      print('\n=== LƯU THÔNG TIN CÂY ===');
      final id = details.id;
      
      if (id != null) {
        print('Cập nhật cây ID: $id');
      } else {
        print('Thêm cây mới');
      }
      
      // Kiểm tra kết nối
      final isConnected = await hasInternetConnection();

      // Luôn lưu vào local trước
      final localSuccess = await saveTreeToLocal(details);
      if (!localSuccess) {
        print('Lỗi lưu local database');
        return false;
      }
      print('Đã lưu thành công vào local database');

      // Nếu online thì đồng bộ ngay
      if (isConnected) {
        print('Online - Đồng bộ lên server...');
        final success = await _remoteDb.saveTreeDetails(details);
        
        if (success && id != null) {
          await _localDb.markAsSynced(id);
          print('Đã đồng bộ server thành công');
        }
        return success;
      }
      
      print('Offline - Đã lưu vào local, sẽ đồng bộ sau');
      return true;

    } catch (e) {
      print('Lỗi khi lưu thông tin cây: $e');
      print('Stack trace: ${StackTrace.current}');
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
    
    // Lấy các bản ghi pending từ local
    final pendingDetails = await _localDb.getPendingSyncTreeDetails();
    print('Có ${pendingDetails.length} bản ghi đang chờ đồng bộ');

    // Đồng bộ từng bản ghi pending lên server
    for (var detail in pendingDetails) {
      try {
        print('Đồng bộ bản ghi ID ${detail['id']}...');
        final treeDetails = TreeDetails.fromJson(detail);
        final success = await _remoteDb.saveTreeDetails(treeDetails);
        
        if (success) {
          await _localDb.markAsSynced(detail['id']);
          print('Đã đồng bộ bản ghi ${detail['id']}');
        }
      } catch (e) {
        print('Lỗi đồng bộ bản ghi ${detail['id']}: $e');
      }
    }
    
    // Sau khi đồng bộ lên server, lấy lại toàn bộ dữ liệu mới từ server
    final remoteMasterTrees = await _remoteDb.getMasterTreeInfo();
    await _localDb.insertMasterTreeInfo(remoteMasterTrees);
    print('Đã đồng bộ ${remoteMasterTrees.length} loại cây');

    // Đồng bộ chi tiết cây
    await getAllTreeDetailsAndSaveLocal();
    
    print('=== HOÀN THÀNH ĐỒNG BỘ DỮ LIỆU ===\n');
    
  } catch (e) {
    print('Lỗi trong quá trình đồng bộ: $e');
    _isOnline = false;
  } finally {
    _isSyncing = false;
  }
}


  // Lưu cây vào local
  Future<bool> saveTreeToLocal(TreeDetails tree) async {
    try {
      print('\n=== LƯU CÂY VÀO LOCAL ===');
      print('ID cây: ${tree.id ?? "Mới"}');
      print('ID loại cây: ${tree.masterTreeId}');
      
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

  // Xóa cây
  Future<bool> deleteTreeDetail(int id) async {
    try {
      print('\n=== XÓA CÂY ID: $id ===');
      
      // Kiểm tra kết nối
      final isConnected = await hasInternetConnection();

      if (isConnected) {
        print('Online - Xóa từ server...');
        final success = await _remoteDb.deleteTreeDetail(id);
        if (success) {
          await _localDb.deleteTreeDetail(id);
          print('Đã xóa thành công');
          return true;
        }
      } else {
        print('Offline - Đánh dấu xóa khi online...');
        // Đánh dấu để xóa khi online
        await _localDb.updateTreeDetail(id, {
          'sync_status': 'delete_pending',
        });
        print('Đã đánh dấu xóa khi online');
        return true;
      }
    } catch (e) {
      print('Lỗi xóa cây $id: $e');
      _isOnline = false;
    }
    return false;
  }

  // Kiểm tra và xử lý các bản ghi đang chờ xóa
  Future<void> handlePendingDeletes() async {
    if (!_isOnline) return;
    
    try {
      print('\n=== XỬ LÝ CÁC BẢN GHI CHỜ XÓA ===');
      final pendingDeletes = await _localDb.getPendingSyncTreeDetails();
      
      for (var record in pendingDeletes) {
        if (record['sync_status'] == 'delete_pending') {
          print('Xóa cây ${record['id']} từ server...');
          final success = await _remoteDb.deleteTreeDetail(record['id']);
          
          if (success) {
            await _localDb.deleteTreeDetail(record['id']);
            print('Đã xóa cây ${record['id']}');
          }
        }
      }
    } catch (e) {
      print('Lỗi xử lý bản ghi chờ xóa: $e');
    }
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