class UserModel {
  final String username;
  final String pass;
  final String role;
  final String fullname;
  final String phone;
  final String avatar;
  final bool isPremium;
  final String? expiresAt;
  final String? createdBy;
  final String createdAt;
  final bool showVipExpired;
  final bool showVipCongrat;
  final DateTime? lastLoginAt;

  const UserModel({
    required this.username,
    required this.pass,
    required this.role,
    this.fullname = '',
    this.phone = '',
    this.avatar = '',
    this.isPremium = false,
    this.expiresAt,
    this.createdBy,
    this.createdAt = '',
    this.showVipExpired = false,
    this.showVipCongrat = false,
    this.lastLoginAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      username: map['username'] ?? '',
      pass: map['pass'] ?? '',
      role: map['role'] ?? 'staff',
      fullname: map['fullname'] ?? '',
      phone: map['phone'] ?? '',
      avatar: map['avatar'] ?? '',
      isPremium: map['is_premium'] ?? false,
      expiresAt: map['expires_at'],
      createdBy: map['created_by'],
      createdAt: map['created_at'] ?? '',
      showVipExpired: map['show_vip_expired'] ?? false,
      showVipCongrat: map['show_vip_congrat'] ?? false,
      lastLoginAt: map['last_login_at'] != null
          ? DateTime.tryParse(map['last_login_at'])
          : null,
    );
  }

  UserModel copyWith({
    String? username,
    String? pass,
    String? role,
    String? fullname,
    String? phone,
    String? avatar,
    bool? isPremium,
    String? expiresAt,
    String? createdBy,
    String? createdAt,
    bool? showVipExpired,
    bool? showVipCongrat,
    DateTime? lastLoginAt,
  }) {
    return UserModel(
      username: username ?? this.username,
      pass: pass ?? this.pass,
      role: role ?? this.role,
      fullname: fullname ?? this.fullname,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      isPremium: isPremium ?? this.isPremium,
      expiresAt: expiresAt ?? this.expiresAt,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      showVipExpired: showVipExpired ?? this.showVipExpired,
      showVipCongrat: showVipCongrat ?? this.showVipCongrat,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
