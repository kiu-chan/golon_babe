import 'dart:io';
import 'package:postgres/postgres.dart';
import '../models/tree_model.dart';
import '../config/env_config.dart';

class DatabaseHelper {
  // Singleton pattern implementation
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  // Class properties
  static PostgreSQLConnection? _connection;
  bool _isConnecting = false;
  static const int _maxRetries = 3;

  // Environment variables getters
  static String get _host => EnvConfig.dbHost;
  static int get _port => EnvConfig.dbPort;
  static String get _database => EnvConfig.dbName;
  static String get _username => EnvConfig.dbUser;
  static String get _password => EnvConfig.dbPassword;

  // Get database connection
  Future<PostgreSQLConnection> get connection async {
    if (_connection != null && !_connection!.isClosed) {
      return _connection!;
    }
    return await _getConnection();
  }

  // Connect to database with retry mechanism
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
      print('Attempting to connect to database at $_host:$_port');
      
      _connection = PostgreSQLConnection(
        _host,
        _port,
        _database,
        username: _username,
        password: _password,
        timeoutInSeconds: 5,
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
      throw Exception('Failed to connect to database: $e');
    }
  }

  // Get master tree information
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

  // Get master tree info by ID
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

  // Get all tree details
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

  // Get tree details by ID
  Future<Map<String, dynamic>?> getTreeDetailsById(int id) async {
    try {
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
      print('Error getting tree details by id: $e');
      if (e is SocketException) {
        await _reconnectIfNeeded();
      }
      return null;
    }
  }

  // Insert new tree detail
  Future<bool> insertTreeDetail({
    required int masterTreeId,
    required Map<String, dynamic> details,
  }) async {
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        final conn = await connection;
        await conn.transaction((ctx) async {
          // Check if master tree exists
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

  // Update existing tree detail
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

  // Save tree details (insert or update)
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

  // Delete tree detail
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

  // Test database connection
  Future<bool> testConnection() async {
    try {
      print('Testing database connection...');
      
      // Close existing connection if any
      if (_connection != null) {
        try {
          await _connection!.close();
        } catch (e) {
          print('Error closing existing connection: $e');
        }
        _connection = null;
        _isConnecting = false;
      }

      // Try new connection
      _connection = PostgreSQLConnection(
        _host,
        _port,
        _database,
        username: _username,
        password: _password,
        timeoutInSeconds: 5,
        queryTimeoutInSeconds: 5,
        timeZone: 'UTC',
        useSSL: false,
      );

      await _connection!.open();
      await _connection!.query('SELECT 1');
      print('Database connection test successful');
      return true;
    } catch (e) {
      print('Database connection test failed: $e');
      if (_connection != null) {
        try {
          await _connection!.close();
        } catch (e) {
          print('Error closing failed connection: $e');
        }
        _connection = null;
        _isConnecting = false;
      }
      return false;
    }
  }

  // Reconnect if needed
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

  // Close database connection
  Future<void> close() async {
    if (_connection != null && !_connection!.isClosed) {
      await _connection!.close();
      _connection = null;
    }
  }
}