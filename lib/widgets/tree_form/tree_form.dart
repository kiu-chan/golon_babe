import 'package:flutter/material.dart';
import 'package:golon_babe/models/tree_model.dart';
import 'package:golon_babe/repositories/tree_repository.dart';
import 'tree_form_controller.dart';
import 'tree_form_widgets.dart';
import 'tree_form_styles.dart';
import 'camera_handler.dart';

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
    
    return Container(
      decoration: BoxDecoration(
        color: TreeFormStyles.backgroundColor,
      ),
      child: Form(
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
                        _controller.imageBase64 = base64String.isNotEmpty ? base64String : null;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

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

            TreeFormWidgets.buildSubmitButton(
              _controller,
              () => _controller.handleSubmit(widget.onSubmit),
            ),
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