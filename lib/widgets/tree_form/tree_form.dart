import 'package:flutter/material.dart';
import 'package:golon_babe/models/tree_model.dart';
import 'package:golon_babe/repositories/tree_repository.dart';
import 'tree_form_controller.dart';
import 'tree_form_widgets.dart';
import 'tree_form_styles.dart';
import 'tree_form_validator.dart';

class TreeForm extends StatefulWidget {
  final List<MasterTreeInfo> masterTreeList;
  final Function(TreeDetails) onSubmit;
  final TreeRepository repository;

  const TreeForm({
    super.key,
    required this.masterTreeList,
    required this.onSubmit,
    required this.repository,
  });

  @override
  State<TreeForm> createState() => _TreeFormState();
}

class _TreeFormState extends State<TreeForm> {
  late final TreeFormController _controller;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = TreeFormController(widget.repository);
  }

  void _validateSelectedTree() {
    if (_controller.selectedTree != null) {
      final existingTree = widget.masterTreeList.firstWhere(
        (tree) => tree.id == _controller.selectedTree!.id,
        orElse: () => widget.masterTreeList.first,
      );
      _controller.updateTreeInfo(existingTree);
    }
  }

  @override
  Widget build(BuildContext context) {
    _validateSelectedTree();
    
    return Form(
      key: _controller.formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TreeFormWidgets.buildSearchSection(
            _searchController,
            _controller,
            () async {
              if (_searchController.text.isNotEmpty) {
                final found = await _controller.searchTreeById(_searchController.text);
                if (!found && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Không tìm thấy cây với ID này')),
                  );
                }
                setState(() {});
              }
            },
          ),
          const SizedBox(height: 24),

          TreeFormWidgets.buildTreeTypeSection(
            _controller,
            widget.masterTreeList,
            (tree) => setState(() => _controller.updateTreeInfo(tree)),
          ),
          const SizedBox(height: 24),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Thông tin chi tiết', style: TreeFormStyles.titleStyle()),
                  const SizedBox(height: 16),
                  TreeFormWidgets.buildTextField(
                    controller: _controller.tayNameController,
                    label: 'Tên tiếng Tày',
                    enabled: false,
                  ),
                  TreeFormWidgets.buildTextField(
                    controller: _controller.scientificNameController,
                    label: 'Tên khoa học',
                    enabled: false,
                  ),
                  TreeFormWidgets.buildTextField(
                    controller: _controller.branchController,
                    label: 'Ngành',
                    enabled: false,
                  ),
                  TreeFormWidgets.buildTextField(
                    controller: _controller.treeClassController,
                    label: 'Lớp',
                    enabled: false,
                  ),
                  TreeFormWidgets.buildTextField(
                    controller: _controller.divisionController,
                    label: 'Bộ',
                    enabled: false,
                  ),
                  TreeFormWidgets.buildTextField(
                    controller: _controller.familyController,
                    label: 'Họ',
                    enabled: false,
                  ),
                  TreeFormWidgets.buildTextField(
                    controller: _controller.genusController,
                    label: 'Chi',
                    enabled: false,
                  ),
                  TreeFormWidgets.buildTextField(
                    controller: _controller.coordinateXController,
                    label: 'Tọa độ x',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (!TreeFormValidator.validateCoordinate(value)) {
                        return 'Vui lòng nhập số thập phân hợp lệ (tối đa 6 chữ số sau dấu phẩy)';
                      }
                      return null;
                    },
                  ),
                  TreeFormWidgets.buildTextField(
                    controller: _controller.coordinateYController,
                    label: 'Tọa độ y',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (!TreeFormValidator.validateCoordinate(value)) {
                        return 'Vui lòng nhập số thập phân hợp lệ (tối đa 6 chữ số sau dấu phẩy)';
                      }
                      return null;
                    },
                  ),
                  TreeFormWidgets.buildTextField(
                    controller: _controller.heightController,
                    label: 'Chiều cao cây (m)',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (!TreeFormValidator.validateHeight(value)) {
                        return 'Vui lòng nhập số dương từ 0 đến 999.99m (tối đa 2 chữ số sau dấu phẩy)';
                      }
                      return null;
                    },
                  ),
                  TreeFormWidgets.buildTextField(
                    controller: _controller.diameterController,
                    label: 'Đường kính thân cây (cm)',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (!TreeFormValidator.validateDiameter(value)) {
                        return 'Vui lòng nhập số dương từ 0 đến 9999.99cm (tối đa 2 chữ số sau dấu phẩy)';
                      }
                      return null;
                    },
                  ),
                  DropdownButtonFormField<String>(
                    decoration: TreeFormStyles.textFieldDecoration('Mức độ che phủ của tán cây'),
                    value: _controller.selectedCoverLevel,
                    items: TreeConstants.coverLevels.map((level) {
                      return DropdownMenuItem<String>(
                        value: level,
                        child: Text(level),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _controller.selectedCoverLevel = newValue;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TreeFormWidgets.buildTextField(
                    controller: _controller.seaLevelController,
                    label: 'Độ cao so với mực nước biển (m)',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (!TreeFormValidator.validateSeaLevel(value)) {
                        return 'Vui lòng nhập số từ -99999.99 đến 99999.99m (tối đa 2 chữ số sau dấu phẩy)';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          TreeFormWidgets.buildImageSection(
            _controller,
            context,
            (source) => setState(() => _controller.pickImage(source, context)),
          ),
          const SizedBox(height: 24),

          TreeFormWidgets.buildTextField(
            controller: _controller.noteController,
            label: 'Ghi chú',
            maxLines: 3,
          ),

          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _controller.handleSubmit(widget.onSubmit),
            style: TreeFormStyles.submitButtonStyle(),
            child: Text(
              _controller.isEditing ? 'Cập nhật thông tin' : 'Thêm mới',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }
}