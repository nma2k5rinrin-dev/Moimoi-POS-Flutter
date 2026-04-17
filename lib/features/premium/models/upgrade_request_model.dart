class UpgradeRequestModel {
  final String id;
  final String storeId;
  final String planName;
  final int amount;
  final String status;
  final String createdAt;

  const UpgradeRequestModel({
    required this.id,
    required this.storeId,
    required this.planName,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  factory UpgradeRequestModel.fromMap(Map<String, dynamic> map) {
    return UpgradeRequestModel(
      id: map['id']?.toString() ?? '',
      storeId: map['username'] ?? '',
      planName: map['plan_name'] ?? '',
      amount: map['amount'] ?? 0,
      status: map['status'] ?? 'pending',
      createdAt: map['created_at'] ?? '',
    );
  }
}
