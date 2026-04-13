import 'package:flutter/material.dart';
import 'package:moimoi_pos/features/inventory/models/product_model.dart';
import 'package:moimoi_pos/features/pos_order/models/order_model.dart';

class CartStore extends ChangeNotifier {
  List<OrderItemModel> cart = [];
  String selectedTable = '';

  void addToCart(ProductModel product) {
    final existingIdx = cart.indexWhere((item) => item.id == product.id);
    if (existingIdx >= 0) {
      cart = [
        for (int i = 0; i < cart.length; i++)
          if (i == existingIdx)
            cart[i].copyWith(quantity: cart[i].quantity + 1)
          else
            cart[i],
      ];
    } else {
      cart = [
        ...cart,
        OrderItemModel(
          id: product.id,
          name: product.name,
          price: product.price,
          quantity: 1,
          note: '',
          image: product.image,
        ),
      ];
    }
    notifyListeners();
  }

  void removeFromCart(String productId) {
    cart = cart.where((item) => item.id != productId).toList();
    notifyListeners();
  }

  void updateQuantity(String productId, int amount) {
    final idx = cart.indexWhere((item) => item.id == productId);
    if (idx >= 0) {
      final newQty = cart[idx].quantity + amount;
      if (newQty <= 0) {
        cart = [...cart.sublist(0, idx), ...cart.sublist(idx + 1)];
      } else {
        cart = [
          for (int i = 0; i < cart.length; i++)
            if (i == idx) cart[i].copyWith(quantity: newQty) else cart[i],
        ];
      }
      notifyListeners();
    }
  }

  void addNote(String productId, String note) {
    cart = cart
        .map((item) => item.id == productId ? item.copyWith(note: note) : item)
        .toList();
    notifyListeners();
  }

  void clearCart() {
    cart = [];
    selectedTable = '';
    notifyListeners();
  }

  double getCartTotal() {
    return cart.fold(
      0.0,
      (total, item) => total + (item.price * item.quantity),
    );
  }

  int get cartItemCount => cart.fold(0, (total, item) => total + item.quantity);

  void setSelectedTable(String table) {
    selectedTable = table;
    notifyListeners();
  }
}
