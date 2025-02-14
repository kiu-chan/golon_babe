import 'package:flutter/material.dart';
import 'package:golon_babe/app.dart';
import 'package:golon_babe/config/env_config.dart';
import 'package:golon_babe/services/background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.initialize();

  // Khởi tạo notification
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initializationSettingsIOS = DarwinInitializationSettings();
  const initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  
  // Khởi tạo background service
  await initBackgroundSync();
  
  runApp(const App());
}