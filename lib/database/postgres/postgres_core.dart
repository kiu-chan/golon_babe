import 'package:postgres/postgres.dart';
import '../../config/env_config.dart';

class PostgresCore {
  static final PostgresCore _instance = PostgresCore._internal();
  factory PostgresCore() => _instance;
  PostgresCore._internal();

  static PostgreSQLConnection? _connection;
  bool _isConnecting = false;
  static const int _maxRetries = 3;
  static const int _connectionTimeout = 30; // Timeout là 30 giây
  static const int _queryTimeout = 30;

  // Environment variables getters
  static String get _host => EnvConfig.dbHost;
  static int get _port => EnvConfig.dbPort;
  static String get _database => EnvConfig.dbName;
  static String get _username => EnvConfig.dbUser;
  static String get _password => EnvConfig.dbPassword;

  Future<PostgreSQLConnection> get connection async {
    if (_connection != null && !_connection!.isClosed) {
      return _connection!;
    }
    return await _getConnection();
  }

  Future<PostgreSQLConnection> _getConnection() async {
    if (_isConnecting) {
      while (_isConnecting) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (_connection != null && !_connection!.isClosed) {
        return _connection!;
      }
    }

    _isConnecting = true;
    int retryCount = 0;
    
    while (retryCount < _maxRetries) {
      try {
        print('\n=== KẾT NỐI DATABASE ===');
        print('Đang kết nối đến database tại $_host:$_port (lần thử ${retryCount + 1})');
        
        // Đóng kết nối cũ nếu có
        if (_connection != null) {
          try {
            await _connection!.close();
            print('Đã đóng kết nối cũ');
          } catch (e) {
            print('Lỗi khi đóng kết nối cũ: $e');
          }
          _connection = null;
        }

        _connection = PostgreSQLConnection(
          _host,
          _port,
          _database,
          username: _username,
          password: _password,
          timeoutInSeconds: _connectionTimeout,
          queryTimeoutInSeconds: _queryTimeout,
          timeZone: 'UTC',
          useSSL: false,
          allowClearTextPassword: true,
        );

        await _connection!.open();
        _isConnecting = false;
        print('Kết nối database thành công\n');
        return _connection!;

      } catch (e) {
        retryCount++;
        print('Lỗi khi kết nối (lần thử $retryCount): $e');
        
        if (retryCount >= _maxRetries) {
          _isConnecting = false;
          throw Exception('Không thể kết nối đến database sau $_maxRetries lần thử: $e');
        }
        
        // Tăng thời gian chờ theo số lần thử
        final delaySeconds = retryCount * 2;
        print('Chờ $delaySeconds giây trước khi thử lại...\n');
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }

    _isConnecting = false;
    throw Exception('Lỗi không xác định trong quá trình kết nối database');
  }

  Future<bool> testConnection() async {
    try {
      print('\n=== KIỂM TRA KẾT NỐI DATABASE ===');
      
      // Đóng kết nối hiện tại nếu có
      if (_connection != null) {
        try {
          await _connection!.close();
          print('Đã đóng kết nối hiện tại');
        } catch (e) {
          print('Lỗi khi đóng kết nối hiện tại: $e');
        }
        _connection = null;
        _isConnecting = false;
      }

      // Thử mở kết nối mới
      _connection = PostgreSQLConnection(
        _host,
        _port,
        _database,
        username: _username,
        password: _password,
        timeoutInSeconds: _connectionTimeout,
        queryTimeoutInSeconds: _queryTimeout,
        timeZone: 'UTC',
        useSSL: false,
        allowClearTextPassword: true,
      );

      await _connection!.open();
      await _connection!.query('SELECT 1');
      print('Kiểm tra kết nối database thành công\n');
      return true;

    } catch (e) {
      print('Kiểm tra kết nối database thất bại: $e\n');
      
      if (_connection != null) {
        try {
          await _connection!.close();
        } catch (e) {
          print('Lỗi khi đóng kết nối thất bại: $e');
        }
        _connection = null;
        _isConnecting = false;
      }
      return false;
    }
  }

  Future<void> reconnectIfNeeded() async {
    print('\n=== KIỂM TRA VÀ KẾT NỐI LẠI NẾU CẦN ===');
    
    if (_connection == null || _connection!.isClosed) {
      print('Kết nối đã đóng hoặc null, thử kết nối lại...');
      await _getConnection();
      return;
    }

    try {
      // Thử thực hiện một truy vấn đơn giản để kiểm tra kết nối
      await _connection!.query('SELECT 1');
      print('Kết nối vẫn hoạt động tốt\n');
    } catch (e) {
      print('Phát hiện kết nối có vấn đề: $e');
      print('Thử kết nối lại...');
      
      try {
        await _connection!.close();
      } catch (e) {
        print('Lỗi khi đóng kết nối cũ: $e');
      }
      
      _connection = null;
      await _getConnection();
    }
  }

  Future<void> close() async {
    if (_connection != null && !_connection!.isClosed) {
      try {
        await _connection!.close();
        print('Đã đóng kết nối database');
      } catch (e) {
        print('Lỗi khi đóng kết nối database: $e');
      } finally {
        _connection = null;
        _isConnecting = false;
      }
    }
  }
}