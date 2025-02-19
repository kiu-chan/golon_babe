import 'package:postgres/postgres.dart';
import '../../models/tree_model.dart';
import 'postgres_core.dart';

class PostgresAdditionalImages {
  final PostgresCore _core;
  static const int _maxRetries = 3;

  PostgresAdditionalImages(this._core);

  Future<List<TreeAdditionalImage>> getImagesByTreeId(int treeId) async {
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        final conn = await _core.connection;
        final results = await conn.mappedResultsQuery('''
          SELECT * FROM tree_additional_images 
          WHERE tree_detail_id = @treeId
          ORDER BY created_at DESC
        ''', substitutionValues: {'treeId': treeId});
        
        return results.map((r) => 
          TreeAdditionalImage.fromJson(r['tree_additional_images']!)
        ).toList();
      } catch (e) {
        retryCount++;
        print('Lỗi khi lấy ảnh phụ (lần thử $retryCount): $e');
        
        if (retryCount >= _maxRetries) {
          throw Exception('Không thể lấy ảnh phụ sau $_maxRetries lần thử');
        }
        
        await Future.delayed(Duration(seconds: retryCount));
        await _core.reconnectIfNeeded();
      }
    }
    throw Exception('Lỗi không xác định trong getImagesByTreeId');
  }

  Future<bool> saveImage(TreeAdditionalImage image) async {
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        final conn = await _core.connection;
        await conn.execute('''
          INSERT INTO tree_additional_images (
            tree_detail_id, image_base64, created_at
          ) VALUES (
            @treeId, @imageBase64, CURRENT_TIMESTAMP
          )
        ''', substitutionValues: {
          'treeId': image.treeDetailId,
          'imageBase64': image.imageBase64,
        });
        return true;
      } catch (e) {
        retryCount++;
        print('Lỗi khi lưu ảnh phụ (lần thử $retryCount): $e');
        
        if (retryCount >= _maxRetries) {
          return false;
        }
        
        await Future.delayed(Duration(seconds: retryCount));
        await _core.reconnectIfNeeded();
      }
    }
    return false;
  }

  Future<bool> deleteImage(int id) async {
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        final conn = await _core.connection;
        final result = await conn.execute(
          'DELETE FROM tree_additional_images WHERE id = @id',
          substitutionValues: {'id': id},
        );
        return result > 0;
      } catch (e) {
        retryCount++;
        print('Lỗi khi xóa ảnh phụ (lần thử $retryCount): $e');
        
        if (retryCount >= _maxRetries) {
          return false;
        }
        
        await Future.delayed(Duration(seconds: retryCount));
        await _core.reconnectIfNeeded();
      }
    }
    return false;
  }
}