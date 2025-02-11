import 'package:postgres/postgres.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static PostgreSQLConnection? _connection;

  Future<PostgreSQLConnection> get connection async {
    if (_connection == null || _connection!.isClosed) {
      _connection = PostgreSQLConnection(
        '163.44.193.74',  // host
        5432,             // port
        'caygolon_babe',  // database name
        username: 'postgres',
        password: '2W34pRi%AEzYtRy3QfF)tV',
      );
      await _connection!.open();
    }
    return _connection!;
  }

  Future<List<Map<String, dynamic>>> getMasterTreeInfo() async {
    final conn = await connection;
    final results = await conn.mappedResultsQuery(
      'SELECT * FROM master_tree_info ORDER BY tree_type',
    );
    return results.map((r) => r['master_tree_info']!).toList();
  }

  Future<Map<String, dynamic>?> getMasterTreeInfoById(int id) async {
    final conn = await connection;
    final results = await conn.mappedResultsQuery(
      'SELECT * FROM master_tree_info WHERE id = @id',
      substitutionValues: {'id': id},
    );
    if (results.isEmpty) return null;
    return results.first['master_tree_info'];
  }

  Future<List<Map<String, dynamic>>> getTreeDetails() async {
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
  }

  Future<Map<String, dynamic>?> getTreeDetailsById(int id) async {
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
  }

  Future<bool> insertTreeDetail({
    required int masterTreeId,
    required Map<String, dynamic> details,
  }) async {
    try {
      final conn = await connection;
      await conn.execute('''
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
      return true;
    } catch (e) {
      print('Error inserting tree detail: $e');
      return false;
    }
  }

  Future<bool> updateTreeDetail({
    required int id,
    required Map<String, dynamic> details,
  }) async {
    try {
      final conn = await connection;
      await conn.execute('''
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
        'imageBase64': details['image_url'],
        'notes': details['notes'],
      });
      return true;
    } catch (e) {
      print('Error updating tree detail: $e');
      return false;
    }
  }

  Future<bool> deleteTreeDetail(int id) async {
    try {
      final conn = await connection;
      await conn.execute(
        'DELETE FROM tree_details WHERE id = @id',
        substitutionValues: {'id': id},
      );
      return true;
    } catch (e) {
      print('Error deleting tree detail: $e');
      return false;
    }
  }

  Future<void> close() async {
    if (_connection != null && !_connection!.isClosed) {
      await _connection!.close();
    }
  }
}