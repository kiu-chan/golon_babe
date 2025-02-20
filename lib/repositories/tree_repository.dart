import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:golon_babe/database/postgres/postgres_additional_images.dart';
import 'package:golon_babe/database/postgres/postgres_core.dart';
import 'package:golon_babe/database/sqlite/sqlite_additional_images.dart';
import 'package:golon_babe/database/sqlite/sqlite_core.dart';
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
  late final PostgresAdditionalImages _remoteAdditionalImages;
  late final SQLiteAdditionalImages _localAdditionalImages;
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
_remoteAdditionalImages = PostgresAdditionalImages(PostgresCore());
_localAdditionalImages = SQLiteAdditionalImages(SQLiteCore());
  }

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

  Future<bool> hasLocalData() async {
    return await _localRepo.hasData();
  }

  Future<List<MasterTreeInfo>> getLocalMasterTreeInfo() async {
    return await _localRepo.getLocalMasterTreeInfo();
  }

  Future<List<MasterTreeInfo>> getAllMasterTreeInfo() async {
    try {
      print('\n=== LẤY DANH SÁCH CÂY MẪU ===');
      
      final isConnected = await hasInternetConnection();
      
      if (isConnected) {
        print('Online - Lấy dữ liệu từ server...');
        final remoteData = await _remoteRepo.getMasterTreeInfo();
        
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

  Future<void> getAllTreeDetailsAndSaveLocal() async {
    try {
      if (!await hasInternetConnection()) {
        print('Không có kết nối - Bỏ qua đồng bộ');
        return;
      }
      
      print('\n=== ĐỒNG BỘ CHI TIẾT CÂY ===');
      
      final treeDetails = await _remoteRepo.getAllTreeDetails();
      print('Đã lấy ${treeDetails.length} chi tiết cây từ server');

      final pendingDetails = await _localRepo.getPendingSyncDetails();
      print('Có ${pendingDetails.length} bản ghi đang chờ đồng bộ');

      await _localRepo.clearSyncedDetails();
      print('Đã xóa các bản ghi đã đồng bộ');

      for (var detail in pendingDetails) {
        final treeDetails = TreeDetails.fromJson(detail);
        await _localRepo.saveTreeDetail(treeDetails, syncStatus: 'pending');
      }
      print('Đã khôi phục ${pendingDetails.length} bản ghi pending');

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

      final localSuccess = await _localRepo.saveTreeDetail(details);
      if (!localSuccess) {
        print('Lỗi lưu local database');
        return false;
      }
      print('Đã lưu thành công vào local database');

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


Future<List<TreeAdditionalImage>> getAdditionalImages(int treeId) async {
  try {
    print('\n=== LẤY DANH SÁCH ẢNH PHỤ ===');
    print('Tree ID: $treeId');
    
    final isConnected = await hasInternetConnection();
    print('Trạng thái kết nối: ${isConnected ? "Online" : "Offline"}');

    if (isConnected) {
      // Online: lấy từ server và cập nhật local
      print('Online - Lấy ảnh từ server...');
      final remoteImages = await _remoteAdditionalImages.getImagesByTreeId(treeId);
      print('Đã lấy ${remoteImages.length} ảnh từ server');

      // Cập nhật lại local với data từ server
      for (var image in remoteImages) {
        await _localAdditionalImages.saveImage(image, syncStatus: 'synced');
      }

      // Xóa những ảnh cũ đã đồng bộ không còn trên server
      await _cleanupSyncedImages(treeId, remoteImages);

      return remoteImages;
    }
    
    // Offline: chỉ lấy từ local
    print('Offline - Lấy ảnh từ local...');
    return await _localAdditionalImages.getImagesByTreeId(treeId);
    
  } catch (e) {
    print('Lỗi khi lấy ảnh phụ: $e');
    print('Stack trace: ${StackTrace.current}');
    return [];
  }
}

// Hàm mới để dọn dẹp ảnh cũ
Future<void> _cleanupSyncedImages(int treeId, List<TreeAdditionalImage> serverImages) async {
  try {
    final localImages = await _localAdditionalImages.getImagesByTreeId(treeId);
    final serverImageIds = serverImages.map((e) => e.id).toSet();
    
    for (var localImage in localImages) {
      if (localImage.id != null && 
          !serverImageIds.contains(localImage.id) && 
          await _localAdditionalImages.isImageSynced(localImage.id!)) {
        print('Xóa ảnh cũ đã đồng bộ ID: ${localImage.id}');
        await _localAdditionalImages.deleteImage(localImage.id!);
      }
    }
  } catch (e) {
    print('Lỗi khi dọn dẹp ảnh cũ: $e');
  }
}

Future<bool> saveAdditionalImage(TreeAdditionalImage image) async {
  try {
    print('\n=== BẮT ĐẦU LƯU ẢNH PHỤ ===');
    final isConnected = await hasInternetConnection();
    print('Trạng thái kết nối: ${isConnected ? "Online" : "Offline"}');
    
    // Lưu vào local trước
    final localId = await _localAdditionalImages.saveImage(image);
    print('Đã lưu ảnh phụ vào local với ID: $localId');
    
    if (isConnected) {
      print('Đang đồng bộ ảnh phụ lên server...');
      final success = await _remoteAdditionalImages.saveImage(image);
      if (success) {
        print('Đã đồng bộ ảnh phụ lên server thành công');
        await _localAdditionalImages.markAsSynced(localId);
        print('Đã đánh dấu ảnh phụ đã đồng bộ trong local');
      } else {
        print('Không thể đồng bộ ảnh phụ lên server');
      }
      return success;
    }
    
    print('Offline - Đã lưu ảnh phụ vào local, sẽ đồng bộ sau');
    return true;
  } catch (e) {
    print('Lỗi khi lưu ảnh phụ: $e');
    return false;
  }
}

Future<bool> deleteAdditionalImage(int id) async {
  try {
    print('\n=== XÓA ẢNH PHỤ ===');
    final isConnected = await hasInternetConnection();
    
    bool remoteSuccess = false;
    if (isConnected) {
      // Thử xóa server trước
      remoteSuccess = await _remoteAdditionalImages.deleteImage(id);
      print('Xóa ảnh trên server: ${remoteSuccess ? "thành công" : "thất bại"}');
    }

    // Luôn xóa local dù server thành công hay thất bại
    final localSuccess = await _localAdditionalImages.deleteImage(id);
    print('Xóa ảnh trên local: ${localSuccess ? "thành công" : "thất bại"}');

    // Trả về true nếu:
    // - Đang offline và xóa local thành công
    // - Đang online, xóa server thành công hoặc ảnh không tồn tại trên server
    return !isConnected ? localSuccess : (remoteSuccess || localSuccess);

  } catch (e) {
    print('Lỗi khi xóa ảnh phụ: $e');
    return false;
  }
}

Future<void> syncData() async {
  if (_isSyncing || !await hasInternetConnection()) {
    print('Đang đồng bộ hoặc không có mạng, bỏ qua');
    return;
  }

  _isSyncing = true;
  try {
    print('\n=== BẮT ĐẦU ĐỒNG BỘ DỮ LIỆU ===');
    
    // Đồng bộ cây trước
    await _syncRepo.syncData();
    await getAllTreeDetailsAndSaveLocal();

    // Đồng bộ ảnh phụ
    print('\n=== ĐỒNG BỘ ẢNH PHỤ ===');
    final pendingImages = await _localAdditionalImages.getPendingSyncImages();
    print('Có ${pendingImages.length} ảnh cần đồng bộ');

    for (var image in pendingImages) {
      try {
        final treeImage = TreeAdditionalImage(
          id: image['id'],
          treeDetailId: image['tree_detail_id'],
          imageBase64: image['image_base64'],
          createdAt: image['created_at'],
        );

        final success = await _remoteAdditionalImages.saveImage(treeImage);
        if (success) {
          await _localAdditionalImages.markAsSynced(image['id']);
          print('Đã đồng bộ ảnh ${image['id']} thành công');
        } else {
          print('Không thể đồng bộ ảnh ${image['id']}');
        }
      } catch (e) {
        print('Lỗi đồng bộ ảnh ${image['id']}: $e');
      }
    }
    
    print('=== HOÀN THÀNH ĐỒNG BỘ DỮ LIỆU ===\n');
    _isOnline = true;
    
  } catch (e) {
    print('Lỗi trong quá trình đồng bộ: $e');
    _isOnline = false;
  } finally {
    _isSyncing = false;
  }
}

  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;

  Future<void> dispose() async {
    await _remoteDb.close();
    await _localDb.close();
  }
}