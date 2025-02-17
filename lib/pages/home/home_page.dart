import 'package:flutter/material.dart';
import 'home_controller.dart';
import 'home_state.dart';
import 'home_view.dart';
import 'package:golon_babe/repositories/tree_repository.dart';
import 'package:golon_babe/models/tree_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeController _controller;
  List<MasterTreeInfo> _masterTreeList = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isOnline = true;
  bool _isInitialized = false;
  final TreeRepository _repository = TreeRepository();

  @override
  void initState() {
    super.initState();
    _controller = HomeController(
      repository: _repository,
      onStateChange: _handleStateChange,
      onError: _handleError,
      onSuccess: _handleSuccess,
    );
    _controller.initialize();
  }

  void _handleStateChange(HomeState state) {
    if (mounted) {
      setState(() {
        _masterTreeList = state.masterTreeList;
        _isLoading = state.isLoading;
        _isSyncing = state.isSyncing;
        _isOnline = state.isOnline;
        _isInitialized = state.isInitialized;
      });
    }
  }

  void _handleError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _handleSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return HomeView(
      masterTreeList: _masterTreeList,
      isLoading: _isLoading,
      isSyncing: _isSyncing,
      isOnline: _isOnline,
      isInitialized: _isInitialized,
      repository: _repository,
      onSync: _controller.syncData,
      onRefresh: _controller.refreshData,
      onSubmit: _controller.handleSubmit,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}