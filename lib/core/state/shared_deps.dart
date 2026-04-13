import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moimoi_pos/core/database/app_database.dart';
import 'package:moimoi_pos/core/sync/sync_engine.dart';
import 'dart:convert';

/// Shared dependencies injected into all feature Stores.
/// Replaces the old `BaseMixin` coupling pattern — no Store needs to know about
/// any other Store to access Supabase, Drift, Toast, or offline-first helpers.
class SharedDeps {
  final SupabaseClient supabaseClient = Supabase.instance.client;

  AppDatabase? db;
  SyncEngine? syncEngine;
  BuildContext? rootContext;

  /// Resolved by AuthStore after login, then consumed by every other Store.
  String Function() getStoreId = () => '';

  // ── Toast ────────────────────────────────────────────────
  String? toastMessage;
  String toastType = 'success';
  VoidCallback? _notifyUI;

  /// Register a callback that fires whenever toast state changes.
  void setNotifyUI(VoidCallback fn) => _notifyUI = fn;

  void showToast(String message, [String type = 'success']) {
    toastMessage = message;
    toastType = type;
    _notifyUI?.call();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (toastMessage == message) {
        toastMessage = null;
        _notifyUI?.call();
      }
    });
  }

  // ── Loading ──────────────────────────────────────────────
  bool isLoading = false;
  void setLoading(bool value) {
    isLoading = value;
    _notifyUI?.call();
  }

  // ── Optimistic UI Helper ─────────────────────────────────
  void optimistic({
    required VoidCallback apply,
    required Future<void> Function() remote,
    required VoidCallback rollback,
    required VoidCallback notify,
    String errorMsg = 'Có lỗi xảy ra, đã hoàn tác',
  }) {
    apply();
    notify();
    remote().catchError((e) {
      debugPrint('[Optimistic rollback] $e');
      rollback();
      notify();
      final detail = e.toString();
      showToast('$errorMsg\n$detail', 'error');
    });
  }

  // ── Offline-First Helper ─────────────────────────────────
  Future<void> offlineFirst({
    required String table,
    required String operation,
    required String recordId,
    required Map<String, dynamic> payload,
    required VoidCallback applyInMemory,
    required Future<void> Function() applyDrift,
    required VoidCallback notify,
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
        notify: notify,
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

      notify();
      syncEngine?.tryImmediateSync();
    } catch (e) {
      debugPrint('[offlineFirst] Drift failed: $e — falling back to Supabase');
      rollback?.call();
      notify();
      supabaseFallback(
        table: table,
        operation: operation,
        recordId: recordId,
        payload: payload,
        applyInMemory: applyInMemory,
        notify: notify,
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
    required VoidCallback notify,
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
      notify: notify,
      errorMsg: errorMsg,
    );
  }
}
