import 'package:flutter/material.dart';
import 'package:golon_babe/app.dart';
import 'package:golon_babe/services/background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo notification
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  
  // Thêm cấu hình cho iOS
  const initializationSettingsIOS = DarwinInitializationSettings();  // Thêm dòng này

  const initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS  // Thêm dòng này
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  
  // Khởi tạo background service
  await initBackgroundSync();
  
  runApp(const App());
}