import 'package:flutter/material.dart';
import 'package:golon_babe/models/tree_model.dart';
import 'package:golon_babe/repositories/tree_repository.dart';
import 'package:golon_babe/widgets/tree_form/tree_form.dart';

class HomeView extends StatelessWidget {
  final List<MasterTreeInfo> masterTreeList;
  final bool isLoading;
  final bool isSyncing;
  final bool isOnline;
  final bool isInitialized;
  final TreeRepository repository;
  final VoidCallback onSync;
  final VoidCallback onRefresh;
  final Function(TreeDetails) onSubmit;

  const HomeView({
    super.key,
    required this.masterTreeList,
    required this.isLoading,
    required this.isSyncing,
    required this.isOnline,
    required this.isInitialized,
    required this.repository,
    required this.onSync,
    required this.onRefresh,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: !isInitialized 
          ? _buildLoadingView()
          : isLoading
              ? _buildLoadingView()
              : masterTreeList.isEmpty
                  ? _buildEmptyView()
                  : _buildMainContent(),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text(
        'Quản lý cây gỗ lớn Ba Bể',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
      backgroundColor: Colors.lightGreen[200],
      elevation: 0,
      actions: [
        if (!isOnline)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.offline_bolt, color: Colors.orange),
          ),
        IconButton(
          icon: const Icon(Icons.sync),
          onPressed: !isOnline || isSyncing || isLoading 
            ? null 
            : onSync,
          tooltip: 'Đồng bộ dữ liệu',
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: isLoading ? null : onRefresh,
          tooltip: 'Làm mới dữ liệu',
        ),
      ],
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.lightGreen[200]!),
          ),
          const SizedBox(height: 16),
          Text(
            isSyncing ? 'Đang đồng bộ dữ liệu...' : 'Đang tải dữ liệu...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
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
            isOnline 
                ? 'Chưa có dữ liệu' 
                : 'Không có kết nối mạng và chưa có dữ liệu offline',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (isOnline)
            ElevatedButton.icon(
              onPressed: onRefresh,
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
    );
  }

  Widget _buildMainContent() {
    return Container(
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
        masterTreeList: masterTreeList,
        onSubmit: onSubmit,
        repository: repository,
      ),
    );
  }
}