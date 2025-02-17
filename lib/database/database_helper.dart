import 'package:golon_babe/database/postgres/postgres_core.dart';
import 'package:golon_babe/database/postgres/postgres_master_tree.dart';
import 'package:golon_babe/database/postgres/postgres_tree_details.dart';
import '../models/tree_model.dart';

class PostgresHelper {
  static final PostgresHelper _instance = PostgresHelper._internal();
  final PostgresCore _core = PostgresCore();
  late final PostgresMasterTree masterTree;
  late final PostgresTreeDetails treeDetails;
  
  factory PostgresHelper() => _instance;
  
  PostgresHelper._internal() {
    masterTree = PostgresMasterTree(_core);
    treeDetails = PostgresTreeDetails(_core);
  }

  // Wrapper methods for master tree info
  Future<List<Map<String, dynamic>>> getMasterTreeInfo() async {
    return await masterTree.getMasterTreeInfo();
  }

  Future<Map<String, dynamic>?> getMasterTreeInfoById(int id) async {
    return await masterTree.getMasterTreeInfoById(id);
  }

  // Wrapper methods for tree details
  Future<List<Map<String, dynamic>>> getTreeDetails() async {
    return await treeDetails.getTreeDetails();
  }

  Future<Map<String, dynamic>?> getTreeDetailsById(int id) async {
    return await treeDetails.getTreeDetailsById(id);
  }

  Future<bool> insertTreeDetail({
    required int masterTreeId,
    required Map<String, dynamic> details,
  }) async {
    return await treeDetails.insertTreeDetail(
      masterTreeId: masterTreeId,
      details: details,
    );
  }

  Future<bool> updateTreeDetail({
    required int id,
    required Map<String, dynamic> details,
  }) async {
    return await treeDetails.updateTreeDetail(
      id: id,
      details: details,
    );
  }

  Future<bool> deleteTreeDetail(int id) async {
    return await treeDetails.deleteTreeDetail(id);
  }

  // Phương thức lưu tree details (insert hoặc update)
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
      print('Lỗi khi lưu chi tiết cây: $e');
      return false;
    }
  }

  // Kiểm tra kết nối database
  Future<bool> testConnection() async {
    return await _core.testConnection();
  }

  // Đóng kết nối database
  Future<void> close() async {
    await _core.close();
  }
}