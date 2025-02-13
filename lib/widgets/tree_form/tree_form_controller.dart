import 'package:flutter/material.dart';
import 'package:golon_babe/models/tree_model.dart';
import 'package:golon_babe/repositories/tree_repository.dart';

class TreeFormController {
  // Form key để validate
  final formKey = GlobalKey<FormState>();

  // Text controllers cho các trường nhập liệu
  final idController = TextEditingController();
  final coordinateXController = TextEditingController();
  final coordinateYController = TextEditingController();
  final heightController = TextEditingController();
  final diameterController = TextEditingController();
  final seaLevelController = TextEditingController();
  final noteController = TextEditingController();
  
  // Controllers cho thông tin cây master
  final tayNameController = TextEditingController();
  final scientificNameController = TextEditingController();
  final branchController = TextEditingController();
  final treeClassController = TextEditingController();
  final divisionController = TextEditingController();
  final familyController = TextEditingController();
  final genusController = TextEditingController();

  // Các biến trạng thái
  MasterTreeInfo? selectedTree;
  String? selectedCoverLevel;
  String? imageBase64;
  bool isEditing = false;
  int? editingId;
  String? imageError;

  final TreeRepository _repository;

  TreeFormController(this._repository);

  // Reset form về trạng thái ban đầu
  void resetForm() {
    print('\n=== RESET FORM ===');
    isEditing = false;
    editingId = null; 
    selectedTree = null;
    selectedCoverLevel = null;
    imageBase64 = null;
    imageError = null;
    
    // Reset các text controllers
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

  // Xóa thông tin cây master
  void _clearMasterTreeInfo() {
    tayNameController.clear();
    scientificNameController.clear();
    branchController.clear();
    treeClassController.clear();
    divisionController.clear();
    familyController.clear();
    genusController.clear();
  }

  // Cập nhật thông tin cây master
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

  // Tìm kiếm cây theo ID
  Future<bool> searchTreeById(String id) async {
    try {
      final idNumber = int.tryParse(id);
      if (idNumber == null) return false;
      
      print('\n=== BẮT ĐẦU TÌM KIẾM CÂY ===');
      print('ID người dùng nhập: $id'); 
      print('ID đã parse: $idNumber');
      print('ID đang sửa hiện tại: $editingId');
      
      // Kiểm tra online/offline
      final isOnline = await _repository.hasInternetConnection();
      print('Trạng thái kết nối: ${isOnline ? "Online" : "Offline"}');

      final treeDetails = await _repository.getTreeDetailsById(idNumber);
      
      if (treeDetails != null) {
        print('Đã tìm thấy cây:');
        print('ID cây: ${treeDetails.id}');
        print('ID loại cây: ${treeDetails.masterTreeId}');
        
        isEditing = true;
        editingId = idNumber;
        print('Đã set editingId = $editingId');
        
        _updateFormWithTreeDetails(treeDetails);
        return true;
      }
      
      print('Không tìm thấy cây ID: $idNumber');
      resetForm();
      return false;
      
    } catch (e) {
      print('Lỗi khi tìm kiếm cây:');
      print(e.toString());
      print('Stack trace:');
      print(StackTrace.current);
      resetForm();
      return false;
    }
  }

  // Cập nhật form với dữ liệu cây
  void _updateFormWithTreeDetails(TreeDetails tree) {
    print('\n=== CẬP NHẬT FORM VỚI DỮ LIỆU CÂY ==='); 
    print('ID ban đầu: $editingId');
    print('ID cây từ dữ liệu: ${tree.id}');
    print('ID loại cây: ${tree.masterTreeId}');
    
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

  // Xử lý submit form
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

  // Helper function để parse double an toàn
  double? _parseDouble(String value) {
    if (value.isEmpty) return null;
    try {
      return double.parse(value.replaceAll(',', '.'));
    } catch (e) {
      print('Lỗi parse double: $value');
      return null;
    }
  }

  // Dispose để giải phóng tài nguyên
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