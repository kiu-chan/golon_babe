import 'package:postgres/postgres.dart';
import 'postgres_core.dart';

class PostgresMasterTree {
  final PostgresCore _core;
  static const int _maxRetries = 3;

  PostgresMasterTree(this._core);

  Future<List<Map<String, dynamic>>> getMasterTreeInfo() async {
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        final conn = await _core.connection;
        final results = await conn.mappedResultsQuery(
          'SELECT * FROM master_tree_info ORDER BY tree_type',
        );
        return results.map((r) => r['master_tree_info']!).toList();
      } catch (e) {
        retryCount++;
        print('Lỗi khi lấy thông tin master tree (lần thử $retryCount): $e');
        
        if (retryCount >= _maxRetries) {
          throw Exception('Không thể lấy thông tin master tree sau $_maxRetries lần thử');
        }
        
        await Future.delayed(Duration(seconds: retryCount));
        await _core.reconnectIfNeeded();
      }
    }
    throw Exception('Lỗi không xác định trong getMasterTreeInfo');
  }

  Future<Map<String, dynamic>?> getMasterTreeInfoById(int id) async {
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        final conn = await _core.connection;
        final results = await conn.mappedResultsQuery(
          'SELECT * FROM master_tree_info WHERE id = @id',
          substitutionValues: {'id': id},
        );
        if (results.isEmpty) return null;
        return results.first['master_tree_info'];
      } catch (e) {
        retryCount++;
        print('Lỗi khi lấy thông tin master tree theo id (lần thử $retryCount): $e');
        
        if (retryCount >= _maxRetries) {
          return null;
        }
        
        await Future.delayed(Duration(seconds: retryCount));
        await _core.reconnectIfNeeded();
      }
    }
    return null;
  }
}