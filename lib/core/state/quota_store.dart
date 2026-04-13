import 'package:moimoi_pos/core/utils/quota_helper.dart';
import 'package:moimoi_pos/features/auth/models/user_model.dart';
import 'package:moimoi_pos/features/settings/models/store_info_model.dart';
import 'package:moimoi_pos/features/inventory/models/category_model.dart';
import 'package:moimoi_pos/features/inventory/models/product_model.dart';
import 'package:moimoi_pos/features/pos_order/models/order_model.dart';

import 'package:moimoi_pos/features/auth/logic/auth_store_standalone.dart';
import 'package:moimoi_pos/features/inventory/logic/inventory_store_standalone.dart';
import 'package:moimoi_pos/features/pos_order/logic/order_store_standalone.dart';
import 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';

/// Standalone QuotaDataProvider — aggregates data from individual stores
/// for quota checks. NOT a ChangeNotifier — quota checks are point-in-time
/// reads, they don't need to be reactive.
class QuotaStore implements QuotaDataProvider {
  late final AuthStore _auth;
  late final InventoryStore _inv;
  late final OrderStore _order;
  late final ManagementStore _mgmt;

  /// Wire up after all stores are created (called from main.dart).
  void init({
    required AuthStore auth,
    required InventoryStore inv,
    required OrderStore order,
    required ManagementStore mgmt,
  }) {
    _auth = auth;
    _inv = inv;
    _order = order;
    _mgmt = mgmt;
  }

  @override
  UserModel? get currentUser => _auth.currentUser;

  @override
  StoreInfoModel get currentStoreInfo => _mgmt.currentStoreInfo;

  @override
  List<UserModel> get users => _auth.users;

  @override
  List<CategoryModel> get currentCategories => _inv.currentCategories;

  @override
  List<ProductModel> get currentProducts => _inv.currentProducts;

  @override
  List<OrderModel> get orders => _order.orders;

  @override
  List<String> get currentTables => _mgmt.currentTables;

  @override
  String getStoreId() {
    final u = _auth.currentUser;
    if (u == null) return '';
    if (u.role == 'sadmin') return 'sadmin';
    if (u.role == 'admin') return u.username;
    final owner = u.createdBy ?? '';
    return owner.isNotEmpty ? owner : u.username;
  }
}
