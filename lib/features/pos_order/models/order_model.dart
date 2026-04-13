import 'package:flutter/widgets.dart';

class OrderItemModel {
  final String id;
  final String name;
  final double price;
  final int quantity;
  final String note;
  final String? image;
  final int doneQuantity;
  final bool isNewlyAdded;

  const OrderItemModel({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.note = '',
    this.image,
    this.doneQuantity = 0,
    this.isNewlyAdded = false,
  });

  bool get isDone => doneQuantity >= quantity;

  String getResolvedImage(dynamic store) {
    if (image != null && image!.isNotEmpty) return image!;
    // Fallback to searching the store's current products if we have a UI dependency inject
    try {
      final prods = store.currentProducts as List<dynamic>;
      final match = prods.where((p) => p.id == id).firstOrNull;
      if (match != null && match.image.isNotEmpty) {
        return match.image;
      }
    } catch (_) {}
    return '';
  }

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    final qty = map['quantity'] ?? 1;
    final legacyIsDone = map['isDone'] ?? false;
    int parsedDoneQty = 0;
    if (map.containsKey('doneQuantity')) {
      parsedDoneQty = map['doneQuantity'] ?? 0;
    } else if (legacyIsDone) {
      parsedDoneQty = qty;
    }

    return OrderItemModel(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      quantity: qty,
      note: map['note'] ?? '',
      image: map['image'],
      doneQuantity: parsedDoneQty,
      isNewlyAdded: map['isNewlyAdded'] == true || map['isNewlyAdded'] == 'true',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
      'note': note,
      // 'image': image, // DO NOT save image base64 here to prevent huge ingress/egress costs!
      'doneQuantity': doneQuantity,
      'isDone': doneQuantity >= quantity,
      'isNewlyAdded': isNewlyAdded,
    };
  }

  OrderItemModel copyWith({
    String? id,
    String? name,
    double? price,
    int? quantity,
    String? note,
    String? image,
    int? doneQuantity,
    bool? isDone,
    bool? isNewlyAdded,
  }) {
    int newDoneQty = this.doneQuantity;
    if (doneQuantity != null) {
      newDoneQty = doneQuantity;
    } else if (isDone != null) {
      newDoneQty = isDone ? (quantity ?? this.quantity) : 0;
    }

    return OrderItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
      image: image ?? this.image,
      doneQuantity: newDoneQty,
      isNewlyAdded: isNewlyAdded ?? this.isNewlyAdded,
    );
  }
}

class OrderModel {
  final String id;
  final String table;
  final List<OrderItemModel> items;
  final String status;
  final String paymentStatus;
  final double totalAmount;
  final String createdBy;
  final String time;
  final String storeId;
  final String paymentMethod; // 'cash', 'transfer', or '' (unknown)
  final String? deletedAt;

  const OrderModel({
    required this.id,
    this.table = '',
    this.items = const [],
    this.status = 'pending',
    this.paymentStatus = 'unpaid',
    this.totalAmount = 0,
    this.createdBy = '',
    this.time = '',
    this.storeId = '',
    this.paymentMethod = '',
    this.deletedAt,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id: map['id']?.toString() ?? '',
      table: map['table_name'] ?? '',
      items:
          (map['items'] as List<dynamic>?)
              ?.map((e) => OrderItemModel.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      status: map['status'] ?? 'pending',
      paymentStatus: map['payment_status'] ?? 'unpaid',
      totalAmount: (map['total_amount'] ?? 0).toDouble(),
      createdBy: map['created_by'] ?? '',
      time: map['time'] ?? '',
      storeId: map['store_id'] ?? '',
      paymentMethod: map['payment_method'] ?? '',
      deletedAt: map['deleted_at']?.toString(),
    );
  }

  OrderModel copyWith({
    String? id,
    String? table,
    List<OrderItemModel>? items,
    String? status,
    String? paymentStatus,
    double? totalAmount,
    String? createdBy,
    String? time,
    String? storeId,
    String? paymentMethod,
    ValueGetter<String?>? deletedAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      table: table ?? this.table,
      items: items ?? this.items,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      totalAmount: totalAmount ?? this.totalAmount,
      createdBy: createdBy ?? this.createdBy,
      time: time ?? this.time,
      storeId: storeId ?? this.storeId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
    );
  }

  /// Always recalculate total from items to avoid stale values.
  double get calculatedTotal =>
      items.fold(0.0, (sum, i) => sum + (i.price * i.quantity));
}
