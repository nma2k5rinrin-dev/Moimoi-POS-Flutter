import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moimoi_pos/core/utils/notification_helper.dart';
import 'package:moimoi_pos/core/utils/env_config.dart';
import 'package:moimoi_pos/features/pos_order/models/order_model.dart';
import 'dart:ui';

/// Persistent foreground notification ID (pinned like Messenger)
const int _kForegroundNotificationId = 888;

/// Notification channel for persistent foreground service (low priority, silent)
const String _kForegroundChannelId = 'pos_foreground_service';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // Android specific behavior
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Khởi tạo Local Notifications cho Isolate khác
  try {
    await NotificationHelper.init(isBackgroundService: true); 
  } catch (e) {
    debugPrint('Background init NotificationHelper error: $e');
  }
  
  // Khởi tạo kết nối Supabase
  try {
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      anonKey: EnvConfig.supabaseAnonKey,
    );
  } catch (e) {
    // If already initialized
  }

  final client = Supabase.instance.client;

  // Supabase v2 tự động khôi phục session nội bộ khi initialize() nên không cần recoverSession thủ công.
  
  // Đọc StoreID được lưu
  final prefs = await SharedPreferences.getInstance();
  final storeId = prefs.getString('moimoi_background_store_id');
  if (storeId == null || storeId.isEmpty) {
    service.stopSelf();
    return;
  }

  // Show persistent pinned notification immediately
  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: "MoiMoi POS đang hoạt động",
      content: "Đang lắng nghe đơn hàng mới...",
    );
  }

  // ── Helper: fetch đơn gộp và bắn notification ──
  Future<void> notifyMergedOrder(OrderModel triggerOrder) async {
    try {
      final existingData = await client
          .from('orders')
          .select('id, table_name, items, total_amount, status, store_id')
          .eq('store_id', triggerOrder.storeId)
          .eq('table_name', triggerOrder.table)
          .isFilter('deleted_at', null)
          .inFilter('status', ['pending', 'processing'])
          .eq('payment_status', 'unpaid')
          .order('time', ascending: false)
          .limit(1)
          .maybeSingle();

      if (existingData != null) {
        final mergedOrder = OrderModel.fromMap(existingData);
        await NotificationHelper.showNewOrderNotification(mergedOrder, isUpdate: true);
      }
    } catch (e) {
      debugPrint('[BackgroundService] Merge notification error: $e');
    }
  }

  // Subscribe Realtime for orders (INSERT + UPDATE in a single channel)
  client.channel('background-orders-$storeId').onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'orders',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'store_id',
          value: storeId,
        ),
        callback: (payload) async {
          // Skip nếu app đang foreground (foreground handler đã xử lý)
          final p = await SharedPreferences.getInstance();
          if (p.getBool('app_in_foreground') == true) return;

          if (payload.eventType == PostgresChangeEvent.insert) {
            final newOrder = OrderModel.fromMap(payload.newRecord);
            if (newOrder.deletedAt != null || newOrder.status == 'cancelled') {
              // INSERT bị DB trigger merge → tìm đơn cũ đã gộp và thông báo
              await notifyMergedOrder(newOrder);
            } else {
              // Đơn mới thật sự
              await NotificationHelper.showNewOrderNotification(newOrder);
            }
          } else if (payload.eventType == PostgresChangeEvent.update) {
            final newOrder = OrderModel.fromMap(payload.newRecord);
            if (newOrder.deletedAt == null) {
              // Thông báo nếu có item isNewlyAdded (từ DB trigger merge)
              final hasNewItems = newOrder.items.any((item) => item.isNewlyAdded);
              if (hasNewItems) {
                await NotificationHelper.showNewOrderNotification(newOrder, isUpdate: true);
              }
            }
          }
        },
      ).subscribe();

  // ── Heartbeat: cập nhật notification + reconnect Realtime nếu cần ──
  Timer.periodic(const Duration(minutes: 5), (timer) async {
    // Cập nhật thông báo foreground service (chống Android sleep)
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        final now = DateTime.now();
        final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
        service.setForegroundNotificationInfo(
          title: "MoiMoi POS đang hoạt động",
          content: "Đang lắng nghe đơn hàng mới • Cập nhật lúc $timeStr",
        );
      }
    }

    // Ghi chú: Supabase realtime channel sẽ tự động reconnect nếu rớt mạng.
    // Việc timer thức dậy đã giúp Android wake lock CPU một chút.
  });
}

class BackgroundServiceHelper {
  static Future<void> initialize() async {
    if (kIsWeb) return;
    
    final service = FlutterBackgroundService();

    // Tạo kênh thông báo cho Foreground Service — ongoing, pinned (like Messenger)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _kForegroundChannelId, 
      'Dịch vụ nhận đơn ngầm', 
      description: 'Hiện thông báo ghim khi đang lắng nghe đơn hàng mới',
      importance: Importance.low, // Low = silent but visible, no sound/vibration
      showBadge: false,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        autoStartOnBoot: false,
        isForegroundMode: true,
        notificationChannelId: _kForegroundChannelId,
        initialNotificationTitle: 'MoiMoi POS đang hoạt động',
        initialNotificationContent: 'Đang lắng nghe đơn hàng mới...',
        foregroundServiceNotificationId: _kForegroundNotificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
      ),
    );
  }

  /// Start the background foreground service (call after login if enabled)
  static Future<void> startService(String storeId) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('moimoi_background_store_id', storeId);
    
    final service = FlutterBackgroundService();
    
    // Check if already running to avoid duplicate starts
    final isRunning = await service.isRunning();
    if (isRunning) {
      debugPrint('[BackgroundService] Already running, skipping start');
      return;
    }
    
    service.startService();
    debugPrint('[BackgroundService] Started for store: $storeId');
  }

  /// Stop the service (call on logout or when user disables)
  static Future<void> stopService() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('moimoi_background_store_id');

    final service = FlutterBackgroundService();
    service.invoke('stopService');
    debugPrint('[BackgroundService] Stopped');
  }
  
  /// Check if background service is currently running
  static Future<bool> isRunning() async {
    if (kIsWeb) return false;
    final service = FlutterBackgroundService();
    return await service.isRunning();
  }
}
