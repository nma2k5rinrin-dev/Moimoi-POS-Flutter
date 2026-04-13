import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moimoi_pos/core/database/app_database.dart';
import 'package:moimoi_pos/core/sync/sync_engine.dart';

/// Base mixin for common Store helpers.
/// All feature mixins extend this to access shared dependencies.
mixin BaseMixin on ChangeNotifier {
  bool isLoading = false;
  String? toastMessage;
  String toastType = 'success';

  // ── Shared Dependencies (set by AppStore) ────────────────
  AppDatabase? db;
  SyncEngine? syncEngine;
  BuildContext? rootContext;
  SupabaseClient get supabaseClient => Supabase.instance.client;

  /// Must be implemented by AppStore — resolves the active store ID.
  String getStoreId();

  // ── Toast ────────────────────────────────────────────────
  void Function(String message, [String type])? externalShowToast;

  void showToast(String message, [String type = 'success']) {
    if (externalShowToast != null) {
      externalShowToast!(message, type);
      return;
    }
    toastMessage = message;
    toastType = type;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (toastMessage == message) {
        toastMessage = null;
        super.notifyListeners();
      }
    });
  }

  // ── Loading ──────────────────────────────────────────────
  void setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  // ── Optimistic UI Helper ─────────────────────────────────
  void optimistic({
    required VoidCallback apply,
    required Future<void> Function() remote,
    required VoidCallback rollback,
    String errorMsg = 'Có lỗi xảy ra, đã hoàn tác',
  }) {
    apply();
    notifyListeners();
    remote().catchError((e) {
      debugPrint('[Optimistic rollback] $e');
      rollback();
      notifyListeners();
      final detail = e.toString();
      showToast('$errorMsg\n$detail', 'error');
    });
  }

  // ── Offline-First Helper ─────────────────────────────────
  /// Write to Drift first, enqueue sync_queue, update UI immediately.
  /// Falls back to direct Supabase if Drift is unavailable.
  Future<void> offlineFirst({
    required String table,
    required String operation,
    required String recordId,
    required Map<String, dynamic> payload,
    required VoidCallback applyInMemory,
    required Future<void> Function() applyDrift,
    VoidCallback? rollback,
    String errorMsg = 'Có lỗi xảy ra',
  }) async {
    if (db == null) {
      supabaseFallback(
        table: table,
        operation: operation,
        recordId: recordId,
        payload: payload,
        applyInMemory: applyInMemory,
        rollback: rollback,
        errorMsg: errorMsg,
      );
      return;
    }

    try {
      applyInMemory();
      await applyDrift();

      final txId =
          'tx_${DateTime.now().millisecondsSinceEpoch}_${recordId.hashCode}';
      await db!.enqueueSyncOp(
        txId: txId,
        tableName: table,
        operation: operation,
        recordId: recordId,
        payload: jsonEncode(payload),
      );

      notifyListeners();
      syncEngine?.tryImmediateSync();
    } catch (e) {
      debugPrint('[offlineFirst] Drift failed: $e — falling back to Supabase');
      rollback?.call();
      notifyListeners();
      supabaseFallback(
        table: table,
        operation: operation,
        recordId: recordId,
        payload: payload,
        applyInMemory: applyInMemory,
        rollback: rollback,
        errorMsg: errorMsg,
      );
    }
  }

  /// Direct Supabase fallback when Drift is unavailable or crashes.
  void supabaseFallback({
    required String table,
    required String operation,
    required String recordId,
    required Map<String, dynamic> payload,
    required VoidCallback applyInMemory,
    VoidCallback? rollback,
    required String errorMsg,
  }) {
    optimistic(
      apply: applyInMemory,
      remote: () async {
        if (operation == 'INSERT') {
          await supabaseClient.from(table).upsert(payload);
        } else if (operation == 'UPDATE') {
          await supabaseClient.from(table).update(payload).eq('id', recordId);
        } else if (operation == 'DELETE') {
          await supabaseClient.from(table).delete().eq('id', recordId);
        }
      },
      rollback: rollback ?? () {},
      errorMsg: errorMsg,
    );
  }
}
