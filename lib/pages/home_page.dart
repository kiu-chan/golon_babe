import 'dart:async';
import 'package:flutter/material.dart';
import 'package:golon_babe/models/tree_model.dart';
import 'package:golon_babe/widgets/tree_form/tree_form.dart';
import 'package:golon_babe/repositories/tree_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TreeRepository _repository = TreeRepository();
  List<MasterTreeInfo> _masterTreeList = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  SharedPreferences? _prefs;
  late StreamSubscription<dynamic> _connectivitySubscription;
  bool _isOnline = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await _initPrefs();
      await _setupConnectivity();
      await _initialDataLoad();
    } catch (e) {
      print('Lỗi khởi tạo ứng dụng: $e');
      _handleError('Lỗi khởi tạo ứng dụng');
    } finally {
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initPrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      print('Lỗi khởi tạo SharedPreferences: $e');
      throw Exception('Không thể khởi tạo bộ nhớ cục bộ');
    }
  }

Future<void> _setupConnectivity() async {
  try {
    final connectivity = Connectivity();
    
    // Kiểm tra kết nối ban đầu
    final result = await connectivity.checkConnectivity();
    final hasConnection = result != ConnectivityResult.none;
    
    // Kiểm tra kết nối database nếu có mạng
    final isConnected = hasConnection ? 
        await _repository.hasInternetConnection() : false;
    
    if (mounted) {
      setState(() => _isOnline = isConnected);
      if (isConnected) {
        _showConnectionStatusSnackBar('Đã kết nối mạng', Colors.green);
        await _handleOnlineConnection(); // Đồng bộ ngay khi khởi động
      }
    }

    // Lắng nghe sự thay đổi kết nối
    _connectivitySubscription = connectivity.onConnectivityChanged.listen((dynamic result) async {
      if (!mounted) return;
      
      final connectivityResult = result is List<ConnectivityResult> 
          ? result.first 
          : result as ConnectivityResult;
      
      final hasConnection = connectivityResult != ConnectivityResult.none;
      if (hasConnection) {
        // Thêm delay nhỏ để đợi kết nối ổn định
        await Future.delayed(const Duration(milliseconds: 500));
        final isConnected = await _repository.hasInternetConnection();
        if (mounted && isConnected) {
          setState(() => _isOnline = true);
          _showConnectionStatusSnackBar('Đã kết nối mạng', Colors.green);
          await _handleOnlineConnection();
        }
      } else {
        if (mounted) {
          setState(() => _isOnline = false);
          _showConnectionStatusSnackBar('Đang sử dụng dữ liệu offline', Colors.orange);
          await _loadOfflineData();
        }
      }
    });
  } catch (e) {
    print('Lỗi thiết lập kết nối: $e');
    if (mounted) {
      setState(() => _isOnline = false);
    }
  }
}

Future<void> _handleOnlineConnection() async {
  try {
    print('\n=== XỬ LÝ KẾT NỐI ONLINE ===');
    // Đồng bộ dữ liệu ngay khi có kết nối
    await _syncData();
    await _loadMasterTreeInfo();
  } catch (e) {
    print('Lỗi xử lý kết nối online: $e');
    _handleError('Không thể cập nhật dữ liệu');
  }
}

Future<void> _initialDataLoad() async {
  try {
    print('\n=== KHỞI TẠO DỮ LIỆU ỨNG DỤNG ===');
    
    // Kiểm tra dữ liệu local trước
    final hasLocalData = await _repository.hasLocalData();
    
    if (hasLocalData) {
      print('Đã có dữ liệu local - Tải dữ liệu từ local...');
      await _loadOfflineData();
      
      // Nếu có mạng thì đồng bộ ngầm
      if (_isOnline) {
        _syncData();
      }
    } else {
      if (_isOnline) {
        print('Chưa có dữ liệu local - Tải dữ liệu lần đầu');
        _showFirstTimeDataDialog();
      } else {
        print('Không có dữ liệu offline và không có kết nối mạng');
        await _loadOfflineData();
      }
    }
    
    await _repository.printSavedData();
    
  } catch (e) {
    print('Lỗi tải dữ liệu ban đầu: $e');
    _handleError('Không thể tải dữ liệu ban đầu');
    await _loadOfflineData();
  }
}

  Future<bool> _shouldSyncData() async {
    if (_prefs == null) return true;
    
    final lastSync = _prefs!.getString('last_sync_date');
    if (lastSync == null) return true;

    final lastSyncDate = DateTime.parse(lastSync);
    final now = DateTime.now();
    return now.difference(lastSyncDate).inHours >= 1;
  }

  void _showFirstTimeDataDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Tải dữ liệu lần đầu'),
        content: const Text('Bạn cần tải dữ liệu lần đầu để sử dụng ứng dụng. Tiếp tục?'),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _syncData();
              await _loadMasterTreeInfo();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tải ngay'),
          ),
        ],
      ),
    );
  }

  void _showUpdateDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cập nhật dữ liệu'),
        content: const Text('Dữ liệu đã cũ. Bạn có muốn cập nhật dữ liệu mới không?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadMasterTreeInfo();
            },
            child: const Text('Để sau'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _syncData();
              await _loadMasterTreeInfo();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cập nhật ngay'),
          ),
        ],
      ),
    );
  }

