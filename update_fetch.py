import re

with open('lib/core/state/app_store.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace fetchOrdersByDateRange
src_orders = """  Future<List<OrderModel>> fetchOrdersByDateRange(DateTime start, DateTime end) async {
    final storeId = getStoreId();
    var query = _supabase.from('orders').select();
    if (storeId != 'sadmin') {
      query = query.eq('store_id', storeId).isFilter('deleted_at', null);
    }
    final response = await query
        .gte('time', start.toIso8601String())
        .lte('time', end.toIso8601String())
        .order('time', ascending: false);

    return (response as List).map((o) => OrderModel.fromMap(o)).toList();
  }"""

dest_orders = """  Future<List<OrderModel>> fetchOrdersByDateRange(DateTime start, DateTime end, {int offset = 0, int limit = 50}) async {
    final storeId = getStoreId();
    var query = _supabase.from('orders').select();
    if (storeId != 'sadmin') {
      query = query.eq('store_id', storeId).isFilter('deleted_at', null);
    }
    final response = await query
        .gte('time', start.toIso8601String())
        .lte('time', end.toIso8601String())
        .order('time', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List).map((o) => OrderModel.fromMap(o)).toList();
  }"""

if src_orders in content:
    content = content.replace(src_orders, dest_orders)
else:
    # Try more robust replacement
    content = re.sub(
        r"Future<List<OrderModel>> fetchOrdersByDateRange\(DateTime start, DateTime end\) async \{[^\}]+?\.order\('time', ascending: false\);\s+return \(response as List\)\.map\(\(o\) => OrderModel\.fromMap\(o\)\)\.toList\(\);\s+\}",
        dest_orders,
        content,
        flags=re.DOTALL
    )

with open('lib/core/state/app_store.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated fetchOrders")
