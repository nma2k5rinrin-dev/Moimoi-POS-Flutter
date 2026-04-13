import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:moimoi_pos/features/auth/models/user_model.dart';
import 'package:moimoi_pos/features/settings/models/store_info_model.dart';
import 'package:moimoi_pos/core/state/base_mixin.dart';
import 'package:moimoi_pos/core/utils/quota_helper.dart';

import 'package:moimoi_pos/features/auth/logic/auth_store_standalone.dart';
import 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';
import 'package:moimoi_pos/features/premium/models/premium_payment_model.dart';

/// Manages In-App Purchases for Premium features.
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
  final InAppPurchase? _iap = kIsWeb ? null : InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  List<ProductDetails> storeProducts = [];
  List<PremiumPaymentModel> get premiumPayments => managementStore.premiumPayments;
  bool isIapAvailable = false;

  static const List<String> _kProductIds = <String>[
    'premium_1_month',
    'premium_3_months',
    'premium_6_months',
    'premium_12_months',
  ];

  // Dependencies that AppStore provides
  UserModel? get currentUser => authStore.currentUser;
  Map<String, StoreInfoModel> get storeInfos => managementStore.storeInfos;
  Future<void> loadInitialData(UserModel user) => onLoadInitialData(user);

  // Need to be able to showToast
  void showToast(String message, [String type = 'success']) => onShowToast(message, type);

  void initIAP() {
    if (kIsWeb) return;
    final purchaseUpdated = _iap!.purchaseStream;
    _purchaseSubscription = purchaseUpdated.listen(
      (purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () {
        _purchaseSubscription?.cancel();
      },
      onError: (error) {
        debugPrint('[IAP] Purchase Stream Error: $error');
      },
    );

    _iap!.isAvailable().then((available) async {
      isIapAvailable = available;
      if (available) {
        await loadStoreProducts();
        await _iap!.restorePurchases();
      } else {
        debugPrint('[IAP] Store not available');
      }
    });
  }

  void disposeIAP() {
    _purchaseSubscription?.cancel();
  }

  Future<void> loadStoreProducts() async {
    if (kIsWeb || _iap == null) {
      isIapAvailable = false;
      notifyListeners();
      return;
    }
    isIapAvailable = await _iap!.isAvailable();
    if (!isIapAvailable) {
      notifyListeners();
      return;
    }

    final ProductDetailsResponse response = await _iap!.queryProductDetails(
      _kProductIds.toSet(),
    );
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('[IAP] Not found IDs: ${response.notFoundIDs}');
    }
    storeProducts = response.productDetails;
    notifyListeners();
  }

  Future<void> requestInAppPurchase(ProductDetails product) async {
    if (kIsWeb || _iap == null) return;
    isLoading = true;
    notifyListeners();
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    await _iap!.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() async {
    if (kIsWeb || _iap == null) return;
    isLoading = true;
    notifyListeners();
    try {
      await _iap!.restorePurchases();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _listenToPurchaseUpdated(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        isLoading = true;
        notifyListeners();
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          isLoading = false;
          showToast(
            'Giao dịch thất bại: ${purchaseDetails.error?.message}',
            'error',
          );
          notifyListeners();
        } else if (purchaseDetails.status == PurchaseStatus.canceled) {
          isLoading = false;
          notifyListeners();
          await _revokePremium();
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          await _verifyAndDeliverProduct(purchaseDetails);
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap?.completePurchase(purchaseDetails);
        }
      }
    }
  }

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

      // Force update user model and store info - done locally by UI logic or refetch.
      // Since currentUser is a getter, we can't directly assign to it here if it's set in AuthStore.
      // Easiest is just calling loadInitialData
      await loadInitialData(user);
    } catch (_) {}
  }

  Future<void> _verifyAndDeliverProduct(PurchaseDetails purchaseDetails) async {
    final user = currentUser;
    if (user == null) return;

    int months = 0;
    if (purchaseDetails.productID == 'premium_1_month') {
      months = 1;
    } else if (purchaseDetails.productID == 'premium_3_months')
      months = 3;
    else if (purchaseDetails.productID == 'premium_6_months')
      months = 6;
    else if (purchaseDetails.productID == 'premium_12_months')
      months = 12;

    if (months > 0) {
      var baseDate =
          (user.expiresAt != null &&
              DateTime.parse(user.expiresAt!).isAfter(DateTime.now()))
          ? DateTime.parse(user.expiresAt!)
          : DateTime.now();
      baseDate = baseDate.add(Duration(days: months * 30));

      await supabaseClient
          .from('users')
          .update({
            'is_premium': true,
            'expires_at': baseDate.toIso8601String(),
            'show_vip_congrat': true,
          })
          .eq('username', user.username);

      final storeId = getStoreId();
      if (storeId != 'sadmin' && storeId.isNotEmpty) {
        await supabaseClient
            .from('store_infos')
            .update({
              'is_premium': true,
              'premium_expires_at': baseDate.toIso8601String(),
              'premium_activated_at': DateTime.now().toIso8601String(),
            })
            .eq('store_id', storeId)
            .isFilter('deleted_at', null);
      }

      final paymentRecord = {
        'id':
            purchaseDetails.purchaseID ??
            'pp_${DateTime.now().millisecondsSinceEpoch}',
        'username': user.username,
        'plan_name': '$months Tháng',
        'months': months,
        'amount': 0,
        'paid_at': DateTime.now().toIso8601String(),
      };
      try {
        await supabaseClient.from('premium_payments').insert(paymentRecord);
      } catch (_) {}

      await loadInitialData(user);
      showToast('Đăng ký Premium thành công!', 'success');
      isLoading = false;
      notifyListeners();
    }
  }
}
