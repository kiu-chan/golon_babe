import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/tree_model.dart';

class TreeForm extends StatefulWidget {
  final List<MasterTreeInfo> masterTreeList;
  final Function(TreeDetails) onSubmit;

  const TreeForm({
    super.key,
    required this.masterTreeList,
    required this.onSubmit,
  });

  @override
  State<TreeForm> createState() => _TreeFormState();
}

class _TreeFormState extends State<TreeForm> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _coordinateXController = TextEditingController();
  final _coordinateYController = TextEditingController();
  final _heightController = TextEditingController();
  final _diameterController = TextEditingController();
  final _seaLevelController = TextEditingController();
  final _noteController = TextEditingController();

  // Các TextEditingController cho các trường thông tin tự động
  final _latinNameController = TextEditingController();
  final _scientificNameController = TextEditingController();
  final _branchController = TextEditingController();
  final _treeClassController = TextEditingController();
  final _divisionController = TextEditingController();
  final _familyController = TextEditingController();
  final _genusController = TextEditingController();

  MasterTreeInfo? selectedTree;
  String? selectedCoverLevel;
  String? imagePath;

  @override
  void dispose() {
    _idController.dispose();
    _coordinateXController.dispose();
    _coordinateYController.dispose();
    _heightController.dispose();
    _diameterController.dispose();
    _seaLevelController.dispose();
    _noteController.dispose();
    _latinNameController.dispose();
    _scientificNameController.dispose();
    _branchController.dispose();
    _treeClassController.dispose();
    _divisionController.dispose();
    _familyController.dispose();
    _genusController.dispose();
    super.dispose();
  }

  Future<void> _handleCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isDenied) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Cấp quyền truy cập máy ảnh'),
          content: const Text('Ứng dụng cần quyền truy cập máy ảnh để chụp ảnh cây'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Không'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final result = await Permission.camera.request();
                if (result.isGranted) {
                  _pickImage(ImageSource.camera);
                }
              },
              child: const Text('Đồng ý'),
            ),
          ],
        ),
      );
    } else if (status.isPermanentlyDenied) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Quyền truy cập máy ảnh bị từ chối'),
          content: const Text('Vui lòng vào Cài đặt để cấp quyền cho ứng dụng'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Để sau'),
            ),
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.pop(context);
              },
              child: const Text('Mở Cài đặt'),
            ),
          ],
        ),
      );
    } else if (status.isGranted) {
      _pickImage(ImageSource.camera);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          imagePath = image.path;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở máy ảnh')),
      );
    }
  }

  void _updateTreeInfo(MasterTreeInfo? tree) {
    setState(() {
      selectedTree = tree;
      if (tree != null) {
        // Cập nhật các controller với thông tin mới
        _latinNameController.text = tree.vietnameseName ?? '';
        _scientificNameController.text = tree.scientificName ?? '';
        _branchController.text = tree.branch ?? '';
        _treeClassController.text = tree.treeClass ?? '';
        _divisionController.text = tree.division ?? '';
        _familyController.text = tree.family ?? '';
        _genusController.text = tree.genus ?? '';
      } else {
        // Xóa tất cả thông tin khi không có cây được chọn
        _latinNameController.clear();
        _scientificNameController.clear();
        _branchController.clear();
        _treeClassController.clear();
        _divisionController.clear();
        _familyController.clear();
        _genusController.clear();
      }
    });
  }

  String _formatNumber(String text) {
    // Thay thế dấu phẩy bằng dấu chấm
    String formattedText = text.replaceAll(',', '.');
    // Đảm bảo chỉ có một dấu thập phân
    int decimalCount = '.'.allMatches(formattedText).length;
    if (decimalCount > 1) {
      // Giữ lại dấu thập phân đầu tiên, bỏ các dấu còn lại
      formattedText = formattedText.replaceAll(RegExp(r'\.(?=.*\.)'), '');
    }
    return formattedText;
  }

  double? _parseNumber(String text) {
    if (text.isEmpty) return null;
    String formattedText = _formatNumber(text);
    return double.tryParse(formattedText);
  }

  bool _validateCoordinate(String? value) {
    if (value == null || value.isEmpty) return true; // Cho phép để trống
    String formattedValue = _formatNumber(value);
    double? number = double.tryParse(formattedValue);
    if (number == null) return false;
    // Kiểm tra số thập phân tối đa 6 chữ số
    String decimalPart = formattedValue.contains('.') 
        ? formattedValue.split('.')[1] 
        : '';
    return decimalPart.length <= 6;
  }

  bool _validateHeight(String? value) {
    if (value == null || value.isEmpty) return true; // Cho phép để trống
    String formattedValue = _formatNumber(value);
    double? number = double.tryParse(formattedValue);
    if (number == null) return false;
    
    // Kiểm tra giới hạn: > 0 và <= 999.99
    if (number <= 0 || number > 999.99) return false;
    
    // Kiểm tra số thập phân tối đa 2 chữ số
    String decimalPart = formattedValue.contains('.') 
        ? formattedValue.split('.')[1] 
        : '';
    return decimalPart.length <= 2;
  }

  bool _validateDiameter(String? value) {
    if (value == null || value.isEmpty) return true;
    String formattedValue = _formatNumber(value);
    double? number = double.tryParse(formattedValue);
    if (number == null) return false;
    
    // Kiểm tra giới hạn: > 0 và <= 9999.99
    if (number <= 0 || number > 9999.99) return false;
    
    String decimalPart = formattedValue.contains('.') 
        ? formattedValue.split('.')[1] 
        : '';
    return decimalPart.length <= 2;
  }

  bool _validateSeaLevel(String? value) {
    if (value == null || value.isEmpty) return true;
    String formattedValue = _formatNumber(value);
    double? number = double.tryParse(formattedValue);
    if (number == null) return false;
    
    // Kiểm tra giới hạn: -99999.99 đến 99999.99
    if (number < -99999.99 || number > 99999.99) return false;
    
    String decimalPart = formattedValue.contains('.') 
        ? formattedValue.split('.')[1] 
        : '';
    return decimalPart.length <= 2;
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate() && selectedTree != null) {
      final details = TreeDetails(
        masterTreeId: selectedTree!.id,
        coordinateX: _parseNumber(_coordinateXController.text),
        coordinateY: _parseNumber(_coordinateYController.text),
        height: _parseNumber(_heightController.text),
        diameter: _parseNumber(_diameterController.text),
        coverLevel: selectedCoverLevel,
        seaLevel: _parseNumber(_seaLevelController.text),
        imagePath: imagePath,
        note: _noteController.text,
      );
      widget.onSubmit(details);

      // Reset form
      _formKey.currentState!.reset();
      _idController.clear();
      _coordinateXController.clear();
      _coordinateYController.clear();
      _heightController.clear();
      _diameterController.clear();
      _seaLevelController.clear();
      _noteController.clear();
      
      setState(() {
        selectedTree = null;
        selectedCoverLevel = null;
        imagePath = null;
        _updateTreeInfo(null);
      });
    }
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
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTextField(
            controller: _idController,
            label: 'ID cây',
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Vui lòng nhập ID cây';
              }
              return null;
            },
          ),
          
          DropdownButtonFormField<MasterTreeInfo>(
            decoration: const InputDecoration(
              labelText: 'Tên loại',
              border: OutlineInputBorder(),
            ),
            value: selectedTree,
            items: widget.masterTreeList.map((tree) {
              return DropdownMenuItem<MasterTreeInfo>(
                value: tree,
                child: Text(tree.treeType),
              );
            }).toList(),
            onChanged: _updateTreeInfo,
            validator: (value) {
              if (value == null) {
                return 'Vui lòng chọn loại cây';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _latinNameController,
            label: 'Tên tiếng tây',
            enabled: false,
          ),

          _buildTextField(
            controller: _scientificNameController,
            label: 'Tên khoa học',
            enabled: false,
          ),

          _buildTextField(
            controller: _branchController,
            label: 'Ngành',
            enabled: false,
          ),

          _buildTextField(
            controller: _treeClassController,
            label: 'Lớp',
            enabled: false,
          ),

          _buildTextField(
            controller: _divisionController,
            label: 'Bộ',
            enabled: false,
          ),

          _buildTextField(
            controller: _familyController,
            label: 'Họ',
            enabled: false,
          ),

          _buildTextField(
            controller: _genusController,
            label: 'Chi',
            enabled: false,
          ),

          _buildTextField(
            controller: _coordinateXController,
            label: 'Tọa độ x',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (!_validateCoordinate(value)) {
                return 'Vui lòng nhập số thập phân hợp lệ (tối đa 6 chữ số sau dấu phẩy)';
              }
              return null;
            },
          ),

          _buildTextField(
            controller: _coordinateYController,
            label: 'Tọa độ y',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (!_validateCoordinate(value)) {
                return 'Vui lòng nhập số thập phân hợp lệ (tối đa 6 chữ số sau dấu phẩy)';
              }
              return null;
            },
          ),

          _buildTextField(
            controller: _heightController,
            label: 'Chiều cao cây (m)',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (!_validateHeight(value)) {
                return 'Vui lòng nhập số dương từ 0 đến 999.99m (tối đa 2 chữ số sau dấu phẩy)';
              }
              return null;
            },
          ),

          _buildTextField(
            controller: _diameterController,
            label: 'Đường kính thân cây (cm)',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (!_validateDiameter(value)) {
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
            value: selectedCoverLevel,
            items: TreeConstants.coverLevels.map((level) {
              return DropdownMenuItem<String>(
                value: level,
                child: Text(level),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                selectedCoverLevel = newValue;
              });
            },
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _seaLevelController,
            label: 'Độ cao so với mực nước biển (m)',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (!_validateSeaLevel(value)) {
                return 'Vui lòng nhập số từ -99999.99 đến 99999.99m (tối đa 2 chữ số sau dấu phẩy)';
              }
              return null;
            },
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _handleCameraPermission,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Chụp ảnh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
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
          if (imagePath != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Đã chọn ảnh: $imagePath'),
            ),

          _buildTextField(
            controller: _noteController,
            label: 'Ghi chú',
            maxLines: 3,
          ),

          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Lưu thông tin',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}