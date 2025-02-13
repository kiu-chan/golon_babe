import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/sqlite_helper.dart';
import '../database/database_helper.dart';
import '../models/tree_model.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      print('Bắt đầu đồng bộ dữ liệu ngầm...');
      
      final localDb = SQLiteHelper();
      final remoteDb = DatabaseHelper();
      
      final isConnected = await remoteDb.testConnection();
      if (!isConnected) {
        print('Không có kết nối đến server');
        return Future.value(false);
      }

      final pendingRecords = await localDb.getPendingSyncTreeDetails();
      if (pendingRecords.isEmpty) {
        print('Không có dữ liệu cần đồng bộ');
        return Future.value(true);
      }

      print('Có ${pendingRecords.length} bản ghi cần đồng bộ');
      
      for (var record in pendingRecords) {
        try {
          if (record['sync_status'] == 'pending') {
            // Chuyển đổi Map thành TreeDetails
            final treeDetails = TreeDetails.fromJson(record);
            
            // Đồng bộ lên server
            final success = await remoteDb.saveTreeDetails(treeDetails);
            if (success) {
              await localDb.markAsSynced(record['id']);
              print('Đã đồng bộ bản ghi ${record['id']}');
              
              await showSyncNotification(
                'Đồng bộ thành công',
                'Đã đồng bộ dữ liệu cây ${record['id']}'
              );
            }
          }
        } catch (e) {
          print('Lỗi đồng bộ bản ghi ${record['id']}: $e');
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync', DateTime.now().toIso8601String());
      
      print('Hoàn thành đồng bộ ngầm');
      return Future.value(true);
    } catch (e) {
      print('Lỗi trong quá trình đồng bộ ngầm: $e');
      return Future.value(false);
    }
  });
}

// Khởi tạo service đồng bộ ngầm
Future<void> initBackgroundSync() async {
  try {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true
    );

    await Workmanager().registerPeriodicTask(
      'com.golon_babe.sync',
      'syncData',
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );

    print('Đã khởi tạo service đồng bộ ngầm');
  } catch (e) {
    print('Lỗi khởi tạo service đồng bộ ngầm: $e');
  }
}

Future<void> showSyncNotification(String title, String body) async {
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  const androidPlatformChannelSpecifics = AndroidNotificationDetails(
    'sync_channel',
    'Đồng bộ dữ liệu',
    channelDescription: 'Thông báo trạng thái đồng bộ dữ liệu',
    importance: Importance.low,
    priority: Priority.low,
    showWhen: false,
  );

  const platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
  );

  await flutterLocalNotificationsPlugin.show(
    0,
    title,
    body,
    platformChannelSpecifics,
  );
}