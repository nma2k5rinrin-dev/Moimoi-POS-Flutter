class CategoryModel {
  final String id;
  final String name;
  final String storeId;

  const CategoryModel({
    required this.id,
    required this.name,
    this.storeId = '',
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      storeId: map['store_id'] ?? '',
    );
  }

  CategoryModel copyWith({String? id, String? name, String? storeId}) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      storeId: storeId ?? this.storeId,
    );
  }
}
