class UpgradeRequestModel {
  final String id;
  final String username;
  final int planIndex;
  final String planName;
  final int months;
  final String time;

  const UpgradeRequestModel({
    required this.id,
    required this.username,
    required this.planIndex,
    required this.planName,
    required this.months,
    required this.time,
  });

  factory UpgradeRequestModel.fromMap(Map<String, dynamic> map) {
    return UpgradeRequestModel(
      id: map['id']?.toString() ?? '',
      username: map['username'] ?? '',
      planIndex: map['plan_index'] ?? 0,
      planName: map['plan_name'] ?? '',
      months: map['months'] ?? 0,
      time: map['time'] ?? '',
    );
  }
}
