import 'package:flutter/material.dart';
import 'package:golon_babe/models/tree_model.dart';
import 'package:golon_babe/repositories/tree_repository.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'tree_form_validator.dart';
import 'dart:io';
import 'dart:convert';

class TreeFormController {
  // Form key
  final formKey = GlobalKey<FormState>();

  // Text controllers
  final idController = TextEditingController();
  final coordinateXController = TextEditingController();
  final coordinateYController = TextEditingController();
  final heightController = TextEditingController();
  final diameterController = TextEditingController();
  final seaLevelController = TextEditingController();
  final noteController = TextEditingController();
  
  // Thông tin cây master
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
  final ImagePicker _picker = ImagePicker();

  TreeFormController(this._repository);

  // Xử lý cập nhật thông tin cây master
  void updateTreeInfo(MasterTreeInfo? tree) {
    selectedTree = tree;
    if (tree != null) {
      tayNameController.text = tree.tayName ?? '';
      scientificNameController.text = tree.scientificName ?? '';
      branchController.text = tree.branch ?? '';
      treeClassController.text = tree.treeClass ?? '';
      divisionController.text = tree.division ?? '';
      familyController.text = tree.family ?? '';
      genusController.text = tree.genus ?? '';
    } else {
      _clearMasterTreeInfo();
    }
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

  // Xử lý tìm kiếm cây theo ID
  Future<bool> searchTreeById(String id) async {
    try {
      final idNumber = int.tryParse(id);
      if (idNumber == null) return false;
      
      print('Đang tìm kiếm cây với ID: $idNumber');
      final tree = await _repository.getTreeDetailsById(idNumber);
      
      if (tree != null) {
        print('Đã tìm thấy cây: ${tree.id}');
        isEditing = true;
        editingId = tree.id;
        
        // Cập nhật thông tin form
        coordinateXController.text = tree.coordinateX?.toString() ?? '';
        coordinateYController.text = tree.coordinateY?.toString() ?? '';
        heightController.text = tree.height?.toString() ?? '';
        diameterController.text = tree.diameter?.toString() ?? '';
        selectedCoverLevel = tree.coverLevel;
        seaLevelController.text = tree.seaLevel?.toString() ?? '';
        noteController.text = tree.note ?? '';
        
        // Cập nhật ảnh
        if (tree.imageBase64 != null && tree.imageBase64!.isNotEmpty) {
          imageBase64 = tree.imageBase64;
          print('Đã tải ảnh: ${tree.imageBase64!.length} ký tự');
        } else {
          imageBase64 = null;
          print('Không có ảnh cho cây này');
        }
        
        // Cập nhật thông tin master tree
        if (tree.masterInfo != null) {
          selectedTree = tree.masterInfo;
          updateTreeInfo(tree.masterInfo);
          print('Đã cập nhật thông tin master tree: ${tree.masterInfo!.treeType}');
        } else {
          print('Không tìm thấy thông tin master tree');
        }
        
        return true;
      } else {
        print('Không tìm thấy cây với ID: $idNumber');
        resetForm();
        return false;
      }
    } catch (e) {
      print('Lỗi khi tìm kiếm cây: $e');
      print('Stack trace: ${StackTrace.current}');
      resetForm();
      return false;
    }
  }

  // Reset form về trạng thái ban đầu
  void resetForm() {
    isEditing = false;
    editingId = null;
    selectedTree = null;
    selectedCoverLevel = null;
    imageBase64 = null;
    imageError = null;
    
    coordinateXController.clear();
    coordinateYController.clear();
    heightController.clear();
    diameterController.clear();
    seaLevelController.clear();
    noteController.clear();
    _clearMasterTreeInfo();
  }

  // Xử lý submit form
  Future<void> handleSubmit(Function(TreeDetails) onSubmit) async {
    if (!formKey.currentState!.validate()) {
      print('Form validation failed');
      return;
    }

    if (selectedTree == null) {
      print('Chưa chọn loại cây');
      return;
    }

    try {
      final details = TreeDetails(
        id: editingId,
        masterTreeId: selectedTree!.id,
        coordinateX: TreeFormValidator.parseNumber(coordinateXController.text),
        coordinateY: TreeFormValidator.parseNumber(coordinateYController.text),
        height: TreeFormValidator.parseNumber(heightController.text),
        diameter: TreeFormValidator.parseNumber(diameterController.text),
        coverLevel: selectedCoverLevel,
        seaLevel: TreeFormValidator.parseNumber(seaLevelController.text),
        imageBase64: imageBase64,
        note: noteController.text,
        masterInfo: selectedTree,
      );

      print('Đang lưu thông tin cây...');
      if (editingId != null) {
        print('Cập nhật cây ID: $editingId');
      } else {
        print('Thêm cây mới');
      }

      onSubmit(details);
      
      print('Đã lưu thông tin cây thành công');
      formKey.currentState!.reset();
      resetForm();
      
    } catch (e) {
      print('Lỗi khi lưu thông tin cây: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  // Giải phóng tài nguyên
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