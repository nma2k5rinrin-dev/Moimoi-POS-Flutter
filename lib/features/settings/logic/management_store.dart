import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moimoi_pos/features/notifications/models/notification_model.dart';
import 'package:moimoi_pos/features/premium/models/upgrade_request_model.dart';
import 'package:moimoi_pos/features/premium/models/premium_payment_model.dart';
import 'package:moimoi_pos/features/thu_chi/models/thu_chi_transaction_model.dart';
import 'package:moimoi_pos/core/state/base_mixin.dart';

mixin ManagementStore on ChangeNotifier, BaseMixin {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<NotificationModel> notifications = [];
  List<UpgradeRequestModel> upgradeRequests = [];
  List<PremiumPaymentModel> premiumPayments = [];
  List<ThuChiTransaction> thuChiTransactions = [];

  RealtimeChannel? _notiChannel;
  RealtimeChannel? _upgradeChannel;
  RealtimeChannel? _thuChiChannel;

  void clearManagementState() {
    notifications = [];
    upgradeRequests = [];
    premiumPayments = [];
    thuChiTransactions = [];
    _notiChannel?.unsubscribe();
    _upgradeChannel?.unsubscribe();
    _thuChiChannel?.unsubscribe();
  }
}
