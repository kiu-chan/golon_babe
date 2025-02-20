// Vị trí: lib/repositories/tree_sync_repository.dart

import '../database/database_helper.dart';
import '../database/sqlite_helper.dart';
import '../models/tree_model.dart';

class TreeSyncRepository {
 final PostgresHelper _remoteDb;
 final SQLiteHelper _localDb;
 bool _isSyncing = false;

 TreeSyncRepository(this._remoteDb, this._localDb);

 Future<void> syncData() async {
   if (_isSyncing) {
     print('Đang trong quá trình đồng bộ, bỏ qua');
     return;
   }

   _isSyncing = true;
   try {
     print('\n=== BẮT ĐẦU ĐỒNG BỘ DỮ LIỆU ===');
     
     await _syncPendingRecords();
     await _syncPendingAdditionalImages();
     await handlePendingDeletes();
     await _syncFromServer();
     
     print('=== HOÀN THÀNH ĐỒNG BỘ DỮ LIỆU ===\n');
     
   } catch (e) {
     print('Lỗi trong quá trình đồng bộ: $e');
   } finally {
     _isSyncing = false;
   }
 }

 Future<void> _syncPendingRecords() async {
   try {
     print('\n=== ĐỒNG BỘ BẢN GHI PENDING ===');
     
     final pendingRecords = await _localDb.getPendingSyncTreeDetails();
     print('Có ${pendingRecords.length} bản ghi chưa đồng bộ');

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

Future<void> _syncPendingAdditionalImages() async {
  try {
    print('\n=== ĐỒNG BỘ ẢNH PHỤ PENDING ===');
    
    final pendingImages = await _localDb.getPendingSyncImages();
    print('Có ${pendingImages.length} ảnh phụ chưa đồng bộ');

    for (var image in pendingImages) {
      try {
        print('Đồng bộ ảnh phụ ID: ${image['id']} của cây ${image['tree_detail_id']}...');
        
        final treeImage = TreeAdditionalImage(
          id: image['id'],
          treeDetailId: image['tree_detail_id'],
          imageBase64: image['image_base64'],
          createdAt: image['created_at'],
        );
        
        final success = await _remoteDb.saveAdditionalImage(treeImage);
        
        if (success) {
          await _localDb.markImageAsSynced(image['id']);
          print('Đã đánh dấu ảnh phụ ID: ${image['id']} đã đồng bộ');
        } else {
          print('Không thể đồng bộ ảnh phụ ID: ${image['id']}');
        }
      } catch (e) {
        print('Lỗi khi đồng bộ ảnh phụ ${image['id']}: $e');
      }
    }
  } catch (e) {
    print('Lỗi khi đồng bộ ảnh phụ pending: $e');
  }
}

 Future<void> _syncFromServer() async {
   try {
     print('\n=== ĐỒNG BỘ DỮ LIỆU TỪ SERVER ===');
     
     final remoteMasterTrees = await _remoteDb.getMasterTreeInfo();
     await _localDb.insertMasterTreeInfo(remoteMasterTrees);
     print('Đã đồng bộ ${remoteMasterTrees.length} loại cây');

     await syncTreeDetails();
     
   } catch (e) {
     print('Lỗi khi đồng bộ từ server: $e');
     rethrow;
   }
 }

 Future<void> syncTreeDetails() async {
   try {
     print('\n=== ĐỒNG BỘ CHI TIẾT CÂY ===');
     
     final treeDetails = await _remoteDb.getTreeDetails();
     print('Đã lấy ${treeDetails.length} chi tiết cây từ server');

     final pendingDetails = await _localDb.getPendingSyncTreeDetails();
     print('Có ${pendingDetails.length} bản ghi đang chờ đồng bộ');

     await _localDb.clearSyncedTreeDetails();
     print('Đã xóa các bản ghi đã đồng bộ');

     for (var detail in pendingDetails) {
       if (detail['sync_status'] == 'pending') {
         await _localDb.insertTreeDetail({
           ...detail,
           'sync_status': 'pending',
         });
       }
     }
     print('Đã khôi phục ${pendingDetails.length} bản ghi pending');

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

 bool get isSyncing => _isSyncing;

 Future<int> getPendingCount() async {
   try {
     final pendingRecords = await _localDb.getPendingSyncTreeDetails();
     return pendingRecords.length;
   } catch (e) {
     print('Lỗi khi đếm bản ghi pending: $e');
     return 0;
   }
 }
}