import 'dart:io';

import 'package:postgres/postgres.dart';
import '../../models/tree_model.dart';
import 'postgres_core.dart';

class PostgresTreeDetails {
  final PostgresCore _core;
  static const int _maxRetries = 3;

  PostgresTreeDetails(this._core);

  Future<List<Map<String, dynamic>>> getTreeDetails() async {
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        final conn = await _core.connection;
        final results = await conn.mappedResultsQuery('''
          SELECT td.*, mti.tree_type, mti.scientific_name, mti.tay_name,
                 mti.branch, mti.class, mti.division, mti.family, mti.genus
          FROM tree_details td
          JOIN master_tree_info mti ON td.master_tree_id = mti.id
          ORDER BY td.created_at DESC
        ''');
        return results.map((r) => {
          ...r['tree_details']!,
          ...r['master_tree_info']!,
        }).toList();
      } catch (e) {
        retryCount++;
        print('Lỗi khi lấy chi tiết cây (lần thử $retryCount): $e');
        
        if (retryCount >= _maxRetries) {
          throw Exception('Không thể lấy chi tiết cây sau $_maxRetries lần thử');
        }
        
        await Future.delayed(Duration(seconds: retryCount));
        await _core.reconnectIfNeeded();
      }
    }
    throw Exception('Lỗi không xác định trong getTreeDetails');
  }

  Future<Map<String, dynamic>?> getTreeDetailsById(int id) async {
    try {
      final conn = await _core.connection;
      final results = await conn.mappedResultsQuery('''
        SELECT td.*, mti.tree_type, mti.scientific_name, mti.tay_name,
               mti.branch, mti.class, mti.division, mti.family, mti.genus
        FROM tree_details td
        JOIN master_tree_info mti ON td.master_tree_id = mti.id
        WHERE td.id = @id
      ''', substitutionValues: {'id': id});
      
      if (results.isEmpty) return null;
      return {
        ...results.first['tree_details']!,
        ...results.first['master_tree_info']!,
      };
    } catch (e) {
      print('Lỗi khi lấy chi tiết cây theo id: $e');
      if (e is SocketException) {
        await _core.reconnectIfNeeded();
      }
      return null;
    }
  }

Future<bool> insertTreeDetail({
  required int masterTreeId,
  required Map<String, dynamic> details,
}) async {
  int retryCount = 0;
  while (retryCount < _maxRetries) {
    try {
      print('\n=== LƯU CHI TIẾT CÂY LÊN SERVER ===');
      final conn = await _core.connection;
      
      final success = await conn.transaction((ctx) async {
        // Kiểm tra master tree tồn tại
        final masterTree = await ctx.query(
          'SELECT id FROM master_tree_info WHERE id = @id',
          substitutionValues: {'id': masterTreeId},
        );
        if (masterTree.isEmpty) {
          throw Exception('Không tìm thấy master tree');
        }

        final result = await ctx.execute('''
          INSERT INTO tree_details (
            master_tree_id, coordinate_x, coordinate_y, height,
            trunk_diameter, canopy_coverage, sea_level_height,
            image_base64, notes, created_at
          ) VALUES (
            @masterTreeId, @coordX, @coordY, @height,
            @diameter, @coverage, @seaLevel,
            @imageBase64, @notes, CURRENT_TIMESTAMP
          )
        ''', substitutionValues: {
          'masterTreeId': masterTreeId,
          'coordX': details['coordinate_x'],
          'coordY': details['coordinate_y'],
          'height': details['height'],
          'diameter': details['trunk_diameter'],
          'coverage': details['canopy_coverage'],
          'seaLevel': details['sea_level_height'],
          'imageBase64': details['image_base64'],
          'notes': details['notes'],
        });

        return result > 0;
      });

      print(success ? 'Đã lưu thành công lên server' : 'Lưu thất bại trên server');
      return success;

    } catch (e) {
      retryCount++;
      print('Lỗi khi lưu chi tiết cây (lần thử $retryCount): $e');
      
      if (retryCount >= _maxRetries) {
        return false;
      }
      
      await Future.delayed(Duration(seconds: retryCount));
      await _core.reconnectIfNeeded();
    }
  }
  return false;
}

  Future<bool> updateTreeDetail({
    required int id,
    required Map<String, dynamic> details,
  }) async {
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        final conn = await _core.connection;
        final result = await conn.execute('''
          UPDATE tree_details
          SET master_tree_id = @masterTreeId,
              coordinate_x = @coordX,
              coordinate_y = @coordY,
              height = @height,
              trunk_diameter = @diameter,
              canopy_coverage = @coverage,
              sea_level_height = @seaLevel,
              image_base64 = @imageBase64,
              notes = @notes,
              updated_at = CURRENT_TIMESTAMP
          WHERE id = @id
        ''', substitutionValues: {
          'id': id,
          'masterTreeId': details['master_tree_id'],
          'coordX': details['coordinate_x'],
          'coordY': details['coordinate_y'],
          'height': details['height'],
          'diameter': details['trunk_diameter'],
          'coverage': details['canopy_coverage'],
          'seaLevel': details['sea_level_height'],
          'imageBase64': details['image_base64'],
          'notes': details['notes'],
        });
        return result > 0;
      } catch (e) {
        retryCount++;
        print('Lỗi khi cập nhật chi tiết cây (lần thử $retryCount): $e');
        
        if (retryCount >= _maxRetries) {
          return false;
        }
        
        await Future.delayed(Duration(seconds: retryCount));
        await _core.reconnectIfNeeded();
      }
    }
    return false;
  }

  Future<bool> deleteTreeDetail(int id) async {
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        final conn = await _core.connection;
        final result = await conn.execute(
          'DELETE FROM tree_details WHERE id = @id',
          substitutionValues: {'id': id},
        );
        return result > 0;
      } catch (e) {
        retryCount++;
        print('Lỗi khi xóa chi tiết cây (lần thử $retryCount): $e');
        
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