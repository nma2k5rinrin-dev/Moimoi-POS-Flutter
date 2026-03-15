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
  final bool isPremium;

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
    this.isPremium = false,
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
      isPremium: map['is_premium'] ?? false,
    );
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
    bool? isPremium,
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
      isPremium: isPremium ?? this.isPremium,
    );
  }
}
