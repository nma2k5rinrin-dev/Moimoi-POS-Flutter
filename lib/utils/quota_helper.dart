import '../store/app_store.dart';

/// Quota limits for the free (Cơ bản) tier.
/// Premium users have no limits.
class QuotaLimits {
  static const int maxStaff = 1;
  static const int maxTables = 2;
  static const int maxCategories = 1;
  static const int maxProducts = 5;
  static const int maxOrdersPerDay = 10;
}

class QuotaHelper {
  final AppStore store;
  const QuotaHelper(this.store);

  bool get _isPremium => store.currentStoreInfo.isPremium;

  // ── Staff ──────────────────────────────────────────────
  int get currentStaffCount {
    final storeId = store.getStoreId();
    return store.users
        .where((u) => u.role == 'staff' && u.createdBy == storeId)
        .length;
  }

  bool get canAddStaff =>
      _isPremium || currentStaffCount < QuotaLimits.maxStaff;

  String get staffLimitMsg =>
      'Gói Cơ bản chỉ cho phép tối đa ${QuotaLimits.maxStaff} nhân viên. '
      'Nâng cấp Premium để thêm không giới hạn.';

  // ── Tables ─────────────────────────────────────────────
  int get currentTableCount => store.currentTables.length;

  bool get canAddTable =>
      _isPremium || currentTableCount < QuotaLimits.maxTables;

  String get tableLimitMsg =>
      'Gói Cơ bản chỉ cho phép tối đa ${QuotaLimits.maxTables} bàn. '
      'Nâng cấp Premium để thêm không giới hạn.';

  // ── Categories ─────────────────────────────────────────
  int get currentCategoryCount => store.currentCategories.length;

  bool get canAddCategory =>
      _isPremium || currentCategoryCount < QuotaLimits.maxCategories;

  String get categoryLimitMsg =>
      'Gói Cơ bản chỉ cho phép tối đa ${QuotaLimits.maxCategories} khu vực. '
      'Nâng cấp Premium để thêm không giới hạn.';

  // ── Products ───────────────────────────────────────────
  int get currentProductCount => store.currentProducts.length;

  bool get canAddProduct =>
      _isPremium || currentProductCount < QuotaLimits.maxProducts;

  String get productLimitMsg =>
      'Gói Cơ bản chỉ cho phép tối đa ${QuotaLimits.maxProducts} sản phẩm. '
      'Nâng cấp Premium để thêm không giới hạn.';

  // ── Orders / day ───────────────────────────────────────
  int get todayOrderCount {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final storeId = store.getStoreId();
    return store.orders.where((o) {
      if (o.storeId != storeId) return false;
      final orderTime = DateTime.tryParse(o.time);
      return orderTime != null && orderTime.isAfter(startOfDay);
    }).length;
  }

  bool get canPlaceOrder =>
      _isPremium || todayOrderCount < QuotaLimits.maxOrdersPerDay;

  int get remainingOrdersToday =>
      _isPremium ? -1 : QuotaLimits.maxOrdersPerDay - todayOrderCount;

  String get orderLimitMsg =>
      'Gói Cơ bản chỉ cho phép tối đa ${QuotaLimits.maxOrdersPerDay} đơn/ngày. '
      'Còn lại: ${remainingOrdersToday < 0 ? 0 : remainingOrdersToday} đơn. '
      'Nâng cấp Premium để không giới hạn.';
}