Future<void> _syncData() async {
  if (_isSyncing || !_isOnline) return;
  
  setState(() {
    _isLoading = true;
    _isSyncing = true;
  });

  try {
    print('Bắt đầu đồng bộ dữ liệu...');
    await _repository.syncData();
    _prefs?.setString('last_sync_date', DateTime.now().toIso8601String());
    
    if (mounted) {
      _showSuccessSnackBar('Đồng bộ dữ liệu thành công');
    }
  } catch (e) {
    print('Lỗi đồng bộ: $e');
    _handleError('Lỗi đồng bộ dữ liệu');
  } finally {
    if (mounted) {
      setState(() {
        _isSyncing = false;
        _isLoading = false;
      });
    }
  }
}

  Future<void> _loadOfflineData() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      print('Đang tải dữ liệu offline...');
      final localData = await _repository.getLocalMasterTreeInfo();
      
      if (localData.isEmpty) {
        print('Không có dữ liệu trong local database');
      } else {
        print('Đã tải ${localData.length} bản ghi từ local database');
      }
      
      await _repository.printSavedData();
      
      if (mounted) {
        setState(() {
          _masterTreeList = localData;
          _isLoading = false;
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Lỗi khi tải dữ liệu offline: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialized = true;
        });
        _handleError('Không thể tải dữ liệu offline');
      }
    }
  }

  Future<void> _loadMasterTreeInfo() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      if (_isOnline) {
        print('Đang tải dữ liệu online...');
        final treeList = await _repository.getAllMasterTreeInfo();
        await _repository.getAllTreeDetailsAndSaveLocal();
        
        if (mounted) {
          setState(() {
            _masterTreeList = treeList;
            _isLoading = false;
          });
        }
      } else {
        await _loadOfflineData();
      }
    } catch (e) {
      print('Lỗi tải dữ liệu: $e');
      _handleError('Không thể tải dữ liệu');
      await _loadOfflineData();
    }
  }

  Future<void> _refreshData() async {
    if (_isOnline) {
      await _syncData();
    }
    await _loadMasterTreeInfo();
  }

  Future<void> _handleSubmit(TreeDetails details) async {
    try {
      final success = await _repository.saveTreeDetails(details);
      if (!mounted) return;

      if (success) {
        final message = details.id != null 
          ? 'Cập nhật thông tin thành công' 
          : 'Lưu thông tin thành công';
        _showSuccessSnackBar(message);
        
        if (_isOnline && !_isSyncing) {
          await _repository.syncData();
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
    if (!mounted) return;
    setState(() => _isLoading = false);
    _showErrorSnackBar(message);
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Đóng',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showConnectionStatusSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
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
            _isSyncing ? 'Đang đồng bộ dữ liệu...' : 'Đang tải dữ liệu...',
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
            _isOnline 
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
          if (_isOnline)
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
        masterTreeList: _masterTreeList,
        onSubmit: _handleSubmit,
        repository: _repository,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quản lý cây gỗ lớn Ba Bể',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.lightGreen[200],
        elevation: 0,
        actions: [
          if (!_isOnline)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.offline_bolt, color: Colors.orange),
            ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: !_isOnline || _isSyncing || _isLoading 
              ? null 
              : _syncData,
            tooltip: 'Đồng bộ dữ liệu',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : () {
              if (_isOnline) {
                _loadMasterTreeInfo();
              } else {
                _loadOfflineData();
              }
            },
            tooltip: 'Làm mới dữ liệu',
          ),
        ],
      ),
      body: !_isInitialized 
          ? _buildLoadingView()
          : _isLoading
              ? _buildLoadingView()
              : _buildMainContent(),
    );
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _repository.dispose();
    super.dispose();
  }
}