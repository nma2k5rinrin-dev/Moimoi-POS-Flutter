class UpgradeRequestModel {
  final String id;
  final String username;
  final int planIndex;
  final String planName;
  final int months;
  final String time;
  final String status; // pending, paid, approved, rejected
  final String transferContent; // unique transfer message e.g. MOIMOI_john_1
  final int amount; // total price in VND

  const UpgradeRequestModel({
    required this.id,
    required this.username,
    required this.planIndex,
    required this.planName,
    required this.months,
    required this.time,
    this.status = 'pending',
    this.transferContent = '',
    this.amount = 0,
  });

  factory UpgradeRequestModel.fromMap(Map<String, dynamic> map) {
    return UpgradeRequestModel(
      id: map['id']?.toString() ?? '',
      username: map['username'] ?? '',
      planIndex: map['plan_index'] ?? 0,
      planName: map['plan_name'] ?? '',
      months: map['months'] ?? 0,
      time: map['time'] ?? '',
      status: map['status'] ?? 'pending',
      transferContent: map['transfer_content'] ?? '',
      amount: map['amount'] ?? 0,
    );
  }

  UpgradeRequestModel copyWith({String? status}) {
    return UpgradeRequestModel(
      id: id,
      username: username,
      planIndex: planIndex,
      planName: planName,
      months: months,
      time: time,
      status: status ?? this.status,
      transferContent: transferContent,
      amount: amount,
    );
  }
}
