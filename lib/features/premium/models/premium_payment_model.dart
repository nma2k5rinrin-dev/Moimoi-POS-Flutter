class PremiumPaymentModel {
  final String id;
  final String username;
  final String planName;
  final int months;
  final int amount;
  final DateTime paidAt;

  const PremiumPaymentModel({
    required this.id,
    required this.username,
    required this.planName,
    required this.months,
    required this.amount,
    required this.paidAt,
  });

  factory PremiumPaymentModel.fromMap(Map<String, dynamic> map) {
    return PremiumPaymentModel(
      id: map['id']?.toString() ?? '',
      username: map['username'] ?? '',
      planName: map['plan_name'] ?? '',
      months: map['months'] ?? 0,
      amount: map['amount'] ?? 0,
      paidAt: DateTime.tryParse(map['paid_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'plan_name': planName,
      'months': months,
      'amount': amount,
      'paid_at': paidAt.toIso8601String(),
    };
  }
}
