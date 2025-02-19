// Vị trí: lib/database/database_helper.dart

import 'package:golon_babe/database/postgres/postgres_core.dart';
import 'package:golon_babe/database/postgres/postgres_master_tree.dart';
import 'package:golon_babe/database/postgres/postgres_tree_details.dart';
import 'package:golon_babe/database/postgres/postgres_additional_images.dart';
import '../models/tree_model.dart';

class PostgresHelper {
 static final PostgresHelper _instance = PostgresHelper._internal();
 final PostgresCore _core = PostgresCore();
 late final PostgresMasterTree masterTree;
 late final PostgresTreeDetails treeDetails;
 late final PostgresAdditionalImages additionalImages;
 
 factory PostgresHelper() => _instance;
 
 PostgresHelper._internal() {
   masterTree = PostgresMasterTree(_core);
   treeDetails = PostgresTreeDetails(_core);
   additionalImages = PostgresAdditionalImages(_core);
 }

 Future<List<Map<String, dynamic>>> getMasterTreeInfo() async {
   return await masterTree.getMasterTreeInfo();
 }

 Future<Map<String, dynamic>?> getMasterTreeInfoById(int id) async {
   return await masterTree.getMasterTreeInfoById(id);
 }

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

 Future<bool> saveAdditionalImage(TreeAdditionalImage image) async {
   return await additionalImages.saveImage(image);
 }

 Future<List<TreeAdditionalImage>> getAdditionalImages(int treeId) async {
   return await additionalImages.getImagesByTreeId(treeId);
 }

 Future<bool> deleteAdditionalImage(int id) async {
   return await additionalImages.deleteImage(id);
 }

 Future<bool> testConnection() async {
   return await _core.testConnection();
 }

 Future<void> close() async {
   await _core.close();
 }
}