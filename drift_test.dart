import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'drift_test.g.dart';

class LocalTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get time => text()();
  TextColumn get deletedAt => text().nullable()();
}

@DriftDatabase(tables: [LocalTransactions])
class MyDatabase extends _$MyDatabase {
  MyDatabase() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  Future<List<LocalTransaction>> testQuery(String storeId, String fromStr, String toStr) async {
    final query = select(localTransactions)
      ..where((t) => t.storeId.equals(storeId))
      ..where((t) => CustomExpression<bool>("time >= '$fromStr' AND time <= '$toStr'"))
      ..where((t) => t.deletedAt.isNull());
    return query.get();
  }
}

void main() async {
  final db = MyDatabase();
  await db.into(db.localTransactions).insert(LocalTransactionsCompanion.insert(
    id: '1', storeId: 'store1', time: '2026-04-10T12:00:00.000',
  ));
  
  try {
    final res = await db.testQuery('store1', '2026-04-01T00:00:00.000', '2026-04-30T00:00:00.000');
    print("Found ${res.length} matching rows.");
  } catch (e) {
    print("ERROR: $e");
  }
}
