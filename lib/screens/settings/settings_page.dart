import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../store/app_store.dart';
import '../../models/user_model.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import 'menu_management.dart';
import 'change_pin_dialog.dart';
import '../../utils/avatar_picker.dart';
import '../../widgets/square_crop_dialog.dart';
import 'package:image_picker/image_picker.dart';

Uint8List _decodeAvatar(String dataUri) {
  final base64Part = dataUri.split(',').last;
  return base64Decode(base64Part);
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _selectedSection;

  final List<_SettingMenu> _menus = [
    _SettingMenu(
      id: 'account',
      name: 'Tài Khoản & Bảo Mật',
      desc: 'Thông tin cá nhân, đổi mật khẩu',
      icon: Icons.person_outline,
    ),
    _SettingMenu(
      id: 'general',
      name: 'Thông Tin Cửa Hàng',
      desc: 'Tên quán, địa chỉ, số điện thoại',
      icon: Icons.storefront_outlined,
    ),
    _SettingMenu(
      id: 'menu',
      name: 'Quản Lý Danh Mục & Thực Đơn',
      desc: 'Thêm/sửa món ăn, danh mục',
      icon: Icons.restaurant_menu,
    ),
    _SettingMenu(
      id: 'tables',
      name: 'Quản Lý Bàn & Khu Vực',
      desc: 'Thiết lập danh sách bàn Order',
      icon: Icons.grid_view_outlined,
    ),
    _SettingMenu(
      id: 'users',
      name: 'Quản Lý Nhân Viên',
      desc: 'Tạo tài khoản, thống kê doanh số',
      icon: Icons.people_outline,
      adminOnly: true,
    ),
    _SettingMenu(
      id: 'printer',
      name: 'Máy In & Hoá Đơn',
      desc: 'Kết nối máy in bill, in bếp',
      icon: Icons.print_outlined,
    ),
    _SettingMenu(
      id: 'backup',
      name: 'Lưu Trữ & Phục Hồi',
      desc: 'Sao lưu dữ liệu đám mây',
      icon: Icons.cloud_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isWide = MediaQuery.of(context).size.width >= 768;
    final isAdmin = ['admin', 'sadmin'].contains(store.currentUser?.role);

    final menus = _menus.where((m) => !m.adminOnly || isAdmin).toList();

    if (isWide) {
      return Row(
        children: [
          SizedBox(
            width: 300,
            child: _SettingsMenuList(
              menus: menus,
              selected: _selectedSection,
              onSelect: (id) => setState(() => _selectedSection = id),
            ),
          ),
          Expanded(
            child: _selectedSection != null
                ? _buildSection(_selectedSection!)
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.settings,
                            size: 64, color: AppColors.slate300),
                        const SizedBox(height: 12),
                        const Text(
                          'Chọn mục cài đặt',
                          style: TextStyle(
                            color: AppColors.slate400,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      );
    }

    if (_selectedSection != null) {
      return _buildSection(_selectedSection!,
          onBack: () => setState(() => _selectedSection = null));
    }

    return _SettingsMenuList(
      menus: menus,
      selected: null,
      onSelect: (id) => setState(() => _selectedSection = id),
    );
  }

  Widget _buildSection(String id, {VoidCallback? onBack}) {
    switch (id) {
      case 'account':
        return _AccountSection(onBack: onBack);
      case 'general':
        return _StoreInfoSection(onBack: onBack);
      case 'menu':
        return MenuManagementSection(onBack: onBack);
      case 'tables':
        return _TablesSection(onBack: onBack);
      case 'users':
        return _UsersSection(onBack: onBack);
      case 'printer':
        return _PrinterSection(onBack: onBack);
      case 'backup':
        return _BackupSection(onBack: onBack);
      default:
        return const Center(child: Text('Coming soon'));
    }
  }
}

class _SettingMenu {
  final String id;
  final String name;
  final String desc;
  final IconData icon;
  final bool adminOnly;
  const _SettingMenu({
    required this.id,
    required this.name,
    required this.desc,
    required this.icon,
    this.adminOnly = false,
  });
}

class _SettingsMenuList extends StatelessWidget {
  final List<_SettingMenu> menus;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _SettingsMenuList({
    required this.menus,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.slate50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Text(
              'Cài Đặt',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.slate800,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: menus.length,
              itemBuilder: (_, i) {
                final menu = menus[i];
                final isActive = selected == menu.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onSelect(menu.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.emerald50
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isActive
                                ? AppColors.emerald200
                                : AppColors.slate200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.emerald100
                                    : AppColors.slate100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                menu.icon,
                                color: isActive
                                    ? AppColors.emerald600
                                    : AppColors.slate500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    menu.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: isActive
                                          ? AppColors.emerald700
                                          : AppColors.slate800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    menu.desc,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.slate500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: AppColors.slate400),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Account Section ─────────────────────────────────
class _AccountSection extends StatefulWidget {
  final VoidCallback? onBack;
  const _AccountSection({this.onBack});

  @override
  State<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<_AccountSection> {
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _phoneController.text = store.currentUser?.phone ?? '';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final user = store.currentUser;
    final hasPIN = user?.pin != null && user!.pin!.isNotEmpty;

    return Container(
      color: AppColors.slate50,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  _SectionCard(
                    title: 'Tài Khoản & Bảo Mật',
                    subtitle: 'Thông tin cá nhân, đổi mật khẩu',
                    icon: Icons.person_outline_rounded,
                    iconColor: AppColors.emerald600,
                    iconBg: AppColors.emerald50,
                    onBack: widget.onBack,
                    child: Column(
                      children: [
                        // Avatar section
                        Column(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 44,
                                  backgroundColor: AppColors.emerald100,
                                  backgroundImage: (user?.avatar ?? '').isNotEmpty
                                      ? MemoryImage(_decodeAvatar(user!.avatar))
                                      : null,
                                  child: (user?.avatar ?? '').isEmpty
                                      ? Text(
                                          (user?.fullname ?? 'U')
                                              .substring(0, 1)
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.emerald600,
                                          ),
                                        )
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () => _showAvatarPicker(context, store, user),
                                    child: Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: AppColors.emerald500,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(Icons.camera_alt,
                                          size: 13, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  user?.fullname ?? 'User',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.slate800,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.edit,
                                    size: 16, color: AppColors.emerald500),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Kích hoạt: 01/01/2026',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.slate400,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.emerald50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified_rounded,
                                      size: 14, color: AppColors.emerald500),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getRoleName(user?.role),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.emerald600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // Username + Phone (2-column)
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Tên đăng nhập',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.slate600)),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: AppColors.slate100,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.alternate_email_rounded,
                                            size: 18,
                                            color: AppColors.slate400),
                                        const SizedBox(width: 8),
                                        Text(
                                          user?.username ?? '',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: AppColors.slate500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Số điện thoại',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.slate600)),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 0),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border:
                                          Border.all(color: AppColors.slate200),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.phone_outlined,
                                            size: 18,
                                            color: AppColors.slate400),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            controller: _phoneController,
                                            style:
                                                const TextStyle(fontSize: 14),
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              hintText: '0912 345 678',
                                              hintStyle: TextStyle(
                                                  color: AppColors.slate300),
                                            ),
                                            keyboardType:
                                                TextInputType.phone,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Email field
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Email',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.slate600)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.slate200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.mail_outline_rounded,
                                      size: 18, color: AppColors.slate400),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${user?.username ?? ''}@moimoi.vn',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.slate700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // "Bảo mật" separator
                        Row(
                          children: [
                            const Expanded(
                                child: Divider(color: AppColors.slate200)),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12),
                              child: Text(
                                'Bảo mật',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.slate400,
                                ),
                              ),
                            ),
                            const Expanded(
                                child: Divider(color: AppColors.slate200)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Security Row: Change Password
                        _SecurityRow(
                          icon: Icons.lock_outline_rounded,
                          label: 'Đổi mật khẩu',
                          trailing: const Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: AppColors.slate400),
                          onTap: () =>
                              _showChangePasswordDialog(context, store),
                        ),
                        const SizedBox(height: 10),

                        // Security Row: Branch
                        _SecurityRow(
                          icon: Icons.business_outlined,
                          label: 'Chi nhánh làm việc',
                          trailing: Text(
                            'Chi nhánh chính',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.emerald500,
                            ),
                          ),
                          onTap: () {},
                        ),
                        const SizedBox(height: 10),

                        // Security Row: FaceID
                        _SecurityRow(
                          icon: Icons.fingerprint_rounded,
                          label: 'Vân tay / FaceID',
                          trailing: Switch(
                            value: false,
                            activeTrackColor: AppColors.emerald500,
                            onChanged: (v) {
                              store.showToast(
                                  'Tính năng đang phát triển', 'error');
                            },
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Security Row: PIN
                        Column(
                          children: [
                            _SecurityRow(
                              icon: Icons.pin_outlined,
                              label: 'Mã PIN 4 số',
                              trailing: Switch(
                                value: hasPIN,
                                activeTrackColor: AppColors.emerald500,
                                onChanged: (enabled) {
                                  if (enabled) {
                                    showChangePinDialog(context,
                                            isFirstTimeSetup: true)
                                        .then((_) => setState(() {}));
                                  } else {
                                    store.updateUser(
                                        user!.username, {'pin': ''});
                                    setState(() {});
                                  }
                                },
                              ),
                            ),
                            if (hasPIN)
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      top: 4, right: 4),
                                  child: InkWell(
                                    onTap: () {
                                      showChangePinDialog(context)
                                          .then((_) => setState(() {}));
                                    },
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 3),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.edit,
                                              size: 13,
                                              color:
                                                  AppColors.emerald500),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Đổi mã PIN',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight:
                                                  FontWeight.w600,
                                              color:
                                                  AppColors.emerald500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Cancel + Save buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  _phoneController.text = user?.phone ?? '';
                                  store.showToast('Đã hủy thay đổi');
                                },
                                icon: const Icon(Icons.close_rounded, size: 18),
                                label: const Text('Hủy bỏ'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.red500,
                                  side: const BorderSide(color: AppColors.red200),
                                  minimumSize: const Size(0, 50),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  textStyle: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  store.updateUser(user!.username, {
                                    'phone': _phoneController.text.trim(),
                                  });
                                  store.showToast('Cập nhật thành công!');
                                },
                                icon: const Icon(Icons.save_rounded, size: 18),
                                label: const Text('Lưu thay đổi'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.emerald500,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 50),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  textStyle: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Logout button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                  title: const Text('Đăng xuất',
                                      style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700)),
                                  content: const Text(
                                      'Bạn có chắc chắn muốn đăng xuất?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx),
                                      child: Text('Hủy',
                                          style: TextStyle(
                                              color:
                                                  AppColors.slate500)),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        store.clearSavedCredentials();
                                        store.logout();
                                      },
                                      child: const Text('Đăng xuất',
                                          style: TextStyle(
                                              color: AppColors.red500,
                                              fontWeight:
                                                  FontWeight.w600)),
                                    ),
                                  ],
                                ),
                              );
                            },
                            icon: Icon(Icons.logout_rounded,
                                size: 20, color: AppColors.red500),
                            label: Text('Đăng xuất',
                                style: TextStyle(color: AppColors.red500)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: AppColors.red200),
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleName(String? role) {
    switch (role) {
      case 'sadmin':
        return 'Quản lý';
      case 'admin':
        return 'Quản lý';
      case 'staff':
        return 'Nhân viên';
      default:
        return 'Nhân viên';
    }
  }

  void _showChangePasswordDialog(
      BuildContext context, AppStore store) {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, a1, a2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 360,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: 0.15),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: StatefulBuilder(
                builder: (ctx2, setState2) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.slate100,
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            child: const Icon(
                                Icons.lock_outline_rounded,
                                size: 18,
                                color: AppColors.slate600),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Đổi mật khẩu',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate800,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () =>
                                Navigator.of(ctx).pop(),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.slate100,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  size: 16,
                                  color: AppColors.slate500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Fields
                      _DialogPasswordField(
                          label: 'Mật khẩu hiện tại',
                          hint: 'Nhập mật khẩu hiện tại',
                          controller: oldPassCtrl),
                      const SizedBox(height: 14),
                      _DialogPasswordField(
                          label: 'Mật khẩu mới',
                          hint: 'Nhập mật khẩu mới',
                          controller: newPassCtrl),
                      const SizedBox(height: 14),
                      _DialogPasswordField(
                          label: 'Nhập lại mật khẩu mới',
                          hint: 'Nhập lại mật khẩu mới',
                          controller: confirmPassCtrl),
                      const SizedBox(height: 24),

                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.of(ctx).pop(),
                              style:
                                  OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                        vertical: 14),
                                shape:
                                    RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                                    12)),
                                side: BorderSide(
                                    color:
                                        AppColors.slate300),
                              ),
                              child: const Text('Huỷ',
                                  style: TextStyle(
                                      fontWeight:
                                          FontWeight.w600,
                                      color: AppColors
                                          .slate600)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (oldPassCtrl.text !=
                                    store.currentUser
                                        ?.pass) {
                                  store.showToast(
                                      'Mật khẩu hiện tại không đúng',
                                      'error');
                                  return;
                                }
                                final passErr =
                                    validatePassword(
                                        newPassCtrl.text);
                                if (passErr != null) {
                                  store.showToast(
                                      passErr, 'error');
                                  return;
                                }
                                if (newPassCtrl.text !=
                                    confirmPassCtrl.text) {
                                  store.showToast(
                                      'Xác nhận mật khẩu không khớp',
                                      'error');
                                  return;
                                }
                                store.updateUser(
                                    store.currentUser!
                                        .username,
                                    {
                                      'pass':
                                          newPassCtrl.text,
                                    });
                                Navigator.of(ctx).pop();
                                store.showToast(
                                    'Đổi mật khẩu thành công!');
                              },
                              icon: const Icon(Icons.check,
                                  size: 16),
                              label:
                                  const Text('Xác nhận'),
                              style:
                                  ElevatedButton.styleFrom(
                                backgroundColor:
                                    AppColors.emerald500,
                                foregroundColor:
                                    Colors.white,
                                padding: const EdgeInsets
                                    .symmetric(
                                    vertical: 14),
                                shape:
                                    RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                                    12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, a1, a2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
              parent: a1, curve: Curves.easeOutCubic),
          child: FadeTransition(opacity: a1, child: child),
        );
      },
    );
  }

  void _showAvatarPicker(BuildContext context, AppStore store, dynamic user) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
          Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Thay \u0111\u1ed5i \u1ea3nh \u0111\u1ea1i di\u1ec7n',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate800)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              Navigator.pop(ctx);
                              final picker = ImagePicker();
                              final picked = await picker.pickImage(
                                source: ImageSource.camera,
                                maxWidth: 800, maxHeight: 800,
                                imageQuality: 85,
                              );
                              if (picked != null && user != null) {
                                final bytes = await picked.readAsBytes();
                                final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                                store.updateUser(user.username, {'avatar': b64});
                                setState(() {});
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              decoration: BoxDecoration(
                                color: AppColors.blue50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.blue200),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.camera_alt_rounded,
                                      color: Color(0xFF3B82F6), size: 40),
                                  SizedBox(height: 8),
                                  Text('M\u00e1y \u1ea3nh',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: Color(0xFF3B82F6))),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              Navigator.pop(ctx);
                              final picker = ImagePicker();
                              final picked = await picker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 800, maxHeight: 800,
                                imageQuality: 85,
                              );
                              if (picked != null && user != null) {
                                final bytes = await picked.readAsBytes();
                                final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                                store.updateUser(user.username, {'avatar': b64});
                                setState(() {});
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              decoration: BoxDecoration(
                                color: AppColors.emerald50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.emerald200),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.photo_library_rounded,
                                      color: AppColors.emerald500, size: 40),
                                  SizedBox(height: 8),
                                  Text('Th\u01b0 vi\u1ec7n',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: AppColors.emerald500)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.slate500,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('H\u1ee7y',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Security Row Widget ────────────────
class _SecurityRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SecurityRow({
    required this.icon,
    required this.label,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.slate400),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate800,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

// ─── Dialog Password Field ──────────────
class _DialogPasswordField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;

  const _DialogPasswordField({
    required this.label,
    required this.hint,
    required this.controller,
  });

  @override
  State<_DialogPasswordField> createState() =>
      _DialogPasswordFieldState();
}

class _DialogPasswordFieldState
    extends State<_DialogPasswordField> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.slate600)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.slate200),
          ),
          child: TextField(
            controller: widget.controller,
            obscureText: !_show,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(
                  color: AppColors.slate300, fontSize: 14),
              prefixIcon: Icon(Icons.lock_outline_rounded,
                  size: 18, color: AppColors.slate400),
              suffixIcon: GestureDetector(
                onTap: () =>
                    setState(() => _show = !_show),
                child: Icon(
                  _show
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  size: 18,
                  color: AppColors.slate400,
                ),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
            ),
          ),
        ),
      ],
    );
}
}


