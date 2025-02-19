import 'package:flutter/material.dart';
import 'package:golon_babe/models/tree_model.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';

class AdditionalImagesHandler extends StatefulWidget {
  final int treeId;
  final List<TreeAdditionalImage> initialImages;
  final Function(TreeAdditionalImage) onImageAdded;
  final Function(int) onImageDeleted;

  const AdditionalImagesHandler({
    Key? key,
    required this.treeId,
    required this.initialImages,
    required this.onImageAdded,
    required this.onImageDeleted,
  }) : super(key: key);

  @override
  State<AdditionalImagesHandler> createState() => _AdditionalImagesHandlerState();
}

class _AdditionalImagesHandlerState extends State<AdditionalImagesHandler> {
  final ImagePicker _picker = ImagePicker();
  List<TreeAdditionalImage> _images = [];

  @override
  void initState() {
    super.initState();
    _images = widget.initialImages;
  }

Future<void> _pickImage({ImageSource source = ImageSource.gallery}) async {
  try {
    final XFile? photo = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (photo != null && mounted) {
      final String? base64Image = await _convertImageToBase64(photo.path);
      if (base64Image != null) {
        print('Thêm ảnh phụ cho tree detail ID: ${widget.treeId}');
        
        final newImage = TreeAdditionalImage(
          treeDetailId: widget.treeId,  // Đây là tree_details ID
          imageBase64: base64Image,
        );
        
        widget.onImageAdded(newImage);
        setState(() {
          _images.add(newImage);
        });
      }
    }
  } catch (e) {
    print('Lỗi khi chọn ảnh phụ: $e');
  }
}

  Future<String?> _convertImageToBase64(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      if (await imageFile.exists()) {
        final List<int> imageBytes = await imageFile.readAsBytes();
        final String base64String = base64Encode(imageBytes);
        return base64String;
      }
      return null;
    } catch (e) {
      print('Lỗi khi chuyển ảnh sang base64: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickImage(source: ImageSource.camera),
                icon: const Icon(Icons.camera_alt, color: Colors.lightGreen),
                label: const Text('Chụp ảnh phụ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.lightGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Colors.lightGreen),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickImage(source: ImageSource.gallery),
                icon: const Icon(Icons.photo_library, color: Colors.lightGreen),
                label: const Text('Chọn ảnh phụ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.lightGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Colors.lightGreen),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_images.isNotEmpty) ...[
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _images.length,
            itemBuilder: (context, index) {
              final image = _images[index];
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(image.imageBase64.split(',').last),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        if (image.id != null) {
                          widget.onImageDeleted(image.id!);
                        }
                        setState(() {
                          _images.removeAt(index);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.close, size: 16),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}