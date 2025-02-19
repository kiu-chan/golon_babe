import 'package:golon_babe/models/tree_model.dart';
import 'package:sqflite/sqflite.dart';
import 'sqlite_core.dart';

class SQLiteAdditionalImages {
  final SQLiteCore _core;

  SQLiteAdditionalImages(this._core);

Future<List<TreeAdditionalImage>> getImagesByTreeId(int treeId) async {
  try {
    print('\n=== LẤY ẢNH PHỤ TỪ SQLITE ===');
    print('Tree Detail ID cần tìm: $treeId');
    
    final db = await _core.database;
    
    // In ra cấu trúc bảng để debug
    final tableInfo = await db.query('sqlite_master', 
      where: 'type = ? AND name = ?',
      whereArgs: ['table', 'tree_additional_images']
    );
    print('Cấu trúc bảng tree_additional_images:');
    print(tableInfo.first['sql']);
    
    // Kiểm tra dữ liệu hiện có
    final allImages = await db.query('tree_additional_images');
    print('Tổng số ảnh phụ trong database: ${allImages.length}');
    for (var img in allImages) {
      print('ID: ${img['id']}, Tree Detail ID: ${img['tree_detail_id']}');
    }
    
    // Lấy ảnh theo tree_detail_id
    final results = await db.query(
      'tree_additional_images',
      where: 'tree_detail_id = ?',
      whereArgs: [treeId],
      orderBy: 'created_at DESC',
    );
    
    print('Tìm thấy ${results.length} ảnh phụ cho cây ID $treeId');
    
    final images = results.map((map) => TreeAdditionalImage.fromJson(map)).toList();
    print('Đã chuyển đổi thành công sang đối tượng TreeAdditionalImage');
    
    return images;
  } catch (e) {
    print('Lỗi khi lấy ảnh phụ từ SQLite:');
    print(e.toString());
    print('Stack trace:');
    print(StackTrace.current);
    return [];
  }
}

Future<int> saveImage(TreeAdditionalImage image) async {
  try {
    print('\n=== LƯU ẢNH PHỤ VÀO SQLITE ===');
    final db = await _core.database;
    
    String? imageBase64 = image.imageBase64;
    // Xử lý base64 data URI nếu có
    if (imageBase64.contains(',')) {
      print('Phát hiện data URI, đang xử lý...');
      imageBase64 = imageBase64.split(',')[1];
    }

    print('Tree Detail ID: ${image.treeDetailId}');
    print('Image Base64 length: ${imageBase64.length}');

    final data = {
      'tree_detail_id': image.treeDetailId,
      'image_base64': imageBase64,
      'created_at': DateTime.now().toIso8601String(),
      'sync_status': 'pending',
    };

    // Nếu có ID, thử update trước
    if (image.id != null) {
      print('Cập nhật ảnh phụ ID: ${image.id}');
      final count = await db.update(
        'tree_additional_images',
        data,
        where: 'id = ?',
        whereArgs: [image.id],
      );
      if (count > 0) {
        print('Đã cập nhật ảnh phụ thành công');
        return image.id!;
      }
    }

    // Thêm mới nếu không có ID hoặc update thất bại
    print('Thêm ảnh phụ mới...');
    final id = await db.insert(
      'tree_additional_images',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    print('Đã lưu ảnh phụ với ID: $id');
    return id;
  } catch (e) {
    print('Lỗi khi lưu ảnh phụ vào SQLite:');
    print(e.toString());
    print('Stack trace:');
    print(StackTrace.current);
    throw e;
  }
}

  Future<bool> deleteImage(int id) async {
    try {
      final db = await _core.database;
      final count = await db.delete(
        'tree_additional_images',
        where: 'id = ?',
        whereArgs: [id],
      );
      return count > 0;
    } catch (e) {
      print('Lỗi khi xóa ảnh phụ từ SQLite: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getPendingSyncImages() async {
    try {
      final db = await _core.database;
      return await db.query(
        'tree_additional_images',
        where: 'sync_status = ?',
        whereArgs: ['pending'],
      );
    } catch (e) {
      print('Lỗi khi lấy ảnh phụ chờ đồng bộ: $e');
      return [];
    }
  }

  Future<void> markAsSynced(int id) async {
    try {
      final db = await _core.database;
      await db.update(
        'tree_additional_images',
        {
          'sync_status': 'synced',
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('Lỗi khi đánh dấu ảnh phụ đã đồng bộ: $e');
    }
  }
}