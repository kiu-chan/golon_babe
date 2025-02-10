import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:golon_babe/models/tree_model.dart';
import 'dart:io';
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
    IconData? prefixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        decoration: TreeFormStyles.textFieldDecoration(
          label,
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon,
                  color: enabled ? TreeFormStyles.accentColor : Colors.grey)
              : null,
        ).copyWith(
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey[100],
        ),
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
        style: TextStyle(
          color: enabled ? Colors.black87 : Colors.grey[600],
        ),
      ),
    );
  }

  static Widget buildSearchSection(
    TextEditingController searchController,
    TreeFormController controller,
    VoidCallback onSearchPressed,
  ) {
    return Container(
      decoration: TreeFormStyles.cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tìm kiếm cây',
            style: TreeFormStyles.titleStyle(),
          ),
          const SizedBox(height: 8),
          Text(
            'Nhập ID cây để tìm kiếm thông tin chi tiết',
            style: TreeFormStyles.subtitleStyle(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: searchController,
                  decoration: TreeFormStyles.searchFieldDecoration(),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: onSearchPressed,
                icon: const Icon(Icons.search, color: Colors.white),
                label: const Text('Tìm kiếm'),
                style: TreeFormStyles.elevatedButtonStyle(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget buildTreeTypeSection(
    TreeFormController controller,
    List<MasterTreeInfo> masterTreeList,
    Function(MasterTreeInfo?) onChanged,
  ) {
    return Container(
      decoration: TreeFormStyles.cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thông tin cơ bản', style: TreeFormStyles.titleStyle()),
          const SizedBox(height: 8),
          Text(
            'Chọn loại cây để xem và cập nhật thông tin',
            style: TreeFormStyles.subtitleStyle(),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<MasterTreeInfo>(
            decoration: TreeFormStyles.textFieldDecoration(
              'Tên loại',
              prefixIcon: Icon(Icons.forest, color: TreeFormStyles.accentColor),
            ),
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
    );
  }

  static Widget buildImageSection(
    TreeFormController controller,
    BuildContext context,
    Function(ImageSource) onImagePicked,
  ) {
    return Container(
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
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => controller.handleCameraPermission(
                    context,
                    onImagePicked,
                  ),
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  label: const Text('Chụp ảnh mới'),
                  style: TreeFormStyles.elevatedButtonStyle(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => onImagePicked(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library, color: Colors.green),
                  label: const Text('Chọn từ thư viện'),
                  style: TreeFormStyles.elevatedButtonStyle(isOutlined: true),
                ),
              ),
            ],
          ),
          if (controller.imagePath != null) ...[
            const SizedBox(height: 16),
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(controller.imagePath!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      controller.imagePath = null;
                      (context as Element).markNeedsBuild();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.close, size: 20, color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Đã chọn ảnh thành công',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget buildDetailSection(
    TreeFormController controller,
    Widget content,
  ) {
    return Container(
      decoration: TreeFormStyles.cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thông tin chi tiết', style: TreeFormStyles.titleStyle()),
          const SizedBox(height: 8),
          Text(
            'Nhập các thông số chi tiết của cây',
            style: TreeFormStyles.subtitleStyle(),
          ),
          const SizedBox(height: 20),
          content,
        ],
      ),
    );
  }
}