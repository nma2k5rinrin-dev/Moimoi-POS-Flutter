import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:moimoi_pos/features/auth/models/user_model.dart';
import 'package:moimoi_pos/features/settings/models/store_info_model.dart';
import 'package:moimoi_pos/core/state/base_mixin.dart';
import 'package:moimoi_pos/core/utils/quota_helper.dart';

import 'package:moimoi_pos/features/auth/logic/auth_store_standalone.dart';
import 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';
import 'package:moimoi_pos/features/premium/models/premium_payment_model.dart';

/// Manages Premium features (bank transfer flow — IAP removed).
class PremiumStore extends ChangeNotifier with BaseMixin {
  final AuthStore authStore;
  final ManagementStore managementStore;
  final QuotaDataProvider quotaProvider;
  final Future<void> Function(UserModel user) onLoadInitialData;
  final void Function(String message, [String type]) onShowToast;

  PremiumStore({
    required this.authStore,
    required this.managementStore,
    required this.quotaProvider,
    required this.onLoadInitialData,
    required this.onShowToast,
  });

  @override
  String getStoreId() => quotaProvider.getStoreId();

  List<PremiumPaymentModel> get premiumPayments => managementStore.premiumPayments;

  // Dependencies that AppStore provides
  UserModel? get currentUser => authStore.currentUser;
  Map<String, StoreInfoModel> get storeInfos => managementStore.storeInfos;
  Future<void> loadInitialData(UserModel user) => onLoadInitialData(user);

  // Need to be able to showToast
  void showToast(String message, [String type = 'success']) => onShowToast(message, type);

  /// IAP has been removed — premium is activated via bank transfer.
  /// These stubs exist so the rest of the codebase compiles.
  void initIAP() {}
  void disposeIAP() {}
  Future<void> loadStoreProducts() async {}
  Future<void> restorePurchases() async {}

  Future<void> _revokePremium() async {
    final user = currentUser;
    if (user == null) return;

    try {
      await supabaseClient
          .from('users')
          .update({'is_premium': false, 'show_vip_congrat': false})
          .eq('username', user.username);

      final storeId = getStoreId();
      if (storeId != 'sadmin' && storeId.isNotEmpty) {
        await supabaseClient
            .from('store_infos')
            .update({'is_premium': false})
            .eq('store_id', storeId)
            .isFilter('deleted_at', null);
      }

      await loadInitialData(user);
    } catch (_) {}
  }
}
