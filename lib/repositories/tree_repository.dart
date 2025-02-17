import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/database_helper.dart';
import '../database/sqlite_helper.dart';
import '../models/tree_model.dart';
import 'tree_sync_repository.dart';
import 'tree_local_repository.dart';
import 'tree_remote_repository.dart';

class TreeRepository {
  final PostgresHelper _remoteDb;
  final SQLiteHelper _localDb;
  final Connectivity _connectivity;
  late final TreeSyncRepository _syncRepo;
  late final TreeLocalRepository _localRepo;
  late final TreeRemoteRepository _remoteRepo;
  bool _isSyncing = false;
  bool _isOnline = true;

  TreeRepository({
    PostgresHelper? remoteDb,
    SQLiteHelper? localDb,
    Connectivity? connectivity,
  }) : _remoteDb = remoteDb ?? PostgresHelper(),
       _localDb = localDb ?? SQLiteHelper(),
       _connectivity = connectivity ?? Connectivity() {
    _syncRepo = TreeSyncRepository(_remoteDb, _localDb);
    _localRepo = TreeLocalRepository(_localDb);
    _remoteRepo = TreeRemoteRepository(_remoteDb);
  }

  // Kiểm tra kết nối
  Future<bool> hasInternetConnection() async {
    try {
      print('\n=== KIỂM TRA KẾT NỐI ===');
      final result = await _connectivity.checkConnectivity();
      if (result == ConnectivityResult.none) {
        print('Không có kết nối mạng');
        _isOnline = false;
        return false;
      }
      
      print('Có kết nối mạng - Kiểm tra kết nối database...');
      bool isConnected = await _remoteDb.testConnection();
      
      _isOnline = isConnected;
      print('Kết nối database: ${isConnected ? "thành công" : "thất bại"}');
      return isConnected;
      
    } catch (e) {
      print('Lỗi kiểm tra kết nối: $e');
      _isOnline = false;
      return false;
    }
  }

  // Kiểm tra có dữ liệu local
  Future<bool> hasLocalData() async {
    return await _localRepo.hasData();
  }

  // Lấy danh sách cây mẫu từ local
  Future<List<MasterTreeInfo>> getLocalMasterTreeInfo() async {
    return await _localRepo.getLocalMasterTreeInfo();
  }

  // Lấy danh sách cây mẫu
  Future<List<MasterTreeInfo>> getAllMasterTreeInfo() async {
    try {
      print('\n=== LẤY DANH SÁCH CÂY MẪU ===');
      
      final isConnected = await hasInternetConnection();
      
      if (isConnected) {
        print('Online - Lấy dữ liệu từ server...');
        final remoteData = await _remoteRepo.getMasterTreeInfo();
        
        // Lưu vào local
        await _localRepo.saveMasterTreeInfo(remoteData);
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

  // Lấy chi tiết cây theo ID
  Future<TreeDetails?> getTreeDetailsById(int id) async {
    try {
      print('\n=== TÌM KIẾM CHI TIẾT CÂY ID: $id ===');
      
      final isConnected = await hasInternetConnection();
      
      if (isConnected) {
        print('Online - Tìm kiếm trên server...');
        final remoteData = await _remoteRepo.getTreeDetailsById(id);
        
        if (remoteData != null) {
          print('Đã tìm thấy cây trên server');
          final treeDetails = TreeDetails.fromJson(remoteData);
          
          // Cập nhật vào local
          await _localRepo.saveTreeDetail(treeDetails, syncStatus: 'synced');
          print('Đã cập nhật dữ liệu vào local');
          
          return treeDetails;
        }
        
        print('Không tìm thấy trên server - Thử tìm trong local...');
      }

      return await _localRepo.getTreeDetailsById(id);

    } catch (e) {
      print('Lỗi khi tìm kiếm cây: $e');
      return null;
    }
  }

  // Lấy và lưu tất cả chi tiết cây
  Future<void> getAllTreeDetailsAndSaveLocal() async {
    try {
      if (!await hasInternetConnection()) {
        print('Không có kết nối - Bỏ qua đồng bộ');
        return;
      }
      
      print('\n=== ĐỒNG BỘ CHI TIẾT CÂY ===');
      
      final treeDetails = await _remoteRepo.getAllTreeDetails();
      print('Đã lấy ${treeDetails.length} chi tiết cây từ server');

      // Lưu trữ các bản ghi pending
      final pendingDetails = await _localRepo.getPendingSyncDetails();
      print('Có ${pendingDetails.length} bản ghi đang chờ đồng bộ');

      // Xóa tree_details đã đồng bộ
      await _localRepo.clearSyncedDetails();
      print('Đã xóa các bản ghi đã đồng bộ');

      // Khôi phục lại các bản ghi pending
      for (var detail in pendingDetails) {
        final treeDetails = TreeDetails.fromJson(detail);
        await _localRepo.saveTreeDetail(treeDetails, syncStatus: 'pending');
      }
      print('Đã khôi phục ${pendingDetails.length} bản ghi pending');

      // Lưu dữ liệu mới từ server
      int savedCount = 0;
      for (var detail in treeDetails) {
        try {
          final treeDetails = TreeDetails.fromJson(detail);
          await _localRepo.saveTreeDetail(treeDetails, syncStatus: 'synced');
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
      
      final isConnected = await hasInternetConnection();

      // Luôn lưu vào local trước
      final localSuccess = await _localRepo.saveTreeDetail(details);
      if (!localSuccess) {
        print('Lỗi lưu local database');
        return false;
      }
      print('Đã lưu thành công vào local database');

      // Nếu online thì đồng bộ ngay
      if (isConnected) {
        print('Online - Đồng bộ lên server...');
        final success = await _remoteRepo.saveTreeDetails(details);
        
        if (success && id != null) {
          await _localRepo.markAsSynced(id);
          print('Đã đồng bộ server thành công');
        }
        return success;
      }
      
      print('Offline - Đã lưu vào local, sẽ đồng bộ sau');
      return true;

    } catch (e) {
      print('Lỗi khi lưu thông tin cây: $e');
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
      
      await _syncRepo.syncData();
      await getAllTreeDetailsAndSaveLocal();
      
      print('=== HOÀN THÀNH ĐỒNG BỘ DỮ LIỆU ===\n');
      
    } catch (e) {
      print('Lỗi trong quá trình đồng bộ: $e');
      _isOnline = false;
    } finally {
      _isSyncing = false;
    }
  }

  // Xóa cây
  Future<bool> deleteTreeDetail(int id) async {
    try {
      print('\n=== XÓA CÂY ID: $id ===');
      
      final isConnected = await hasInternetConnection();

      if (isConnected) {
        print('Online - Xóa từ server...');
        final success = await _remoteRepo.deleteTreeDetail(id);
        if (success) {
          await _localRepo.deleteTreeDetail(id);
          print('Đã xóa thành công');
          return true;
        }
      } else {
        print('Offline - Đánh dấu xóa khi online...');
        await _localRepo.markForDeletion(id);
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
      await _syncRepo.handlePendingDeletes();
    } catch (e) {
      print('Lỗi xử lý bản ghi chờ xóa: $e');
    }
  }

  // In thông tin dữ liệu đã lưu
  Future<void> printSavedData() async {
    try {
      print('\n=== THÔNG TIN DỮ LIỆU ĐÃ LƯU ===');
      await _localRepo.printSavedData();
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
    await _localRepo.printDebugInfo();
    print('=== KẾT THÚC DEBUG ===\n');
  }

  // Xóa dữ liệu local
  Future<void> clearLocalData() async {
    await _localRepo.clearAllData();
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