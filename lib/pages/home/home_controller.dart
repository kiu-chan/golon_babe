import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'home_state.dart';
import 'package:golon_babe/repositories/tree_repository.dart';
import 'package:golon_babe/models/tree_model.dart';

class HomeController {
  final TreeRepository _repository;
  SharedPreferences? _prefs;
  late StreamSubscription<dynamic> _connectivitySubscription;
  
  final Function(HomeState) onStateChange;
  final Function(String) onError;
  final Function(String) onSuccess;

  HomeState _state = const HomeState();
  HomeState get state => _state;

  HomeController({
    TreeRepository? repository,
    required this.onStateChange,
    required this.onError,
    required this.onSuccess,
  }) : _repository = repository ?? TreeRepository();

  Future<void> initialize() async {
    try {
      await _initPrefs();
      await _setupConnectivity();
      await _initialDataLoad();
    } catch (e) {
      print('Lỗi khởi tạo ứng dụng: $e');
      _handleError('Lỗi khởi tạo ứng dụng');
    } finally {
      _updateState(isInitialized: true, isLoading: false);
    }
  }

  Future<void> _initPrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final lastSync = _prefs!.getString('last_sync_date');
      if (lastSync != null) {
        _updateState(lastSyncDate: DateTime.parse(lastSync));
      }
    } catch (e) {
      print('Lỗi khởi tạo SharedPreferences: $e');
      throw Exception('Không thể khởi tạo bộ nhớ cục bộ');
    }
  }

  Future<void> _setupConnectivity() async {
    try {
      final connectivity = Connectivity();
      final result = await connectivity.checkConnectivity();
      final hasConnection = result != ConnectivityResult.none;
      final isConnected = hasConnection ? await _repository.hasInternetConnection() : false;
      
      _updateState(isOnline: isConnected);
      
      if (isConnected) {
        _handleSuccess('Đã kết nối mạng');
        await _handleOnlineConnection();
      }

      _connectivitySubscription = connectivity.onConnectivityChanged.listen((dynamic result) async {
        final connectivityResult = result is List<ConnectivityResult> ? result.first : result as ConnectivityResult;
        final hasConnection = connectivityResult != ConnectivityResult.none;
        
        if (hasConnection) {
          await Future.delayed(const Duration(milliseconds: 500));
          final isConnected = await _repository.hasInternetConnection();
          if (isConnected) {
            _updateState(isOnline: true);
            _handleSuccess('Đã kết nối mạng');
            await _handleOnlineConnection();
          }
        } else {
          _updateState(isOnline: false);
          _handleSuccess('Đang sử dụng dữ liệu offline');
          await _loadOfflineData();
        }
      });
    } catch (e) {
      print('Lỗi thiết lập kết nối: $e');
      _updateState(isOnline: false);
    }
  }

  Future<void> _handleOnlineConnection() async {
    try {
      if (state.needsSync) {
        await syncData();
      }
      await _loadMasterTreeInfo();
    } catch (e) {
      print('Lỗi xử lý kết nối online: $e');
      _handleError('Không thể cập nhật dữ liệu');
    }
  }

  Future<void> _initialDataLoad() async {
    try {
      final hasLocalData = await _repository.hasLocalData();
      
      if (hasLocalData) {
        await _loadOfflineData();
        if (state.isOnline) {
          syncData();
        }
      } else {
        if (state.isOnline) {
          await syncData();
          await _loadMasterTreeInfo();
        } else {
          await _loadOfflineData();
        }
      }
    } catch (e) {
      print('Lỗi tải dữ liệu ban đầu: $e');
      _handleError('Không thể tải dữ liệu ban đầu');
      await _loadOfflineData();
    }
  }

  Future<void> syncData() async {
    if (state.isSyncing || !state.isOnline) return;
    
    _updateState(isLoading: true, isSyncing: true);

    try {
      await _repository.syncData();
      _prefs?.setString('last_sync_date', DateTime.now().toIso8601String());
      _handleSuccess('Đồng bộ dữ liệu thành công');
    } catch (e) {
      print('Lỗi đồng bộ: $e');
      _handleError('Lỗi đồng bộ dữ liệu');
    } finally {
      _updateState(isSyncing: false, isLoading: false);
    }
  }

  Future<void> _loadOfflineData() async {
    if (state.isLoading) return;
    _updateState(isLoading: true);

    try {
      final localData = await _repository.getLocalMasterTreeInfo();
      _updateState(
        masterTreeList: localData,
        isLoading: false,
      );
    } catch (e) {
      print('Lỗi khi tải dữ liệu offline: $e');
      _handleError('Không thể tải dữ liệu offline');
      _updateState(isLoading: false);
    }
  }

  Future<void> _loadMasterTreeInfo() async {
    if (state.isLoading) return;
    _updateState(isLoading: true);

    try {
      if (state.isOnline) {
        final treeList = await _repository.getAllMasterTreeInfo();
        await _repository.getAllTreeDetailsAndSaveLocal();
        _updateState(
          masterTreeList: treeList,
          isLoading: false,
        );
      } else {
        await _loadOfflineData();
      }
    } catch (e) {
      print('Lỗi tải dữ liệu: $e');
      _handleError('Không thể tải dữ liệu');
      await _loadOfflineData();
    }
  }

  Future<void> refreshData() async {
    if (state.isOnline) {
      await syncData();
    }
    await _loadMasterTreeInfo();
  }

  Future<void> handleSubmit(TreeDetails details) async {
    try {
      final success = await _repository.saveTreeDetails(details);
      
      if (success) {
        final message = details.id != null 
          ? 'Cập nhật thông tin thành công' 
          : 'Lưu thông tin thành công';
        _handleSuccess(message);
        
        if (state.isOnline && !state.isSyncing) {
          await syncData();
        }
      } else {
        _handleError('Không thể lưu dữ liệu');
      }
    } catch (e) {
      print('Lỗi submit: $e');
      _handleError('Lỗi khi lưu dữ liệu');
    }
  }

  void _handleError(String message) {
    _updateState(errorMessage: message);
    onError(message);
  }

  void _handleSuccess(String message) {
    _updateState(successMessage: message);
    onSuccess(message);
  }

  void _updateState({
    List<MasterTreeInfo>? masterTreeList,
    bool? isLoading,
    bool? isSyncing,
    bool? isOnline,
    bool? isInitialized,
    String? errorMessage,
    String? successMessage,
    DateTime? lastSyncDate,
  }) {
    _state = _state.copyWith(
      masterTreeList: masterTreeList,
      isLoading: isLoading,
      isSyncing: isSyncing,
      isOnline: isOnline,
      isInitialized: isInitialized,
      errorMessage: errorMessage,
      successMessage: successMessage,
      lastSyncDate: lastSyncDate,
    );
    onStateChange(_state);
  }

  void dispose() {
    _connectivitySubscription.cancel();
    _repository.dispose();
  }
}