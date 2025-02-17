import 'package:postgres/postgres.dart';
import '../../config/env_config.dart';

class PostgresCore {
  static final PostgresCore _instance = PostgresCore._internal();
  factory PostgresCore() => _instance;
  PostgresCore._internal();

  static PostgreSQLConnection? _connection;
  bool _isConnecting = false;
  static const int _maxRetries = 3;

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
    
    try {
      print('Đang kết nối đến database tại $_host:$_port');
      
      _connection = PostgreSQLConnection(
        _host,
        _port,
        _database,
        username: _username,
        password: _password,
        timeoutInSeconds: 5,
        queryTimeoutInSeconds: 5,
        timeZone: 'UTC',
        useSSL: false,
      );

      await _connection!.open();
      _isConnecting = false;
      print('Kết nối database thành công');
      return _connection!;

    } catch (e) {
      _isConnecting = false;
      if (_connection != null) {
        try {
          await _connection!.close();
        } catch (e) {
          print('Lỗi khi đóng kết nối thất bại: $e');
        }
        _connection = null;
      }
      throw Exception('Không thể kết nối đến database: $e');
    }
  }

  Future<bool> testConnection() async {
    try {
      print('Kiểm tra kết nối database...');
      
      if (_connection != null) {
        try {
          await _connection!.close();
        } catch (e) {
          print('Lỗi khi đóng kết nối hiện tại: $e');
        }
        _connection = null;
        _isConnecting = false;
      }

      _connection = PostgreSQLConnection(
        _host,
        _port,
        _database,
        username: _username,
        password: _password,
        timeoutInSeconds: 5,
        queryTimeoutInSeconds: 5,
        timeZone: 'UTC',
        useSSL: false,
      );

      await _connection!.open();
      await _connection!.query('SELECT 1');
      print('Kiểm tra kết nối database thành công');
      return true;
    } catch (e) {
      print('Kiểm tra kết nối database thất bại: $e');
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
    if (_connection != null) {
      try {
        await _connection!.close();
      } catch (e) {
        print('Lỗi khi đóng kết nối: $e');
      }
      _connection = null;
    }
  }

  Future<void> close() async {
    if (_connection != null && !_connection!.isClosed) {
      await _connection!.close();
      _connection = null;
    }
  }
}