import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/state/ui_store.dart';
import 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';
import 'package:moimoi_pos/features/auth/models/user_model.dart';
import 'package:moimoi_pos/features/settings/models/store_info_model.dart';
import 'package:moimoi_pos/core/utils/validators.dart';
import 'package:moimoi_pos/features/settings/presentation/sections/shared_widgets.dart';
import 'package:moimoi_pos/features/settings/presentation/sections/roles_section.dart';
import 'package:moimoi_pos/core/utils/image_helper.dart';

class UsersSection extends StatefulWidget {
  const UsersSection({super.key});

  @override
  State<UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends State<UsersSection> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _collapsedStores = {};
  String _searchQuery = '';
  String _selectedStoreFilter = 'all';

  // Add/Edit panel state
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
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _fullnameCtrl.dispose();
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordCtrl.dispose();
    _storeNameCtrl.dispose();
    _addressCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ManagementStore>();
    final currentUser = store.currentUser;
    final allUsers = store.users; // store.users is already a List<UserModel>

    List<UserModel> displayUsers;
    if (currentUser?.role == 'sadmin') {
      displayUsers = List.from(allUsers);
    } else {
      displayUsers = allUsers
          .where(
            (u) =>
                u.role != 'sadmin' &&
                (u.username == currentUser?.username ||
                    u.createdBy == currentUser?.username),
          )
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      displayUsers = displayUsers
          .where(
            (u) =>
                u.fullname.toLowerCase().contains(q) ||
                u.username.toLowerCase().contains(q),
          )
          .toList();
    }

    // Sắp xếp: sadmin -> admin -> staff, sau đó theo tên
    displayUsers.sort((a, b) {
      int rank(String role) {
        if (role == 'sadmin') return 0;
        if (role == 'admin') return 1;
        return 2;
      }

      int r = rank(a.role).compareTo(rank(b.role));
      if (r != 0) return r;
      return a.fullname.compareTo(b.fullname);
    });

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
        : Map.fromEntries(
            storeGroups.entries.where((e) => e.key == _selectedStoreFilter),
          );

