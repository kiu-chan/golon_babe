import 'package:flutter/material.dart';
import 'package:golon_babe/models/tree_model.dart';
import 'package:golon_babe/repositories/tree_repository.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'tree_form_validator.dart';

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

  final TreeRepository _repository;

  TreeFormController(this._repository);

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
      tayNameController.clear();
      scientificNameController.clear();
      branchController.clear();
      treeClassController.clear();
      divisionController.clear();
      familyController.clear();
      genusController.clear();
    }
  }

  Future<bool> searchTreeById(String id) async {
    try {
      final idNumber = int.tryParse(id);
      if (idNumber == null) return false;
      
      final tree = await _repository.getTreeDetailsById(idNumber);
      if (tree != null) {
        isEditing = true;
        editingId = tree.id;
        
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
        }
        return true;
      } else {
        resetForm();
        return false;
      }
    } catch (e) {
      print('Error searching tree: $e');
      resetForm();
      return false;
    }
  }

  void resetForm() {
    isEditing = false;
    editingId = null;
    coordinateXController.clear();
    coordinateYController.clear();
    heightController.clear();
    diameterController.clear();
    selectedCoverLevel = null;
    seaLevelController.clear();
    noteController.clear();
    imageBase64 = null;
    selectedTree = null;
    updateTreeInfo(null);
  }

  Future<void> handleSubmit(Function(TreeDetails) onSubmit) async {
    if (formKey.currentState!.validate() && selectedTree != null) {
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
      );

      onSubmit(details);
      
      formKey.currentState!.reset();
      resetForm();
    }
  }
}