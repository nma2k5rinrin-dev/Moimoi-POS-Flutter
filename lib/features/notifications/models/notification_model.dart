class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final String time;
  final bool read;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    this.type = '',
    required this.time,
    this.read = false,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: map['type'] ?? '',
      time: map['time'] ?? '',
      read: map['read'] ?? false,
    );
  }

  NotificationModel copyWith({bool? read}) {
    return NotificationModel(
      id: id,
      userId: userId,
      title: title,
      message: message,
      type: type,
      time: time,
      read: read ?? this.read,
    );
  }
}
