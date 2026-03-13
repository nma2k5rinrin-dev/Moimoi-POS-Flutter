import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../store/app_store.dart';
import '../../models/user_model.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import 'menu_management.dart';

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
      name: 'Tài Khoản Cá Nhân',
      desc: 'Đổi mật khẩu, thông tin cá nhân',
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
      name: 'Quản Lý Thực Đơn',
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
  final _fullnameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _oldPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _showOldPass = false;
  bool _showNewPass = false;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _fullnameController.text = store.currentUser?.fullname ?? '';
    _phoneController.text = store.currentUser?.phone ?? '';
  }

  @override
  void dispose() {
    _fullnameController.dispose();
    _phoneController.dispose();
    _oldPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    return Container(
      color: AppColors.slate50,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.onBack != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onBack,
                ),
              const SizedBox(height: 8),

              // Profile Card
              _SectionCard(
                title: 'Thông Tin Cá Nhân',
                icon: Icons.person_outline,
                iconColor: AppColors.blue600,
                iconBg: AppColors.blue50,
                child: Column(
                  children: [
                    _SettingsField(
                      label: 'Họ và Tên',
                      controller: _fullnameController,
                      hint: 'Nguyễn Văn A',
                    ),
                    const SizedBox(height: 12),
                    _SettingsField(
                      label: 'Số Điện Thoại',
                      controller: _phoneController,
                      hint: '0987...',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.slate50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.slate200),
                      ),
                      child: Row(
                        children: [
                          const Text('Tên đăng nhập: ',
                              style: TextStyle(color: AppColors.slate500, fontSize: 14)),
                          Text(
                            '@${store.currentUser?.username ?? ''}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate800,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          store.updateUser(store.currentUser!.username, {
                            'fullname': _fullnameController.text.trim(),
                            'phone': _phoneController.text.trim(),
                          });
                        },
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text('Lưu Thông Tin'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald500,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Password Card
              _SectionCard(
                title: 'Đổi Mật Khẩu',
                icon: Icons.shield_outlined,
                iconColor: AppColors.amber600,
                iconBg: AppColors.amber100,
                child: Column(
                  children: [
                    _SettingsField(
                      label: 'Mật khẩu hiện tại',
                      controller: _oldPassController,
                      hint: 'Nhập mật khẩu đang dùng',
                      isPassword: true,
                      showPassword: _showOldPass,
                      onToggle: () =>
                          setState(() => _showOldPass = !_showOldPass),
                    ),
                    const SizedBox(height: 12),
                    _SettingsField(
                      label: 'Mật khẩu mới',
                      controller: _newPassController,
                      hint: 'Mật khẩu mới',
                      isPassword: true,
                      showPassword: _showNewPass,
                      onToggle: () =>
                          setState(() => _showNewPass = !_showNewPass),
                    ),
                    const SizedBox(height: 12),
                    _SettingsField(
                      label: 'Xác nhận mật khẩu mới',
                      controller: _confirmPassController,
                      hint: 'Nhập lại mật khẩu mới',
                      isPassword: true,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (_oldPassController.text !=
                              store.currentUser?.pass) {
                            store.showToast(
                                'Mật khẩu hiện tại không đúng', 'error');
                            return;
                          }
                          final passErr =
                              validatePassword(_newPassController.text);
                          if (passErr != null) {
                            store.showToast(passErr, 'error');
                            return;
                          }
                          if (_newPassController.text !=
                              _confirmPassController.text) {
                            store.showToast(
                                'Xác nhận mật khẩu không khớp', 'error');
                            return;
                          }
                          store.updateUser(store.currentUser!.username, {
                            'pass': _newPassController.text,
                          });
                          _oldPassController.clear();
                          _newPassController.clear();
                          _confirmPassController.clear();
                        },
                        icon: const Icon(Icons.shield_outlined, size: 18),
                        label: const Text('Cập Nhật Mật Khẩu'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.amber500,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
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

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    final info = store.currentStoreInfo;
    _nameController.text = info.name;
    _phoneController.text = info.phone;
    _addressController.text = info.address;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    return Container(
      color: AppColors.slate50,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.onBack != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onBack,
                ),
              const SizedBox(height: 8),
              _SectionCard(
                title: 'Thông Tin Cửa Hàng',
                icon: Icons.storefront_outlined,
                iconColor: AppColors.emerald600,
                iconBg: AppColors.emerald50,
                child: Column(
                  children: [
                    _SettingsField(
                      label: 'Tên Cửa Hàng',
                      controller: _nameController,
                      hint: 'Nhà Hàng ABC',
                    ),
                    const SizedBox(height: 12),
                    _SettingsField(
                      label: 'Số Điện Thoại',
                      controller: _phoneController,
                      hint: '0987...',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _SettingsField(
                      label: 'Địa Chỉ',
                      controller: _addressController,
                      hint: '123 Đường ABC...',
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final info = store.currentStoreInfo.copyWith(
                            name: _nameController.text.trim(),
                            phone: _phoneController.text.trim(),
                            address: _addressController.text.trim(),
                          );
                          store.updateStoreInfo(info);
                          store.showToast('Cập nhật thông tin thành công!');
                        },
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text('Lưu'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald500,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
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
    );
  }
}

// ─── Tables Section ─────────────────────────────────
class _TablesSection extends StatelessWidget {
  final VoidCallback? onBack;
  const _TablesSection({this.onBack});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final tables = store.currentTables;

    return Container(
      color: AppColors.slate50,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (onBack != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBack,
                ),
              _SectionCard(
                title: 'Quản Lý Bàn & Khu Vực',
                icon: Icons.grid_view_outlined,
                iconColor: AppColors.emerald600,
                iconBg: AppColors.emerald50,
                child: Column(
                  children: [
                    // Add Table Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showAddTableDialog(context, store),
                        icon: const Icon(Icons.add),
                        label: const Text('Thêm Bàn Mới'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.emerald600,
                          side: const BorderSide(color: AppColors.emerald200),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Table Grid
                    if (tables.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: AppColors.slate300,
                              style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Chưa có bàn nào\nHãy tạo bàn đầu tiên!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.slate400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tables.map((t) {
                          return Chip(
                            label: Text(
                              t,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate700,
                              ),
                            ),
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: AppColors.slate200),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            deleteIconColor: AppColors.red400,
                            onDeleted: () {
                              store.showConfirm(
                                'Xóa bàn "$t"?',
                                () => store.removeTable(t),
                              );
                            },
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddTableDialog(BuildContext context, AppStore store) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Thêm Bàn Mới',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'VD: Bàn 1, Tầng 1::Bàn 2...',
            filled: true,
            fillColor: AppColors.slate50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.slate200),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                store.addTable(name);
                store.showToast('Đã thêm bàn "$name"');
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }
}

// ─── Users Section ──────────────────────────────────
class _UsersSection extends StatelessWidget {
  final VoidCallback? onBack;
  const _UsersSection({this.onBack});

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

    return Container(
      color: AppColors.slate50,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (onBack != null)
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Quản Lý Nhân Viên',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate800,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddStaffDialog(context, store),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Thêm'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald500,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ...displayUsers.map((user) {
              final isCurrentUser = user.username == currentUser?.username;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.emerald100,
                      child: Text(
                        user.username.isNotEmpty
                            ? user.username[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.emerald600,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                user.fullname.isNotEmpty
                                    ? user.fullname
                                    : user.username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.slate800,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: user.role == 'sadmin'
                                      ? AppColors.violet100
                                      : user.role == 'admin'
                                          ? AppColors.red100
                                          : AppColors.blue50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  user.role == 'sadmin'
                                      ? 'SuperAdmin'
                                      : user.role == 'admin'
                                          ? 'Admin'
                                          : 'Staff',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: user.role == 'sadmin'
                                        ? AppColors.violet600
                                        : user.role == 'admin'
                                            ? AppColors.red500
                                            : AppColors.blue600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '@${user.username}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isCurrentUser &&
                        (currentUser?.role == 'sadmin' ||
                            user.role == 'staff'))
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.red400, size: 20),
                        onPressed: () {
                          store.showConfirm(
                            'Xoá nhân viên "${user.fullname.isNotEmpty ? user.fullname : user.username}"?',
                            () => store.deleteUser(user.username),
                          );
                        },
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showAddStaffDialog(BuildContext context, AppStore store) {
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final fullnameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tạo Tài Khoản Mới',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogField(controller: usernameCtrl, label: 'Tên đăng nhập *'),
              const SizedBox(height: 8),
              _DialogField(
                  controller: passwordCtrl,
                  label: 'Mật khẩu *',
                  isPassword: true),
              const SizedBox(height: 8),
              _DialogField(controller: fullnameCtrl, label: 'Họ và tên'),
              const SizedBox(height: 8),
              _DialogField(
                  controller: phoneCtrl,
                  label: 'Số điện thoại',
                  keyboardType: TextInputType.phone),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (usernameCtrl.text.isEmpty || passwordCtrl.text.isEmpty) {
                store.showToast('Vui lòng nhập đầy đủ thông tin bắt buộc', 'error');
                return;
              }
              final passErr = validatePassword(passwordCtrl.text);
              if (passErr != null) {
                store.showToast(passErr, 'error');
                return;
              }
              store.addStaff(
                username: usernameCtrl.text
                    .trim()
                    .toLowerCase()
                    .replaceAll(' ', ''),
                password: passwordCtrl.text,
                fullname: fullnameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
              );
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Lưu lại'),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ─────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
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

  const _SettingsField({
    required this.label,
    required this.controller,
    this.hint,
    this.isPassword = false,
    this.showPassword = false,
    this.onToggle,
    this.keyboardType,
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
