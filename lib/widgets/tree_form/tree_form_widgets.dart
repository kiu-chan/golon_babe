import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:golon_babe/models/tree_model.dart';
import 'tree_form_controller.dart';
import 'tree_form_styles.dart';
import 'tree_form_validator.dart';

class TreeFormWidgets {
  static Widget buildTextField({
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
        decoration: TreeFormStyles.textFieldDecoration(label).copyWith(
          filled: !enabled,
          fillColor: enabled ? Colors.white : Colors.grey[100],
        ),
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
      ),
    );
  }

  static Widget buildSearchSection(
    TextEditingController searchController,
    TreeFormController controller,
    VoidCallback onSearchPressed,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: searchController,
                decoration: TreeFormStyles.searchFieldDecoration(),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: onSearchPressed,
              style: TreeFormStyles.elevatedButtonStyle(),
              child: const Text('Tìm kiếm'),
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildTreeTypeSection(
    TreeFormController controller,
    List<MasterTreeInfo> masterTreeList,
    Function(MasterTreeInfo?) onChanged,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thông tin cơ bản', style: TreeFormStyles.titleStyle()),
            const SizedBox(height: 16),
            DropdownButtonFormField<MasterTreeInfo>(
              decoration: TreeFormStyles.textFieldDecoration('Tên loại'),
              value: controller.selectedTree,
              items: masterTreeList.map((tree) {
                return DropdownMenuItem<MasterTreeInfo>(
                  value: tree,
                  child: Text(tree.treeType),
                );
              }).toList(),
              onChanged: onChanged,
              validator: (value) {
                if (value == null) {
                  return 'Vui lòng chọn loại cây';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildImageSection(
    TreeFormController controller,
    BuildContext context,
    Function(ImageSource) onImagePicked,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hình ảnh', style: TreeFormStyles.titleStyle()),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => controller.handleCameraPermission(
                      context,
                      onImagePicked,
                    ),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Chụp ảnh'),
                    style: TreeFormStyles.elevatedButtonStyle(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => onImagePicked(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Thư viện'),
                    style: TreeFormStyles.elevatedButtonStyle(),
                  ),
                ),
              ],
            ),
            if (controller.imagePath != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Đã chọn ảnh: ${controller.imagePath}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}