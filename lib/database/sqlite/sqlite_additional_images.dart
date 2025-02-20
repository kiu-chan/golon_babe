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
    
    // Lấy ảnh theo tree_detail_id
    final results = await db.query(
      'tree_additional_images',
      where: 'tree_detail_id = ?',
      whereArgs: [treeId],
      orderBy: 'created_at DESC',
    );
    
    print('Tìm thấy ${results.length} ảnh phụ');

    final images = results.map((map) {
      final image = TreeAdditionalImage.fromJson(map);
      print('Chuyển đổi ảnh: ID=${image.id}, Size=${image.imageBase64.length}');
      return image;
    }).toList();
    
    print('Đã chuyển đổi thành công ${images.length} ảnh');
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
    
    // Kiểm tra ảnh đã tồn tại chưa
    if (image.id != null) {
      final existing = await db.query(
        'tree_additional_images',
        where: 'id = ?',
        whereArgs: [image.id],
      );
      if (existing.isNotEmpty) {
        print('Ảnh đã tồn tại, bỏ qua');
        return image.id!;
      }
    }

    String? imageBase64 = image.imageBase64;
    if (imageBase64.contains(',')) {
      imageBase64 = imageBase64.split(',')[1];
    }

    final data = {
      if (image.id != null) 'id': image.id,
      'tree_detail_id': image.treeDetailId,
      'image_base64': imageBase64,
      'created_at': DateTime.now().toIso8601String(),
      'sync_status': 'pending',
    };

    final id = await db.insert(
      'tree_additional_images',
      data,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    
    print('Đã lưu ảnh phụ với ID: $id');
    return id;
  } catch (e) {
    print('Lỗi khi lưu ảnh phụ vào SQLite: $e');
    throw e;
  }
}

Future<bool> deleteImage(int id) async {
  try {
    print('\n=== XÓA ẢNH PHỤ TỪ SQLITE ===');
    print('Xóa ảnh ID: $id');
    
    final db = await _core.database;
    
    // Kiểm tra ảnh tồn tại
    final existing = await db.query(
      'tree_additional_images',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (existing.isEmpty) {
      print('Không tìm thấy ảnh ID: $id');
      return false;
    }

    final count = await db.delete(
      'tree_additional_images',
      where: 'id = ?',
      whereArgs: [id],
    );

    final success = count > 0;
    print(success ? 'Đã xóa ảnh thành công' : 'Xóa ảnh thất bại');
    return success;

  } catch (e) {
    print('Lỗi khi xóa ảnh phụ từ SQLite:');
    print(e.toString());
    print('Stack trace:');
    print(StackTrace.current);
    return false;
  }
}

Future<List<Map<String, dynamic>>> getPendingSyncImages() async {
  try {
    print('\n=== LẤY ẢNH PHỤ ĐANG CHỜ ĐỒNG BỘ ===');
    final db = await _core.database;
    
    final results = await db.query(
      'tree_additional_images',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
    );
    
    print('Có ${results.length} ảnh phụ đang chờ đồng bộ:');
    for (var img in results) {
      print('- ID: ${img['id']}, Tree ID: ${img['tree_detail_id']}');
    }
    
    return results;
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