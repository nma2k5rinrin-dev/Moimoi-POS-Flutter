import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/state/app_store.dart';
import 'package:moimoi_pos/features/auth/models/user_model.dart';
import 'package:moimoi_pos/features/settings/models/store_info_model.dart';
import 'package:moimoi_pos/core/utils/validators.dart';
import 'package:moimoi_pos/features/settings/presentation/sections/shared_widgets.dart';

class UsersSection extends StatefulWidget {
  const UsersSection({super.key});

  @override
  State<UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends State<UsersSection> {
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
  final _storeNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  @override
  void dispose() {
    _fullnameCtrl.dispose();
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _storeNameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final currentUser = store.currentUser;
    final allUsers = store.users; // store.users is already a List<UserModel>

    List<UserModel> displayUsers;
    if (currentUser?.role == 'sadmin') {
      displayUsers = allUsers;
    } else {
      displayUsers = allUsers
          .where((u) =>
              u.role != 'sadmin' &&
              (u.username == currentUser?.username ||
              u.createdBy == currentUser?.username))
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      displayUsers = displayUsers
          .where((u) =>
              u.fullname.toLowerCase().contains(q) ||
              u.username.toLowerCase().contains(q))
          .toList();
    }

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

    final filteredGroups = _selectedStoreFilter == 'all'
        ? storeGroups
        : Map.fromEntries(storeGroups.entries.where((e) => e.key == _selectedStoreFilter));

    final storeOptions = <String, String>{'all': 'Tất cả cửa hàng'};
    for (final sid in storeGroups.keys) {
      storeOptions[sid] = _getStoreName(store, sid);
    }

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _buildStoreSelector(storeOptions),
                  const SizedBox(height: 12),
                  _buildSearchBar(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filteredGroups.isEmpty
                        ? const Center(child: Text('Không tìm thấy nhân viên', style: TextStyle(color: AppColors.slate400, fontSize: 14)))
                        : ListView(
                            padding: EdgeInsets.zero,
                            children: filteredGroups.entries.map((entry) {
                              final storeId = entry.key;
                              final users = entry.value;
                              final isCollapsed = _collapsedStores.contains(storeId);
                              final storeName = _getStoreName(store, storeId);
                              return _buildStoreGroup(store, storeId, users, isCollapsed, storeName, currentUser);
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 12),
                  _buildAddButton(store),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStoreSelector(Map<String, String> storeOptions) {
    final selectorKey = GlobalKey();
    return GestureDetector(
      key: selectorKey,
      onTap: () {
        final renderBox = selectorKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) return;
        final position = renderBox.localToGlobal(Offset.zero);
        final fieldSize = renderBox.size;
        showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(position.dx, position.dy + fieldSize.height, position.dx + fieldSize.width, 0),
          items: storeOptions.entries.map((e) => PopupMenuItem<String>(value: e.key, child: Text(e.value))).toList(),
        ).then((v) { if (v != null) setState(() => _selectedStoreFilter = v); });
      },
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: AppColors.emerald50, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.emerald200)),
        child: Row(children: [
          const Icon(Icons.storefront, size: 20, color: AppColors.emerald600),
          const SizedBox(width: 8),
          Expanded(child: Text(storeOptions[_selectedStoreFilter] ?? 'Tất cả cửa hàng', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.emerald700))),
          const Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.emerald600),
        ]),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.slate200)),
      child: Row(children: [
        const Icon(Icons.search, size: 20, color: AppColors.slate400),
        const SizedBox(width: 10),
        Expanded(child: TextField(
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: const InputDecoration(hintText: 'Tìm kiếm nhân viên...', hintStyle: TextStyle(fontSize: 14, color: AppColors.slate400), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
          style: const TextStyle(fontSize: 14),
        )),
      ]),
    );
  }

  Widget _buildStoreGroup(AppStore store, String storeId, List<UserModel> users, bool isCollapsed, String storeName, UserModel? currentUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.slate200)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(
            onTap: () => setState(() => isCollapsed ? _collapsedStores.remove(storeId) : _collapsedStores.add(storeId)),
            child: Row(children: [
              const Icon(Icons.storefront, size: 16, color: AppColors.emerald600),
              const SizedBox(width: 6),
              Expanded(child: Text(storeName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate800))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppColors.emerald50, borderRadius: BorderRadius.circular(10)), child: Text('${users.length} nhân viên', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.emerald600))),
              const SizedBox(width: 8),
              Icon(isCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, size: 18, color: AppColors.slate400),
            ]),
          ),
          if (!isCollapsed) ...users.map((u) => _buildEmployeeCard(store, u, currentUser, storeName)),
        ]),
      ),
    );
  }

  Widget _buildEmployeeCard(AppStore store, UserModel user, UserModel? currentUser, String storeName) {
    final isCurrentUser = user.username == currentUser?.username;
    final displayName = user.fullname.isNotEmpty ? user.fullname : user.username;
    final initials = displayName.length >= 2 ? displayName.substring(0, 2).toUpperCase() : displayName[0].toUpperCase();

    Color avatarBg = AppColors.slate100, avatarFg = AppColors.slate600;
    String roleLabel = 'Nhân viên'; Color roleBg = AppColors.slate50, roleFg = AppColors.slate600;

    switch (user.role) {
      case 'sadmin': avatarBg = AppColors.violet100; avatarFg = AppColors.violet600; roleLabel = 'Super Admin'; roleBg = AppColors.violet100; roleFg = AppColors.violet600; break;
      case 'admin': avatarBg = AppColors.emerald100; avatarFg = AppColors.emerald600; roleLabel = 'Admin'; roleBg = AppColors.emerald50; roleFg = AppColors.emerald600; break;
      case 'manager': avatarBg = const Color(0xFFFEF3C7); avatarFg = const Color(0xFFD97706); roleLabel = 'QL Chi nhánh'; roleBg = const Color(0xFFFEF3C7); roleFg = const Color(0xFFD97706); break;
      case 'cashier': avatarBg = const Color(0xFFDBEAFE); avatarFg = const Color(0xFF2563EB); roleLabel = 'Thu ngân'; roleBg = const Color(0xFFDBEAFE); roleFg = const Color(0xFF2563EB); break;
      case 'kitchen': avatarBg = const Color(0xFFFEE2E2); avatarFg = const Color(0xFFDC2626); roleLabel = 'Xử lý đơn'; roleBg = const Color(0xFFFEE2E2); roleFg = const Color(0xFFDC2626); break;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GestureDetector(
        onTap: (!isCurrentUser && _canManageUser(currentUser?.role, user.role)) ? () => _openEditPanel(store, user) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: avatarBg, borderRadius: BorderRadius.circular(20)), child: Center(child: Text(initials, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: avatarFg)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate800), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: roleBg, borderRadius: BorderRadius.circular(8)), child: Text(roleLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: roleFg))),
              ]),
              const SizedBox(height: 2),
              Text(storeName, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
            ])),
            if (!isCurrentUser && _canManageUser(currentUser?.role, user.role))
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _deleteUser(store, user, displayName, initials, avatarFg, roleLabel)),
          ]),
        ),
      ),
    );
  }

  bool _canManageUser(String? myRole, String? targetRole) {
    if (myRole == null || targetRole == null) return false;
    if (myRole == 'sadmin') return true;
    if (myRole == 'admin') return targetRole != 'sadmin' && targetRole != 'admin';
    return false;
  }

  void _deleteUser(AppStore store, UserModel user, String displayName, String initials, Color avatarFg, String roleLabel) {
    store.showConfirm('Xóa nhân viên "$displayName"?', () => store.deleteUser(user.username), title: 'Xóa nhân viên?', description: 'Hành động này không thể hoàn tác.', icon: Icons.person_remove_rounded, itemName: displayName, itemSubtitle: '$roleLabel • @${user.username}', avatarInitials: initials, avatarColor: avatarFg);
  }

  Widget _buildAddButton(AppStore store) {
    return GestureDetector(
      onTap: () => _openAddPanel(store),
      child: Container(
        height: 52,
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.emerald500, AppColors.emerald600]), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: AppColors.emerald500.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 4))]),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.person_add, size: 20, color: Colors.white), SizedBox(width: 8), Text('Thêm nhân viên', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white))]),
      ),
    );
  }

  String _getStoreName(AppStore store, String storeId) {
    if (storeId == 'sadmin') return 'Super Admin';
    final info = store.storeInfos[storeId];
    if (info != null && info.name.isNotEmpty) return info.name;
    
    // Fixed: users is a List, not a Map
    UserModel? adminUser;
    for (final u in store.users) {
      if (u.username == storeId) {
        adminUser = u;
        break;
      }
    }
    return adminUser?.fullname ?? storeId;
  }

  void _openAddPanel(AppStore store) {
    _editingUser = null; _fullnameCtrl.clear(); _usernameCtrl.clear(); _phoneCtrl.clear(); _passwordCtrl.clear(); _selectedRole = 'staff'; _selectedStore = store.currentUser?.username ?? ''; _storeNameCtrl.clear(); _addressCtrl.clear(); _obscurePassword = true;
    _showEmployeePanelDialog();
  }

  void _openEditPanel(AppStore store, UserModel user) {
    _editingUser = user; _fullnameCtrl.text = user.fullname; _usernameCtrl.text = user.username; _phoneCtrl.text = user.phone; _passwordCtrl.clear(); _selectedRole = user.role; _selectedStore = user.createdBy ?? store.currentUser?.username ?? ''; _obscurePassword = true;
    _showEmployeePanelDialog();
  }

  void _showEmployeePanelDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      useRootNavigator: true,
      transitionDuration: Duration.zero,
      pageBuilder: (ctx, _, _) => StatefulBuilder(builder: (dialogCtx, dialogSetState) => _buildEmployeeFormPanel(dialogCtx.read<AppStore>(), dialogSetState: dialogSetState)),
    );
  }

  void _closePanel() { Navigator.of(context, rootNavigator: true).pop(); setState(() => _showPanel = false); }

  Widget _buildEmployeeFormPanel(AppStore store, {required StateSetter dialogSetState}) {
    final isEditing = _editingUser != null;
    final currentUser = store.currentUser;
    final storeList = <MapEntry<String, String>>[];
    if (currentUser?.role == 'sadmin') {
      for (final u in store.users.where((u) => u.role == 'admin' || u.role == 'sadmin')) {
        storeList.add(MapEntry(u.username, _getStoreName(store, u.username)));
      }
    } else {
      storeList.add(MapEntry(currentUser?.username ?? '', _getStoreName(store, currentUser?.username ?? '')));
    }

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: _closePanel,
        child: Container(
          color: Colors.black.withValues(alpha: 0.4),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: GestureDetector(
              onTap: () {},
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 480),
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 60),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 40, offset: const Offset(0, 12))]),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(isEditing ? 'Sửa nhân viên' : 'Thêm nhân viên', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        IconButton(icon: const Icon(Icons.close), onPressed: _closePanel),
                      ]),
                      const SizedBox(height: 20),
                      _buildRoleSelector(currentUser, dialogSetState),
                      const SizedBox(height: 14),
                      SettingsDialogField(controller: _fullnameCtrl, label: 'Họ và tên'),
                      const SizedBox(height: 14),
                      SettingsDialogField(controller: _usernameCtrl, label: 'Tên đăng nhập', keyboardType: TextInputType.text),
                      const SizedBox(height: 14),
                      SettingsDialogField(controller: _phoneCtrl, label: 'Số điện thoại', keyboardType: TextInputType.phone),
                      const SizedBox(height: 14),
                      if (_selectedRole == 'admin') ...[
                        SettingsDialogField(controller: _storeNameCtrl, label: 'Tên cửa hàng'),
                        const SizedBox(height: 14),
                        SettingsDialogField(controller: _addressCtrl, label: 'Địa chỉ'),
                      ] else ...[
                        _buildStoreSelectorForAdd(storeList, dialogSetState),
                      ],
                      const SizedBox(height: 14),
                      _buildPasswordField(dialogSetState),
                      const SizedBox(height: 24),
                      ElevatedButton(onPressed: () => _saveEmployee(store), style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald500, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text(isEditing ? 'Cập nhật' : 'Thêm nhân viên')),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelector(UserModel? currentUser, StateSetter dialogSetState) {
    final roles = currentUser?.role == 'sadmin'
        ? [const MapEntry('admin', 'Admin'), const MapEntry('manager', 'Quản lý'), const MapEntry('cashier', 'Thu ngân'), const MapEntry('staff', 'Nhân viên'), const MapEntry('kitchen', 'KDS')]
        : [const MapEntry('manager', 'Quản lý'), const MapEntry('cashier', 'Thu ngân'), const MapEntry('staff', 'Nhân viên'), const MapEntry('kitchen', 'KDS')];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Vai trò', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        initialValue: _selectedRole,
        items: roles.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
        onChanged: (v) => dialogSetState(() => _selectedRole = v!),
        decoration: InputDecoration(filled: true, fillColor: AppColors.slate50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      ),
    ]);
  }

  Widget _buildStoreSelectorForAdd(List<MapEntry<String, String>> storeList, StateSetter dialogSetState) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Cửa hàng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        initialValue: _selectedStore.isEmpty ? storeList.first.key : _selectedStore,
        items: storeList.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
        onChanged: (v) => dialogSetState(() => _selectedStore = v!),
        decoration: InputDecoration(filled: true, fillColor: AppColors.slate50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      ),
    ]);
  }

  Widget _buildPasswordField(StateSetter dialogSetState) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Mật khẩu', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      TextField(
        controller: _passwordCtrl,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          hintText: _editingUser != null ? 'Để trống nếu không đổi' : 'Nhập mật khẩu',
          suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility), onPressed: () => dialogSetState(() => _obscurePassword = !_obscurePassword)),
          filled: true, fillColor: AppColors.slate50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ]);
  }

  Future<void> _saveEmployee(AppStore store) async {
    if (_usernameCtrl.text.trim().isEmpty) { store.showToast('Vui lòng nhập tên đăng nhập', 'error'); return; }
    if (_editingUser == null && _passwordCtrl.text.isEmpty) { store.showToast('Vui lòng nhập mật khẩu', 'error'); return; }
    if (_passwordCtrl.text.isNotEmpty) { final err = validatePassword(_passwordCtrl.text); if (err != null) { store.showToast(err, 'error'); return; } }

    if (_editingUser != null) {
      final updatedData = <String, dynamic>{'fullname': _fullnameCtrl.text.trim(), 'phone': _phoneCtrl.text.trim()};
      if (_passwordCtrl.text.isNotEmpty) updatedData['pass'] = _passwordCtrl.text;
      if (_selectedRole != _editingUser!.role) { updatedData['role'] = _selectedRole; updatedData['createdBy'] = _selectedRole == 'admin' ? store.currentUser?.username : _selectedStore; }
      store.updateUser(_editingUser!.username, updatedData);
    } else {
      await store.addStaff(username: _usernameCtrl.text.trim().toLowerCase().replaceAll(' ', ''), password: _passwordCtrl.text, fullname: _fullnameCtrl.text.trim(), phone: _phoneCtrl.text.trim(), role: _selectedRole, createdBy: _selectedRole == 'admin' ? store.currentUser?.username : _selectedStore);
      if (_selectedRole == 'admin') {
        final storeId = _usernameCtrl.text.trim().toLowerCase().replaceAll(' ', '');
        final storeData = <String, dynamic>{'store_id': storeId, 'name': _storeNameCtrl.text.trim(), 'address': _addressCtrl.text.trim()};
        try { await Supabase.instance.client.from('store_infos').upsert(storeData); store.storeInfos[storeId] = StoreInfoModel(name: _storeNameCtrl.text.trim(), phone: _phoneCtrl.text.trim(), address: _addressCtrl.text.trim()); store.notifyListeners(); } catch (e) { debugPrint('[saveEmployee] $e'); }
      }
    }
    _closePanel();
  }
}
