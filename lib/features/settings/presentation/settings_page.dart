import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:moimoi_pos/features/auth/logic/auth_store_standalone.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/features/settings/presentation/menu_management.dart';
import 'package:moimoi_pos/features/cashflow/presentation/cashflow_page.dart';
import 'package:moimoi_pos/features/premium/presentation/premium_page.dart';
import 'package:moimoi_pos/features/settings/presentation/qr_menu_page.dart';
import 'package:moimoi_pos/features/settings/presentation/printer_section.dart';
import 'package:moimoi_pos/core/utils/quota_helper.dart';
import 'package:moimoi_pos/features/premium/presentation/widgets/upgrade_dialog.dart';

// Modular Sections
import 'package:moimoi_pos/features/settings/presentation/sections/account_section.dart';
import 'package:moimoi_pos/features/settings/presentation/sections/store_info_section.dart';
import 'package:moimoi_pos/features/settings/presentation/sections/tables_section.dart';
import 'package:moimoi_pos/features/settings/presentation/sections/users_section.dart';
import 'package:moimoi_pos/features/settings/presentation/sections/notifications_section.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _selectedSection;
  String? _lastAppliedTab;
  bool _hideSectionHeader = false;

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
  static const List<_SettingMenu> _storeMenus = [
    // 👤 TÀI KHOẢN & CỬA HÀNG
    _SettingMenu(
      id: 'account',
      name: 'Tài Khoản & Bảo Mật',
      desc: 'Thông tin cá nhân, đổi mật khẩu',
      icon: Icons.person_outline,
      group: '👤 TÀI KHOẢN & CỬA HÀNG',
    ),
    _SettingMenu(
      id: 'general',
      name: 'Cài Đặt Cửa Hàng',
      desc: 'Tên quán, địa chỉ, số điện thoại',
      icon: Icons.storefront_outlined,
      requiresStore: true,
      group: '👤 TÀI KHOẢN & CỬA HÀNG',
      requiredPermission: 'settings_general',
    ),
    _SettingMenu(
      id: 'users',
      name: 'Nhân Sự & Phân Quyền',
      desc: 'Quản lý nhân viên, tùy chỉnh vai trò',
      icon: Icons.people_outline,
      group: '👤 TÀI KHOẢN & CỬA HÀNG',
      requiredPermission: 'settings_users',
    ),
    _SettingMenu(
      id: 'premium',
      name: 'Moimoi Premium',
      desc: 'Gia hạn gói Premium, xem tính năng',
      icon: Icons.workspace_premium,
      group: '👤 TÀI KHOẢN & CỬA HÀNG',
    ),

    // 📦 KINH DOANH & BÁN HÀNG
    _SettingMenu(
      id: 'management',
      name: 'Danh Mục & Kho Hàng',
      desc: 'Quản lý danh mục, sản phẩm, kho hàng',
      icon: Icons.category_rounded,
      requiresStore: true,
      group: '📦 KINH DOANH & BÁN HÀNG',
      requiredPermission: 'settings_catalog',
    ),
    _SettingMenu(
      id: 'tables',
      name: 'Quản Lý Bàn & Khu Vực',
      desc: 'Thiết lập danh sách bàn Order',
      icon: Icons.grid_view_outlined,
      requiresStore: true,
      group: '📦 KINH DOANH & BÁN HÀNG',
      requiredPermission: 'settings_tables',
    ),
    _SettingMenu(
      id: 'qr-menu',
      name: 'Menu QR & Order',
      desc: 'Quản lý menu QR, đặt hàng online',
      icon: Icons.qr_code_2,
      requiresStore: true,
      group: '📦 KINH DOANH & BÁN HÀNG',
      requiredPermission: 'settings_qr',
    ),
    _SettingMenu(
      id: 'cashflow',
      name: 'Thu nhập/Chi tiêu',
      desc: 'Quản lý doanh thu, thu nhập chi phí',
      icon: Icons.account_balance_wallet_outlined,
      requiresStore: true,
      group: '📦 KINH DOANH & BÁN HÀNG',
      requiredPermission: 'tab_cashflow',
    ),

    // ⚙️ HỆ THỐNG CÀI ĐẶT
    _SettingMenu(
      id: 'printer',
      name: 'Máy In & Hoá Đơn',
      desc: 'Kết nối máy in bill',
      icon: Icons.print_outlined,
      requiresStore: true,
      group: '⚙️ HỆ THỐNG CÀI ĐẶT',
      requiredPermission: 'settings_general', // Printer tied to general settings for now
    ),
    _SettingMenu(
      id: 'notifications',
      name: 'Âm Thanh & Thông Báo',
      desc: 'Tùy chỉnh âm thanh đơn hàng mới',
      icon: Icons.notifications_active_outlined,
      requiresStore: true,
      group: '⚙️ HỆ THỐNG CÀI ĐẶT',
    ),
  ];

  // ── Sadmin menus with groups ──
  static const List<_SettingMenu> _sadminMenus = [
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
    final store = context.watch<ManagementStore>();
    final isAdmin = ['admin', 'sadmin'].contains(store.currentUser?.role);
    final isSadmin = store.currentUser?.role == 'sadmin';
    final hasStoreSelected = !isSadmin || context.read<AuthStore>().sadminViewStoreId != 'all';

    final List<_SettingMenu> menus;
    if (isSadmin) {
      menus = _sadminMenus;
    } else {
      menus = _storeMenus.where((m) {
        if (m.adminOnly && !isAdmin) return false;
        if (m.requiresStore && !hasStoreSelected) return false;
        if (m.requiredPermission != null && !store.hasPermission(m.requiredPermission!)) {
          return false;
        }
        return true;
      }).toList();
    }

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      final activeId = _selectedSection ?? menus.first.id;
      return Row(
        children: [
          SizedBox(
            width: 320,
            child: _SettingsMenuList(
              menus: menus,
              selected: activeId,
              onSelect: (id) => _handleSectionSelect(context, id),
              quota: QuotaHelper(context.read<ManagementStore>().quotaProvider),
            ),
          ),
          Container(width: 1, color: AppColors.slate200),
          Expanded(child: _buildSection(activeId, onBack: null)),
        ],
      );
    }

    if (_selectedSection != null) {
      return _buildSection(
        _selectedSection!,
        onBack: () => setState(() {
          _selectedSection = null;
          _hideSectionHeader = false;
        }),
      );
    }

    return _SettingsMenuList(
      menus: menus,
      selected: null,
      onSelect: (id) => _handleSectionSelect(context, id),
      quota: QuotaHelper(context.read<ManagementStore>().quotaProvider),
    );
  }

  Future<void> _handleSectionSelect(BuildContext context, String id) async {
    final store = context.read<ManagementStore>();
    final quota = QuotaHelper(store.quotaProvider);

    if (id == 'qr-menu' && !quota.canUseMenuOrder) {
      await showUpgradePrompt(context, quota.menuOrderLimitMsg);
      return;
    }
    if (id == 'cashflow' && !quota.canUseTransactions) {
      await showUpgradePrompt(context, quota.transactionLimitMsg);
      return;
    }

    setState(() {
      _selectedSection = id;
      _hideSectionHeader = false;
    });
  }

  Widget _buildSection(String id, {VoidCallback? onBack}) {
    final menu = _allMenus.firstWhere(
      (m) => m.id == id,
      orElse: () => _allMenus.first,
    );
    final sectionWidget = _buildSectionContent(id, onCancel: onBack);
    return NotificationListener<ScrollNotification>(
      onNotification: (_) => true,
      child: Column(
        children: [
          if (!_hideSectionHeader)
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  if (onBack != null) ...[
                    GestureDetector(
                      onTap: onBack,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.slate50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          size: 20,
                          color: AppColors.slate600,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                  ],
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.emerald50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      menu.icon,
                      size: 22,
                      color: AppColors.emerald600,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          menu.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slate800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          menu.desc,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: sectionWidget),
        ],
      ),
    );
  }

  Widget _buildSectionContent(String id, {VoidCallback? onCancel}) {
    switch (id) {
      case 'account':
        return AccountSection(onCancel: onCancel);
      case 'general':
        return StoreInfoSection(onCancel: onCancel);
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
      case 'notifications':
        return NotificationsSection(onCancel: onCancel);
      case 'cashflow':
        return CashflowPage(
          embedded: true,
          onSubViewToggle: (hidden) {
            if (mounted && _hideSectionHeader != hidden) {
              setState(() => _hideSectionHeader = hidden);
            }
          },
        );
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
        return Center(child: Text('Coming soon'));
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
  final String? requiredPermission;
  const _SettingMenu({
    required this.id,
    required this.name,
    required this.desc,
    required this.icon,
    this.adminOnly = false,
    this.requiresStore = false,
    this.group,
    this.requiredPermission,
  });
}

class _SettingsMenuList extends StatelessWidget {
  final List<_SettingMenu> menus;
  final String? selected;
  final ValueChanged<String> onSelect;
  final QuotaHelper quota;

  const _SettingsMenuList({
    required this.menus,
    required this.selected,
    required this.onSelect,
    required this.quota,
  });

  @override
  Widget build(BuildContext context) {
    final slivers = <Widget>[];

    // For store menus, they might not have groups
    List<_SettingMenu> currentGroupItems = [];
    String? currentGroup;

    void addCurrentGroupSlivers() {
      if (currentGroupItems.isEmpty) return;

      if (currentGroup != null) {
        slivers.add(
          SliverPersistentHeader(
            pinned: false,
            delegate: _SettingsGroupHeaderDelegate(title: currentGroup),
          ),
        );
      } else {
        // First group without a title, just add some padding equivalent
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 8)));
      }

      final items = currentGroupItems.map((menu) {
        final isActive = selected == menu.id;
        return Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onSelect(menu.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.emerald50 : AppColors.cardBg,
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
                        color: isActive
                            ? AppColors.emerald100
                            : AppColors.inputBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            menu.icon,
                            color: isActive
                                ? AppColors.emerald600
                                : AppColors.slate500,
                          ),
                          if ((menu.id == 'cashflow' && !quota.canUseTransactions) ||
                              (menu.id == 'qr-menu' && !quota.canUseMenuOrder))
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                padding: EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: AppColors.amber500,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isActive
                                        ? AppColors.emerald100
                                        : AppColors.inputBg,
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  Icons.lock_rounded,
                                  size: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12),
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
                          SizedBox(height: 2),
                          Text(
                            menu.desc,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.slate400),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList();

      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => items[index],
            childCount: items.length,
          ),
        ),
      );

      // Optional spacing between groups
      if (currentGroup != null) {
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 16)));
      }
    }

    for (final menu in menus) {
      if (menu.group != currentGroup) {
        addCurrentGroupSlivers();
        currentGroup = menu.group;
        currentGroupItems = [menu];
      } else {
        currentGroupItems.add(menu);
      }
    }

    // Add the final group
    addCurrentGroupSlivers();

    // Add Footer (Log Out, Version, Privacy Policy)
    slivers.add(
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  icon: Icon(Icons.logout, size: 18, color: AppColors.red500),
                  label: Text(
                    'Đăng xuất khỏi hệ thống',
                    style: TextStyle(
                      color: AppColors.red500,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.red200),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    final store = context.read<AuthStore>();
                    store.logout();
                    context.go('/login');
                  },
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Moimoi POS v1.0.0 (Build 5)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate400,
                ),
              ),
              SizedBox(height: 4),
              TextButton(
                onPressed: () async {
                  final url = Uri.parse(
                    'https://docs.google.com/document/d/1A0i6Gq__4pY6Z8FqweItaelxnvEYGeQNRgQIabx9kks/edit?usp=sharing',
                  );
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.slate500,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text('Chính sách bảo mật & Điều khoản sử dụng'),
              ),
            ],
          ),
        ),
      ),
    );

    return Container(
      color: AppColors.slate50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
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
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: CustomScrollView(slivers: slivers),
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
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon badge
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 36, color: AppColors.emerald600),
            ),
            SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.slate800,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.orange50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.construction_rounded,
                    size: 14,
                    color: Color(0xFFF59E0B),
                  ),
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
            SizedBox(height: 28),
            // Features list
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tính năng sắp ra mắt',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate600,
                    ),
                  ),
                  SizedBox(height: 12),
                  ...features.map(
                    (f) => Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.emerald50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: AppColors.emerald500,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              f,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.slate700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsGroupHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;

  _SettingsGroupHeaderDelegate({required this.title});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppColors.slate50,
      padding: EdgeInsets.fromLTRB(8, 16, 8, 8),
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.slate400,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  double get maxExtent => 40.0; // Estimate based on text sizing and paddings

  @override
  double get minExtent => 40.0;

  @override
  bool shouldRebuild(covariant _SettingsGroupHeaderDelegate oldDelegate) {
    return title != oldDelegate.title;
  }
}
