import '../database/database_helper.dart';
import '../database/sqlite_helper.dart';
import '../models/tree_model.dart';

class TreeSyncRepository {
  final PostgresHelper _remoteDb;
  final SQLiteHelper _localDb;
  bool _isSyncing = false;

  TreeSyncRepository(this._remoteDb, this._localDb);

  // Đồng bộ toàn bộ dữ liệu
  Future<void> syncData() async {
    if (_isSyncing) {
      print('Đang trong quá trình đồng bộ, bỏ qua');
      return;
    }

    _isSyncing = true;
    try {
      print('\n=== BẮT ĐẦU ĐỒNG BỘ DỮ LIỆU ===');
      
      // Đồng bộ các bản ghi chưa đồng bộ lên server
      await _syncPendingRecords();
      
      // Xử lý các bản ghi cần xóa
      await handlePendingDeletes();
      
      // Lấy dữ liệu mới từ server
      await _syncFromServer();
      
      print('=== HOÀN THÀNH ĐỒNG BỘ DỮ LIỆU ===\n');
      
    } catch (e) {
      print('Lỗi trong quá trình đồng bộ: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // Đồng bộ các bản ghi chưa đồng bộ
  Future<void> _syncPendingRecords() async {
    try {
      print('\n=== ĐỒNG BỘ BẢN GHI PENDING ===');
      
      // Lấy các bản ghi pending từ local
      final pendingRecords = await _localDb.getPendingSyncTreeDetails();
      print('Có ${pendingRecords.length} bản ghi chưa đồng bộ');

      // Đồng bộ từng bản ghi
      for (var record in pendingRecords) {
        try {
          if (record['sync_status'] == 'pending') {
            print('Đồng bộ bản ghi ID: ${record['id']}...');
            
            final treeDetails = TreeDetails.fromJson(record);
            final success = await _remoteDb.saveTreeDetails(treeDetails);
            
            if (success) {
              await _localDb.markAsSynced(record['id']);
              print('Đã đồng bộ bản ghi ${record['id']}');
            } else {
              print('Không thể đồng bộ bản ghi ${record['id']}');
            }
          }
        } catch (e) {
          print('Lỗi khi đồng bộ bản ghi ${record['id']}: $e');
        }
      }
      
    } catch (e) {
      print('Lỗi khi đồng bộ bản ghi pending: $e');
      rethrow;
    }
  }

  // Đồng bộ dữ liệu từ server về local
  Future<void> _syncFromServer() async {
    try {
      print('\n=== ĐỒNG BỘ DỮ LIỆU TỪ SERVER ===');
      
      // Lấy danh sách cây mẫu
      final remoteMasterTrees = await _remoteDb.getMasterTreeInfo();
      await _localDb.insertMasterTreeInfo(remoteMasterTrees);
      print('Đã đồng bộ ${remoteMasterTrees.length} loại cây');

      // Đồng bộ chi tiết cây
      await syncTreeDetails();
      
    } catch (e) {
      print('Lỗi khi đồng bộ từ server: $e');
      rethrow;
    }
  }

  // Đồng bộ chi tiết cây
  Future<void> syncTreeDetails() async {
    try {
      print('\n=== ĐỒNG BỘ CHI TIẾT CÂY ===');
      
      // Lấy chi tiết cây từ server
      final treeDetails = await _remoteDb.getTreeDetails();
      print('Đã lấy ${treeDetails.length} chi tiết cây từ server');

      // Lưu trữ các bản ghi pending
      final pendingDetails = await _localDb.getPendingSyncTreeDetails();
      print('Có ${pendingDetails.length} bản ghi đang chờ đồng bộ');

      // Xóa các bản ghi đã đồng bộ
      await _localDb.clearSyncedTreeDetails();
      print('Đã xóa các bản ghi đã đồng bộ');

      // Khôi phục bản ghi pending
      for (var detail in pendingDetails) {
        if (detail['sync_status'] == 'pending') {
          await _localDb.insertTreeDetail({
            ...detail,
            'sync_status': 'pending',
          });
        }
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
      rethrow;
    }
  }

  // Xử lý các bản ghi cần xóa
  Future<void> handlePendingDeletes() async {
    try {
      print('\n=== XỬ LÝ CÁC BẢN GHI CHỜ XÓA ===');
      
      final pendingDeletes = await _localDb.getPendingSyncTreeDetails();
      print('Kiểm tra ${pendingDeletes.length} bản ghi');
      
      int deleteCount = 0;
      for (var record in pendingDeletes) {
        if (record['sync_status'] == 'delete_pending') {
          try {
            print('Xóa cây ${record['id']} từ server...');
            final success = await _remoteDb.deleteTreeDetail(record['id']);
            
            if (success) {
              await _localDb.deleteTreeDetail(record['id']);
              deleteCount++;
              print('Đã xóa cây ${record['id']}');
            } else {
              print('Không thể xóa cây ${record['id']} từ server');
            }
          } catch (e) {
            print('Lỗi khi xóa cây ${record['id']}: $e');
          }
        }
      }
      
      print('Đã xử lý $deleteCount bản ghi cần xóa');
      
    } catch (e) {
      print('Lỗi khi xử lý bản ghi chờ xóa: $e');
      rethrow;
    }
  }

  // Kiểm tra trạng thái đồng bộ
  bool get isSyncing => _isSyncing;

  // Kiểm tra số lượng bản ghi chưa đồng bộ
  Future<int> getPendingCount() async {
    try {
      final pendingRecords = await _localDb.getPendingSyncTreeDetails();
      return pendingRecords.length;
    } catch (e) {
      print('Lỗi khi đếm bản ghi pending: $e');
      return 0;
    }
  }

  // In thông tin đồng bộ
  Future<void> printSyncInfo() async {
    try {
      print('\n=== THÔNG TIN ĐỒNG BỘ ===');
      print('Trạng thái đồng bộ: ${_isSyncing ? "Đang đồng bộ" : "Không đồng bộ"}');
      
      final pendingCount = await getPendingCount();
      print('Số bản ghi chờ đồng bộ: $pendingCount');
      
      if (pendingCount > 0) {
        final pendingRecords = await _localDb.getPendingSyncTreeDetails();
        print('\nChi tiết các bản ghi chờ đồng bộ:');
        for (var record in pendingRecords) {
          print('''
            ID: ${record['id']}
            Trạng thái: ${record['sync_status']}
            --------------------
          ''');
        }
      }
      
      print('=== KẾT THÚC THÔNG TIN ĐỒNG BỘ ===\n');
    } catch (e) {
      print('Lỗi khi in thông tin đồng bộ: $e');
    }
  }
}