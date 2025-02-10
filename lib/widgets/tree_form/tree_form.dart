import 'package:flutter/material.dart';
import 'package:golon_babe/models/tree_model.dart';
import 'package:golon_babe/repositories/tree_repository.dart';
import 'package:image_picker/image_picker.dart';
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

 Widget _buildDetailFields() {
   return Column(
     children: [
       TreeFormWidgets.buildTextField(
         controller: _controller.tayNameController,
         label: 'Tên tiếng Tày',
         enabled: false,
         prefixIcon: Icons.translate,
       ),
       TreeFormWidgets.buildTextField(
         controller: _controller.scientificNameController,
         label: 'Tên khoa học',
         enabled: false,
         prefixIcon: Icons.science,
       ),
       TreeFormWidgets.buildTextField(
         controller: _controller.branchController,
         label: 'Ngành',
         enabled: false,
         prefixIcon: Icons.account_tree,
       ),
       TreeFormWidgets.buildTextField(
         controller: _controller.treeClassController,
         label: 'Lớp',
         enabled: false,
         prefixIcon: Icons.category,
       ),
       TreeFormWidgets.buildTextField(
         controller: _controller.divisionController,
         label: 'Bộ',
         enabled: false,
         prefixIcon: Icons.folder_outlined,
       ),
       TreeFormWidgets.buildTextField(
         controller: _controller.familyController,
         label: 'Họ',
         enabled: false,
         prefixIcon: Icons.family_restroom,
       ),
       TreeFormWidgets.buildTextField(
         controller: _controller.genusController,
         label: 'Chi',
         enabled: false,
         prefixIcon: Icons.eco,
       ),
       TreeFormWidgets.buildTextField(
         controller: _controller.coordinateXController,
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
       TreeFormWidgets.buildTextField(
         controller: _controller.coordinateYController,
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
       TreeFormWidgets.buildTextField(
         controller: _controller.heightController,
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
       TreeFormWidgets.buildTextField(
         controller: _controller.diameterController,
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
       Container(
         margin: const EdgeInsets.only(bottom: 16),
         child: DropdownButtonFormField<String>(
           decoration: TreeFormStyles.textFieldDecoration(
             'Mức độ che phủ của tán cây',
             prefixIcon: Icon(Icons.filter_hdr, color: TreeFormStyles.accentColor),
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
       ),
       TreeFormWidgets.buildTextField(
         controller: _controller.seaLevelController,
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
             _buildDetailFields(),
           ),
           const SizedBox(height: 24),

           TreeFormWidgets.buildImageSection(
             _controller,
             context,
             (source) async {
               final result = await _controller.pickImage(source, context);
               setState(() {});
             },
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

           ElevatedButton(
             onPressed: () => _controller.handleSubmit(widget.onSubmit),
             style: TreeFormStyles.submitButtonStyle(),
             child: Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 Icon(
                   _controller.isEditing ? Icons.update : Icons.add_circle,
                   size: 24, color: Colors.white,
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