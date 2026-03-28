import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:moimoi_pos/features/pos_order/models/order_model.dart';
import 'package:moimoi_pos/core/state/base_mixin.dart';

mixin OrderStore on ChangeNotifier, BaseMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AudioPlayer _orderSoundPlayer = AudioPlayer();

  List<OrderModel> orders = [];
  List<OrderItemModel> cart = [];
  String selectedTable = '';
  
  RealtimeChannel? _ordersChannel;

  void clearOrderState() {
    orders = [];
    cart = [];
    selectedTable = '';
    _ordersChannel?.unsubscribe();
  }
  
  // Audio helpers
  Future<void> playOrderSound() async {
    try {
      await _orderSoundPlayer.play(AssetSource('sounds/new_order.mp3'));
    } catch (e) {
      debugPrint('[OrderStore] Error playing sound: $e');
    }
  }
}
