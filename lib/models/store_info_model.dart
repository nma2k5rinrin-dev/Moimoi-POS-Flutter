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
    );
  }

  /// Số ngày còn lại trước khi hết hạn Premium (null nếu chưa có ngày hết hạn)
  int? get daysUntilExpiry {
    if (premiumExpiresAt == null) return null;
    return premiumExpiresAt!.difference(DateTime.now()).inDays;
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

  /// Số ngày đã hoạt động kể từ khi tạo
  int get activeDays {
    if (createdAt == null) return 0;
    return DateTime.now().difference(createdAt!).inDays;
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
    );
  }
}
