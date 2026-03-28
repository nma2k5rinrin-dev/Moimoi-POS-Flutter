import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:drift_sqflite/drift_sqflite.dart';
import 'package:flutter/foundation.dart';

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
  TextColumn get status =>
      text().withDefault(const Constant('pending'))();
  TextColumn get paymentStatus =>
      text().withDefault(const Constant('unpaid'))();
  RealColumn get totalAmount =>
      real().withDefault(const Constant(0.0))();
  TextColumn get createdBy =>
      text().withDefault(const Constant(''))();
  TextColumn get time => text()(); // ISO8601
  TextColumn get paymentMethod =>
      text().withDefault(const Constant(''))();
  BoolColumn get isSynced =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Thu Chi Transactions — Mirror bảng Supabase `thu_chi_transactions`
class LocalThuChi extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get type => text()(); // 'thu' | 'chi'
  RealColumn get amount => real()();
  TextColumn get category =>
      text().withDefault(const Constant(''))();
  TextColumn get note =>
      text().withDefault(const Constant(''))();
  TextColumn get time => text()();
  TextColumn get createdBy =>
      text().withDefault(const Constant(''))();
  BoolColumn get isSynced =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Products — Read-only cache
class LocalProducts extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get name => text()();
  RealColumn get price => real()();
  TextColumn get image =>
      text().withDefault(const Constant(''))();
  TextColumn get category =>
      text().withDefault(const Constant(''))();
  TextColumn get description =>
      text().withDefault(const Constant(''))();
  BoolColumn get isOutOfStock =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isHot =>
      boolean().withDefault(const Constant(false))();
  IntColumn get quantity =>
      integer().withDefault(const Constant(0))();
  RealColumn get costPrice =>
      real().withDefault(const Constant(0.0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Categories — Read-only cache
class LocalCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get storeId =>
      text().withDefault(const Constant(''))();
  TextColumn get emoji =>
      text().withDefault(const Constant(''))();
  TextColumn get color =>
      text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Sync Queue — Offline write operations pending sync
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get txId => text()(); // UUID v4 — idempotency key
  TextColumn get targetTable => text()(); // 'orders' | 'thu_chi_transactions'
  TextColumn get operation =>
      text()(); // 'INSERT' | 'UPDATE' | 'DELETE'
  TextColumn get recordId => text()(); // target record ID
  TextColumn get payload => text()(); // JSON payload
  IntColumn get retryCount =>
      integer().withDefault(const Constant(0))();
  IntColumn get maxRetries =>
      integer().withDefault(const Constant(5))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get status =>
      text().withDefault(const Constant('pending'))();
  // 'pending' | 'processing' | 'failed' | 'dead'
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

@DriftDatabase(tables: [
  LocalOrders,
  LocalThuChi,
  LocalProducts,
  LocalCategories,
  SyncQueue,
  KvStore,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Factory method to create an encrypted database connection.
  static AppDatabase connect([String? password]) {
    if (kIsWeb) {
      return AppDatabase(driftDatabase(
        name: 'moimoi_pos',
        web: DriftWebOptions(
          sqlite3Wasm: Uri.parse('sqlite3.wasm'),
          driftWorker: Uri.parse('drift_worker.js'),
        ),
      ));
    }

    // Mobile/Desktop encrypted path
    final executor = SqfliteQueryExecutor.inDatabaseFolder(
      path: 'moimoi_pos.db',
      logStatements: kDebugMode,
    );

    return AppDatabase(executor);
  }

  @override
  int get schemaVersion => 1;

  // ── KV Helpers ──
  Future<void> setKv(String key, String value) async {
    await into(kvStore).insertOnConflictUpdate(
      KvStoreCompanion(
        key: Value(key),
        value: Value(value),
      ),
    );
  }

  Future<String?> getKv(String key) async {
    final row = await (select(kvStore)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
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
    return into(syncQueue).insert(SyncQueueCompanion(
      txId: Value(txId),
      targetTable: Value(tableName),
      operation: Value(operation),
      recordId: Value(recordId),
      payload: Value(payload),
    ));
  }

  Future<List<SyncQueueData>> getPendingSyncOps() {
    return (select(syncQueue)
          ..where((t) => t.status.equals('pending'))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<void> markSyncProcessing(int id) {
    return (update(syncQueue)..where((t) => t.id.equals(id)))
        .write(const SyncQueueCompanion(status: Value('processing')));
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
    final count = await (select(syncQueue)
          ..where((t) =>
              t.recordId.equals(recordId) &
              t.status.isIn(['pending', 'processing'])))
        .get();
    return count.isNotEmpty;
  }

  // ── Order CRUD ──
  Future<void> upsertOrder(LocalOrdersCompanion order) {
    return into(localOrders).insertOnConflictUpdate(order);
  }

  Future<List<LocalOrder>> getOrdersByStore(String storeId) {
    return (select(localOrders)
          ..where((t) => t.storeId.equals(storeId))
          ..orderBy([(t) => OrderingTerm.desc(t.time)]))
        .get();
  }

  Stream<List<LocalOrder>> watchOrdersByStore(String storeId) {
    return (select(localOrders)
          ..where((t) => t.storeId.equals(storeId))
          ..orderBy([(t) => OrderingTerm.desc(t.time)]))
        .watch();
  }

  Future<void> markOrderSynced(String orderId) {
    return (update(localOrders)..where((t) => t.id.equals(orderId)))
        .write(const LocalOrdersCompanion(isSynced: Value(true)));
  }

  // ── Product Cache ──
  Future<void> upsertProduct(LocalProductsCompanion product) {
    return into(localProducts).insertOnConflictUpdate(product);
  }

  Future<void> replaceAllProducts(
      String storeId, List<LocalProductsCompanion> products) async {
    await transaction(() async {
      await (delete(localProducts)
            ..where((t) => t.storeId.equals(storeId)))
          .go();
      for (final p in products) {
        await into(localProducts).insert(p);
      }
    });
  }

  Future<List<LocalProduct>> getProductsByStore(String storeId) {
    return (select(localProducts)
          ..where((t) => t.storeId.equals(storeId)))
        .get();
  }

  // ── Category Cache ──
  Future<void> upsertCategory(LocalCategoriesCompanion cat) {
    return into(localCategories).insertOnConflictUpdate(cat);
  }

  Future<void> replaceAllCategories(
      String storeId, List<LocalCategoriesCompanion> categories) async {
    await transaction(() async {
      await (delete(localCategories)
            ..where((t) => t.storeId.equals(storeId)))
          .go();
      for (final c in categories) {
        await into(localCategories).insert(c);
      }
    });
  }

  Future<List<LocalCategory>> getCategoriesByStore(String storeId) {
    return (select(localCategories)
          ..where((t) => t.storeId.equals(storeId)))
        .get();
  }

  // ── Thu Chi CRUD ──
  Future<void> upsertThuChi(LocalThuChiCompanion txn) {
    return into(localThuChi).insertOnConflictUpdate(txn);
  }

  Future<List<LocalThuChiData>> getThuChiByStore(String storeId) {
    return (select(localThuChi)
          ..where((t) => t.storeId.equals(storeId))
          ..orderBy([(t) => OrderingTerm.desc(t.time)]))
        .get();
  }

  Future<void> markThuChiSynced(String txnId) {
    return (update(localThuChi)..where((t) => t.id.equals(txnId)))
        .write(const LocalThuChiCompanion(isSynced: Value(true)));
  }

  // ── Clear all data (logout) ──
  Future<void> clearAll() async {
    await transaction(() async {
      await delete(localOrders).go();
      await delete(localThuChi).go();
      await delete(localProducts).go();
      await delete(localCategories).go();
      await delete(syncQueue).go();
      await delete(kvStore).go();
    });
  }
}
