import 'package:flutter/material.dart';
import 'package:moimoi_pos/core/utils/constants.dart';

class TransactionCategory {
  final String? id;
  final String? storeId;
  final String type; // 'thu' or 'chi'
  final String emoji;
  final String label;
  final Color color;
  final bool isCustom;
  final int sortOrder;

  const TransactionCategory({
    this.id,
    this.storeId,
    required this.type,
    required this.emoji,
    required this.label,
    required this.color,
    this.isCustom = true,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (storeId != null) 'store_id': storeId,
      'type': type,
      'emoji': emoji,
      'label': label,
      'color': color.value,
      'is_custom': isCustom,
      'sort_order': sortOrder,
    };
  }

  factory TransactionCategory.fromMap(Map<String, dynamic> map) {
    return TransactionCategory(
      id: map['id'],
      storeId: map['store_id'],
      type: map['type'] ?? 'chi',
      emoji: map['emoji'] ?? '',
      label: map['label'] ?? '',
      color: Color(map['color'] ?? AppColors.slate500.value),
      isCustom: map['is_custom'] ?? true,
      sortOrder: map['sort_order'] ?? 0,
    );
  }
}
