class ProductModel {
  final String id;
  final String storeId;
  final String name;
  final double price;
  final String image;
  final String category;
  final String description;
  final bool isOutOfStock;
  final bool isHot;
  final int quantity;
  final double costPrice;

  const ProductModel({
    required this.id,
    this.storeId = '',
    required this.name,
    required this.price,
    this.image = '',
    this.category = '',
    this.description = '',
    this.isOutOfStock = false,
    this.isHot = false,
    this.quantity = 0,
    this.costPrice = 0,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id']?.toString() ?? '',
      storeId: map['store_id'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      image: map['image'] ?? '',
      category: map['category'] ?? '',
      description: map['description'] ?? '',
      isOutOfStock: map['is_out_of_stock'] ?? false,
      isHot: map['is_hot'] ?? false,
      quantity: map['quantity'] ?? 0,
      costPrice: (map['cost_price'] ?? 0).toDouble(),
    );
  }

  ProductModel copyWith({
    String? id,
    String? storeId,
    String? name,
    double? price,
    String? image,
    String? category,
    String? description,
    bool? isOutOfStock,
    bool? isHot,
    int? quantity,
    double? costPrice,
  }) {
    return ProductModel(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      price: price ?? this.price,
      image: image ?? this.image,
      category: category ?? this.category,
      description: description ?? this.description,
      isOutOfStock: isOutOfStock ?? this.isOutOfStock,
      isHot: isHot ?? this.isHot,
      quantity: quantity ?? this.quantity,
      costPrice: costPrice ?? this.costPrice,
    );
  }
}
