import 'package:golon_babe/database/database_helper.dart';
import '../models/tree_model.dart';

class TreeRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<MasterTreeInfo>> getAllMasterTreeInfo() async {
    final data = await _db.getMasterTreeInfo();
    return data.map((json) => MasterTreeInfo.fromJson(json)).toList();
  }

  Future<MasterTreeInfo?> getMasterTreeInfoById(int id) async {
    final data = await _db.getMasterTreeInfoById(id);
    if (data == null) return null;
    return MasterTreeInfo.fromJson(data);
  }

  Future<List<TreeDetails>> getAllTreeDetails() async {
    final data = await _db.getTreeDetails();
    return data.map((json) => TreeDetails.fromJson(json)).toList();
  }

  Future<TreeDetails?> getTreeDetailsById(int id) async {
    final data = await _db.getTreeDetailsById(id);
    if (data == null) return null;
    return TreeDetails.fromJson(data);
  }

  Future<bool> saveTreeDetails(TreeDetails details) async {
    final Map<String, dynamic> dbData = {
      'master_tree_id': details.masterTreeId,
      'coordinate_x': details.coordinateX,
      'coordinate_y': details.coordinateY,
      'height': details.height,
      'trunk_diameter': details.diameter,
      'canopy_coverage': details.coverLevel,
      'sea_level_height': details.seaLevel,
      'image_base64': details.imageBase64,
      'notes': details.note,
    };

    if (details.id != null) {
      return await _db.updateTreeDetail(
        id: details.id!,
        details: dbData,
      );
    } else {
      return await _db.insertTreeDetail(
        masterTreeId: details.masterTreeId,
        details: dbData,
      );
    }
  }

  Future<void> dispose() async {
    await _db.close();
  }
}