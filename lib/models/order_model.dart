class OrderItemModel {
  final String id;
  final String name;
  final double price;
  final int quantity;
  final String note;
  final String? image;
  final bool isDone;

  const OrderItemModel({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.note = '',
    this.image,
    this.isDone = false,
  });

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 1,
      note: map['note'] ?? '',
      image: map['image'],
      isDone: map['isDone'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
      'note': note,
      'image': image,
      'isDone': isDone,
    };
  }

  OrderItemModel copyWith({
    String? id,
    String? name,
    double? price,
    int? quantity,
    String? note,
    String? image,
    bool? isDone,
  }) {
    return OrderItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
      image: image ?? this.image,
      isDone: isDone ?? this.isDone,
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
  });

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id: map['id']?.toString() ?? '',
      table: map['table_name'] ?? '',
      items: (map['items'] as List<dynamic>?)
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
    );
  }

  /// Always recalculate total from items to avoid stale values.
  double get calculatedTotal =>
      items.fold(0.0, (sum, i) => sum + (i.price * i.quantity));
}
