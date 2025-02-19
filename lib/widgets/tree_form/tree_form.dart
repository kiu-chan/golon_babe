import 'package:flutter/material.dart';
import 'package:golon_babe/models/tree_model.dart';
import 'package:golon_babe/repositories/tree_repository.dart';
import 'package:golon_babe/widgets/tree_form/camera_handler.dart';
import 'package:golon_babe/widgets/tree_form/tree_form_controller.dart';
import 'package:golon_babe/widgets/tree_form/tree_form_widgets.dart';
import 'package:golon_babe/widgets/tree_form/tree_form_styles.dart';
import 'package:golon_babe/widgets/tree_form/additional_images_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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
  bool _isOnline = true;
  bool _isSearching = false;
  bool _isSubmitting = false;
  List<MasterTreeInfo> _localMasterTreeList = [];

  @override
  void initState() {
    super.initState();
    _controller = TreeFormController(widget.repository);
    _setupConnectivity();
    _loadMasterTreeList();
  }

  Future<void> _setupConnectivity() async {
    try {
      final connectivity = Connectivity();
      final result = await connectivity.checkConnectivity();
      final hasConnection = result != ConnectivityResult.none;
      final isConnected = hasConnection ? await widget.repository.hasInternetConnection() : false;
      
      if (mounted) {
        setState(() => _isOnline = isConnected);
        if (isConnected != _isOnline) {
          _showConnectivitySnackBar();
        }
      }

      connectivity.onConnectivityChanged.listen((result) async {
        if (!mounted) return;
        
        final hasConnection = result != ConnectivityResult.none;
        if (hasConnection) {
          final isConnected = await widget.repository.hasInternetConnection();
          if (mounted && isConnected != _isOnline) {
            setState(() => _isOnline = isConnected);
            _showConnectivitySnackBar();
            if (isConnected) {
              await _loadMasterTreeList();
            }
          }
        } else {
          if (mounted && _isOnline) {
            setState(() => _isOnline = false);
            _showConnectivitySnackBar();
          }
        }
      });
    } catch (e) {
      print('Lỗi kiểm tra kết nối: $e');
      if (mounted) {
        setState(() => _isOnline = false);
      }
    }
  }

  Future<void> _loadMasterTreeList() async {
    try {
      final localData = await widget.repository.getLocalMasterTreeInfo();
      if (mounted) {
        setState(() {
          _localMasterTreeList = localData;
        });
      }
    } catch (e) {
      print('Lỗi khi load master tree list: $e');
    }
  }

  void _showConnectivitySnackBar() {
    if (!mounted) return;

    final message = _isOnline 
        ? 'Đã kết nối mạng. Bắt đầu đồng bộ dữ liệu...' 
        : 'Mất kết nối mạng - Chuyển sang chế độ offline';
    final backgroundColor = _isOnline ? Colors.green : Colors.orange;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _isOnline ? Icons.wifi : Icons.wifi_off,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _validateSelectedTree() {
    if (_controller.selectedTree != null) {
      try {
        if (_localMasterTreeList.isEmpty) {
          _loadMasterTreeList();
          return;
        }

        final existingTree = _localMasterTreeList.firstWhere(
          (tree) => tree.id == _controller.selectedTree!.id,
          orElse: () => _localMasterTreeList.first,
        );
        _controller.updateTreeInfo(existingTree);
      } catch (e) {
        print('Lỗi khi validate selected tree: $e');
        _controller.updateTreeInfo(null);
      }
    }
  }

  Future<void> _handleSearch() async {
    if (_searchController.text.isEmpty) {
      _showMessage('Vui lòng nhập ID cây cần tìm');
      return;
    }

    setState(() => _isSearching = true);

    try {
      final found = await _controller.searchTreeById(_searchController.text);
      if (!found && mounted) {
        _showMessage('Không tìm thấy cây với ID này');
      }
    } catch (e) {
      String errorMessage;
      if (e.toString().contains('Failed to connect')) {
        errorMessage = 'Không thể kết nối đến máy chủ để tìm kiếm';
      } else {
        errorMessage = 'Lỗi khi tìm kiếm: $e';
      }
      _showMessage(errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (!_controller.formKey.currentState!.validate()) {
      _showMessage('Vui lòng kiểm tra lại thông tin');
      return;
    }

    if (_controller.selectedTree == null) {
      _showMessage('Vui lòng chọn loại cây');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final details = TreeDetails(
        id: _controller.editingId,
        masterTreeId: _controller.selectedTree!.id,
        coordinateX: double.tryParse(_controller.coordinateXController.text),
        coordinateY: double.tryParse(_controller.coordinateYController.text),
        height: double.tryParse(_controller.heightController.text),
        diameter: double.tryParse(_controller.diameterController.text),
        coverLevel: _controller.selectedCoverLevel,
        seaLevel: double.tryParse(_controller.seaLevelController.text),
        imageBase64: _controller.imageBase64,
        note: _controller.noteController.text,
        masterInfo: _controller.selectedTree,
      );

      await widget.onSubmit(details);
      
      _showMessage(
        _isOnline 
            ? (_controller.isEditing 
                ? 'Cập nhật thông tin thành công' 
                : 'Thêm mới thành công')
            : 'Đã lưu dữ liệu offline. Sẽ tự động đồng bộ khi có mạng',
        isError: false,
      );
      
      _controller.resetForm();
      _searchController.clear();
      setState(() {});
      
    } catch (e) {
      String errorMessage;
      if (e.toString().contains('Failed to connect')) {
        errorMessage = !_isOnline 
            ? 'Đang ở chế độ offline. Dữ liệu sẽ được lưu trên thiết bị'
            : 'Không thể kết nối đến máy chủ. Đang chuyển sang chế độ offline...';
      } else {
        errorMessage = _isOnline 
            ? 'Lỗi khi lưu thông tin: $e'
            : 'Lỗi khi lưu dữ liệu offline. Vui lòng thử lại';
      }
      _showMessage(errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    if (_isOnline) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.offline_bolt, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đang ở chế độ offline',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bạn vẫn có thể nhập dữ liệu. Hệ thống sẽ tự động đồng bộ khi có kết nối mạng trở lại.',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchLoading() {
    if (!_isSearching) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _handleSubmit,
            style: TreeFormStyles.submitButtonStyle(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _controller.isEditing ? Icons.update : Icons.add_circle,
                          size: 24,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _controller.isEditing ? 'Cập nhật thông tin' : 'Thêm mới',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        if (!_isOnline) ...[
          const SizedBox(height: 8),
          Text(
            'Dữ liệu sẽ được lưu offline và tự động đồng bộ khi có mạng',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.orange.shade800,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _validateSelectedTree();
    
    return Container(
      decoration: BoxDecoration(
        color: TreeFormStyles.backgroundColor,
      ),
      child: Form(
        key: _controller.formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildOfflineBanner(),
            TreeFormWidgets.buildSearchSection(
              _searchController,
              _controller,
              _handleSearch,
            ),
            _buildSearchLoading(),
            const SizedBox(height: 24),

            TreeFormWidgets.buildTreeTypeSection(
              _controller,
              _localMasterTreeList,
              (tree) => setState(() => _controller.updateTreeInfo(tree)),
            ),
            const SizedBox(height: 24),

            TreeFormWidgets.buildDetailSection(
              _controller,
              TreeFormWidgets.buildDetailFields(_controller),
            ),
            const SizedBox(height: 24),

            Container(
              decoration: TreeFormStyles.cardDecoration(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hình ảnh', style: TreeFormStyles.titleStyle()),
                  const SizedBox(height: 8),
                  Text(
                    'Chụp ảnh hoặc chọn ảnh từ thư viện',
                    style: TreeFormStyles.subtitleStyle(),
                  ),
                  const SizedBox(height: 20),
                  CameraHandler(
                    currentImageBase64: _controller.imageBase64,
                    onImageSelected: (String base64String) {
                      setState(() {
                        _controller.imageBase64 = base64String.isNotEmpty 
                            ? base64String 
                            : null;
                      });
                    },
                    onCoordinatesFound: (longitude, latitude) {
                      if (longitude != null && latitude != null) {
                        setState(() {
                          _controller.coordinateXController.text = longitude.toStringAsFixed(6);
                          _controller.coordinateYController.text = latitude.toStringAsFixed(6);
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_controller.imageBase64 != null && _controller.editingId != null) ...[
              Container(
                decoration: TreeFormStyles.cardDecoration(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ảnh phụ', style: TreeFormStyles.titleStyle()),
const SizedBox(height: 8),
                    Text(
                      'Thêm các ảnh phụ của cây',
                      style: TreeFormStyles.subtitleStyle(),
                    ),
                    const SizedBox(height: 16),
                    AdditionalImagesHandler(
                      treeId: _controller.editingId!,
                      initialImages: _controller.additionalImages,
                      onImageAdded: (image) async {
                        await widget.repository.saveAdditionalImage(image);
                      },
                      onImageDeleted: (id) async {
                        await widget.repository.deleteAdditionalImage(id);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            Container(
              decoration: TreeFormStyles.cardDecoration(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ghi chú', style: TreeFormStyles.titleStyle()),
                  const SizedBox(height: 8),
                  Text(
                    'Thêm các ghi chú bổ sung nếu cần',
                    style: TreeFormStyles.subtitleStyle(),
                  ),
                  const SizedBox(height: 16),
                  TreeFormWidgets.buildTextField(
                    controller: _controller.noteController,
                    label: 'Ghi chú',
                    maxLines: 3,
                    prefixIcon: Icons.note,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSubmitButton(),
            const SizedBox(height: 24),
          ],
        ),
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

class _ErrorDialog extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorDialog({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700]),
          const SizedBox(width: 8),
          const Text('Lỗi'),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onRetry();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text('Thử lại'),
        ),
      ],
    );
  }
}