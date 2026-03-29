class StoreInfoModel {
  final String name;
  final String phone;
  final String address;
  final String logoUrl;
  final String taxId;
  final String openHours;
  final String bankId;
  final String bankAccount;
  final String bankOwner;
  final String qrImageUrl;
  final bool isPremium;

  // ── Sadmin Management Fields ──
  final bool isOnline;
  final DateTime? premiumActivatedAt;
  final DateTime? premiumExpiresAt;
  final int totalOfflineDays;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  const StoreInfoModel({
    this.name = '',
    this.phone = '',
    this.address = '',
    this.logoUrl = '',
    this.taxId = '',
    this.openHours = '',
    this.bankId = '',
    this.bankAccount = '',
    this.bankOwner = '',
    this.qrImageUrl = '',
    this.isPremium = false,
    this.isOnline = true,
    this.premiumActivatedAt,
    this.premiumExpiresAt,
     this.totalOfflineDays = 0,
    this.createdAt,
    this.lastLoginAt,
  });

  factory StoreInfoModel.fromMap(Map<String, dynamic> map) {
    return StoreInfoModel(
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      logoUrl: map['logo_url'] ?? '',
      taxId: map['tax_id'] ?? '',
      openHours: map['open_hours'] ?? '',
      bankId: map['bank_id'] ?? '',
      bankAccount: map['bank_account'] ?? '',
      bankOwner: map['bank_owner'] ?? '',
      qrImageUrl: map['qr_image_url'] ?? '',
      isPremium: map['is_premium'] ?? false,
      isOnline: map['is_online'] ?? true,
      premiumActivatedAt: map['premium_activated_at'] != null
          ? DateTime.tryParse(map['premium_activated_at'])
          : null,
      premiumExpiresAt: map['premium_expires_at'] != null
          ? DateTime.tryParse(map['premium_expires_at'])
          : null,
      totalOfflineDays: map['total_offline_days'] ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'])
          : null,
      lastLoginAt: map['last_login_at'] != null
          ? DateTime.tryParse(map['last_login_at'])
          : null,
    );
  }

  /// Số ngày còn lại trước khi hết hạn Premium (tính theo ngày lịch hệ thống UTC)
  int? get daysUntilExpiry {
    if (premiumExpiresAt == null) return null;
    final utcNow = DateTime.now().toUtc();
    final utcExpires = premiumExpiresAt!.toUtc();
    final today = DateTime.utc(utcNow.year, utcNow.month, utcNow.day);
    final expiry = DateTime.utc(utcExpires.year, utcExpires.month, utcExpires.day);
    return expiry.difference(today).inDays;
  }

  /// Kiểm tra cửa hàng sắp hết hạn (≤ 7 ngày)
  bool get isExpiringSoon {
    final days = daysUntilExpiry;
    return days != null && days <= 7 && days >= 0;
  }

  /// Kiểm tra cửa hàng đã hết hạn
  bool get isExpired {
    final days = daysUntilExpiry;
    return days != null && days < 0;
  }

  /// Số ngày đã hoạt động kể từ khi tạo (tính theo ngày lịch hệ thống UTC, bắt đầu từ 1)
  int get activeDays {
    if (createdAt == null) return 0;
    final utcNow = DateTime.now().toUtc();
    final utcCreated = createdAt!.toUtc();
    final start = DateTime.utc(utcCreated.year, utcCreated.month, utcCreated.day);
    final today = DateTime.utc(utcNow.year, utcNow.month, utcNow.day);
    return today.difference(start).inDays + 1;
  }

  /// Số ngày offline kể từ lần đăng nhập cuối (tính theo ngày lịch hệ thống UTC)
  /// Nếu chưa bao giờ đăng nhập, tính từ ngày tạo tài khoản
  int get consecutiveOfflineDays {
    final referenceDate = lastLoginAt ?? createdAt;
    if (referenceDate == null) return 0;
    final utcNow = DateTime.now().toUtc();
    final utcRef = referenceDate.toUtc();
    final ref = DateTime.utc(utcRef.year, utcRef.month, utcRef.day);
    final today = DateTime.utc(utcNow.year, utcNow.month, utcNow.day);
    final diff = today.difference(ref).inDays;
    return diff > 0 ? diff : 0;
  }

  StoreInfoModel copyWith({
    String? name,
    String? phone,
    String? address,
    String? logoUrl,
    String? taxId,
    String? openHours,
    String? bankId,
    String? bankAccount,
    String? bankOwner,
    String? qrImageUrl,
    bool? isPremium,
    bool? isOnline,
    DateTime? premiumActivatedAt,
    DateTime? premiumExpiresAt,
    int? totalOfflineDays,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return StoreInfoModel(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      logoUrl: logoUrl ?? this.logoUrl,
      taxId: taxId ?? this.taxId,
      openHours: openHours ?? this.openHours,
      bankId: bankId ?? this.bankId,
      bankAccount: bankAccount ?? this.bankAccount,
      bankOwner: bankOwner ?? this.bankOwner,
      qrImageUrl: qrImageUrl ?? this.qrImageUrl,
      isPremium: isPremium ?? this.isPremium,
      isOnline: isOnline ?? this.isOnline,
      premiumActivatedAt: premiumActivatedAt ?? this.premiumActivatedAt,
      premiumExpiresAt: premiumExpiresAt ?? this.premiumExpiresAt,
      totalOfflineDays: totalOfflineDays ?? this.totalOfflineDays,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
