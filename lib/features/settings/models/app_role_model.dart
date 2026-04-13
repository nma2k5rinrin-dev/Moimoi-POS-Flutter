class AppRoleModel {
  final String id;
  final String storeId;
  final String roleName;
  final Map<String, dynamic> permissions;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AppRoleModel({
    required this.id,
    required this.storeId,
    required this.roleName,
    required this.permissions,
    this.createdAt,
    this.updatedAt,
  });

  factory AppRoleModel.fromMap(Map<String, dynamic> map) {
    return AppRoleModel(
      id: map['id'] ?? '',
      storeId: map['store_id'] ?? '',
      roleName: map['role_name'] ?? '',
      permissions: map['permissions'] is Map ? Map<String, dynamic>.from(map['permissions']) : {},
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'store_id': storeId,
      'role_name': roleName,
      'permissions': permissions,
    };
  }

  AppRoleModel copyWith({
    String? id,
    String? storeId,
    String? roleName,
    Map<String, dynamic>? permissions,
  }) {
    return AppRoleModel(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      roleName: roleName ?? this.roleName,
      permissions: permissions ?? this.permissions,
    );
  }

  bool hasPermission(String key) {
    if (permissions.containsKey(key)) {
      return permissions[key] == true;
    }
    return false;
  }
}
