import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:moimoi_pos/core/state/ui_store.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/features/settings/models/app_role_model.dart';


class RolesSection extends StatefulWidget {
  const RolesSection({super.key});

  @override
  State<RolesSection> createState() => _RolesSectionState();
}

class _RolesSectionState extends State<RolesSection> {
  bool _isLoading = false;

  void _showRoleForm({AppRoleModel? existing}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _RoleFormDialog(existingRole: existing),
    );
  }

  void _deleteRole(AppRoleModel role) async {
    final store = context.read<ManagementStore>();
    // Pre-check if any user is currently assigned this role
    try {
      final isAssigned = store.users.any((u) => u.role == role.id);
      if (isAssigned) {
        store.showToast('Không thể xóa chức vụ đang có nhân viên sử dụng.', 'error');
        return;
      }

      setState(() => _isLoading = true);
      await Supabase.instance.client
          .from('app_roles')
          .delete()
          .eq('id', role.id);

      store.appRoles.removeWhere((r) => r.id == role.id);
      store.showToast('Xóa chức vụ thành công!');
    } catch (e) {
      store.showToast('Lỗi khi xóa: $e', 'error');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _confirmDelete(AppRoleModel role) {
    final store = context.read<ManagementStore>();
    context.read<UIStore>().showConfirm(
      'Xóa chức vụ "${role.roleName}"?',
      () => _deleteRole(role),
      title: 'Xóa chức vụ?',
      description: 'Hành động này không thể hoàn tác.',
      icon: Icons.delete_forever_rounded,
      confirmLabel: 'Xóa ngay',
    );
  }

  Future<void> _migrateLegacyRoles() async {
    final store = context.read<ManagementStore>();
    final storeId = store.getStoreId();
    setState(() => _isLoading = true);

    final legacyRoles = [
      {'role_name': 'Quản lý', 'permissions': {'tab_dashboard': true, 'tab_pos': true, 'tab_orders': true, 'tab_inventory': true, 'tab_cashflow': true, 'settings_general': true, 'settings_users': true, 'settings_catalog': true, 'settings_tables': true, 'settings_qr': true}},
      {'role_name': 'Thu ngân', 'permissions': {'tab_dashboard': false, 'tab_pos': true, 'tab_orders': true, 'tab_inventory': false, 'tab_cashflow': true, 'settings_general': false, 'settings_users': false, 'settings_catalog': false, 'settings_tables': false, 'settings_qr': false}},
      {'role_name': 'Nhân viên', 'permissions': {'tab_dashboard': false, 'tab_pos': true, 'tab_orders': true, 'tab_inventory': false, 'tab_cashflow': false, 'settings_general': false, 'settings_users': false, 'settings_catalog': false, 'settings_tables': false, 'settings_qr': false}},
      {'role_name': 'KDS', 'permissions': {'tab_dashboard': false, 'tab_pos': false, 'tab_orders': true, 'tab_inventory': false, 'tab_cashflow': false, 'settings_general': false, 'settings_users': false, 'settings_catalog': false, 'settings_tables': false, 'settings_qr': false}},
    ];

    try {
      final oldRolesMap = {
         'Quản lý': 'manager',
         'Thu ngân': 'cashier',
         'Nhân viên': 'staff',
         'KDS': 'kitchen',
      };
      
      for (var r in legacyRoles) {
        final newId = const Uuid().v4();
        final data = {
          'id': newId, 
          'store_id': storeId,
          'role_name': r['role_name'],
          'permissions': r['permissions'],
        };
        await Supabase.instance.client.from('app_roles').insert(data);
        store.appRoles.add(AppRoleModel.fromMap(data));
        
        final oldRoleKey = oldRolesMap[r['role_name']];
        if (oldRoleKey != null) {
           final usersToUpdate = store.users.where((u) => u.role == oldRoleKey).toList();
           for (var u in usersToUpdate) {
             await Supabase.instance.client.from('users').update({'role': newId}).eq('username', u.username);
             final idx = store.users.indexWhere((user) => user.username == u.username);
             if (idx != -1) {
               store.users[idx] = store.users[idx].copyWith(role: newId);
             }
           }
        }
      }
      
      store.showToast('Gộp dữ liệu cũ thành công!');
    } catch (e) {
      store.showToast('Lỗi: $e', 'error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ManagementStore>();
    final roles = store.appRoles;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.slate200)),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Phân Quyền Chức Vụ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slate800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tạo các chức danh (ví dụ: Kế toán, Thu ngân) và phân quyền chi tiết cho nhân viên.',
                    style: TextStyle(fontSize: 13, color: AppColors.slate500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (roles.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Bạn chưa tạo chức vụ tùy chỉnh nào.',
                        style: TextStyle(color: AppColors.slate400),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _migrateLegacyRoles,
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('Điền sẵn vai trò mặc định (cũ)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blue500,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: roles.length,
                  itemBuilder: (ctx, i) {
                    final role = roles[i];
                    final activePerms = role.permissions.values.where((v) => v == true).length;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Slidable(
                        key: ValueKey(role.id),
                        endActionPane: ActionPane(
                          motion: const DrawerMotion(),
                          extentRatio: 0.45,
                          children: [
                            SlidableAction(
                              onPressed: (_) => _showRoleForm(existing: role),
                              backgroundColor: AppColors.blue500,
                              foregroundColor: Colors.white,
                              icon: Icons.edit_rounded,
                              label: 'Sửa',
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                              ),
                            ),
                            SlidableAction(
                              onPressed: (_) => _confirmDelete(role),
                              backgroundColor: AppColors.red500,
                              foregroundColor: Colors.white,
                              icon: Icons.delete_outline_rounded,
                              label: 'Xóa',
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                            ),
                          ],
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.slate200),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.emerald50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.admin_panel_settings, color: AppColors.emerald600),
                            ),
                            title: Text(
                              role.roleName,
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            subtitle: Text('$activePerms quyền được cấp', style: TextStyle(fontSize: 13, color: AppColors.slate500)),
                            trailing: Icon(Icons.chevron_left_rounded, color: AppColors.slate400),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            _buildAddRoleBtn(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAddRoleBtn() {
    return GestureDetector(
      onTap: _isLoading ? null : () => _showRoleForm(),
      child: Container(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.emerald500, AppColors.emerald600],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.emerald500.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.add_moderator, size: 20, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Thêm Chức Vụ',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleFormDialog extends StatefulWidget {
  final AppRoleModel? existingRole;
  const _RoleFormDialog({this.existingRole});

  @override
  State<_RoleFormDialog> createState() => _RoleFormDialogState();
}

class _RoleFormDialogState extends State<_RoleFormDialog> {
  final _nameCtrl = TextEditingController();
  bool _isLoading = false;
  
  final Map<String, bool> _permissions = {
    'tab_dashboard': false,
    'tab_pos': false,
    'tab_orders': false,
    'tab_inventory': false,
    'tab_cashflow': false,
    'settings_general': false,
    'settings_users': false,
    'settings_catalog': false,
    'settings_tables': false,
    'settings_qr': false,
  };

  static const Map<String, String> _permLabels = {
    'tab_dashboard': 'Báo Cáo Doanh Thu (Dashboard)',
    'tab_pos': 'Màn hình Bán hàng (POS)',
    'tab_orders': 'Quản lý Đơn hàng',
    'tab_inventory': 'Quản lý Kho (tổng quan)',
    'tab_cashflow': 'Sổ quỹ (Thu/Chi)',
    'settings_general': 'Cài đặt Cửa hàng & Máy in',
    'settings_users': 'Quản lý Nhân sự',
    'settings_catalog': 'Quản lý Danh mục & Sản phẩm',
    'settings_tables': 'Cài đặt Bàn & Khu vực',
    'settings_qr': 'Cài đặt Menu QR',
  };

  @override
  void initState() {
    super.initState();
    if (widget.existingRole != null) {
      _nameCtrl.text = widget.existingRole!.roleName;
      widget.existingRole!.permissions.forEach((key, value) {
        if (_permissions.containsKey(key)) {
          _permissions[key] = value == true;
        }
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      context.read<ManagementStore>().showToast('Vui lòng nhập tên chức vụ', 'error');
      return;
    }

    setState(() => _isLoading = true);
    final store = context.read<ManagementStore>();
    final storeId = store.getStoreId();

    try {
      if (widget.existingRole == null) {
        // Insert
        final newId = const Uuid().v4();
        final data = {
          'id': newId,
          'store_id': storeId,
          'role_name': name,
          'permissions': _permissions,
        };
        await Supabase.instance.client.from('app_roles').insert(data);
        
        store.appRoles.add(AppRoleModel.fromMap(data));
        store.showToast('Thêm chức vụ thành công');
      } else {
        // Update
        await Supabase.instance.client
            .from('app_roles')
            .update({
              'role_name': name,
              'permissions': _permissions,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', widget.existingRole!.id);
            
        final idx = store.appRoles.indexWhere((r) => r.id == widget.existingRole!.id);
        if (idx != -1) {
          store.appRoles[idx] = store.appRoles[idx].copyWith(
            roleName: name,
            permissions: Map.from(_permissions),
          );
        }
        store.showToast('Cập nhật chức vụ thành công');
      }
      
      if (mounted) {
        
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) store.showToast('Có lỗi xảy ra: $e', 'error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSwitch(String key) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: Text(
          _permLabels[key]!,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        value: _permissions[key]!,
        activeColor: AppColors.emerald500,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        onChanged: (val) {
          setState(() {
            _permissions[key] = val;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: 500,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.slate50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.existingRole == null ? Icons.add_circle : Icons.edit,
                    color: AppColors.emerald600,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tùy Chỉnh Chức Vụ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.slate800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    icon: Icon(Icons.close),
                    color: AppColors.slate400,
                  ),
                ],
              ),
            ),
            
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tên chức vụ',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.slate600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'VD: Kế toán, Quản lý kho, Lễ tân...',
                        filled: true,
                        fillColor: AppColors.slate50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Text(
                      'Quyền truy cập Màn hình Chính',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.slate600),
                    ),
                    const SizedBox(height: 12),
                    _buildSwitch('tab_dashboard'),
                    _buildSwitch('tab_pos'),
                    _buildSwitch('tab_orders'),
                    _buildSwitch('tab_inventory'),
                    _buildSwitch('tab_cashflow'),
                    
                    const SizedBox(height: 16),
                    Text(
                      'Quyền truy cập Cài đặt Hậu đài',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.slate600),
                    ),
                    const SizedBox(height: 12),
                    _buildSwitch('settings_general'),
                    _buildSwitch('settings_users'),
                    _buildSwitch('settings_catalog'),
                    _buildSwitch('settings_tables'),
                    _buildSwitch('settings_qr'),
                  ],
                ),
              ),
            ),
            
            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.slate200)),
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  backgroundColor: AppColors.emerald500,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Lưu Chức Vụ',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


