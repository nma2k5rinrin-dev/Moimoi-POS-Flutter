import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:moimoi_pos/core/state/app_store.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/features/settings/presentation/menu_management.dart';
import 'package:moimoi_pos/features/thu_chi/presentation/thu_chi_page.dart';
import 'package:moimoi_pos/features/premium/presentation/premium_page.dart';
import 'package:moimoi_pos/features/settings/presentation/qr_menu_page.dart';
import 'package:moimoi_pos/features/settings/presentation/printer_section.dart';

// Modular Sections
import 'package:moimoi_pos/features/settings/presentation/sections/account_section.dart';
import 'package:moimoi_pos/features/settings/presentation/sections/store_info_section.dart';
import 'package:moimoi_pos/features/settings/presentation/sections/tables_section.dart';
import 'package:moimoi_pos/features/settings/presentation/sections/users_section.dart';
import 'package:moimoi_pos/features/settings/presentation/sections/backup_section.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _selectedSection;
  String? _lastAppliedTab;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tab = GoRouterState.of(context).uri.queryParameters['tab'];
    if (tab != null && tab.isNotEmpty && tab != _lastAppliedTab) {
      _selectedSection = tab;
      _lastAppliedTab = tab;
    }
  }

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
      requiresStore: true,
    ),
    _SettingMenu(
      id: 'management',
      name: 'Danh Mục & Kho Hàng',
      desc: 'Quản lý danh mục, sản phẩm, kho hàng',
      icon: Icons.restaurant_menu,
      requiresStore: true,
    ),
    _SettingMenu(
      id: 'tables',
      name: 'Quản Lý Bàn & Khu Vực',
      desc: 'Thiết lập danh sách bàn Order',
      icon: Icons.grid_view_outlined,
      requiresStore: true,
    ),
    _SettingMenu(
      id: 'qr-menu',
      name: 'Menu QR & Order',
      desc: 'Quản lý menu QR, đặt hàng online',
      icon: Icons.qr_code_2,
      requiresStore: true,
    ),
    _SettingMenu(
      id: 'users',
      name: 'Quản Lý Nhân Sự',
      desc: 'Quản lý nhân viên, phân quyền vai trò',
      icon: Icons.people_outline,
      adminOnly: true,
    ),
    _SettingMenu(
      id: 'thu-chi',
      name: 'Thu Chi',
      desc: 'Quản lý dòng tiền thu chi',
      icon: Icons.account_balance_wallet_outlined,
      requiresStore: true,
    ),
    _SettingMenu(
      id: 'printer',
      name: 'Máy In & Hoá Đơn',
      desc: 'Kết nối máy in bill, in bếp',
      icon: Icons.print_outlined,
      requiresStore: true,
    ),
    _SettingMenu(
      id: 'backup',
      name: 'Lưu Trữ & Phục Hồi',
      desc: 'Sao lưu dữ liệu đám mây',
      icon: Icons.cloud_outlined,
    ),
    _SettingMenu(
      id: 'premium',
      name: 'Moimoi Premium',
      desc: 'Gia hạn gói Premium, xem tính năng',
      icon: Icons.workspace_premium,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isAdmin = ['admin', 'sadmin'].contains(store.currentUser?.role);
    final isSadmin = store.currentUser?.role == 'sadmin';
    final hasStoreSelected = !isSadmin || store.sadminViewStoreId != 'all';

    // Sadmin only sees: account
    const sadminTabs = {'account'};

    final menus = _menus.where((m) {
      if (isSadmin) return sadminTabs.contains(m.id);
      if (m.adminOnly && !isAdmin) return false;
      if (m.requiresStore && !hasStoreSelected) return false;
      return true;
    }).toList();

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      final activeId = _selectedSection ?? menus.first.id;
      return Row(
        children: [
          SizedBox(
            width: 320,
            child: _SettingsMenuList(
              menus: menus,
              selected: activeId,
              onSelect: (id) => setState(() => _selectedSection = id),
            ),
          ),
          Container(width: 1, color: AppColors.slate200),
          Expanded(
            child: _buildSection(activeId, onBack: null),
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
    final menu = _menus.firstWhere((m) => m.id == id, orElse: () => _menus.first);
    final sectionWidget = _buildSectionContent(id);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              if (onBack != null) ...[
                GestureDetector(
                  onTap: onBack,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.slate50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.slate600),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.emerald50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(menu.icon, size: 22, color: AppColors.emerald600),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(menu.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.slate800)),
                    const SizedBox(height: 2),
                    Text(menu.desc,
                        style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(child: sectionWidget),
      ],
    );
  }

  Widget _buildSectionContent(String id) {
    switch (id) {
      case 'account':
        return const AccountSection();
      case 'general':
        return const StoreInfoSection();
      case 'management':
        return const MenuManagementSection();
      case 'tables':
        return const TablesSection();
      case 'qr-menu':
        return const QrMenuPage();
      case 'users':
        return const UsersSection();
      case 'printer':
        return const PrinterSection();
      case 'backup':
        return const BackupSection();
      case 'thu-chi':
        return const ThuChiPage(embedded: true);
      case 'premium':
        return const PremiumPage();
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
  final bool requiresStore;
  const _SettingMenu({
    required this.id,
    required this.name,
    required this.desc,
    required this.icon,
    this.adminOnly = false,
    this.requiresStore = false,
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
