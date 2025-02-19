import 'package:flutter/material.dart';
import 'package:golon_babe/models/tree_model.dart';
import 'package:golon_babe/repositories/tree_repository.dart';

class TreeFormController {
 final formKey = GlobalKey<FormState>();

 final idController = TextEditingController();
 final coordinateXController = TextEditingController();
 final coordinateYController = TextEditingController();
 final heightController = TextEditingController();
 final diameterController = TextEditingController();
 final seaLevelController = TextEditingController();
 final noteController = TextEditingController();
 
 final tayNameController = TextEditingController();
 final scientificNameController = TextEditingController();
 final branchController = TextEditingController();
 final treeClassController = TextEditingController();
 final divisionController = TextEditingController();
 final familyController = TextEditingController();
 final genusController = TextEditingController();

 MasterTreeInfo? selectedTree;
 String? selectedCoverLevel;
 String? imageBase64;
 bool isEditing = false;
 int? editingId;
 String? imageError;
 List<TreeAdditionalImage> additionalImages = [];

 final TreeRepository _repository;

 TreeFormController(this._repository);

 void resetForm() {
   print('\n=== RESET FORM ===');
   isEditing = false;
   editingId = null; 
   selectedTree = null;
   selectedCoverLevel = null;
   imageBase64 = null;
   imageError = null;
   additionalImages = [];
   
   idController.clear();
   coordinateXController.clear();
   coordinateYController.clear();
   heightController.clear();
   diameterController.clear();
   seaLevelController.clear();
   noteController.clear();
   _clearMasterTreeInfo();
   
   print('Đã reset form về trạng thái ban đầu');
 }

 void _clearMasterTreeInfo() {
   tayNameController.clear();
   scientificNameController.clear();
   branchController.clear();
   treeClassController.clear();
   divisionController.clear();
   familyController.clear();
   genusController.clear();
 }

 void updateTreeInfo(MasterTreeInfo? tree) {
   selectedTree = tree;
   if (tree != null) {
     print('\n=== CẬP NHẬT THÔNG TIN MASTER TREE ===');
     print('ID: ${tree.id}');
     print('Tên: ${tree.treeType}');
     
     tayNameController.text = tree.tayName ?? '';
     scientificNameController.text = tree.scientificName ?? '';
     branchController.text = tree.branch ?? '';
     treeClassController.text = tree.treeClass ?? '';
     divisionController.text = tree.division ?? '';
     familyController.text = tree.family ?? '';
     genusController.text = tree.genus ?? '';
   } else {
     print('\n=== XÓA THÔNG TIN MASTER TREE ===');
     _clearMasterTreeInfo();
   }
 }

Future<bool> searchTreeById(String id) async {
  try {
    final idNumber = int.tryParse(id);
    if (idNumber == null) return false;
    
    print('\n=== BẮT ĐẦU TÌM KIẾM CÂY ===');
    print('ID người dùng nhập: $id'); 
    print('ID đã parse: $idNumber');
    print('ID đang sửa hiện tại: $editingId');
    
    final treeDetails = await _repository.getTreeDetailsById(idNumber);
    
    if (treeDetails != null) {
      print('Đã tìm thấy cây:');
      print('ID cây: ${treeDetails.id}');
      print('Master Tree ID: ${treeDetails.masterTreeId}');
      
      isEditing = true;
      editingId = treeDetails.id; // Lưu ID của tree_details
      print('Đã set editingId = $editingId');
      
      _updateFormWithTreeDetails(treeDetails);
      
      // Load ảnh phụ với tree_details ID
      if (editingId != null) {
        print('Đang tải ảnh phụ cho tree detail ID: $editingId'); 
        additionalImages = await _repository.getAdditionalImages(editingId!);
        print('Đã tải ${additionalImages.length} ảnh phụ');
      }
      
      return true;
    }
    
    print('Không tìm thấy cây ID: $idNumber');
    resetForm();
    return false;
  } catch (e) {
    print('Lỗi khi tìm kiếm cây: $e');
    resetForm();
    return false;
  }
}

void _updateFormWithTreeDetails(TreeDetails tree) {
  print('\n=== CẬP NHẬT FORM VỚI DỮ LIỆU CÂY ==='); 
  print('ID ban đầu: ${tree.id}');  // ID của tree_details
  print('Master Tree ID: ${tree.masterTreeId}');
  
  editingId = tree.id;  // Đảm bảo lưu đúng ID của tree_details
  
  coordinateXController.text = tree.coordinateX?.toString() ?? '';
  coordinateYController.text = tree.coordinateY?.toString() ?? '';
  heightController.text = tree.height?.toString() ?? '';
  diameterController.text = tree.diameter?.toString() ?? '';
  selectedCoverLevel = tree.coverLevel;
  seaLevelController.text = tree.seaLevel?.toString() ?? '';
  noteController.text = tree.note ?? '';
  imageBase64 = tree.imageBase64;
  
  if (tree.masterInfo != null) {
    selectedTree = tree.masterInfo;
    updateTreeInfo(tree.masterInfo);
    print('Đã cập nhật thông tin loại cây: ${tree.masterInfo!.treeType}');
  }
}

 Future<bool> handleSubmit() async {
   print('\n=== XỬ LÝ SUBMIT FORM ===');
   print('ID cây đang sửa (editingId): $editingId');
   print('ID loại cây đã chọn: ${selectedTree?.id}');

   if (!formKey.currentState!.validate()) {
     print('Form validation failed');
     return false;
   }

   if (selectedTree == null) {
     print('Chưa chọn loại cây');
     return false;
   }

   try {
     final isOnline = await _repository.hasInternetConnection();
     print('Trạng thái kết nối: ${isOnline ? "Online" : "Offline"}');

     final details = TreeDetails(
       id: editingId,
       masterTreeId: selectedTree!.id,
       coordinateX: _parseDouble(coordinateXController.text),
       coordinateY: _parseDouble(coordinateYController.text),
       height: _parseDouble(heightController.text),
       diameter: _parseDouble(diameterController.text),
       coverLevel: selectedCoverLevel,
       seaLevel: _parseDouble(seaLevelController.text),
       imageBase64: imageBase64,
       note: noteController.text,
       masterInfo: selectedTree,
     );

     print('Đang lưu thông tin cây...');
     final success = await _repository.saveTreeDetails(details);
     
     if (success) {
       print('Đã lưu thông tin cây thành công');
       if (isOnline && !_repository.isSyncing) {
         print('Bắt đầu đồng bộ dữ liệu...');
         await _repository.syncData();
       }
       formKey.currentState!.reset();
       resetForm();
     } else {
       print('Lỗi khi lưu thông tin cây');
     }
     
     return success;

   } catch (e) {
     print('Lỗi khi xử lý submit form:');
     print(e.toString());
     print('Stack trace:');
     print(StackTrace.current);
     return false;
   }
 }

 double? _parseDouble(String value) {
   if (value.isEmpty) return null;
   try {
     return double.parse(value.replaceAll(',', '.'));
   } catch (e) {
     print('Lỗi parse double: $value');
     return null;
   }
 }

 void dispose() {
   idController.dispose();
   coordinateXController.dispose();
   coordinateYController.dispose();
   heightController.dispose();
   diameterController.dispose();
   seaLevelController.dispose();
   noteController.dispose();
   tayNameController.dispose();
   scientificNameController.dispose();
   branchController.dispose();
   treeClassController.dispose();
   divisionController.dispose();
   familyController.dispose();
   genusController.dispose();
 }
}