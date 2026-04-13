import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'sqlcipher_executor.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// ═══════════════════════════════════════════════════════════
// TABLE DEFINITIONS
// ═══════════════════════════════════════════════════════════

/// Orders — Mirror bảng Supabase `orders`
class LocalOrders extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get orderTable => text().withDefault(const Constant(''))();
  TextColumn get itemsJson => text()(); // JSON-encoded List<OrderItemModel>
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get paymentStatus =>
      text().withDefault(const Constant('unpaid'))();
  RealColumn get totalAmount => real().withDefault(const Constant(0.0))();
  TextColumn get createdBy => text().withDefault(const Constant(''))();
  TextColumn get time => text()(); // ISO8601
  TextColumn get paymentMethod => text().withDefault(const Constant(''))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Transactions — Mirror of Supabase `transactions` table
class LocalTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get type => text()(); // 'thu' | 'chi'
  RealColumn get amount => real()();
  TextColumn get category => text().withDefault(const Constant(''))();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get time => text()();
  TextColumn get createdBy => text().withDefault(const Constant(''))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Products — Offline-first Support
class LocalProducts extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get name => text()();
  RealColumn get price => real()();
  TextColumn get image => text().withDefault(const Constant(''))();
  TextColumn get category => text().withDefault(const Constant(''))();
  TextColumn get description => text().withDefault(const Constant(''))();
  BoolColumn get isOutOfStock => boolean().withDefault(const Constant(false))();
  BoolColumn get isHot => boolean().withDefault(const Constant(false))();
  IntColumn get quantity => integer().withDefault(const Constant(0))();
  RealColumn get costPrice => real().withDefault(const Constant(0.0))();
  TextColumn get deletedAt => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Categories — Offline-first Support
class LocalCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get storeId => text().withDefault(const Constant(''))();
  TextColumn get emoji => text().withDefault(const Constant(''))();
  TextColumn get color => text().withDefault(const Constant(''))();
  TextColumn get deletedAt => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Sync Queue — Offline write operations pending sync
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get txId => text()(); // UUID v4 — idempotency key
  TextColumn get targetTable => text()(); // 'orders' | 'transactions'
  TextColumn get operation => text()(); // 'INSERT' | 'UPDATE' | 'DELETE'
  TextColumn get recordId => text()(); // target record ID
  TextColumn get payload => text()(); // JSON payload
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  IntColumn get maxRetries => integer().withDefault(const Constant(5))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  // 'pending' | 'processing' | 'failed' | 'dead'
}

/// Thu Chi Custom Categories (Read/Write Support)
class LocalTransactionCategories extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get type => text()(); // 'thu' | 'chi'
  TextColumn get emoji => text()();
  TextColumn get label => text()();
  IntColumn get color => integer()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Key-Value Store — Metadata (last_pull_at, logged_in user, etc.)
class KvStore extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// ═══════════════════════════════════════════════════════════
// DATABASE CLASS
// ═══════════════════════════════════════════════════════════

