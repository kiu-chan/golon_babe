import 'package:flutter/material.dart';
import 'package:golon_babe/models/tree_model.dart';
import 'package:golon_babe/repositories/tree_repository.dart';
import 'package:image_picker/image_picker.dart';
import 'tree_form_controller.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: !enabled,
          fillColor: enabled ? null : Colors.grey[100],
        ),
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _controller.formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Phần tìm kiếm
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Tìm kiếm theo ID',
                    border: OutlineInputBorder(),
                    hintText: 'Nhập ID cây cần tìm',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () async {
                  if (_searchController.text.isNotEmpty) {
                    final found = await _controller.searchTreeById(_searchController.text);
                    if (!found && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Không tìm thấy cây với ID này'),
                        ),
                      );
                    }
                    setState(() {}); // Cập nhật UI
                  }
                },
                child: const Text('Tìm kiếm'),
              ),
            ],
          ),
          const SizedBox(height: 16),

DropdownButtonFormField<MasterTreeInfo>(
  decoration: const InputDecoration(
    labelText: 'Tên loại',
    border: OutlineInputBorder(),
  ),
  value: null,  // Bắt đầu với null
  items: widget.masterTreeList.map((tree) {
    return DropdownMenuItem<MasterTreeInfo>(
      value: tree,
      child: Text(tree.treeType),
    );
  }).toList(),
  onChanged: (tree) {
    setState(() {
      _controller.updateTreeInfo(tree);
    });
  },
  validator: (value) {
    if (value == null) {
      return 'Vui lòng chọn loại cây';
    }
    return null;
  },
),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _controller.latinNameController,
            label: 'Tên tiếng tây',
            enabled: false,
          ),

          _buildTextField(
            controller: _controller.scientificNameController,
            label: 'Tên khoa học',
            enabled: false,
          ),

          _buildTextField(
            controller: _controller.branchController,
            label: 'Ngành',
            enabled: false,
          ),

          _buildTextField(
            controller: _controller.treeClassController,
            label: 'Lớp',
            enabled: false,
          ),

          _buildTextField(
            controller: _controller.divisionController,
            label: 'Bộ',
            enabled: false,
          ),

          _buildTextField(
            controller: _controller.familyController,
            label: 'Họ',
            enabled: false,
          ),

          _buildTextField(
            controller: _controller.genusController,
            label: 'Chi',
            enabled: false,
          ),

          _buildTextField(
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

          _buildTextField(
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

          _buildTextField(
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

          _buildTextField(
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
            decoration: const InputDecoration(
              labelText: 'Mức độ che phủ của tán cây',
              border: OutlineInputBorder(),
            ),
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

          _buildTextField(
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

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () => _controller.handleCameraPermission(
                  context,
                  (source) => setState(() => _controller.pickImage(source, context)),
                ),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Chụp ảnh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => setState(() => _controller.pickImage(ImageSource.gallery, context)),
                icon: const Icon(Icons.photo_library),
                label: const Text('Chọn từ thư viện'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          if (_controller.imagePath != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Đã chọn ảnh: ${_controller.imagePath}'),
            ),

          _buildTextField(
            controller: _controller.noteController,
            label: 'Ghi chú',
            maxLines: 3,
          ),

          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _controller.handleSubmit(widget.onSubmit),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              _controller.isEditing ? 'Cập nhật thông tin' : 'Thêm mới',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}