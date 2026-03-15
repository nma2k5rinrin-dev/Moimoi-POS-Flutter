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
  final String? pin;
  final bool showVipExpired;
  final bool showVipCongrat;

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
    this.pin,
    this.showVipExpired = false,
    this.showVipCongrat = false,
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
      pin: map['pin'],
      showVipExpired: map['show_vip_expired'] ?? false,
      showVipCongrat: map['show_vip_congrat'] ?? false,
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
    String? pin,
    bool? showVipExpired,
    bool? showVipCongrat,
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
      pin: pin ?? this.pin,
      showVipExpired: showVipExpired ?? this.showVipExpired,
      showVipCongrat: showVipCongrat ?? this.showVipCongrat,
    );
  }
}
