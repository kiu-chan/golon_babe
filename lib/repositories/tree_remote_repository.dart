import '../database/database_helper.dart';
import '../models/tree_model.dart';

class TreeRemoteRepository {
  final PostgresHelper _remoteDb;

  TreeRemoteRepository(this._remoteDb);

  // Lấy danh sách cây mẫu từ server
  Future<List<Map<String, dynamic>>> getMasterTreeInfo() async {
    try {
      print('\n=== LẤY DANH SÁCH CÂY MẪU TỪ SERVER ===');
      final data = await _remoteDb.getMasterTreeInfo();
      print('Đã lấy ${data.length} loại cây từ server');
      return data;
    } catch (e) {
      print('Lỗi khi lấy master trees từ server: $e');
      rethrow; // Ném lỗi để xử lý ở tầng trên
    }
  }

  // Lấy chi tiết cây theo ID từ server
  Future<Map<String, dynamic>?> getTreeDetailsById(int id) async {
    try {
      print('\n=== LẤY CHI TIẾT CÂY TỪ SERVER ===');
      final data = await _remoteDb.getTreeDetailsById(id);
      if (data != null) {
        print('Đã tìm thấy cây ID: $id trên server');
      } else {
        print('Không tìm thấy cây ID: $id trên server');
      }
      return data;
    } catch (e) {
      print('Lỗi khi lấy chi tiết cây từ server: $e');
      rethrow;
    }
  }

  // Lấy tất cả chi tiết cây từ server
  Future<List<Map<String, dynamic>>> getAllTreeDetails() async {
    try {
      print('\n=== LẤY TẤT CẢ CHI TIẾT CÂY TỪ SERVER ===');
      final data = await _remoteDb.getTreeDetails();
      print('Đã lấy ${data.length} chi tiết cây từ server');
      return data;
    } catch (e) {
      print('Lỗi khi lấy tất cả chi tiết cây từ server: $e');
      rethrow;
    }
  }

  // Lưu chi tiết cây lên server
  Future<bool> saveTreeDetails(TreeDetails tree) async {
    try {
      print('\n=== LƯU CHI TIẾT CÂY LÊN SERVER ===');
      if (tree.id != null) {
        print('Cập nhật cây ID: ${tree.id}');
      } else {
        print('Thêm cây mới');
      }
      
      final success = await _remoteDb.saveTreeDetails(tree);
      
      if (success) {
        print('Đã lưu thành công lên server');
      } else {
        print('Lưu thất bại trên server');
      }
      
      return success;
    } catch (e) {
      print('Lỗi khi lưu chi tiết cây lên server: $e');
      return false;
    }
  }

  // Xóa cây trên server
  Future<bool> deleteTreeDetail(int id) async {
    try {
      print('\n=== XÓA CÂY TRÊN SERVER ===');
      print('Xóa cây ID: $id');
      
      final success = await _remoteDb.deleteTreeDetail(id);
      
      if (success) {
        print('Đã xóa thành công trên server');
      } else {
        print('Xóa thất bại trên server');
      }
      
      return success;
    } catch (e) {
      print('Lỗi khi xóa cây trên server: $e');
      return false;
    }
  }

  // Lưu nhiều cây cùng lúc
  Future<bool> saveBulkTreeDetails(List<TreeDetails> trees) async {
    try {
      print('\n=== LƯU NHIỀU CÂY LÊN SERVER ===');
      print('Số lượng cây cần lưu: ${trees.length}');
      
      bool allSuccess = true;
      int successCount = 0;
      
      for (var tree in trees) {
        try {
          final success = await saveTreeDetails(tree);
          if (success) {
            successCount++;
          } else {
            allSuccess = false;
          }
        } catch (e) {
          print('Lỗi khi lưu cây ${tree.id}: $e');
          allSuccess = false;
        }
      }
      
      print('Đã lưu thành công: $successCount/${trees.length} cây');
      return allSuccess;
    } catch (e) {
      print('Lỗi khi lưu nhiều cây: $e');
      return false;
    }
  }

  // Kiểm tra kết nối đến server
  Future<bool> testConnection() async {
    try {
      print('\n=== KIỂM TRA KẾT NỐI SERVER ===');
      return await _remoteDb.testConnection();
    } catch (e) {
      print('Lỗi khi kiểm tra kết nối server: $e');
      return false;
    }
  }
}