import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:moimoi_pos/features/pos_order/models/order_model.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:moimoi_pos/core/router/app_router.dart';
import 'package:moimoi_pos/features/pos_order/logic/cart_store_standalone.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init({Function(String?)? onNotificationTapped, bool isBackgroundService = false}) async {
    // Xin quyền trước
    if (!isBackgroundService) {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await Permission.notification.request();
      } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
    }

    // Khởi tạo plugin. Dùng icon có sẵn '@mipmap/launcher_icon'
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) {
            final payload = notificationResponse.payload;
            if (payload != null && rootNavigatorKey.currentContext != null) {
              final ctx = rootNavigatorKey.currentContext!;
              final store = Provider.of<CartStore>(ctx, listen: false);
              
              // Select the table associated with the notification
              store.setSelectedTable(payload);
              
              // Navigate to the POS screen where orders for tables are shown
              ctx.go('/');
            }
            if (onNotificationTapped != null) {
              onNotificationTapped(payload);
            }
          },
    );
  }

  static Future<void> showNewOrderNotification(OrderModel order, {bool isUpdate = false}) async {

    final int id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'new_order_channel_v2',
          'Đơn Hàng Mới',
          channelDescription: 'Thông báo khi có đơn hàng mới từ QR code',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          playSound: true,
          audioAttributesUsage: AudioAttributesUsage.notificationEvent,
          icon: '@mipmap/launcher_icon',
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    final currencyFormatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
    );
    final formattedTotal = currencyFormatter.format(order.totalAmount);

    await flutterLocalNotificationsPlugin.show(
      id: id,
      title: isUpdate ? '🔔 Vừa thêm sản phẩm vào đơn!' : '🎉 Có đơn hàng mới!',
      body: '${order.table} - Tổng: $formattedTotal',
      notificationDetails: platformChannelSpecifics,
      payload: order.table,
    );
  }

  static Future<void> showGenericNotification(String title, String body, {String? payload}) async {
    final int id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: AndroidNotificationDetails(
        'new_order_channel_v2',
        'Đơn Hàng Mới',
        channelDescription: 'Thông báo khi có đơn hàng mới từ QR code',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        audioAttributesUsage: AudioAttributesUsage.notificationEvent,
        icon: '@mipmap/launcher_icon',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: payload,
    );
  }

  static Future<void> clearAppBadge() async {
    if (!kIsWeb) {
      // With flutter_local_notifications ^16.0+, setBadgeNumber is no longer natively available
      // Instead, cancelling all notifications will implicitly clear internal badges on most OSes.
      try {
        await flutterLocalNotificationsPlugin.cancelAll();
      } catch (_) {}
    }
  }
}
