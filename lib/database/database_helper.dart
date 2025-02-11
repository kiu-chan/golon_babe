import 'dart:io';

import 'package:postgres/postgres.dart';
import '../models/tree_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static PostgreSQLConnection? _connection;
  bool _isConnecting = false;
  static const int _maxRetries = 3;
  static const _host = '163.44.193.74';
  static const _port = 5432;
  static const _database = 'caygolon_babe';
  static const _username = 'postgres';
  static const _password = '2W34pRi%AEzYtRy3QfF)tV';

  Future<PostgreSQLConnection> get connection async {
    if (_connection != null && !_connection!.isClosed) {
      return _connection!;
    }

    return await _getConnection();
  }

Future<PostgreSQLConnection> _getConnection() async {
  if (_isConnecting) {
    while (_isConnecting) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (_connection != null && !_connection!.isClosed) {
      return _connection!;
    }
  }

  _isConnecting = true;
  
  try {
    // Thử kết nối lần đầu
    _connection = PostgreSQLConnection(
      _host,
      _port,
      _database,
      username: _username,
      password: _password,
      timeoutInSeconds: 5, // Giảm thời gian timeout xuống
      queryTimeoutInSeconds: 5,
      timeZone: 'UTC',
      useSSL: false,
    );

    await _connection!.open();
    _isConnecting = false;
    print('Connected to database successfully');
    return _connection!;

  } catch (e) {
    _isConnecting = false;
    if (_connection != null) {
      try {
        await _connection!.close();
      } catch (e) {
        print('Error closing failed connection: $e');
      }
      _connection = null;
    }
    throw Exception('Failed to connect to database');
  }
}

  Future<List<Map<String, dynamic>>> getMasterTreeInfo() async {
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        final conn = await connection;
        final results = await conn.mappedResultsQuery(
          'SELECT * FROM master_tree_info ORDER BY tree_type',
        );
        return results.map((r) => r['master_tree_info']!).toList();
      } catch (e) {
        retryCount++;
        print('Error getting master tree info (attempt $retryCount): $e');
        
        if (retryCount >= _maxRetries) {
          throw Exception('Failed to get master tree info after $_maxRetries attempts');
        }
        
        await Future.delayed(Duration(seconds: retryCount));
        await _reconnectIfNeeded();
      }
    }
    throw Exception('Unexpected error in getMasterTreeInfo');
  }

  Future<Map<String, dynamic>?> getMasterTreeInfoById(int id) async {
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        final conn = await connection;
        final results = await conn.mappedResultsQuery(
          'SELECT * FROM master_tree_info WHERE id = @id',
          substitutionValues: {'id': id},
        );
        if (results.isEmpty) return null;
        return results.first['master_tree_info'];
      } catch (e) {
        retryCount++;
        print('Error getting master tree info by id (attempt $retryCount): $e');
        
        if (retryCount >= _maxRetries) {
          return null;
        }
        
        await Future.delayed(Duration(seconds: retryCount));
        await _reconnectIfNeeded();
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getTreeDetails() async {
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        final conn = await connection;
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
        print('Error getting tree details (attempt $retryCount): $e');
        
        if (retryCount >= _maxRetries) {
          throw Exception('Failed to get tree details after $_maxRetries attempts');
        }
        
        await Future.delayed(Duration(seconds: retryCount));
        await _reconnectIfNeeded();
      }
    }
    throw Exception('Unexpected error in getTreeDetails');
  }

Future<Map<String, dynamic>?> getTreeDetailsById(int id) async {
  // Thêm tham số để kiểm tra đã thử kết nối lần đầu chưa
  bool hasTriedConnection = false;
  
  int retryCount = 0;
  while (retryCount < _maxRetries) {
    try {
      // Nếu đã thử kết nối một lần và thất bại, không thử lại nữa
      if (hasTriedConnection) {
        return null;
      }
      
      final conn = await connection;
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
      hasTriedConnection = true;
      retryCount++;
      print('Error getting tree details by id (attempt $retryCount): $e');
      
      // Nếu là lỗi kết nối, không thử lại
      if (e is SocketException) {
        return null;
      }
      
      if (retryCount >= _maxRetries) {
        return null;
      }
      
      await Future.delayed(Duration(seconds: retryCount));
      await _reconnectIfNeeded();
    }
  }
  return null;
}

  Future<bool> insertTreeDetail({
    required int masterTreeId,
    required Map<String, dynamic> details,
  }) async {
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        final conn = await connection;
        await conn.transaction((ctx) async {
          // Kiểm tra master tree tồn tại
          final masterTree = await ctx.query(
            'SELECT id FROM master_tree_info WHERE id = @id',
            substitutionValues: {'id': masterTreeId},
          );
          if (masterTree.isEmpty) {
            throw Exception('Master tree not found');
          }

          await ctx.execute('''
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
        });
        return true;
      } catch (e) {
        retryCount++;
        print('Error inserting tree detail (attempt $retryCount): $e');
        
        if (retryCount >= _maxRetries) {
          return false;
        }
        
        await Future.delayed(Duration(seconds: retryCount));
        await _reconnectIfNeeded();
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
        final conn = await connection;
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
        print('Error updating tree detail (attempt $retryCount): $e');
        
        if (retryCount >= _maxRetries) {
          return false;
        }
        
        await Future.delayed(Duration(seconds: retryCount));
        await _reconnectIfNeeded();
      }
    }
    return false;
  }

  Future<bool> saveTreeDetails(TreeDetails details) async {
    try {
      if (details.id != null) {
        return await updateTreeDetail(
          id: details.id!,
          details: details.toJson(),
        );
      } else {
        return await insertTreeDetail(
          masterTreeId: details.masterTreeId,
          details: details.toJson(),
        );
      }
    } catch (e) {
      print('Error saving tree details: $e');
      return false;
    }
  }

  Future<bool> deleteTreeDetail(int id) async {
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        final conn = await connection;
        final result = await conn.execute(
          'DELETE FROM tree_details WHERE id = @id',
          substitutionValues: {'id': id},
        );
        return result > 0;
      } catch (e) {
        retryCount++;
        print('Error deleting tree detail (attempt $retryCount): $e');
        
        if (retryCount >= _maxRetries) {
          return false;
        }
        
        await Future.delayed(Duration(seconds: retryCount));
        await _reconnectIfNeeded();
      }
    }
    return false;
  }

  Future<void> _reconnectIfNeeded() async {
    if (_connection != null) {
      try {
        await _connection!.close();
      } catch (e) {
        print('Error closing connection: $e');
      }
      _connection = null;
    }
  }

Future<bool> testConnection() async {
  try {
    final conn = await connection;
    await conn.query('SELECT 1');
    return true;
  } catch (e) {
    print('Connection test failed: $e');
    return false;
  }
}

  Future<void> close() async {
    if (_connection != null && !_connection!.isClosed) {
      await _connection!.close();
      _connection = null;
    }
  }
}