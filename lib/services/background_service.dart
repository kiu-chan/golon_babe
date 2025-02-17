// Vị trí: lib/services/background_service.dart

import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/sqlite_helper.dart';
import '../database/database_helper.dart';
import '../models/tree_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      print('\n=== BẮT ĐẦU ĐỒNG BỘ NGẦM ===');
      
      // Khởi tạo notification
      final notifications = FlutterLocalNotificationsPlugin();
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await notifications.initialize(initSettings);
      
      // Hiển thị notification đang đồng bộ
      await showSyncNotification('Đang đồng bộ', 'Đang kiểm tra dữ liệu...', notifications);
      
      // Kiểm tra kết nối
      final connectivity = Connectivity();
      final connectivityResult = await connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        print('Không có kết nối mạng - Bỏ qua đồng bộ');
        return Future.value(true);
      }

      final localDb = SQLiteHelper();
      final remoteDb = PostgresHelper();
      
      // Kiểm tra kết nối database
      bool isConnected = false;
      try {
        isConnected = await remoteDb.testConnection();
      } catch (e) {
        print('Lỗi kết nối database: $e');
      }
      
      if (!isConnected) {
        print('Không kết nối được database - Bỏ qua đồng bộ');
        return Future.value(true);
      }

      // Lấy danh sách cây cần đồng bộ
      final pendingRecords = await localDb.getPendingSyncTreeDetails();
      print('Có ${pendingRecords.length} bản ghi cần đồng bộ');

      if (pendingRecords.isNotEmpty) {
        // Hiển thị notification đang đồng bộ
        await showSyncNotification(
          'Đang đồng bộ', 
          'Đang xử lý ${pendingRecords.length} bản ghi...', 
          notifications
        );

        // Đồng bộ từng bản ghi
        int syncedCount = 0;
        for (var record in pendingRecords) {
          try {
            final treeDetails = TreeDetails.fromJson(record);
            final success = await remoteDb.saveTreeDetails(treeDetails);
            if (success) {
              await localDb.markAsSynced(record['id']);
              syncedCount++;
            }
          } catch (e) {
            print('Lỗi đồng bộ bản ghi ${record['id']}: $e');
          }
        }

        if (syncedCount > 0) {
          await showSyncNotification(
            'Đồng bộ thành công', 
            'Đã đồng bộ $syncedCount bản ghi', 
            notifications
          );
        }
      }

      // Cập nhật dữ liệu từ server
      try {
        // Lấy và cập nhật master trees
        final masterTrees = await remoteDb.getMasterTreeInfo();
        await localDb.insertMasterTreeInfo(masterTrees);

        // Lấy và cập nhật tree details
        final treeDetails = await remoteDb.getTreeDetails();
        for (var detail in treeDetails) {
          await localDb.insertTreeDetail({
            ...detail,
            'sync_status': 'synced',
          });
        }
      } catch (e) {
        print('Lỗi cập nhật dữ liệu từ server: $e');
      }

      // Lưu thời gian đồng bộ
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync', DateTime.now().toIso8601String());
      
      print('=== KẾT THÚC ĐỒNG BỘ NGẦM ===\n');
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

    // Đăng ký task định kỳ
    await Workmanager().registerPeriodicTask(
      'com.golon_babe.periodic_sync',
      'periodicSync',
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 5),
    );

    // Đăng ký task chạy ngay
    await Workmanager().registerOneOffTask(
      'com.golon_babe.immediate_sync',
      'immediateSync',
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );

    print('Đã khởi tạo service đồng bộ ngầm');
  } catch (e) {
    print('Lỗi khởi tạo service đồng bộ ngầm: $e');
  }
}

Future<void> showSyncNotification(
  String title, 
  String body, 
  FlutterLocalNotificationsPlugin notifications
) async {
  const androidDetails = AndroidNotificationDetails(
    'sync_channel',
    'Đồng bộ dữ liệu',
    channelDescription: 'Thông báo trạng thái đồng bộ dữ liệu',
    importance: Importance.low,
    priority: Priority.low,
    ongoing: true,
    autoCancel: false,
    showWhen: false,
  );

  const details = NotificationDetails(android: androidDetails);

  await notifications.show(
    0,
    title,
    body,
    details,
  );
}