@DriftDatabase(
  tables: [
    LocalOrders,
    LocalTransactions,
    LocalProducts,
    LocalCategories,
    LocalTransactionCategories,
    SyncQueue,
    KvStore,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Factory method to create an encrypted database connection.
  static AppDatabase connect([String? password]) {
    if (kIsWeb) {
      return AppDatabase(
        driftDatabase(
          name: 'moimoi_pos',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );
    }

    // Mobile/Desktop encrypted path
    final executor = LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'moimoi_pos.db'));

      return SqlCipherQueryExecutor(
        path: file.path,
        password: password,
        logStatements: kDebugMode,
      );
    });

    return AppDatabase(executor);
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(localTransactionCategories);
      }
    },
  );

  // ── KV Helpers ──
  Future<void> setKv(String key, String value) async {
    await into(kvStore).insertOnConflictUpdate(
      KvStoreCompanion(key: Value(key), value: Value(value)),
    );
  }

  Future<String?> getKv(String key) async {
    final row = await (select(
      kvStore,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  // ── Sync Queue Helpers ──
  Future<int> enqueueSyncOp({
    required String txId,
    required String tableName,
    required String operation,
    required String recordId,
    required String payload,
  }) {
    return into(syncQueue).insert(
      SyncQueueCompanion(
        txId: Value(txId),
        targetTable: Value(tableName),
        operation: Value(operation),
        recordId: Value(recordId),
        payload: Value(payload),
      ),
    );
  }

  Future<List<SyncQueueData>> getPendingSyncOps() {
    return (select(syncQueue)
          ..where((t) => t.status.equals('pending'))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<void> markSyncProcessing(int id) {
    return (update(syncQueue)..where((t) => t.id.equals(id))).write(
      const SyncQueueCompanion(status: Value('processing')),
    );
  }

  Future<void> markSyncDone(int id) {
    return (delete(syncQueue)..where((t) => t.id.equals(id))).go();
  }

  Future<void> markSyncFailed(int id, int currentRetry, int maxRetry) {
    final newStatus = currentRetry + 1 >= maxRetry ? 'dead' : 'pending';
    return (update(syncQueue)..where((t) => t.id.equals(id))).write(
      SyncQueueCompanion(
        retryCount: Value(currentRetry + 1),
        status: Value(newStatus),
      ),
    );
  }

  /// Check if a record has pending sync operations
  Future<bool> hasPendingSync(String recordId) async {
    final count =
        await (select(syncQueue)..where(
              (t) =>
                  t.recordId.equals(recordId) &
                  t.status.isIn(['pending', 'processing']),
            ))
            .get();
    return count.isNotEmpty;
  }

  // ── Order CRUD ──
  Future<void> upsertOrder(LocalOrdersCompanion order) {
    return into(localOrders).insertOnConflictUpdate(order);
  }

  Future<void> deleteOrderLocally(String orderId) {
    return (delete(localOrders)..where((t) => t.id.equals(orderId))).go();
  }

  Future<List<LocalOrder>> getOrdersByStore(String storeId) {
    return (select(localOrders)
          ..where((t) => t.storeId.equals(storeId))
          ..orderBy([(t) => OrderingTerm.desc(t.time)]))
        .get();
  }

  Future<LocalOrder?> getOrderById(String orderId) {
    return (select(localOrders)
          ..where((t) => t.id.equals(orderId)))
        .getSingleOrNull();
  }

  Stream<List<LocalOrder>> watchOrdersByStore(String storeId) {
    return (select(localOrders)
          ..where((t) => t.storeId.equals(storeId))
          ..orderBy([(t) => OrderingTerm.desc(t.time)]))
        .watch();
  }

  Future<void> markOrderSynced(String orderId) {
    return (update(localOrders)..where((t) => t.id.equals(orderId))).write(
      const LocalOrdersCompanion(isSynced: Value(true)),
    );
  }

  // ── Product Cache ──
  Future<void> upsertProduct(LocalProductsCompanion product) {
    return into(localProducts).insertOnConflictUpdate(product);
  }

  Future<void> deleteProductLocally(String productId) {
    return (delete(localProducts)..where((t) => t.id.equals(productId))).go();
  }

  Future<void> markProductSynced(String productId) {
    return (update(localProducts)..where((t) => t.id.equals(productId))).write(
      const LocalProductsCompanion(isSynced: Value(true)),
    );
  }

  Future<void> replaceAllProducts(
    String storeId,
    List<LocalProductsCompanion> products,
  ) async {
    await transaction(() async {
      // Chỉ XÓA những SP đã đồng bộ (isSynced = true) 
      // để không xóa nhầm SP user vừa tạo offline đang kẹt trong máy.
      await (delete(localProducts)
        ..where((t) => t.storeId.equals(storeId) & t.isSynced.equals(true))).go();
      
      for (final p in products) {
        await into(localProducts).insertOnConflictUpdate(p);
      }
    });
  }

  Future<List<LocalProduct>> getProductsByStore(String storeId) {
    return (select(
      localProducts,
    )..where((t) => t.storeId.equals(storeId))).get();
  }

  // ── Category Cache ──
  Future<void> upsertCategory(LocalCategoriesCompanion cat) {
    return into(localCategories).insertOnConflictUpdate(cat);
  }

  Future<void> deleteCategoryLocally(String categoryId) {
    return (delete(localCategories)..where((t) => t.id.equals(categoryId))).go();
  }

  Future<void> markCategorySynced(String categoryId) {
    return (update(localCategories)..where((t) => t.id.equals(categoryId))).write(
      const LocalCategoriesCompanion(isSynced: Value(true)),
    );
  }

  Future<void> replaceAllCategories(
    String storeId,
    List<LocalCategoriesCompanion> categories,
  ) async {
    await transaction(() async {
      await (delete(localCategories)
        ..where((t) => t.storeId.equals(storeId) & t.isSynced.equals(true))).go();
        
      for (final c in categories) {
        await into(localCategories).insertOnConflictUpdate(c);
      }
    });
  }

  Future<List<LocalCategory>> getCategoriesByStore(String storeId) {
    return (select(
      localCategories,
    )..where((t) => t.storeId.equals(storeId))).get();
  }

  // ── Thu Chi CRUD ──
  Future<void> upsertTransaction(LocalTransactionsCompanion txn) {
    return into(localTransactions).insertOnConflictUpdate(txn);
  }

  Future<List<LocalTransaction>> getTransactionsByStore(String storeId) {
    return (select(localTransactions)
          ..where((t) => t.storeId.equals(storeId))
          ..orderBy([(t) => OrderingTerm.desc(t.time)]))
        .get();
  }

  Future<void> markTransactionSynced(String txnId) {
    return (update(localTransactions)..where((t) => t.id.equals(txnId))).write(
      const LocalTransactionsCompanion(isSynced: Value(true)),
    );
  }

  // ── Thu Chi Categories Cache ──
  Future<void> upsertTransactionCategory(
    LocalTransactionCategoriesCompanion cat,
  ) {
    return into(localTransactionCategories).insertOnConflictUpdate(cat);
  }

  Future<void> replaceAllTransactionCategories(
    String storeId,
    List<LocalTransactionCategoriesCompanion> categories,
  ) async {
    await transaction(() async {
      await (delete(
        localTransactionCategories,
      )..where((t) => t.storeId.equals(storeId))).go();
      for (final c in categories) {
        await into(localTransactionCategories).insert(c);
      }
    });
  }

  Future<void> deleteTransactionCategory(String id) {
    return (delete(
      localTransactionCategories,
    )..where((t) => t.id.equals(id))).go();
  }

  Future<List<LocalTransactionCategory>> getTransactionCategoriesByStore(
    String storeId,
  ) {
    return (select(
      localTransactionCategories,
    )..where((t) => t.storeId.equals(storeId))).get();
  }

  // ── Clear all data (logout) ──
  Future<void> clearAll() async {
    await transaction(() async {
      await delete(localOrders).go();
      await delete(localTransactions).go();
      await delete(localProducts).go();
      await delete(localCategories).go();
      await delete(localTransactionCategories).go();
      await delete(syncQueue).go();
      await delete(kvStore).go();
    });
  }
}
