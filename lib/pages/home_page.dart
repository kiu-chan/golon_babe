import 'package:flutter/material.dart';
import 'package:golon_babe/models/tree_model.dart';
import 'package:golon_babe/widgets/tree_form/tree_form.dart';
import '../repositories/tree_repository.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TreeRepository _repository = TreeRepository();
  List<MasterTreeInfo> _masterTreeList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMasterTreeInfo();
  }

  Future<void> _loadMasterTreeInfo() async {
    try {
      final treeList = await _repository.getAllMasterTreeInfo();
      setState(() {
        _masterTreeList = treeList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showErrorSnackBar('Lỗi khi tải dữ liệu: ${e.toString()}');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _handleSubmit(TreeDetails details) async {
    try {
      final success = await _repository.saveTreeDetails(details);
      if (!mounted) return;

      if (success) {
        _showSuccessSnackBar(
          details.id != null ? 'Cập nhật thông tin thành công' : 'Lưu thông tin thành công'
        );
      } else {
        _showErrorSnackBar('Lỗi khi lưu dữ liệu');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Lỗi khi lưu dữ liệu: ${e.toString()}');
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await _loadMasterTreeInfo();
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quản lý cây xanh',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.lightGreen[200],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Làm mới dữ liệu',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.lightGreen[200]!),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Đang tải dữ liệu...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : _masterTreeList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.forest,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chưa có dữ liệu',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _refreshData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tải lại'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightGreen[200],
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.lightGreen[50]!,
                        Colors.white,
                      ],
                    ),
                  ),
                  child: TreeForm(
                    masterTreeList: _masterTreeList,
                    onSubmit: _handleSubmit,
                    repository: _repository,
                  ),
                ),
    );
  }
}