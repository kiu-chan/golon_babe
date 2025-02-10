

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải dữ liệu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleSubmit(TreeDetails details) async {
    try {
      final success = await _repository.saveTreeDetails(details);
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(details.id != null ? 'Cập nhật thông tin thành công' : 'Lưu thông tin thành công'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lỗi khi lưu dữ liệu'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi lưu dữ liệu: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
        title: const Text('Nhập thông tin cây'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TreeForm(
              masterTreeList: _masterTreeList,
              onSubmit: _handleSubmit,
              repository: _repository,
            ),
    );
  }
}