    final storeOptions = <String, String>{'all': 'Tất cả cửa hàng'};
    for (final sid in storeGroups.keys) {
      storeOptions[sid] = _getStoreName(store, sid);
    }

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 9),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 600),
              child: Column(children: [ SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: Colors.white,
                      unselectedLabelColor: AppColors.slate500,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      indicator: BoxDecoration(
                        color: AppColors.emerald500,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      padding: const EdgeInsets.all(4),
                      tabs: const [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 18),
                              SizedBox(width: 6),
                              Text('Danh Sách Nhân Viên'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.admin_panel_settings_outlined, size: 18),
                              SizedBox(width: 6),
                              Text('Chức Vụ & Quyền'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // TAB 1: NHÂN VIÊN
                        Column(
                          children: [
                            if (currentUser?.role == 'sadmin') ...[
                              _buildStoreSelector(storeOptions),
                              SizedBox(height: 12),
                            ],
                            _buildSearchBar(),
                            SizedBox(height: 12),
                            Expanded(
                              child: displayUsers.isEmpty
                                  ? Center(
                                      child: Text(
                                        'Không tìm thấy nhân viên',
                                        style: TextStyle(
                                          color: AppColors.slate400,
                                          fontSize: 14,
                                        ),
                                      ),
                                    )
                                  : currentUser?.role == 'sadmin'
                                  ? ListView(
                                      padding: EdgeInsets.zero,
                                      children: filteredGroups.entries.map((entry) {
                                        final storeId = entry.key;
                                        final users = entry.value;
                                        final isCollapsed = _collapsedStores.contains(storeId);
                                        final storeName = _getStoreName(store, storeId);
                                        return _buildStoreGroup(
                                          store, storeId, users, isCollapsed, storeName, currentUser,
                                        );
                                      }).toList(),
                                    )
                                  : ListView(
                                      padding: EdgeInsets.zero,
                                      children: displayUsers.map((u) {
                                        final sId = u.role == 'admin' ? u.username : (u.createdBy ?? u.username);
                                        return _buildEmployeeCard(
                                          store, u, currentUser, _getStoreName(store, sId),
                                        );
                                      }).toList(),
                                    ),
                            ),
                            SizedBox(height: 12),
                            _buildAddButton(store),
                          ],
                        ),
                        
                        // TAB 2: CHỨC VỤ
                        const RolesSection(),
                      ],
                    ),
                  ),
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
        final renderBox =
            selectorKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) return;
        final position = renderBox.localToGlobal(Offset.zero);
        final fieldSize = renderBox.size;
        showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(
            position.dx,
            position.dy + fieldSize.height,
            position.dx + fieldSize.width,
            0,
          ),
          items: storeOptions.entries
              .map(
                (e) =>
                    PopupMenuItem<String>(value: e.key, child: Text(e.value)),
              )
              .toList(),
        ).then((v) {
          if (v != null) setState(() => _selectedStoreFilter = v);
        });
      },
      child: Container(
        height: 48,
        padding: EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.emerald50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.emerald200),
        ),
        child: Row(
          children: [
            Icon(Icons.storefront, size: 20, color: AppColors.emerald600),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                storeOptions[_selectedStoreFilter] ?? 'Tất cả cửa hàng',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.emerald700,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: AppColors.emerald600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 20, color: AppColors.slate400),
          SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm nhân viên...',
                hintStyle: TextStyle(fontSize: 14, color: AppColors.slate400),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreGroup(
    ManagementStore store,
    String storeId,
    List<UserModel> users,
    bool isCollapsed,
    String storeName,
    UserModel? currentUser,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => setState(
                () => isCollapsed
                    ? _collapsedStores.remove(storeId)
                    : _collapsedStores.add(storeId),
              ),
              child: Row(
                children: [
                  Icon(Icons.storefront, size: 16, color: AppColors.emerald600),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      storeName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate800,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.emerald50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${users.length} nhân viên',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.emerald600,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    isCollapsed
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    size: 18,
                    color: AppColors.slate400,
                  ),
                ],
              ),
            ),
            if (!isCollapsed)
              ...users.map(
                (u) => _buildEmployeeCard(store, u, currentUser, storeName),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(
    ManagementStore store,
    UserModel user,
    UserModel? currentUser,
    String storeName,
  ) {
    final isCurrentUser = user.username == currentUser?.username;
    final displayName = user.fullname.isNotEmpty
        ? user.fullname
        : user.username;
    final initials = displayName.length >= 2
        ? displayName.substring(0, 2).toUpperCase()
        : displayName[0].toUpperCase();

    Color avatarBg = AppColors.slate100, avatarFg = AppColors.slate600;
    String roleLabel = 'Nhân viên';
    Color roleBg = AppColors.slate50, roleFg = AppColors.slate600;

    switch (user.role) {
      case 'sadmin':
        avatarBg = AppColors.violet100;
        avatarFg = AppColors.violet600;
        roleLabel = 'Super Admin';
        roleBg = AppColors.violet100;
        roleFg = AppColors.violet600;
        break;
      case 'admin':
        avatarBg = AppColors.emerald100;
        avatarFg = AppColors.emerald600;
        roleLabel = 'Admin';
        roleBg = AppColors.emerald50;
        roleFg = AppColors.emerald600;
        break;
      default:
        avatarBg = AppColors.blue50;
        avatarFg = const Color(0xFF2563EB);
        final roleIndex = store.appRoles.indexWhere((r) => r.id == user.role);
        roleLabel = roleIndex != -1 ? store.appRoles[roleIndex].roleName : 'Nhân viên';
        roleBg = AppColors.blue50;
        roleFg = const Color(0xFF2563EB);
        break;
    }

    String avatarUrl = user.avatar;
    if (user.role == 'admin') {
      final storeInfo = store.storeInfos[user.username];
      if (storeInfo != null && storeInfo.logoUrl.isNotEmpty) {
        avatarUrl = storeInfo.logoUrl;
      }
    }

    final fallbackWidget = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: avatarBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: avatarFg,
          ),
        ),
      ),
    );

    final canManage =
        !isCurrentUser && _canManageUser(currentUser?.role, user.role);

    return Padding(
      padding: EdgeInsets.only(top: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Slidable(
          key: ValueKey(user.username),
          enabled: canManage,
          endActionPane: ActionPane(
            motion: ScrollMotion(),
            extentRatio: 0.45,
            children: [
              SlidableAction(
                onPressed: (_) => _openEditPanel(store, user),
                backgroundColor: AppColors.emerald500,
                foregroundColor: Colors.white,
                icon: Icons.edit_rounded,
                label: 'Sửa',
              ),
              SlidableAction(
                onPressed: (_) => _deleteUser(
                  store,
                  user,
                  displayName,
                  initials,
                  avatarFg,
                  roleLabel,
                ),
                backgroundColor: AppColors.red500,
                foregroundColor: Colors.white,
                icon: Icons.delete_outline,
                label: 'Xóa',
              ),
            ],
          ),
          child: GestureDetector(
            onTap: canManage ? () => _openEditPanel(store, user) : null,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: AppColors.slate50),
              child: Row(
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: SmartImage(
                        imageData: avatarUrl,
                        placeholder: fallbackWidget,
                        errorWidget: fallbackWidget,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.slate800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: roleBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                roleLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: roleFg,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (currentUser?.role == 'sadmin') ...[
                          SizedBox(height: 2),
                          Text(
                            storeName,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.slate500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (canManage)
                    Icon(Icons.chevron_left_rounded, color: AppColors.slate400),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _canManageUser(String? myRole, String? targetRole) {
    if (myRole == null || targetRole == null) return false;
    if (myRole == 'sadmin') return true;
    if (myRole == 'admin') {
      return targetRole != 'sadmin' && targetRole != 'admin';
    }
    return false;
  }

  void _deleteUser(
    ManagementStore store,
    UserModel user,
    String displayName,
    String initials,
    Color avatarFg,
    String roleLabel,
  ) {
    context.read<UIStore>().showConfirm(
      'Xóa nhân viên "$displayName"?',
      () => store.deleteUser(user.username),
      title: 'Xóa nhân viên?',
      description: 'Hành động này không thể hoàn tác.',
      icon: Icons.person_remove_rounded,
      itemName: displayName,
      itemSubtitle: '$roleLabel • @${user.username}',
      avatarInitials: initials,
      avatarColor: avatarFg,
    );
  }

  Widget _buildAddButton(ManagementStore store) {
    return GestureDetector(
      onTap: () => _openAddPanel(store),
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
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add, size: 20, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Thêm nhân viên',
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

  String _getStoreName(ManagementStore store, String storeId) {
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

  void _openAddPanel(ManagementStore store) {
    _editingUser = null;
    _fullnameCtrl.clear();
    _usernameCtrl.clear();
    _phoneCtrl.clear();
    _passwordCtrl.clear();
    if (store.appRoles.isNotEmpty) {
      _selectedRole = store.appRoles.first.id;
    } else {
      _selectedRole = 'staff';
    }
    _selectedStore = store.currentUser?.username ?? '';
    _storeNameCtrl.clear();
    _addressCtrl.clear();
    _obscurePassword = true;
    _showEmployeePanelDialog();
  }

  void _openEditPanel(ManagementStore store, UserModel user) {
    _editingUser = user;
    _fullnameCtrl.text = user.fullname;
    _usernameCtrl.text = user.username;
    _phoneCtrl.text = user.phone;
    _passwordCtrl.clear();
    _selectedRole = user.role;
    _selectedStore = user.createdBy ?? store.currentUser?.username ?? '';
    _obscurePassword = true;
    _showEmployeePanelDialog();
  }

  void _showEmployeePanelDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      useRootNavigator: true,
      transitionDuration: Duration.zero,
      pageBuilder: (ctx, _, _) => StatefulBuilder(
        builder: (dialogCtx, dialogSetState) => _buildEmployeeFormPanel(
          dialogCtx.read<ManagementStore>(),
          dialogSetState: dialogSetState,
        ),
      ),
    );
  }

  void _closePanel() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  Widget _buildEmployeeFormPanel(
    ManagementStore store, {
    required StateSetter dialogSetState,
  }) {
    final isEditing = _editingUser != null;
    final currentUser = store.currentUser;
    final storeList = <MapEntry<String, String>>[];
    if (currentUser?.role == 'sadmin') {
      for (final u in store.users.where(
        (u) => u.role == 'admin' || u.role == 'sadmin',
      )) {
        storeList.add(MapEntry(u.username, _getStoreName(store, u.username)));
      }
    } else {
      storeList.add(
        MapEntry(
          currentUser?.username ?? '',
          _getStoreName(store, currentUser?.username ?? ''),
        ),
      );
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
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: 480),
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 60),
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 40,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isEditing ? 'Sửa nhân viên' : 'Thêm nhân viên',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close),
                              onPressed: _closePanel,
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        _buildRoleSelector(currentUser, dialogSetState, store),
                        SizedBox(height: 14),
                        SettingsDialogField(
                          controller: _fullnameCtrl,
                          label: 'Họ và tên',
                        ),
                        SizedBox(height: 14),
                        SettingsDialogField(
                          controller: _usernameCtrl,
                          label: 'Tên đăng nhập',
                          keyboardType: TextInputType.text,
                        ),
                        SizedBox(height: 14),
                        SettingsDialogField(
                          controller: _phoneCtrl,
                          label: 'Số điện thoại',
                          keyboardType: TextInputType.phone,
                        ),
                        SizedBox(height: 14),
                        if (_selectedRole == 'admin') ...[
                          SettingsDialogField(
                            controller: _storeNameCtrl,
                            label: 'Tên cửa hàng',
                          ),
                          SizedBox(height: 14),
                          SettingsDialogField(
                            controller: _addressCtrl,
                            label: 'Địa chỉ',
                          ),
                        ] else if (currentUser?.role == 'sadmin') ...[
                          _buildStoreSelectorForAdd(storeList, dialogSetState),
                        ],
                        SizedBox(height: 14),
                        _buildPasswordField(dialogSetState),
                        SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => _saveEmployee(store),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.emerald500,
                            foregroundColor: Colors.white,
                            minimumSize: Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            isEditing ? 'Cập nhật' : 'Thêm nhân viên',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelector(
    UserModel? currentUser,
    StateSetter dialogSetState,
    ManagementStore store,
  ) {
    List<MapEntry<String, String>> roles = [];
    if (currentUser?.role == 'sadmin') {
      roles.add(MapEntry('admin', 'Admin'));
    }

    if (store.appRoles.isNotEmpty) {
      for (final role in store.appRoles) {
        roles.add(MapEntry(role.id, role.roleName));
      }
    } else {
      roles.add(MapEntry('staff', 'Nhân viên (Chung)'));
    }

    if (!roles.any((e) => e.key == _selectedRole)) {
      _selectedRole = roles.first.key;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vai trò',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _selectedRole,
          items: roles
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) => dialogSetState(() => _selectedRole = v!),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.slate50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildStoreSelectorForAdd(
    List<MapEntry<String, String>> storeList,
    StateSetter dialogSetState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cửa hàng',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _selectedStore.isEmpty
              ? storeList.first.key
              : _selectedStore,
          items: storeList
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) => dialogSetState(() => _selectedStore = v!),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.slate50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField(StateSetter dialogSetState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mật khẩu',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 6),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: _editingUser != null
                ? 'Để trống nếu không đổi'
                : 'Nhập mật khẩu',
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () =>
                  dialogSetState(() => _obscurePassword = !_obscurePassword),
            ),
            filled: true,
            fillColor: AppColors.slate50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Future<void> _saveEmployee(ManagementStore store) async {
    if (_usernameCtrl.text.trim().isEmpty) {
      context.read<UIStore>().showToast('Vui lòng nhập tên đăng nhập', 'error');
      return;
    }
    if (_editingUser == null && _passwordCtrl.text.isEmpty) {
      context.read<UIStore>().showToast('Vui lòng nhập mật khẩu', 'error');
      return;
    }
    if (_passwordCtrl.text.isNotEmpty) {
      final err = validatePassword(_passwordCtrl.text);
      if (err != null) {
        context.read<UIStore>().showToast(err, 'error');
        return;
      }
    }

    if (_editingUser != null) {
      final updatedData = <String, dynamic>{
        'fullname': _fullnameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      };
      if (_passwordCtrl.text.isNotEmpty) {
        updatedData['pass'] = _passwordCtrl.text;
      }
      if (_selectedRole != _editingUser!.role) {
        updatedData['role'] = _selectedRole;
        updatedData['createdBy'] = _selectedRole == 'admin'
            ? store.currentUser?.username
            : _selectedStore;
      }
      store.updateUser(_editingUser!.username, updatedData);
    } else {
      await store.addStaff(
        username: _usernameCtrl.text.trim().toLowerCase().replaceAll(' ', ''),
        password: _passwordCtrl.text,
        fullname: _fullnameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        role: _selectedRole,
        createdBy: _selectedRole == 'admin'
            ? store.currentUser?.username
            : _selectedStore,
      );
      if (_selectedRole == 'admin') {
        final storeId = _usernameCtrl.text.trim().toLowerCase().replaceAll(
          ' ',
          '',
        );
        final storeData = <String, dynamic>{
          'store_id': storeId,
          'name': _storeNameCtrl.text.trim(),
          'address': _addressCtrl.text.trim(),
        };
        try {
          await Supabase.instance.client.from('store_infos').upsert(storeData);
          store.storeInfos[storeId] = StoreInfoModel(
            name: _storeNameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            address: _addressCtrl.text.trim(),
          );
          store.notifyListeners();
        } catch (e) {
          debugPrint('[saveEmployee] $e');
        }
      }
    }
    _closePanel();
  }
}


