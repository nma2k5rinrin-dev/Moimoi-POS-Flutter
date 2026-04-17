
/// Legacy background service helper.
/// All actual background functionality has been migrated to Firebase Cloud Messaging (FCM).
/// These stubs remain to prevent compilation errors in legacy code that hasn't been removed yet.
class BackgroundServiceHelper {
  static Future<void> initialize() async {}
  static Future<void> startService([String? storeId]) async {}
  static Future<void> stopService() async {}
  static Future<bool> isRunning() async {
    return false;
  }
}
