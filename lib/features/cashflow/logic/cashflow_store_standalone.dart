import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value, OrderingTerm, OrderingMode, CustomExpression;
import 'package:moimoi_pos/core/state/base_mixin.dart';
import 'package:moimoi_pos/core/database/app_database.dart';
import 'package:moimoi_pos/features/cashflow/models/transaction_model.dart';
import 'package:moimoi_pos/features/cashflow/models/transaction_category_model.dart';
import 'package:moimoi_pos/features/auth/models/user_model.dart';
import 'package:moimoi_pos/core/utils/quota_helper.dart';
import 'package:moimoi_pos/features/premium/presentation/widgets/upgrade_dialog.dart';

/// Manages Thu/Chi categories and transactions CRUD.
class CashflowStore extends ChangeNotifier with BaseMixin {
  final QuotaDataProvider quotaProvider;
  final UserModel? Function() getCurrentUser;

  CashflowStore({
    required this.quotaProvider,
    required this.getCurrentUser,
  });

  @override
  String getStoreId() => quotaProvider.getStoreId();
  // ── State ─────────────────────────────────────────────────
  Map<String, List<TransactionCategory>> customTransactionCategories = {
    'sadmin': [],
  };
  List<Transaction> transactions = [];

  UserModel? get currentUser => getCurrentUser();

  void clearCashflowState() {
    customTransactionCategories = {'sadmin': []};
    transactions = [];
  }

