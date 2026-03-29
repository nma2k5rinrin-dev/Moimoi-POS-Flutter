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

  // ── Store/Admin menus ──
  final List<_SettingMenu> _storeMenus = [
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

  // ── Sadmin menus with groups ──
  final List<_SettingMenu> _sadminMenus = [
    // 👤 TÀI KHOẢN CỦA TÔI
    _SettingMenu(
      id: 'account',
      name: 'Thông Tin Cá Nhân',
      desc: 'Tên, email, avatar, đổi mật khẩu',
      icon: Icons.person_outline,
      group: '👤  TÀI KHOẢN CỦA TÔI',
    ),
    _SettingMenu(
      id: 'sa-security',
      name: 'Bảo Mật & Xác Thực 2 Lớp',
      desc: 'Mật khẩu, 2FA, phiên đăng nhập',
      icon: Icons.shield_outlined,
      group: '👤  TÀI KHOẢN CỦA TÔI',
    ),
    // 🏢 QUẢN TRỊ NỀN TẢNG
    _SettingMenu(
      id: 'sa-admins',
      name: 'Quản Lý Nhân Sự Admin',
      desc: 'Tài khoản admin cửa hàng, phân quyền',
      icon: Icons.admin_panel_settings_outlined,
      group: '🏢  QUẢN TRỊ NỀN TẢNG',
    ),
    _SettingMenu(
      id: 'sa-audit',
      name: 'Nhật Ký Hoạt Động',
      desc: 'Audit logs, lịch sử thao tác hệ thống',
      icon: Icons.history_outlined,
      group: '🏢  QUẢN TRỊ NỀN TẢNG',
    ),
    // ⚙️ CẤU HÌNH HỆ THỐNG
    _SettingMenu(
      id: 'sa-pricing',
      name: 'Bảng Giá & Gói Premium',
      desc: 'Quản lý gói cước, bảng giá dịch vụ',
      icon: Icons.price_change_outlined,
      group: '⚙️  CẤU HÌNH HỆ THỐNG',
    ),
    _SettingMenu(
      id: 'sa-notifications',
      name: 'Mẫu Email & Thông Báo',
      desc: 'Tùy chỉnh nội dung email, push notification',
      icon: Icons.mark_email_unread_outlined,
      group: '⚙️  CẤU HÌNH HỆ THỐNG',
    ),
    // 🔌 TÍCH HỢP
    _SettingMenu(
      id: 'sa-payment',
      name: 'Cổng Thanh Toán',
      desc: 'Cấu hình VNPay, MoMo, ZaloPay',
      icon: Icons.payment_outlined,
      group: '🔌  TÍCH HỢP',
    ),
    _SettingMenu(
      id: 'sa-api',
      name: 'API Keys & Webhooks',
      desc: 'Quản lý API keys, webhook endpoints',
      icon: Icons.api_outlined,
      group: '🔌  TÍCH HỢP',
    ),
  ];

  List<_SettingMenu> get _allMenus => [..._storeMenus, ..._sadminMenus];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isAdmin = ['admin', 'sadmin'].contains(store.currentUser?.role);
    final isSadmin = store.currentUser?.role == 'sadmin';
    final hasStoreSelected = !isSadmin || store.sadminViewStoreId != 'all';

    final List<_SettingMenu> menus;
    if (isSadmin) {
      menus = _sadminMenus;
    } else {
      menus = _storeMenus.where((m) {
        if (m.adminOnly && !isAdmin) return false;
        if (m.requiresStore && !hasStoreSelected) return false;
        return true;
      }).toList();
    }

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
    final menu = _allMenus.firstWhere((m) => m.id == id, orElse: () => _allMenus.first);
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
      // ── Sadmin sections ──
      case 'sa-security':
        return _ComingSoonSection(
          icon: Icons.shield_outlined,
          title: 'Bảo Mật & Xác Thực 2 Lớp',
          features: const [
            'Xác thực 2 lớp (2FA) qua Authenticator',
            'Quản lý phiên đăng nhập đang hoạt động',
            'Đặt lại mật khẩu từ xa',
            'Lịch sử đăng nhập & IP',
          ],
        );
      case 'sa-admins':
        return _ComingSoonSection(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Quản Lý Nhân Sự Admin',
          features: const [
            'Danh sách tài khoản admin cửa hàng',
            'Khóa / mở khóa tài khoản',
            'Reset mật khẩu admin',
            'Phân quyền truy cập nâng cao',
          ],
        );
      case 'sa-audit':
        return _ComingSoonSection(
          icon: Icons.history_outlined,
          title: 'Nhật Ký Hoạt Động',
          features: const [
            'Theo dõi thao tác tạo / xóa cửa hàng',
            'Lịch sử duyệt Premium',
            'Nhật ký đăng nhập hệ thống',
            'Xuất báo cáo audit (CSV / PDF)',
          ],
        );
      case 'sa-pricing':
        return _ComingSoonSection(
          icon: Icons.price_change_outlined,
          title: 'Bảng Giá & Gói Premium',
          features: const [
            'Tùy chỉnh gói cước (Tháng / Năm)',
            'Thiết lập giá & khuyến mãi',
            'Coupon & mã giảm giá',
            'Giới hạn tính năng theo gói',
          ],
        );
      case 'sa-notifications':
        return _ComingSoonSection(
          icon: Icons.mark_email_unread_outlined,
          title: 'Mẫu Email & Thông Báo',
          features: const [
            'Tùy chỉnh email chào mừng',
            'Thông báo hết hạn Premium',
            'Template email thanh toán',
            'Push notification hàng loạt',
          ],
        );
      case 'sa-payment':
        return _ComingSoonSection(
          icon: Icons.payment_outlined,
          title: 'Cổng Thanh Toán',
          features: const [
            'Tích hợp VNPay / MoMo / ZaloPay',
            'Cấu hình tự động gia hạn',
            'Quản lý webhook callback',
            'Lịch sử giao dịch thanh toán',
          ],
        );
      case 'sa-api':
        return _ComingSoonSection(
          icon: Icons.api_outlined,
          title: 'API Keys & Webhooks',
          features: const [
            'Tạo & quản lý API keys',
            'Cấu hình webhook endpoints',
            'Rate limiting & quota',
            'Tài liệu API (Swagger / OpenAPI)',
          ],
        );
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
  final String? group;
  const _SettingMenu({
    required this.id,
    required this.name,
    required this.desc,
    required this.icon,
    this.adminOnly = false,
    this.requiresStore = false,
    this.group,
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
    // Build items with group headers
    final items = <Widget>[];
    String? lastGroup;
    for (final menu in menus) {
      if (menu.group != null && menu.group != lastGroup) {
        lastGroup = menu.group;
        items.add(
          Padding(
            padding: EdgeInsets.fromLTRB(8, items.isEmpty ? 0 : 16, 8, 8),
            child: Text(
              menu.group!,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.slate400,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );
      }
      final isActive = selected == menu.id;
      items.add(
        Padding(
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
                  color: isActive ? AppColors.emerald50 : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive ? AppColors.emerald200 : AppColors.slate200,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.emerald100 : AppColors.slate100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        menu.icon,
                        color: isActive ? AppColors.emerald600 : AppColors.slate500,
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
                              color: isActive ? AppColors.emerald700 : AppColors.slate800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            menu.desc,
                            style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.slate400),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

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
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: items,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// Coming Soon Placeholder Section (for sadmin)
// ═════════════════════════════════════════════════════════
class _ComingSoonSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> features;

  const _ComingSoonSection({
    required this.icon,
    required this.title,
    required this.features,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon badge
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 36, color: AppColors.emerald600),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.slate800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.construction_rounded, size: 14, color: Color(0xFFF59E0B)),
                  SizedBox(width: 6),
                  Text(
                    'Đang phát triển',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // Features list
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tính năng sắp ra mắt',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.emerald50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.check_rounded, size: 14, color: AppColors.emerald500),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            f,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.slate700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
