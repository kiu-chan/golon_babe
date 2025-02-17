import 'package:flutter/material.dart';
import 'package:golon_babe/models/tree_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
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

  static Widget buildCoverLevelDropdown(
    TreeFormController controller,
    Function(String?) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        decoration: TreeFormStyles.textFieldDecoration(
          'Mức độ che phủ của tán cây',
          prefixIcon: Icon(Icons.filter_hdr, color: TreeFormStyles.accentColor),
        ),
        value: controller.selectedCoverLevel,
        items: TreeConstants.coverLevels.map((level) {
          return DropdownMenuItem<String>(
            value: level,
            child: Text(level),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  static Future<bool> _handleLocationPermission(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Vui lòng bật dịch vụ vị trí trên thiết bị'),
          backgroundColor: Colors.orange,
        ));
      }
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Quyền truy cập vị trí bị từ chối'),
            backgroundColor: Colors.red,
          ));
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'Quyền truy cập vị trí bị từ chối vĩnh viễn, vui lòng cấp quyền trong Cài đặt',
          ),
          backgroundColor: Colors.red,
        ));
      }
      return false;
    }

    return true;
  }

  static Widget buildDetailFields(TreeFormController controller) {
    return Column(
      children: [
        buildTextField(
          controller: controller.tayNameController,
          label: 'Tên tiếng Tày',
          enabled: false,
          prefixIcon: Icons.translate,
        ),
        buildTextField(
          controller: controller.scientificNameController,
          label: 'Tên khoa học',
          enabled: false,
          prefixIcon: Icons.science,
        ),
        buildTextField(
          controller: controller.branchController,
          label: 'Ngành',
          enabled: false,
          prefixIcon: Icons.account_tree,
        ),
        buildTextField(
          controller: controller.treeClassController,
          label: 'Lớp',
          enabled: false,
          prefixIcon: Icons.category,
        ),
        buildTextField(
          controller: controller.divisionController,
          label: 'Bộ',
          enabled: false,
          prefixIcon: Icons.folder_outlined,
        ),
        buildTextField(
          controller: controller.familyController,
          label: 'Họ',
          enabled: false,
          prefixIcon: Icons.family_restroom,
        ),
        buildTextField(
          controller: controller.genusController,
          label: 'Chi',
          enabled: false,
          prefixIcon: Icons.eco,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: buildTextField(
                controller: controller.coordinateXController,
                label: 'Tọa độ x',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                prefixIcon: Icons.location_on,
                validator: (value) {
                  if (!TreeFormValidator.validateCoordinate(value)) {
                    return 'Vui lòng nhập số thập phân hợp lệ (tối đa 6 chữ số sau dấu phẩy)';
                  }
                  return null;
                },
              ),
            ),
            Center(
              child: Builder(
                builder: (context) => IconButton(
                  onPressed: () async {
                    try {
                      if (await _handleLocationPermission(context)) {
                        final position = await Geolocator.getCurrentPosition(
                          desiredAccuracy: LocationAccuracy.high
                        );
                        
                        controller.coordinateXController.text = position.longitude.toStringAsFixed(6);
                        controller.coordinateYController.text = position.latitude.toStringAsFixed(6);
                        
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã cập nhật tọa độ thành công'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Lỗi khi lấy tọa độ: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.lightGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.my_location,  
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  tooltip: 'Lấy tọa độ hiện tại',
                ),
              ),
            ),
          ],
        ),
        buildTextField(
          controller: controller.coordinateYController,
          label: 'Tọa độ y', 
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          prefixIcon: Icons.location_on,
          validator: (value) {
            if (!TreeFormValidator.validateCoordinate(value)) {
              return 'Vui lòng nhập số thập phân hợp lệ (tối đa 6 chữ số sau dấu phẩy)';
            }
            return null;
          },
        ),
        buildTextField(
          controller: controller.heightController,
          label: 'Chiều cao cây (m)',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          prefixIcon: Icons.height,
          validator: (value) {
            if (!TreeFormValidator.validateHeight(value)) {
              return 'Vui lòng nhập số dương từ 0 đến 999.99m (tối đa 2 chữ số sau dấu phẩy)';
            }
            return null;
          },
        ),
        buildTextField(
          controller: controller.diameterController,
          label: 'Đường kính thân cây (cm)',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          prefixIcon: Icons.straighten,
          validator: (value) {
            if (!TreeFormValidator.validateDiameter(value)) {
              return 'Vui lòng nhập số dương từ 0 đến 9999.99cm (tối đa 2 chữ số sau dấu phẩy)';
            }
            return null;
          },
        ),
        buildCoverLevelDropdown(
          controller,
          (value) => controller.selectedCoverLevel = value,
        ),
        buildTextField(
          controller: controller.seaLevelController,
          label: 'Độ cao so với mực nước biển (m)',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          prefixIcon: Icons.terrain,
          validator: (value) {
            if (!TreeFormValidator.validateSeaLevel(value)) {
              return 'Vui lòng nhập số từ -99999.99 đến 99999.99m (tối đa 2 chữ số sau dấu phẩy)';
            }
            return null;
          },
        ),
      ],
    );
  }
}