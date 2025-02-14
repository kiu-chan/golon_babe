import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:convert';

class CameraHandler extends StatefulWidget {
  final Function(String) onImageSelected;
  final String? currentImageBase64;

  const CameraHandler({
    Key? key, 
    required this.onImageSelected,
    this.currentImageBase64,
  }) : super(key: key);

  @override
  State<CameraHandler> createState() => _CameraHandlerState();
}

class _CameraHandlerState extends State<CameraHandler> {
  final ImagePicker _picker = ImagePicker();
  String? _imageError;

  Future<void> _handleCameraPermission() async {
    final status = await Permission.camera.status;
    
    if (status.isDenied) {
      final result = await Permission.camera.request();
      if (result.isGranted) {
        _pickImage(ImageSource.camera);
      } else {
        if (!mounted) return;
        _showPermissionDeniedDialog();
      }
    } else if (status.isPermanentlyDenied) {
      if (!mounted) return;
      _showSettingsDialog();
    } else if (status.isGranted) {
      _pickImage(ImageSource.camera);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (photo != null && mounted) {
        final String? base64Image = await _convertImageToBase64(photo.path);
        if (base64Image != null) {
          widget.onImageSelected(base64Image);
          setState(() => _imageError = null);
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      if (!mounted) return;
      _showErrorDialog('Không thể ${source == ImageSource.camera ? 'chụp ảnh' : 'chọn ảnh'}: $e');
    }
  }

  Future<String?> _convertImageToBase64(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      if (await imageFile.exists()) {
        final List<int> imageBytes = await imageFile.readAsBytes();
        final String base64String = base64Encode(imageBytes);
        try {
          base64Decode(base64String);
          return base64String;
        } catch (e) {
          print('Error validating base64: $e');
          setState(() => _imageError = 'Lỗi định dạng ảnh');
          return null;
        }
      }
      setState(() => _imageError = 'Không tìm thấy file ảnh');
      return null;
    } catch (e) {
      print('Error converting image to base64: $e');
      setState(() => _imageError = 'Lỗi xử lý ảnh');
      return null;
    }
  }

Widget _buildImagePreview() {
  if (widget.currentImageBase64 == null || widget.currentImageBase64!.isEmpty) {
    return const SizedBox.shrink();
  }

  try {
    String base64String = widget.currentImageBase64!;
    
    // Kiểm tra và thêm prefix nếu cần
    if (!base64String.contains('data:image')) {
      base64String = 'data:image/jpeg;base64,' + base64String;
    }
    
    // Lấy phần base64 thuần túy
    final imageData = base64String.contains(',') 
        ? base64String.split(',')[1] 
        : base64String;
    
    print('Hiển thị ảnh với độ dài base64: ${imageData.length}');
    
    final imageBytes = base64Decode(imageData);
    
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              imageBytes,
              fit: BoxFit.contain,
              width: double.infinity,
              height: 300,
              errorBuilder: (context, error, stackTrace) {
                print('Lỗi hiển thị ảnh: $error');
                print('Stack trace: $stackTrace');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 48, color: Colors.red[300]),
                      const SizedBox(height: 8),
                      Text(
                        'Lỗi hiển thị ảnh',
                        style: TextStyle(color: Colors.red[300]),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () {
              widget.onImageSelected('');
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
              child: const Icon(Icons.close, size: 20),
            ),
          ),
        ),
      ],
    );
  } catch (e) {
    print('Lỗi xử lý ảnh base64: $e');
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image,
            color: Colors.red[300],
            size: 48,
          ),
          const SizedBox(height: 8),
          Text(
            'Lỗi định dạng ảnh: $e',
            style: TextStyle(color: Colors.red[300]),
          ),
        ],
      ),
    );
  }
}

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yêu cầu quyền truy cập'),
        content: const Text('Ứng dụng cần quyền truy cập máy ảnh để chụp ảnh cây'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Để sau'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await Permission.camera.request();
              if (result.isGranted && mounted) {
                _pickImage(ImageSource.camera);
              }
            },
            child: const Text('Cấp quyền'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cài đặt quyền truy cập'),
        content: const Text('Vui lòng vào Cài đặt để cấp quyền truy cập máy ảnh cho ứng dụng'),
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
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lỗi'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _handleCameraPermission,
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                label: const Text('Chụp ảnh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library, color: Colors.lightGreen),
                label: const Text('Chọn ảnh'),
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
        if (_imageError != null) ...[
          const SizedBox(height: 8),
          Text(
            _imageError!,
            style: TextStyle(color: Colors.red[300]),
          ),
        ],
        if (widget.currentImageBase64 != null && widget.currentImageBase64!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildImagePreview(),
          const SizedBox(height: 8),
          Container(
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
    );
  }
}