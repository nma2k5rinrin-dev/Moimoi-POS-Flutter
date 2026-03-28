import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:moimoi_pos/core/database/app_database.dart';
import 'package:moimoi_pos/services/connectivity/connectivity_service.dart';
import 'package:moimoi_pos/core/sync/sync_engine.dart';

/// Tên task cho Workmanager
const kSyncTaskName = 'moimoi_pos_sync';
const kSyncTaskUniqueName = 'moimoi_pos_periodic_sync';

/// Top-level callback cho Workmanager (phải là top-level function)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint('[SyncWorker] Task: $taskName started');

    try {
      // Tạo instances riêng cho background isolate
      final db = AppDatabase();
      final connectivity = ConnectivityService();
      connectivity.init();

      final engine = SyncEngine(
        db: db,
        connectivity: connectivity,
      );

      // Chạy sync
      await engine.syncAll();

      // Cleanup
      engine.dispose();
      connectivity.dispose();

      debugPrint('[SyncWorker] Task completed successfully');
      return true;
    } catch (e) {
      debugPrint('[SyncWorker] Task failed: $e');
      return false;
    }
  });
}

/// Helper class để init và quản lý Workmanager
class SyncWorker {
  /// Khởi tạo Workmanager (gọi 1 lần trong main)
  static Future<void> init() async {
    // Workmanager chỉ hoạt động trên mobile native
    if (kIsWeb) {
      debugPrint('[SyncWorker] Web platform — skipping Workmanager init');
      return;
    }

    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );

      // Register periodic task (mỗi 15 phút)
      await Workmanager().registerPeriodicTask(
        kSyncTaskUniqueName,
        kSyncTaskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingWorkPolicy.keep,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(seconds: 30),
      );

      debugPrint('[SyncWorker] Workmanager initialized + periodic task registered');
    } catch (e) {
      debugPrint('[SyncWorker] Init failed: $e');
    }
  }

  /// Cancel all background tasks (gọi khi logout)
  static Future<void> cancelAll() async {
    if (kIsWeb) return;
    try {
      await Workmanager().cancelAll();
      debugPrint('[SyncWorker] All tasks cancelled');
    } catch (e) {
      debugPrint('[SyncWorker] Cancel failed: $e');
    }
  }
}
