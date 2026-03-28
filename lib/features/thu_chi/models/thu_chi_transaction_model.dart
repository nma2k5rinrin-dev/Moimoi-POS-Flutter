class ThuChiTransaction {
  final String id;
  final String storeId;
  final String type; // 'thu' or 'chi'
  final double amount;
  final String category;
  final String note;
  final String time;
  final String createdBy;

  const ThuChiTransaction({
    required this.id,
    required this.storeId,
    required this.type,
    required this.amount,
    this.category = '',
    this.note = '',
    this.time = '',
    this.createdBy = '',
  });

  factory ThuChiTransaction.fromMap(Map<String, dynamic> map) {
    return ThuChiTransaction(
      id: map['id']?.toString() ?? '',
      storeId: map['store_id'] ?? '',
      type: map['type'] ?? 'thu',
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? '',
      note: map['note'] ?? '',
      time: map['time'] ?? '',
      createdBy: map['created_by'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'store_id': storeId,
      'type': type,
      'amount': amount,
      'category': category,
      'note': note,
      'time': time,
      'created_by': createdBy,
    };
  }

  ThuChiTransaction copyWith({
    String? id,
    String? storeId,
    String? type,
    double? amount,
    String? category,
    String? note,
    String? time,
    String? createdBy,
  }) {
    return ThuChiTransaction(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      note: note ?? this.note,
      time: time ?? this.time,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
