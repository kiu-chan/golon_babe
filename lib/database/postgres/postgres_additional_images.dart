// Vị trí: lib/database/postgres/postgres_additional_images.dart

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
        SELECT id, tree_detail_id, image_base64, created_at 
        FROM tree_additional_images 
        WHERE tree_detail_id = @treeId
        ORDER BY created_at DESC
      ''', substitutionValues: {'treeId': treeId});
      
      return results.map((r) {
        final data = r['tree_additional_images']!;
        print('Server image - ID: ${data['id']}, Tree ID: ${data['tree_detail_id']}');
        return TreeAdditionalImage(
          id: data['id'],
          treeDetailId: data['tree_detail_id'],
          imageBase64: data['image_base64'],
          createdAt: data['created_at']?.toString(),
        );
      }).toList();
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
      print('\n=== LƯU ẢNH PHỤ LÊN SERVER ===');
      final conn = await _core.connection;
      
      String base64String = image.imageBase64;
      if (base64String.contains(',')) {
        base64String = base64String.split(',')[1];
      }
      
      print('Tree Detail ID: ${image.treeDetailId}');
      print('Image Base64 length: ${base64String.length}');
      
      // Kiểm tra và cập nhật nếu ảnh đã tồn tại
      if (image.id != null) {
        final existingImages = await conn.mappedResultsQuery(
          'SELECT id FROM tree_additional_images WHERE id = @id',
          substitutionValues: {'id': image.id},
        );
        
        if (existingImages.isNotEmpty) {
          print('Ảnh đã tồn tại, bỏ qua');
          return true;
        }
      }
      
      final results = await conn.execute('''
        INSERT INTO tree_additional_images (
          tree_detail_id, image_base64, created_at
        ) VALUES (
          @treeId, @imageBase64, CURRENT_TIMESTAMP
        )
      ''', substitutionValues: {
        'treeId': image.treeDetailId,
        'imageBase64': base64String,
      });
      
      print('Đã lưu ảnh phụ lên server thành công');
      return results > 0;
      
    } catch (e) {
      retryCount++;
      print('Lỗi khi lưu ảnh phụ (lần thử $retryCount): $e');
      
      if (retryCount >= _maxRetries) {
        print('Đã hết số lần thử');
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
      print('\n=== XÓA ẢNH PHỤ TRÊN SERVER ===');
      print('Đang xóa ảnh ID: $id (lần thử ${retryCount + 1})');
      
      final conn = await _core.connection;
      
      // Kiểm tra ảnh tồn tại
      final exists = await conn.mappedResultsQuery(
        'SELECT id FROM tree_additional_images WHERE id = @id',
        substitutionValues: {'id': id}
      );
      
      if (exists.isEmpty) {
        print('Ảnh không tồn tại trên server');
        return true; // Coi như xóa thành công nếu ảnh không tồn tại
      }
      
      final result = await conn.execute(
        'DELETE FROM tree_additional_images WHERE id = @id',
        substitutionValues: {'id': id},
      );
      
      print('Kết quả xóa: ${result > 0 ? "thành công" : "thất bại"}');
      return result > 0;
      
    } catch (e) {
      retryCount++;
      print('Lỗi khi xóa ảnh phụ (lần thử $retryCount): $e');
      
      if (retryCount >= _maxRetries) {
        print('Đã hết số lần thử');
        return false;
      }
      
      await Future.delayed(Duration(seconds: retryCount * 2)); // Tăng thời gian chờ
      await _core.reconnectIfNeeded();
    }
  }
  return false;
}
}