// ─── Store Info Section ─────────────────────────────
class _StoreInfoSection extends StatefulWidget {
  final VoidCallback? onBack;
  const _StoreInfoSection({this.onBack});

  @override
  State<_StoreInfoSection> createState() => _StoreInfoSectionState();
}

class _StoreInfoSectionState extends State<_StoreInfoSection> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _openHoursController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankOwnerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    final info = store.currentStoreInfo;
    _nameController.text = info.name;
    _phoneController.text = info.phone;
    _addressController.text = info.address;
    _taxIdController.text = info.taxId;
    _openHoursController.text = info.openHours;
    _bankNameController.text = info.bankId;
    _bankAccountController.text = info.bankAccount;
    _bankOwnerController.text = info.bankOwner;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _taxIdController.dispose();
    _openHoursController.dispose();
    _bankNameController.dispose();
    _bankAccountController.dispose();
    _bankOwnerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final info = store.currentStoreInfo;

    return Container(
      color: AppColors.slate50,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    _SectionCard(
                      title: 'Thông Tin Cửa Hàng',
                      subtitle: 'Tên quán, địa chỉ, số điện thoại',
                      onBack: widget.onBack,
                      icon: Icons.storefront_outlined,
                      iconColor: AppColors.emerald600,
                      iconBg: AppColors.emerald50,
                      child: Column(
                        children: [
                          // ── Store avatar (rounded square) ────────
                          Center(
                            child: Stack(
                              children: [
                                Container(
                                  width: 88,
                                  height: 88,
                                  decoration: BoxDecoration(
                                    color: AppColors.emerald50,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                        color: AppColors.slate200, width: 1.5),
                                    image: info.logoUrl.isNotEmpty
                                        ? DecorationImage(
                                            image: MemoryImage(
                                                _decodeAvatar(info.logoUrl)),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: info.logoUrl.isEmpty
                                      ? const Icon(Icons.storefront,
                                          size: 36,
                                          color: AppColors.emerald500)
                                      : null,
                                ),
                                Positioned(
                                  bottom: -2,
                                  right: -2,
                                  child: GestureDetector(
                                    onTap: () => _pickStoreLogo(store),
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: AppColors.emerald500,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(Icons.camera_alt,
                                          size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Store name display
                          Text(
                            info.name.isNotEmpty ? info.name : 'Moimoi POS',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Plan badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: info.isPremium
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  info.isPremium
                                      ? Icons.workspace_premium
                                      : Icons.verified_rounded,
                                  size: 13,
                                  color: AppColors.emerald500,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  info.isPremium ? 'Gói Premium' : 'Gói cơ bản',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.emerald600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── Row 1: Name + Phone ─────────────────
                          Row(
                            children: [
                              Expanded(
                                child: _SettingsField(
                                  label: 'Tên cửa hàng',
                                  controller: _nameController,
                                  hint: 'Moimoi POS',
                                  prefixIcon: Icons.storefront_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _SettingsField(
                                  label: 'Số điện thoại',
                                  controller: _phoneController,
                                  hint: '028 1234 5678',
                                  keyboardType: TextInputType.phone,
                                  prefixIcon: Icons.phone_outlined,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // ── Row 2: Address (full width) ─────────
                          _SettingsField(
                            label: 'Địa chỉ',
                            controller: _addressController,
                            hint: '123 Nguyễn Huệ, Q.1, TP.HCM',
                            prefixIcon: Icons.location_on_outlined,
                          ),
                          const SizedBox(height: 12),

                          // ── Row 3: Tax ID + Open hours ──────────
                          Row(
                            children: [
                              Expanded(
                                child: _SettingsField(
                                  label: 'Mã số thuế',
                                  controller: _taxIdController,
                                  hint: '0312345678',
                                  prefixIcon: Icons.receipt_long_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _SettingsField(
                                  label: 'Giờ mở cửa',
                                  controller: _openHoursController,
                                  hint: '07:00 - 22:00',
                                  prefixIcon: Icons.access_time_rounded,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ── Bank section separator ──────────────
                          Row(
                            children: [
                              const Expanded(
                                  child: Divider(color: AppColors.slate200)),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                child: Text(
                                  'Thanh toán ngân hàng',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.slate400,
                                  ),
                                ),
                              ),
                              const Expanded(
                                  child: Divider(color: AppColors.slate200)),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ── Bank name (full width) ──────────────
                          _SettingsField(
                            label: 'Tên ngân hàng',
                            controller: _bankNameController,
                            hint: 'Vietcombank',
                            prefixIcon: Icons.account_balance_outlined,
                          ),
                          const SizedBox(height: 12),

                          // ── Bank account + Owner ────────────────
                          Row(
                            children: [
                              Expanded(
                                child: _SettingsField(
                                  label: 'Số tài khoản',
                                  controller: _bankAccountController,
                                  hint: '0123 4567 8910',
                                  keyboardType: TextInputType.number,
                                  prefixIcon: Icons.credit_card_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _SettingsField(
                                  label: 'Chủ tài khoản',
                                  controller: _bankOwnerController,
                                  hint: 'NGUYEN VAN A',
                                  prefixIcon: Icons.person_outline,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ── Cancel + Save buttons ──────────────
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    final info = store.currentStoreInfo;
                                    _nameController.text = info.name;
                                    _phoneController.text = info.phone;
                                    _addressController.text = info.address;
                                    _taxIdController.text = info.taxId;
                                    _openHoursController.text = info.openHours;
                                    _bankNameController.text = info.bankId;
                                    _bankAccountController.text = info.bankAccount;
                                    _bankOwnerController.text = info.bankOwner;
                                    store.showToast('Đã hủy thay đổi');
                                  },
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  label: const Text('Hủy bỏ'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.red500,
                                    side: const BorderSide(color: AppColors.red200),
                                    minimumSize: const Size(0, 50),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    textStyle: const TextStyle(
                                        fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _saveStoreInfo(store),
                                  icon: const Icon(Icons.save, size: 18),
                                  label: const Text('Lưu thay đổi'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.emerald500,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 50),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    textStyle: const TextStyle(
                                        fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickStoreLogo(AppStore store) async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();
    if (!mounted) return;

    final base64 = await showSquareCropDialog(
      context,
      imageBytes: bytes,
      borderRadius: 24,
    );
    if (base64 != null) {
      final info = store.currentStoreInfo.copyWith(logoUrl: base64);
      store.updateStoreInfo(info);
      setState(() {});
    }
  }

  void _saveStoreInfo(AppStore store) {
    final info = store.currentStoreInfo.copyWith(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      taxId: _taxIdController.text.trim(),
      openHours: _openHoursController.text.trim(),
      bankId: _bankNameController.text.trim(),
      bankAccount: _bankAccountController.text.trim(),
      bankOwner: _bankOwnerController.text.trim(),
    );
    store.updateStoreInfo(info);
    store.showToast('Cập nhật thông tin thành công!');
  }
}

// ─── Tables Section ─────────────────────────────────
class _TablesSection extends StatefulWidget {
  final VoidCallback? onBack;
  const _TablesSection({this.onBack});

  @override
  State<_TablesSection> createState() => _TablesSectionState();
}

class _TablesSectionState extends State<_TablesSection> {
  final Set<String> _collapsedAreas = {};
  String _searchQuery = '';

  // Add/Edit panel state
  bool _showPanel = false;
  String? _editingTable; // original name to edit
  final _tableNameCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _newAreaCtrl = TextEditingController();
  String _newAreaName = '';

  @override
  void dispose() {
    _tableNameCtrl.dispose();
    _areaCtrl.dispose();
    _newAreaCtrl.dispose();
    super.dispose();
  }

  // ── Parse area::table name ──────────────────────────
  static String _areaOf(String raw) {
    final parts = raw.split('::');
    return parts.length > 1 ? parts[0] : 'Mặc định';
  }

  static String _nameOf(String raw) {
    final parts = raw.split('::');
    return parts.length > 1 ? parts.sublist(1).join('::') : raw;
  }

  static final _tableAvatarColors = [
    const Color(0xFF10B981),
    const Color(0xFF3B82F6),
    const Color(0xFFF59E0B),
    const Color(0xFF8B5CF6),
    const Color(0xFFEF4444),
    const Color(0xFFEC4899),
  ];

  Color _avatarColor(int i) => _tableAvatarColors[i % _tableAvatarColors.length];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final tables = store.currentTables;

    // Apply search
    var display = tables.toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      display = display.where((t) => t.toLowerCase().contains(q)).toList();
    }

    // Group by area
    final Map<String, List<String>> areaGroups = {};
    for (final t in display) {
      final area = _areaOf(t);
      areaGroups.putIfAbsent(area, () => []);
      areaGroups[area]!.add(t);
    }

    final mainContent = Container(
      color: AppColors.slate50,
      child: Column(
        children: [
          // ── Header ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                if (widget.onBack != null) ...[
                  GestureDetector(
                    onTap: widget.onBack,
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.slate100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.slate800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.emerald50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Icon(Icons.grid_view_rounded, size: 24, color: AppColors.emerald600),
                  ),
                ),
                const SizedBox(width: 12),
                const Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quản Lý Bàn & Khu Vực',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.slate800)),
                      SizedBox(height: 2),
                      Text('Thiết lập danh sách bàn Order',
                          style: TextStyle(fontSize: 13, color: AppColors.slate500)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Content Area ────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // ── Search Bar ──────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 20, color: AppColors.slate400),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            onChanged: (v) => setState(() => _searchQuery = v),
                            decoration: const InputDecoration(
                              hintText: 'Tìm kiếm bàn...',
                              hintStyle: TextStyle(fontSize: 14, color: AppColors.slate400),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Area Groups (collapsible) ───────
                  Expanded(
                    child: areaGroups.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.table_restaurant_outlined, size: 48, color: AppColors.slate300),
                                const SizedBox(height: 12),
                                const Text('Chưa có bàn nào',
                                    style: TextStyle(color: AppColors.slate400, fontSize: 14, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 4),
                                const Text('Hãy thêm bàn đầu tiên!',
                                    style: TextStyle(color: AppColors.slate400, fontSize: 13)),
                              ],
                            ),
                          )
                        : ListView(
                            padding: EdgeInsets.zero,
                            children: areaGroups.entries.map((entry) {
                              final areaName = entry.key;
                              final areaTables = entry.value;
                              final isCollapsed = _collapsedAreas.contains(areaName);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Container(
                                  clipBehavior: Clip.antiAlias,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: AppColors.slate200),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Group Header
                                      GestureDetector(
                                        onTap: () => setState(() {
                                          isCollapsed ? _collapsedAreas.remove(areaName) : _collapsedAreas.add(areaName);
                                        }),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.location_on_rounded, size: 16, color: AppColors.emerald600),
                                                const SizedBox(width: 6),
                                                Text(areaName,
                                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate800)),

                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.emerald50,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text('${areaTables.length} bàn',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.emerald600)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Table Cards (collapsible)
                                      if (!isCollapsed)
                                        ...areaTables.asMap().entries.map((e) {
                                          final idx = e.key;
                                          final raw = e.value;
                                          final displayName = _nameOf(raw);
                                          final initials = displayName.length >= 2
                                              ? displayName.substring(0, 2).toUpperCase()
                                              : displayName.toUpperCase();
                                          final color = _avatarColor(idx);
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 10),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                              decoration: BoxDecoration(
                                                color: AppColors.slate50,
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              child: Row(
                                                children: [
                                                  // Avatar
                                                  Container(
                                                    width: 40, height: 40,
                                                    decoration: BoxDecoration(
                                                      color: color.withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(20),
                                                    ),
                                                    child: Center(
                                                      child: Text(initials,
                                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  // Info
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(displayName,
                                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate800)),
                                                        const SizedBox(height: 2),
                                                        Text(areaName,
                                                            style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                                                      ],
                                                    ),
                                                  ),
                                                  // Actions
                                                  GestureDetector(
                                                    onTap: () => _openEditPanel(raw),
                                                    child: const Icon(Icons.edit, size: 18, color: AppColors.emerald500),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  GestureDetector(
                                                    onTap: () {
                                                      store.showConfirm(
                                                        'Xóa bàn "$displayName"?',
                                                        () => store.removeTable(raw),
                                                        title: 'Xóa bàn?',
                                                        description: 'Bạn có chắc muốn xóa bàn này? Hành động này không thể hoàn tác.',
                                                        icon: Icons.table_restaurant_outlined,
                                                        itemName: displayName,
                                                        itemSubtitle: areaName,
                                                        avatarInitials: initials,
                                                        avatarColor: color,
                                                      );
                                                    },
                                                    child: const Icon(Icons.delete, size: 18, color: Color(0xFFEF4444)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 12),

                  // ── FAB ─────────────────────────────
                  GestureDetector(
                    onTap: _openAddPanel,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
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
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline, size: 20, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Thêm bàn mới',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return Stack(
      children: [
        mainContent,
        if (_showPanel) _buildTableFormPanel(context.read<AppStore>()),
      ],
    );
  }

  // ── Open Add Panel ──────────────────────────────────
  void _openAddPanel() {
    _editingTable = null;
    _tableNameCtrl.clear();
    _areaCtrl.clear();
    _newAreaCtrl.clear();
    _newAreaName = '';
    setState(() => _showPanel = true);
  }

  // ── Open Edit Panel ─────────────────────────────────
  void _openEditPanel(String rawTableName) {
    _editingTable = rawTableName;
    _areaCtrl.text = _areaOf(rawTableName) == 'Mặc định' ? '' : _areaOf(rawTableName);
    _tableNameCtrl.text = _nameOf(rawTableName);
    _newAreaCtrl.clear();
    _newAreaName = '';
    setState(() => _showPanel = true);
  }

  // ── Close Panel ─────────────────────────────────────
  void _closePanel() {
    setState(() {
      _showPanel = false;
      _editingTable = null;
    });
  }

  // ── Table Form Overlay Panel ────────────────────────
  Widget _buildTableFormPanel(AppStore store) {
    final isEditing = _editingTable != null;
    return Positioned.fill(
      child: GestureDetector(
        onTap: _closePanel,
        child: Container(
          color: Colors.black.withValues(alpha: 0.4),
          child: GestureDetector(
            onTap: () {}, // prevent close on panel tap
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 40,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(Icons.table_restaurant_rounded, color: AppColors.emerald600, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isEditing ? 'Sửa bàn' : 'Thêm bàn mới',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.slate800),
                          ),
                        ),
                        GestureDetector(
                          onTap: _closePanel,
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.slate100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.close, size: 18, color: AppColors.slate500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Area field (dropdown of existing areas + new)
                    const Text('Khu vực (tùy chọn)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate600)),
                    const SizedBox(height: 6),
                    Builder(builder: (ctx) {
                      // Collect existing areas from tables
                      final allTables = store.currentTables;
                      final existingAreas = <String>{};
                      for (final t in allTables) {
                        final parts = t.split('::');
                        if (parts.length > 1) existingAreas.add(parts[0]);
                      }
                      final areaList = existingAreas.toList()..sort();
                      final currentAreaText = _areaCtrl.text.trim();
                      final isNewArea = currentAreaText.isNotEmpty && !areaList.contains(currentAreaText);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Dropdown for existing areas
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.slate200),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: areaList.contains(currentAreaText) ? currentAreaText : (isNewArea ? '__new__' : null),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.slate400, size: 18),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                              hint: const Text('Chọn khu vực hoặc thêm mới', style: TextStyle(color: AppColors.slate400, fontSize: 14)),
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate400),
                              items: [
                                // No area option
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('Mặc định (không có khu vực)', style: TextStyle(fontSize: 14, color: AppColors.slate500)),
                                ),
                                // Existing areas
                                ...areaList.map((a) => DropdownMenuItem(
                                  value: a,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.location_on, size: 14, color: AppColors.emerald500),
                                      const SizedBox(width: 8),
                                      Text(a, style: const TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                )),
                                // Add new area option
                                const DropdownMenuItem(
                                  value: '__new__',
                                  child: Row(
                                    children: [
                                      Icon(Icons.add_circle_outline, size: 14, color: AppColors.emerald600),
                                      SizedBox(width: 8),
                                      Text('Thêm khu vực mới...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.emerald600)),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  if (val == '__new__') {
                                    _areaCtrl.text = '__new__';
                                  } else {
                                    _areaCtrl.text = val ?? '';
                                  }
                                });
                              },
                            ),
                          ),
                          // New area text field (shown when "Thêm khu vực mới" selected)
                          if (_areaCtrl.text == '__new__') ...[
                            const SizedBox(height: 8),
                            TextField(
                              autofocus: true,
                              onChanged: (v) {
                                // Store as __new__::actualName so we can extract it
                                _areaCtrl.text = '__new__';
                                _newAreaName = v;
                              },
                              controller: _newAreaCtrl,
                              decoration: InputDecoration(
                                hintText: 'Nhập tên khu vực mới...',
                                hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 14),
                                prefixIcon: const Icon(Icons.edit_location_alt_outlined, color: AppColors.emerald500, size: 18),
                                filled: true,
                                fillColor: AppColors.emerald50,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.emerald200)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.emerald200)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.emerald400)),
                              ),
                            ),
                          ],
                        ],
                      );
                    }),
                    const SizedBox(height: 16),

                    // Table name field
                    const Text('Tên bàn',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _tableNameCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'VD: Bàn 1, VIP 2...',
                        hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 14),
                        prefixIcon: const Icon(Icons.table_restaurant_outlined, color: AppColors.slate400, size: 18),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.slate200)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.slate200)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.emerald400)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _closePanel,
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.red500, width: 1),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.close, size: 20, color: AppColors.red500),
                                  SizedBox(width: 8),
                                  Text('Hủy bỏ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.red500)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _saveTable(store),
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.emerald500,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(isEditing ? Icons.save : Icons.add_circle, size: 20, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(isEditing ? 'Lưu thay đổi' : 'Thêm bàn',
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Save Table ──────────────────────────────────────
  Future<void> _saveTable(AppStore store) async {
    final name = _tableNameCtrl.text.trim();
    if (name.isEmpty) {
      store.showToast('Tên bàn không được trống', 'error');
      return;
    }
    String area = _areaCtrl.text.trim();
    if (area == '__new__') {
      area = _newAreaName.trim();
    }
    final fullName = area.isNotEmpty ? '$area::$name' : name;

    try {
      if (_editingTable != null) {
        await store.updateTable(_editingTable!, fullName);
        store.showToast('Đã cập nhật bàn "$name"');
      } else {
        await store.addTable(fullName);
        store.showToast('Đã thêm bàn "$name"');
      }
      _closePanel();
    } catch (e) {
      store.showToast('Lỗi: ${e.toString()}', 'error');
    }
  }
}

// ─── Users Section ──────────────────────────────────
class _UsersSection extends StatefulWidget {
  final VoidCallback? onBack;
  const _UsersSection({this.onBack});

  @override
  State<_UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends State<_UsersSection> {
  final Set<String> _collapsedStores = {};
  String _searchQuery = '';
  String _selectedStoreFilter = 'all';

  // Add/Edit panel state
  bool _showPanel = false;
  UserModel? _editingUser;
  final _fullnameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _selectedRole = 'staff';
  String _selectedStore = '';
  bool _obscurePassword = true;

  @override
  void dispose() {
    _fullnameCtrl.dispose();
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final currentUser = store.currentUser;
    final allUsers = store.users;

    List<UserModel> displayUsers;
    if (currentUser?.role == 'sadmin') {
      displayUsers = allUsers;
    } else {
      displayUsers = allUsers
          .where((u) =>
              u.username == currentUser?.username ||
              u.createdBy == currentUser?.username)
          .toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      displayUsers = displayUsers
          .where((u) =>
              u.fullname.toLowerCase().contains(q) ||
              u.username.toLowerCase().contains(q))
          .toList();
    }

    // Group users by store
    final Map<String, List<UserModel>> storeGroups = {};
    for (final user in displayUsers) {
      String storeId;
      if (user.role == 'sadmin') {
        storeId = 'sadmin';
      } else if (user.role == 'admin') {
        storeId = user.username;
      } else {
        storeId = user.createdBy ?? user.username;
      }
      storeGroups.putIfAbsent(storeId, () => []);
      storeGroups[storeId]!.add(user);
    }

    // Apply store filter
    final filteredGroups = _selectedStoreFilter == 'all'
        ? storeGroups
        : Map.fromEntries(storeGroups.entries.where((e) => e.key == _selectedStoreFilter));

    // Build store options for selector
    final storeOptions = <String, String>{'all': 'Tất cả cửa hàng'};
    for (final sid in storeGroups.keys) {
      storeOptions[sid] = _getStoreName(store, sid);
    }

    final mainContent = Container(
      color: AppColors.slate50,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                if (widget.onBack != null) ...[
                  GestureDetector(
                    onTap: widget.onBack,
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.slate100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.slate800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.emerald50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Icon(Icons.groups_rounded, size: 24, color: AppColors.emerald600),
                  ),
                ),
                const SizedBox(width: 12),
                const Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quản Lý Nhân Viên',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.slate800)),
                      SizedBox(height: 2),
                      Text('Tạo tài khoản • Toàn hệ thống',
                          style: TextStyle(fontSize: 13, color: AppColors.slate500)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // ── Store Selector
                  GestureDetector(
                    onTap: () {
                      _showStoreFilterMenu(context, storeOptions);
                    },
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.emerald50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.emerald200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.storefront, size: 20, color: AppColors.emerald600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              storeOptions[_selectedStoreFilter] ?? 'Tất cả cửa hàng',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.emerald700),
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.emerald600),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ── Search Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 20, color: AppColors.slate400),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            onChanged: (v) => setState(() => _searchQuery = v),
                            decoration: const InputDecoration(
                              hintText: 'Tìm kiếm nhân viên...',
                              hintStyle: TextStyle(fontSize: 14, color: AppColors.slate400),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Store Panels (each store = separate panel)
                  Expanded(
                    child: filteredGroups.isEmpty
                        ? const Center(
                            child: Text('Không tìm thấy nhân viên',
                                style: TextStyle(color: AppColors.slate400, fontSize: 14)),
                          )
                        : ListView(
                            padding: EdgeInsets.zero,
                            children: filteredGroups.entries.map((entry) {
                              final storeId = entry.key;
                              final users = entry.value;
                              final isCollapsed = _collapsedStores.contains(storeId);
                              final storeName = _getStoreName(store, storeId);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Container(
                                  clipBehavior: Clip.antiAlias,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: AppColors.slate200),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Group Header
                                      GestureDetector(
                                        onTap: () => setState(() {
                                          isCollapsed ? _collapsedStores.remove(storeId) : _collapsedStores.add(storeId);
                                        }),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.storefront, size: 16, color: AppColors.emerald600),
                                                const SizedBox(width: 6),
                                                Text(storeName,
                                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate800)),
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.emerald50,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text('${users.length} nhân viên',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.emerald600)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Employee Cards (collapsible)
                                      if (!isCollapsed)
                                        ...users.map((user) => _buildEmployeeCard(store, user, currentUser, storeName)),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 12),
                  // ── FAB
                  GestureDetector(
                    onTap: () => _openAddPanel(store),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
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
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_add, size: 20, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Thêm nhân viên',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    // Wrap in Stack for overlay panel
    return Stack(
      children: [
        mainContent,
        if (_showPanel) _buildEmployeeFormPanel(context.read<AppStore>()),
      ],
    );
  }

  void _showStoreFilterMenu(BuildContext context, Map<String, String> options) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Chọn cửa hàng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            ...options.entries.map((e) => ListTile(
              leading: Icon(
                e.key == 'all' ? Icons.store : Icons.storefront,
                color: _selectedStoreFilter == e.key ? AppColors.emerald600 : AppColors.slate400,
              ),
              title: Text(e.value,
                  style: TextStyle(
                    fontWeight: _selectedStoreFilter == e.key ? FontWeight.w700 : FontWeight.normal,
                    color: _selectedStoreFilter == e.key ? AppColors.emerald600 : AppColors.slate800,
                  )),
              trailing: _selectedStoreFilter == e.key
                  ? const Icon(Icons.check_circle, color: AppColors.emerald600)
                  : null,
              onTap: () {
                setState(() => _selectedStoreFilter = e.key);
                Navigator.pop(ctx);
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(AppStore store, UserModel user, UserModel? currentUser, String storeName) {
    final isCurrentUser = user.username == currentUser?.username;
    final displayName = user.fullname.isNotEmpty ? user.fullname : user.username;
    final initials = displayName.length >= 2 ? displayName.substring(0, 2).toUpperCase() : displayName[0].toUpperCase();

    Color avatarBg, avatarFg;
    String roleLabel;
    Color roleBg, roleFg;

    if (user.role == 'sadmin') {
      avatarBg = AppColors.violet100; avatarFg = AppColors.violet600;
      roleLabel = 'SuperAdmin'; roleBg = AppColors.violet100; roleFg = AppColors.violet600;
    } else if (user.role == 'admin') {
      avatarBg = AppColors.emerald100; avatarFg = AppColors.emerald600;
      roleLabel = 'Admin'; roleBg = AppColors.emerald50; roleFg = AppColors.emerald600;
    } else {
      avatarBg = const Color(0xFFDBEAFE); avatarFg = const Color(0xFF2563EB);
      roleLabel = 'Nhân viên'; roleBg = const Color(0xFFDBEAFE); roleFg = const Color(0xFF2563EB);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: avatarBg, borderRadius: BorderRadius.circular(20)),
              child: Center(child: Text(initials, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: avatarFg))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate800), overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: roleBg, borderRadius: BorderRadius.circular(8)),
                        child: Text(roleLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: roleFg)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(storeName, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                ],
              ),
            ),
            if (!isCurrentUser && (currentUser?.role == 'sadmin' || user.role == 'staff'))
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(onTap: () => _openEditPanel(store, user), child: const Icon(Icons.edit, size: 18, color: AppColors.emerald500)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      store.showConfirm(
                        'Xóa nhân viên "$displayName"?',
                        () => store.deleteUser(user.username),
                        title: 'Xóa nhân viên?',
                        description: 'Bạn có chắc muốn xóa nhân viên này? Hành động này không thể hoàn tác.',
                        icon: Icons.person_remove_rounded,
                        itemName: displayName,
                        itemSubtitle: '$roleLabel • @${user.username}',
                        avatarInitials: initials,
                        avatarColor: avatarFg,
                      );
                    },
                    child: const Icon(Icons.delete, size: 18, color: Color(0xFFEF4444)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _getStoreName(AppStore store, String storeId) {
    if (storeId == 'sadmin') return 'Super Admin';
    final info = store.storeInfos[storeId];
    if (info != null && info.name.isNotEmpty) return info.name;
    final adminUser = store.users.firstWhere(
      (u) => u.username == storeId,
      orElse: () => const UserModel(username: '', pass: '', role: ''),
    );
    return adminUser.fullname.isNotEmpty ? adminUser.fullname : storeId.isNotEmpty ? storeId : 'Cửa hàng';
  }

  void _openAddPanel(AppStore store) {
    _editingUser = null;
    _fullnameCtrl.clear();
    _usernameCtrl.clear();
    _phoneCtrl.clear();
    _passwordCtrl.clear();
    _selectedRole = 'staff';
    _selectedStore = store.currentUser?.username ?? '';
    _obscurePassword = true;
    setState(() => _showPanel = true);
  }

  void _openEditPanel(AppStore store, UserModel user) {
    _editingUser = user;
    _fullnameCtrl.text = user.fullname;
    _usernameCtrl.text = user.username;
    _phoneCtrl.text = user.phone;
    _passwordCtrl.clear();
    _selectedRole = user.role;
    _selectedStore = user.createdBy ?? store.currentUser?.username ?? '';
    _obscurePassword = true;
    setState(() => _showPanel = true);
  }

  void _closePanel() {
    setState(() => _showPanel = false);
  }

  Widget _buildEmployeeFormPanel(AppStore store) {
    final isEditing = _editingUser != null;
    final currentUser = store.currentUser;
    // Build store list for dropdown
    final storeList = <MapEntry<String, String>>[];
    if (currentUser?.role == 'sadmin') {
      for (final u in store.users.where((u) => u.role == 'admin' || u.role == 'sadmin')) {
        final name = _getStoreName(store, u.username);
        storeList.add(MapEntry(u.username, name));
      }
    } else {
      storeList.add(MapEntry(currentUser?.username ?? '', _getStoreName(store, currentUser?.username ?? '')));
    }

    return GestureDetector(
      onTap: _closePanel,
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: GestureDetector(
            onTap: () {}, // prevent close on panel tap
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 60),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 40, offset: const Offset(0, 12)),
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Panel Header ──
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.emerald50, Colors.white],
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(isEditing ? Icons.edit : Icons.person_add, size: 22, color: AppColors.emerald600),
                              const SizedBox(width: 10),
                              Text(isEditing ? 'Sửa nhân viên' : 'Thêm nhân viên',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.slate800)),
                            ],
                          ),
                          GestureDetector(
                            onTap: _closePanel,
                            child: Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(16)),
                              child: const Center(child: Icon(Icons.close, size: 18, color: AppColors.slate500)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Form Body ──
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFormField('Họ và tên', Icons.person, _fullnameCtrl, 'Nhập họ tên nhân viên'),
                            const SizedBox(height: 14),
                            _buildFormField('Tên đăng nhập', Icons.badge, _usernameCtrl, 'Nhập tên đăng nhập', enabled: !isEditing),
                            const SizedBox(height: 14),
                            _buildFormField('Số điện thoại', Icons.call, _phoneCtrl, 'Nhập số điện thoại', keyboardType: TextInputType.phone),
                            const SizedBox(height: 14),
                            _buildDropdownField('Cửa hàng', Icons.storefront, _selectedStore,
                                storeList.map((e) => MapEntry(e.key, e.value)).toList(),
                                (v) => setState(() => _selectedStore = v)),
                            const SizedBox(height: 14),
                            _buildDropdownField('Vai trò', Icons.shield, _selectedRole,
                                [const MapEntry('staff', 'Nhân viên'), const MapEntry('admin', 'Admin')],
                                (v) => setState(() => _selectedRole = v)),
                            const SizedBox(height: 14),
                            // Password field with toggle
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Mật khẩu', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate600)),
                                const SizedBox(height: 6),
                                Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: AppColors.slate50,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.slate200),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.lock, size: 20, color: AppColors.slate400),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextField(
                                          controller: _passwordCtrl,
                                          obscureText: _obscurePassword,
                                          decoration: InputDecoration(
                                            hintText: isEditing ? 'Để trống nếu không đổi' : 'Nhập mật khẩu',
                                            hintStyle: const TextStyle(fontSize: 14, color: AppColors.slate400),
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                                        child: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility,
                                            size: 20, color: AppColors.slate400),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),

                    // ── Footer Buttons ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _closePanel,
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.slate200, width: 1.5),
                                ),
                                child: const Center(
                                  child: Text('Hủy bỏ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.slate600)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _saveEmployee(store),
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [AppColors.emerald500, AppColors.emerald600],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(color: AppColors.emerald500.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.save, size: 18, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text('Lưu thay đổi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormField(String label, IconData icon, TextEditingController ctrl, String hint,
      {bool enabled = true, TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate600)),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: enabled ? AppColors.slate50 : AppColors.slate100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.slate200),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.slate400),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  enabled: enabled,
                  keyboardType: keyboardType,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(fontSize: 14, color: AppColors.slate400),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, IconData icon, String value,
      List<MapEntry<String, String>> options, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate600)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (ctx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    ...options.map((e) => ListTile(
                      leading: Icon(icon, color: value == e.key ? AppColors.emerald600 : AppColors.slate400),
                      title: Text(e.value, style: TextStyle(
                        fontWeight: value == e.key ? FontWeight.w700 : FontWeight.normal,
                        color: value == e.key ? AppColors.emerald600 : AppColors.slate800,
                      )),
                      trailing: value == e.key ? const Icon(Icons.check_circle, color: AppColors.emerald600) : null,
                      onTap: () { onChanged(e.key); Navigator.pop(ctx); },
                    )),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.slate50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.slate400),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    options.firstWhere((e) => e.key == value, orElse: () => options.first).value,
                    style: const TextStyle(fontSize: 14, color: AppColors.slate800),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.slate400),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _saveEmployee(AppStore store) {
    if (_usernameCtrl.text.trim().isEmpty) {
      store.showToast('Vui lòng nhập tên đăng nhập', 'error');
      return;
    }
    if (_editingUser == null && _passwordCtrl.text.isEmpty) {
      store.showToast('Vui lòng nhập mật khẩu', 'error');
      return;
    }
    if (_passwordCtrl.text.isNotEmpty) {
      final passErr = validatePassword(_passwordCtrl.text);
      if (passErr != null) { store.showToast(passErr, 'error'); return; }
    }

    if (_editingUser != null) {
      // Update existing employee
      final updatedData = <String, dynamic>{
        'fullname': _fullnameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      };
      if (_passwordCtrl.text.isNotEmpty) {
        updatedData['pass'] = _passwordCtrl.text;
      }
      store.updateUser(_editingUser!.username, updatedData);
    } else {
      // Add new employee
      store.addStaff(
        username: _usernameCtrl.text.trim().toLowerCase().replaceAll(' ', ''),
        password: _passwordCtrl.text,
        fullname: _fullnameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
    }
    _closePanel();
  }
}
// ─── Shared Widgets ─────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback? onBack;
  final Widget child;

  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.onBack,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header outside the card
        Row(
          children: [
            if (onBack != null)
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 22),
                onPressed: onBack,
              ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slate800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.slate500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Card body
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.slate200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }
}

class _SettingsField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool isPassword;
  final bool showPassword;
  final VoidCallback? onToggle;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;

  const _SettingsField({
    required this.label,
    required this.controller,
    this.hint,
    this.isPassword = false,
    this.showPassword = false,
    this.onToggle,
    this.keyboardType,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.slate700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isPassword && !showPassword,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: AppColors.slate800,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.slate400),
            filled: true,
            fillColor: AppColors.slate50,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 18, color: AppColors.slate400)
                : null,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: isPassword && onToggle != null
                ? IconButton(
                    icon: Icon(
                      showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.slate400,
                      size: 20,
                    ),
                    onPressed: onToggle,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.slate200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.slate200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.emerald500, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool isPassword;
  final TextInputType? keyboardType;

  const _DialogField({
    required this.controller,
    required this.label,
    this.isPassword = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 14),
        filled: true,
        fillColor: AppColors.slate50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.slate200),
        ),
      ),
    );
  }
}

// ─── Printer Section ────────────────────────────────
class _PrinterSection extends StatelessWidget {
  final VoidCallback? onBack;
  const _PrinterSection({this.onBack});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (onBack != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBack,
                ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.blue100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.print, color: AppColors.blue600),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Máy In & Hoá Đơn',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slate800,
                    ),
                  ),
                  Text(
                    'Kết nối máy in bill, in bếp',
                    style: TextStyle(fontSize: 13, color: AppColors.slate500),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.blue50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.print_outlined,
                      size: 36, color: AppColors.blue400),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tính năng đang phát triển',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Kết nối máy in nhiệt, tuỳ chỉnh hoá đơn sẽ sớm có mặt trong bản cập nhật tiếp theo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.slate500,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.amber50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.amber200),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline,
                          color: AppColors.amber600, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Coming Soon',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.amber600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Backup Section ─────────────────────────────────
class _BackupSection extends StatelessWidget {
  final VoidCallback? onBack;
  const _BackupSection({this.onBack});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (onBack != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBack,
                ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.emerald100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child:
                    const Icon(Icons.cloud, color: AppColors.emerald600),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lưu Trữ & Phục Hồi',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slate800,
                    ),
                  ),
                  Text(
                    'Sao lưu dữ liệu đám mây',
                    style: TextStyle(fontSize: 13, color: AppColors.slate500),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.emerald50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.cloud_done_outlined,
                      size: 36, color: AppColors.emerald400),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Dữ liệu tự động đồng bộ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Dữ liệu của bạn được tự động lưu trữ trên đám mây thông qua Supabase. Tính năng xuất/nhập dữ liệu thủ công sẽ sớm được bổ sung.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.slate500,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.emerald50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.emerald200),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: AppColors.emerald600, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Đang hoạt động',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.emerald600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
