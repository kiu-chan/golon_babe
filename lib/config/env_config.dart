import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  // Private constructor to prevent instantiation
  EnvConfig._();

  // Database configurations with default values
  static String get dbHost => _getEnvVar('DB_HOST', defaultValue: '127.0.0.1');
  static int get dbPort => int.tryParse(_getEnvVar('DB_PORT', defaultValue: '5432')) ?? 5432;
  static String get dbName => _getEnvVar('DB_NAME', defaultValue: 'caygolon_babe');
  static String get dbUser => _getEnvVar('DB_USER', defaultValue: 'postgres');
  static String get dbPassword => _getEnvVar('DB_PASSWORD', defaultValue: '');

  // Admin configurations
  static String get adminUsername => _getEnvVar('ADMIN_USERNAME', defaultValue: 'admin');
  static String get adminPassword => _getEnvVar('ADMIN_PASSWORD', defaultValue: '123456');

  // API configurations
  static String get apiUrl => _getEnvVar('API_URL', defaultValue: 'http://localhost:8080');

  // Helper method to safely get environment variables
  static String _getEnvVar(String key, {required String defaultValue}) {
    try {
      final value = dotenv.env[key];
      if (value == null || value.isEmpty) {
        print('Warning: Environment variable $key not found, using default value');
        return defaultValue;
      }
      return value;
    } catch (e) {
      print('Error reading environment variable $key: $e');
      return defaultValue;
    }
  }

  // Initialize environment variables
  static Future<void> initialize() async {
    try {
      // Load .env file from the root directory
      await dotenv.load(fileName: '.env');
      print('Environment variables loaded successfully');
      
      // Validate required environment variables
      _validateEnvironmentVariables();
    } catch (e) {
      print('Warning: Error loading .env file: $e');
      print('Using default configuration values');
    }
  }

  // Validate required environment variables
  static void _validateEnvironmentVariables() {
    final requiredVars = [
      'DB_HOST', 
      'DB_PORT', 
      'DB_NAME', 
      'DB_USER', 
      'DB_PASSWORD',
      'ADMIN_USERNAME',
      'ADMIN_PASSWORD',
      'API_URL'
    ];
    
    final missingVars = requiredVars.where((var_) => dotenv.env[var_]?.isEmpty ?? true).toList();
    
    if (missingVars.isNotEmpty) {
      print('Warning: The following environment variables are missing or empty:');
      missingVars.forEach((var_) => print('- $var_'));
      print('Default values will be used for missing variables');
    }
  }
}