  Future<void> initCashflowStore(String? storeId, DateTime todayStart) async {
    if (storeId == null) return;
    try {
      final Future<List<dynamic>> getCategories = supabaseClient
          .from('transaction_categories')
          .select()
          .eq('store_id', storeId)
          .isFilter('deleted_at', null);

      final Future<List<dynamic>> getTxns = supabaseClient
          .from('transactions')
          .select()
          .eq('store_id', storeId)
          .isFilter('deleted_at', null)
          .gte('time', todayStart.toIso8601String())
          .order('time', ascending: false);

      final results = await Future.wait([
        getCategories.catchError((e) { debugPrint('TxnCategories error: $e'); return <Map<String,dynamic>>[]; }), 
        getTxns.catchError((e) { debugPrint('Transactions error: $e'); return <Map<String,dynamic>>[]; })
      ]);

      customTransactionCategories = {};
      for (final c in results[0]) {
        final sid = c['store_id']?.toString() ?? '';
        if (sid.isNotEmpty) {
          customTransactionCategories.putIfAbsent(sid, () => []);
          customTransactionCategories[sid]!.add(TransactionCategory.fromMap(c));
        }
      }

      if (storeId != 'sadmin' && (customTransactionCategories[storeId] == null || customTransactionCategories[storeId]!.isEmpty)) {
        await _seedDefaultCategories(storeId);
      }

      transactions = (results[1]).map((r) => Transaction.fromMap(r)).toList();

      if (db != null) {
        final customCatCompanions = <LocalTransactionCategoriesCompanion>[];
        for (final entry in customTransactionCategories.entries) {
          for (final c in entry.value) {
            customCatCompanions.add(
              LocalTransactionCategoriesCompanion(
                id: Value(c.id!),
                storeId: Value(c.storeId!),
                type: Value(c.type),
                emoji: Value(c.emoji),
                label: Value(c.label),
                color: Value(c.color.value),
                isCustom: Value(c.isCustom),
              ),
            );
          }
        }
        if (customCatCompanions.isNotEmpty) {
          await db!.replaceAllTransactionCategories(
            storeId,
            customCatCompanions,
          );
        }

        for (final t in transactions) {
          await db!.upsertTransaction(
            LocalTransactionsCompanion(
              id: Value(t.id),
              storeId: Value(t.storeId),
              type: Value(t.type),
              amount: Value(t.amount),
              category: Value(t.category),
              note: Value(t.note),
              time: Value(t.time),
              createdBy: Value(t.createdBy),
              isSynced: const Value(true),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[initCashflowStore] $e');
    }
  }

  Future<void> _seedDefaultCategories(String storeId) async {
    final defaults = [
      TransactionCategory(type: 'chi', emoji: '📦', label: 'Nhập hàng', color: const Color(0xFFEF4444), isCustom: true),
      TransactionCategory(type: 'chi', emoji: '🥦', label: 'Nguyên liệu', color: const Color(0xFFF97316), isCustom: true),
      TransactionCategory(type: 'chi', emoji: '⚡', label: 'Điện nước', color: const Color(0xFF3B82F6), isCustom: true),
      TransactionCategory(type: 'chi', emoji: '🏠', label: 'Mặt bằng', color: const Color(0xFF8B5CF6), isCustom: true),
      TransactionCategory(type: 'chi', emoji: '💰', label: 'Lương nhân viên', color: const Color(0xFF14B8A6), isCustom: true),
      TransactionCategory(type: 'chi', emoji: '📝', label: 'Khác', color: const Color(0xFF64748B), isCustom: true),
      TransactionCategory(type: 'thu', emoji: '💵', label: 'Bán hàng', color: const Color(0xFF10B981), isCustom: true),
      TransactionCategory(type: 'thu', emoji: '🎁', label: 'Thanh lý', color: const Color(0xFFF59E0B), isCustom: true),
      TransactionCategory(type: 'thu', emoji: '📝', label: 'Khác', color: const Color(0xFF64748B), isCustom: true),
    ];

    for (final cat in defaults) {
      addTransactionCategory(cat);
    }
  }

  List<TransactionCategory> get currentCustomThuChiCategories =>
      customTransactionCategories[getStoreId()] ?? [];

  // ── Thu Chi Categories CRUD ───────────────────────────────
  void addTransactionCategory(TransactionCategory category) {
    final storeId = getStoreId();
    final newId = const Uuid().v4();

    final newCat = category.toMap();
    newCat['id'] = newId;
    newCat['store_id'] = storeId;
    newCat.removeWhere((k, v) => v == null);

    final catToDraft = TransactionCategory.fromMap(newCat);
    final oldList = List<TransactionCategory>.from(
      customTransactionCategories[storeId] ?? [],
    );

    offlineFirst(
      table: 'transaction_categories',
      operation: 'INSERT',
      recordId: newId,
      payload: newCat,
      applyInMemory: () {
        customTransactionCategories.putIfAbsent(storeId, () => []);
        customTransactionCategories[storeId]!.add(catToDraft);
      },
      applyDrift: () async {
        if (db != null) {
          await db!.upsertTransactionCategory(
            LocalTransactionCategoriesCompanion(
              id: Value(newId),
              storeId: Value(storeId),
              type: Value(catToDraft.type),
              emoji: Value(catToDraft.emoji),
              label: Value(catToDraft.label),
              color: Value(catToDraft.color.value),
              isCustom: Value(catToDraft.isCustom),
            ),
          );
        }
      },
      rollback: () {
        customTransactionCategories[storeId] = oldList;
      },
      errorMsg: 'Thêm danh mục Thu/Chi thất bại',
    );
  }

  void updateTransactionCategory(TransactionCategory updated) {
    if (updated.id == null) return;
    final storeId = getStoreId();
    final dbData = updated.toMap();
    dbData.remove('id');
    dbData.remove('store_id');
    final oldList = List<TransactionCategory>.from(
      customTransactionCategories[storeId] ?? [],
    );

    offlineFirst(
      table: 'transaction_categories',
      operation: 'UPDATE',
      recordId: updated.id!,
      payload: dbData,
      applyInMemory: () {
        customTransactionCategories[storeId] =
            (customTransactionCategories[storeId] ?? []).map((c) {
              return c.id == updated.id ? updated : c;
            }).toList();
      },
      applyDrift: () async {
        if (db != null) {
          await db!.upsertTransactionCategory(
            LocalTransactionCategoriesCompanion(
              id: Value(updated.id!),
              storeId: Value(storeId),
              type: Value(updated.type),
              emoji: Value(updated.emoji),
              label: Value(updated.label),
              color: Value(updated.color.value),
              isCustom: Value(updated.isCustom),
            ),
          );
        }
      },
      rollback: () {
        customTransactionCategories[storeId] = oldList;
      },
      errorMsg: 'Cập nhật mục Thu/Chi thất bại',
    );
  }

  void updateThuChiCategoryOrder(List<TransactionCategory> sortedList) {
    final storeId = getStoreId();
    final oldList = List<TransactionCategory>.from(
      customTransactionCategories[storeId] ?? [],
    );

    customTransactionCategories[storeId] = sortedList;
    notifyListeners();

    for (int i = 0; i < sortedList.length; i++) {
      final category = sortedList[i];
      final updatedData = {'sort_order': i};

      offlineFirst(
        table: 'transaction_categories',
        operation: 'UPDATE',
        recordId: category.id!,
        payload: updatedData,
        applyInMemory: () {},
        applyDrift: () async {
          if (db != null) {
            await db!.upsertTransactionCategory(
              LocalTransactionCategoriesCompanion(
                id: Value(category.id!),
                sortOrder: Value(i),
              ),
            );
          }
        },
        rollback: () {
          customTransactionCategories[storeId] = oldList;
        },
        errorMsg: 'Cập nhật thứ tự lỗi',
      );
    }
  }

  void deleteTransactionCategory(String categoryId) {
    final storeId = getStoreId();
    final oldList = List<TransactionCategory>.from(
      customTransactionCategories[storeId] ?? [],
    );

    offlineFirst(
      table: 'transaction_categories',
      operation: 'UPDATE',
      recordId: categoryId,
      payload: {'deleted_at': DateTime.now().toUtc().toIso8601String()},
      applyInMemory: () {
        customTransactionCategories[storeId]?.removeWhere(
          (c) => c.id == categoryId,
        );
      },
      applyDrift: () async {
        if (db != null) {
          await db!.deleteTransactionCategory(categoryId);
        }
      },
      rollback: () {
        customTransactionCategories[storeId] = oldList;
      },
      errorMsg: 'Xóa mục Thu/Chi thất bại',
    );
  }

  // ── Transactions CRUD ─────────────────────────────────────
  Future<void> loadTransactions(String? storeId) async {
    try {
      PostgrestFilterBuilder query = supabaseClient
          .from('transactions')
          .select();
      if (storeId != null) {
        query = query.eq('store_id', storeId).isFilter('deleted_at', null);
      }
      // Giới hạn 30 ngày gần nhất để tiết kiệm egress
      final since = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      final data = await query
          .gte('time', since)
          .order('time', ascending: false);
      transactions = (data as List).map((r) => Transaction.fromMap(r)).toList();
    } catch (e) {
      debugPrint('[loadTransactions] $e');
      transactions = [];
    }
  }

  Future<void> addTransaction({
    required String type,
    required double amount,
    required String category,
    String note = '',
    DateTime? date,
  }) async {
    final quota = QuotaHelper(quotaProvider);
    if (!quota.canUseTransactions) {
      final ctx = rootContext;
      if (ctx != null) await showUpgradePrompt(ctx, quota.transactionLimitMsg);
      return;
    }
    final storeId = getStoreId();
    final txnId = 'tc_${DateTime.now().millisecondsSinceEpoch}';
    final txnTime = (date ?? DateTime.now()).toIso8601String();
    final createdBy = currentUser?.fullname.isNotEmpty == true
        ? (currentUser?.fullname ?? 'unknown')
        : (currentUser?.username ?? 'unknown');

    final newTxn = {
      'id': txnId,
      'store_id': storeId,
      'type': type,
      'amount': amount,
      'category': category,
      'note': note,
      'time': txnTime,
      'created_by': createdBy,
    };
    final txnModel = Transaction.fromMap(newTxn);
    await offlineFirst(
      table: 'transactions',
      operation: 'INSERT',
      recordId: txnId,
      payload: newTxn,
      applyInMemory: () {
        transactions.insert(0, txnModel);
      },
      applyDrift: () => db!.upsertTransaction(
        LocalTransactionsCompanion(
          id: Value(txnId),
          storeId: Value(storeId),
          type: Value(type),
          amount: Value(amount),
          category: Value(category),
          note: Value(note),
          time: Value(txnTime),
          createdBy: Value(createdBy),
          isSynced: const Value(false),
        ),
      ),
      rollback: () {
        transactions.removeWhere((t) => t.id == txnId);
      },
      errorMsg: 'Lưu giao dịch thất bại, đã hoàn tác',
    );
  }

  Future<void> addThuChiTransaction({
    required String type,
    required double amount,
    required String category,
    String note = '',
    DateTime? date,
  }) => addTransaction(
    type: type,
    amount: amount,
    category: category,
    note: note,
    date: date,
  );

  Future<void> updateTransaction({
    required String id,
    required double amount,
    required String category,
    String note = '',
    DateTime? date,
  }) async {
    final idx = transactions.indexWhere((t) => t.id == id);
    if (idx == -1) return;

    final oldTxn = transactions[idx];
    final txnTime = date != null ? date.toIso8601String() : oldTxn.time;
    final payload = {
      'amount': amount,
      'category': category,
      'note': note,
      'time': txnTime,
    };

    final oldTransactions = List<Transaction>.from(transactions);

    await offlineFirst(
      table: 'transactions',
      operation: 'UPDATE',
      recordId: id,
      payload: payload,
      applyInMemory: () {
        transactions[idx] = oldTxn.copyWith(
          amount: amount,
          category: category,
          note: note,
          time: txnTime,
        );
        notifyListeners();
      },
      applyDrift: () => db!.upsertTransaction(
        LocalTransactionsCompanion(
          id: Value(id),
          storeId: Value(oldTxn.storeId),
          type: Value(oldTxn.type),
          amount: Value(amount),
          category: Value(category),
          note: Value(note),
          time: Value(txnTime),
          createdBy: Value(oldTxn.createdBy),
          isSynced: const Value(false),
        ),
      ),
      rollback: () {
        transactions = oldTransactions;
        notifyListeners();
      },
      errorMsg: 'Cập nhật giao dịch thất bại, đã hoàn tác',
    );
  }

  Future<void> deleteTransaction(String id) async {
    final oldTransactions = List<Transaction>.from(transactions);

    await offlineFirst(
      table: 'transactions',
      operation: 'UPDATE',
      recordId: id,
      payload: {'deleted_at': DateTime.now().toUtc().toIso8601String()},
      applyInMemory: () {
        transactions.removeWhere((t) => t.id == id);
        notifyListeners();
      },
      applyDrift: () async {
        if (db != null) {
          await (db!.delete(
            db!.localTransactions,
          )..where((tbl) => tbl.id.equals(id))).go();
        }
      },
      rollback: () {
        transactions = oldTransactions;
        notifyListeners();
      },
      errorMsg: 'Xóa giao dịch thất bại, đã hoàn tác',
    );
  }

  // ── Date Range Fetch ──────────────────────────────────────
  Future<List<Transaction>> fetchTransactionsByDateRange(
    DateTime from,
    DateTime to,
  ) async {
    final storeId = getStoreId();
    if (storeId.isEmpty || storeId == 'sadmin' || db == null) return [];

    final fromStr = DateTime(from.year, from.month, from.day).toIso8601String();
    final toStr = DateTime(
      to.year,
      to.month,
      to.day,
      23,
      59,
      59,
    ).toIso8601String();

    try {
      final query = db!.select(db!.localTransactions)
        ..where((t) => t.storeId.equals(storeId))
        ..where((t) => CustomExpression<bool>("time >= '$fromStr' AND time <= '$toStr'"))
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm(expression: t.time, mode: OrderingMode.desc)]);

      final records = await query.get();
      return records.map((r) => Transaction(
        id: r.id,
        storeId: r.storeId,
        type: r.type,
        amount: r.amount,
        category: r.category,
        time: r.time,
        note: r.note,
        createdBy: r.createdBy,
      )).toList();
    } catch (e) {
      debugPrint('[fetchTransactionsByDateRange] $e');
      return [];
    }
  }

  Future<Map<String, double>> fetchCashflowSummary(DateTime from, DateTime to) async {
    final storeId = getStoreId();
    if (storeId.isEmpty || storeId == 'sadmin') return {'totalIncome': 0.0, 'totalExpense': 0.0};
    
    try {
      final fromStr = DateTime(from.year, from.month, from.day).toIso8601String();
      final toStr = DateTime(to.year, to.month, to.day, 23, 59, 59).toIso8601String();
      
      final response = await supabaseClient.rpc('get_cashflow_summary', params: {
        'p_store_id': storeId,
        'p_start_date': fromStr,
        'p_end_date': toStr,
      });
      return {
        'totalIncome': (response['totalIncome'] ?? 0).toDouble(),
        'totalExpense': (response['totalExpense'] ?? 0).toDouble(),
      };
    } catch (e) {
      debugPrint('[fetchCashflowSummary] $e');
      return {'totalIncome': 0.0, 'totalExpense': 0.0};
    }
  }
}
