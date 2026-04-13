import 'package:flutter/widgets.dart';

class CategoryModel {
  final String id;
  final String name;
  final String storeId;
  final String emoji;
  final String color;
  final String description;
  final String? deletedAt;

  const CategoryModel({
    required this.id,
    required this.name,
    this.storeId = '',
    this.emoji = '',
    this.color = '',
    this.description = '',
    this.deletedAt,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      storeId: map['store_id'] ?? '',
      emoji: map['emoji'] ?? '',
      color: map['color'] ?? '',
      description: map['description'] ?? '',
      deletedAt: map['deleted_at']?.toString(),
    );
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    String? storeId,
    String? emoji,
    String? color,
    String? description,
    ValueGetter<String?>? deletedAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      storeId: storeId ?? this.storeId,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      description: description ?? this.description,
      deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
    );
  }
}
