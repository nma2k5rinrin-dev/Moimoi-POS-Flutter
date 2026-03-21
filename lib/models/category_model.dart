class CategoryModel {
  final String id;
  final String name;
  final String storeId;
  final String emoji;
  final String color;

  const CategoryModel({
    required this.id,
    required this.name,
    this.storeId = '',
    this.emoji = '',
    this.color = '',
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      storeId: map['store_id'] ?? '',
      emoji: map['emoji'] ?? '',
      color: map['color'] ?? '',
    );
  }

  CategoryModel copyWith({String? id, String? name, String? storeId, String? emoji, String? color}) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      storeId: storeId ?? this.storeId,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
    );
  }
}
