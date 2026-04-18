import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';
import 'package:moimoi_pos/core/state/ui_store.dart';
import 'package:moimoi_pos/features/settings/models/store_info_model.dart';
import 'package:moimoi_pos/features/premium/models/premium_payment_model.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/widgets/date_range_picker_dialog.dart';
import 'package:moimoi_pos/features/dashboard/presentation/admin/store_detail_page.dart';


// ── Color palette for store icons ──
final _storeColors = [
  [Color(0xFF10B981), Color(0xFF059669)], // emerald
  [Color(0xFF6366F1), Color(0xFF4F46E5)], // indigo
  [Color(0xFFF59E0B), Color(0xFFD97706)], // amber
  [Color(0xFFF97316), Color(0xFFEA580C)], // orange
  [Color(0xFF3B82F6), Color(0xFF2563EB)], // blue
  [Color(0xFFEC4899), Color(0xFFDB2777)], // pink
  [Color(0xFF8B5CF6), Color(0xFF7C3AED)], // violet
  [Color(0xFF14B8A6), Color(0xFF0D9488)], // teal
];

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  String _filter = 'all'; // 'all' | 'attention' | 'online' | 'expiring'
  String _searchQuery = '';

  // Date range state — default: first of current month to today
  late DateTimeRange _dateRange;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showCompactDateRangePicker(
      context: context,
      initialStart: _dateRange.start,
      initialEnd: _dateRange.end,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  // ── Computed filtered metrics ──
  List<PremiumPaymentModel> _filteredPayments(ManagementStore store) {
    return context.watch<ManagementStore>().premiumPayments.where((p) {
      return !p.paidAt.isBefore(_dateRange.start) &&
          !p.paidAt.isAfter(_dateRange.end.add(Duration(days: 1)));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ManagementStore>(
      builder: (context, store, _) {
        final storeEntries = context
            .watch<ManagementStore>()
            .storeInfos
            .entries
            .where((e) => e.key != 'sadmin')
            .toList();

        final totalStores = storeEntries.length;
        final totalStaff = context
            .watch<ManagementStore>()
            .users
            .where((u) => u.role != 'sadmin' && u.role != 'admin')
            .length;
        final totalProducts = 0;

        // ── Online count ──
        final users = context.watch<ManagementStore>().users;
        final onlineCount = storeEntries.where((e) {
          final admin = users.where((u) => u.username == e.key).firstOrNull;
          return admin?.isOnline ?? false;
        }).length;

        // ── Expiring soon count (≤7 days) ──
        final expiringCount = storeEntries
            .where(
              (e) => e.value.isPremium && (e.value.daysUntilExpiry ?? 999) <= 7,
            )
            .length;

        // ── Pending Premium request count ──
        final pendingVipCount = storeEntries.where((e) {
          return context.watch<ManagementStore>().upgradeRequests.any((r) => r.storeId == e.key && r.status == 'pending');
        }).length;

        // ── Attention count (offline + expiring) ──
        final attentionEntries = storeEntries.where((e) {
          final admin = users.where((u) => u.username == e.key).firstOrNull;
          final isOffline = !(admin?.isOnline ?? false);
          final isExpiring =
              e.value.isPremium && (e.value.daysUntilExpiry ?? 999) <= 7;
          return isOffline || isExpiring;
        }).toList();

        // ── Apply filters ──
        List<MapEntry<String, StoreInfoModel>> filteredEntries;
        switch (_filter) {
          case 'online':
            filteredEntries = storeEntries.where((e) {
              final admin = users.where((u) => u.username == e.key).firstOrNull;
              return admin?.isOnline ?? false;
            }).toList();
            break;
          case 'expiring':
            filteredEntries = storeEntries
                .where(
                  (e) =>
                      e.value.isPremium &&
                      (e.value.daysUntilExpiry ?? 999) <= 7,
                )
                .toList();
            break;
          case 'attention':
            filteredEntries = attentionEntries;
            break;
          case 'pending_vip':
            filteredEntries = storeEntries.where((e) {
              return context.read<ManagementStore>().upgradeRequests.any((r) => r.storeId == e.key && r.status == 'pending');
            }).toList();
            break;
          default:
            filteredEntries = storeEntries;
        }

        // ── Apply search ──
        if (_searchQuery.isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          filteredEntries = filteredEntries.where((e) {
            final name = e.value.name.toLowerCase();
            final phone = e.value.phone.toLowerCase();
            final id = e.key.toLowerCase();
            return name.contains(q) || phone.contains(q) || id.contains(q);
          }).toList();
        }

        // ── Date-filtered payment metrics ──
        final payments = _filteredPayments(store);
        final totalRevenue = payments.fold<int>(0, (sum, p) => sum + p.amount);
        final yearlyRevenue = payments
            .where((p) => p.months >= 12)
            .fold<int>(0, (sum, p) => sum + p.amount);
        final monthlyRevenue = payments
            .where((p) => p.months < 12)
            .fold<int>(0, (sum, p) => sum + p.amount);
        final yearlyCount = payments.where((p) => p.months >= 12).length;
        final monthlyCount = payments.where((p) => p.months < 12).length;

        // Calculate daily revenue points for the sparkline chart
        final dayCount = _dateRange.end.difference(_dateRange.start).inDays + 1;
        final List<double> revenuePoints = List.filled(
          dayCount > 0 ? dayCount : 1,
          0.0,
        );
        for (final p in payments) {
          final idx = p.paidAt.difference(_dateRange.start).inDays;
          if (idx >= 0 && idx < revenuePoints.length) {
            revenuePoints[idx] += p.amount;
          }
        }

        return Scaffold(
          backgroundColor: AppColors.scaffoldBg,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isLandscape = constraints.maxWidth >= 600;
              if (isLandscape) {
                return _LandscapeLayout(
                  store: store,
                  storeEntries: filteredEntries,
                  allEntries: storeEntries,
                  totalStores: totalStores,
                  totalStaff: totalStaff,
                  totalProducts: totalProducts,
                  pendingVipCount: expiringCount,
                  filter: _filter,
                  onFilterChanged: (f) => setState(() => _filter = f),
                  dateRange: _dateRange,
                  onPickDateRange: _pickDateRange,
                  totalRevenue: totalRevenue,
                  yearlyRevenue: yearlyRevenue,
                  monthlyRevenue: monthlyRevenue,
                  yearlyCount: yearlyCount,
                  monthlyCount: monthlyCount,
                  revenuePoints: revenuePoints,
                );
              }
              return _PortraitLayout(
                store: store,
                storeEntries: filteredEntries,
                allEntries: storeEntries,
                totalStores: totalStores,
                totalStaff: totalStaff,
                totalProducts: totalProducts,
                onlineCount: onlineCount,
                expiringCount: expiringCount,
                attentionCount: attentionEntries.length,
                filter: _filter,
                onFilterChanged: (f) => setState(() => _filter = f),
                searchQuery: _searchQuery,
                onSearchChanged: (q) => setState(() => _searchQuery = q),
                dateRange: _dateRange,
                onPickDateRange: _pickDateRange,
                totalRevenue: totalRevenue,
                yearlyRevenue: yearlyRevenue,
                monthlyRevenue: monthlyRevenue,
                yearlyCount: yearlyCount,
                monthlyCount: monthlyCount,
                revenuePoints: revenuePoints,
              );
            },
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// FILTER CHIPS ROW
// ═══════════════════════════════════════════════════════════
class _FilterChipsRow extends StatelessWidget {
  final String filter;
  final int totalCount;
  final int pendingVipCount;
  final ValueChanged<String> onFilterChanged;

  const _FilterChipsRow({
    required this.filter,
    required this.totalCount,
    required this.pendingVipCount,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterChip(
          label: 'Tất cả',
          count: totalCount,
          isActive: filter == 'all',
          onTap: () => onFilterChanged('all'),
          activeColor: AppColors.emerald500,
          activeBg: AppColors.emerald50,
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isActive;
  final VoidCallback onTap;
  final Color activeColor;
  final Color activeBg;
  final IconData? icon;
  final bool highlight;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isActive,
    required this.onTap,
    required this.activeColor,
    required this.activeBg,
    this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final isHighlighted = highlight && !isActive;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? activeColor : AppColors.slate200,
            width: 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null && !isActive) ...[
              Icon(icon, size: 14, color: Color(0xFFF59E0B)),
              SizedBox(width: 4),
            ],
            Text(
              '$label $count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? Colors.white : AppColors.slate600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// PORTRAIT LAYOUT — Fintech-style Dashboard
// ═══════════════════════════════════════════════════════════
class _PortraitLayout extends StatelessWidget {
  final ManagementStore store;
  final List<MapEntry<String, StoreInfoModel>> storeEntries;
  final List<MapEntry<String, StoreInfoModel>> allEntries;
  final int totalStores, totalStaff, totalProducts;
  final int onlineCount, expiringCount, attentionCount;
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final DateTimeRange dateRange;
  final VoidCallback onPickDateRange;
  final int totalRevenue, yearlyRevenue, monthlyRevenue;
  final int yearlyCount, monthlyCount;
  final List<double> revenuePoints;

  const _PortraitLayout({
    required this.store,
    required this.storeEntries,
    required this.allEntries,
    required this.totalStores,
    required this.totalStaff,
    required this.totalProducts,
    required this.onlineCount,
    required this.expiringCount,
    required this.attentionCount,
    required this.filter,
    required this.onFilterChanged,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.dateRange,
    required this.onPickDateRange,
    required this.totalRevenue,
    required this.yearlyRevenue,
    required this.monthlyRevenue,
    required this.yearlyCount,
    required this.monthlyCount,
    required this.revenuePoints,
  });

  @override
  Widget build(BuildContext context) {
    final premiumCount = allEntries.where((e) => e.value.isPremium).length;
    final basicCount = allEntries.length - premiumCount;

    return CustomScrollView(
      slivers: [
        // ── Header ──
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(9, 16, 9, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quản lý tài khoản hệ thống',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Super Admin Dashboard',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate400,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Overview Section ──
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(9, 14, 9, 0),
            child: Column(
              children: [
                // Date picker
                GestureDetector(
                  onTap: onPickDateRange,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.dividerColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: AppColors.slate400,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '${_formatDate(dateRange.start)} - ${_formatDate(dateRange.end)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slate500,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 16,
                          color: AppColors.slate400,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 12),

                // ── Alert Card ──
                if (expiringCount > 0) ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.red50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 20,
                          color: Color(0xFFEF4444),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Cảnh báo: $expiringCount cửa hàng sắp hết hạn trong 7 ngày',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                ],

                // ── Revenue Card ──
                Container(
                  width: double.infinity,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFB5E4CA),
                        Color(0xFFD1F2E0),
                      ], // Vibrant mint gradient
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emerald500.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Background Sparkline
                      Positioned.fill(
                        bottom: 0,
                        child: Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: CustomPaint(
                            painter: SparklinePainter(
                              data: revenuePoints,
                              // Using a slightly darker mint color for the line
                              color: Color(0xFF10B981).withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ),
                      // Foreground Content
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: 24,
                                    color: AppColors.emerald600,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Doanh thu Premium',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.slate700,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        _formatCurrency(totalRevenue),
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.slate900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            // Divider line has been removed to match the image, using text separation instead
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Gói Năm ($yearlyCount):',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.slate700,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        _formatCurrency(yearlyRevenue),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.slate900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 28,
                                  color: AppColors.emerald500.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Gói Tháng ($monthlyCount):',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.slate700,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        _formatCurrency(monthlyRevenue),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.slate900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),

                // ── 3-column Stat Row ──
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Cửa hàng (Width ~50%)
                      Expanded(
                        flex: 11,
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.emerald500,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.storefront,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '$totalStores Cửa hàng',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(
                                '$premiumCount Premium • $basicCount Basic',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                              SizedBox(height: 10),
                              // Progress bar
                              Container(
                                height: 6,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: totalStores > 0
                                      ? (premiumCount / totalStores)
                                      : 0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      // Nhân viên (Width ~25%)
                      Expanded(
                        flex: 6,
                        child: Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Color(0xFF4338CA), // Deep Indigo
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.group,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                              SizedBox(height: 6),
                              Text(
                                '$totalStaff',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Nhân viên',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      // Online (Width ~25%)
                      Expanded(
                        flex: 6,
                        child: Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Color(0xFF3B82F6), // Blue
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.wifi,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                              SizedBox(height: 6),
                              Text(
                                '$onlineCount/$totalStores',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Online',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.9),
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
        ),

        // ── Section Title + Search + Filters ──
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(9, 18, 9, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Danh sách cửa hàng',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate800,
                  ),
                ),
                SizedBox(height: 10),
                // Search bar
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.dividerColor),
                  ),
                  child: TextField(
                    onChanged: onSearchChanged,
                    style: TextStyle(fontSize: 13, color: AppColors.slate800),
                    decoration: InputDecoration(
                      hintText: 'Tìm tên, SĐT chủ shop...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: AppColors.slate400,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 18,
                        color: AppColors.slate400,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Tất cả',
                        count: allEntries.length,
                        isActive: filter == 'all',
                        onTap: () => onFilterChanged('all'),
                        activeColor: AppColors.emerald500,
                        activeBg: AppColors.emerald500,
                      ),
                      SizedBox(width: 8),
                      _FilterChip(
                        label: 'Cần chú ý',
                        count: attentionCount,
                        isActive: filter == 'attention',
                        onTap: () => onFilterChanged('attention'),
                        activeColor: AppColors.emerald500,
                        activeBg: AppColors.emerald500,
                        highlight: attentionCount > 0,
                      ),
                      SizedBox(width: 8),
                      _FilterChip(
                        label: 'Online',
                        count: onlineCount,
                        isActive: filter == 'online',
                        onTap: () => onFilterChanged('online'),
                        activeColor: AppColors.emerald500,
                        activeBg: AppColors.emerald500,
                      ),
                      SizedBox(width: 8),
                      _FilterChip(
                        label: 'Sắp hết hạn',
                        count: expiringCount,
                        isActive: filter == 'expiring',
                        onTap: () => onFilterChanged('expiring'),
                        activeColor: AppColors.emerald500,
                        activeBg: AppColors.emerald500,
                        highlight: expiringCount > 0,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
              ],
            ),
          ),
        ),

        // ── Store Grid ──
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 9),
          sliver: SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final colCount = 1;
                final useCompactCard = false;
                final bool showAddCard = filter == 'all';
                final totalItems = storeEntries.length + (showAddCard ? 1 : 0);
                final rowCount = (totalItems / colCount).ceil();

                if (storeEntries.isEmpty && filter != 'all') {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 48,
                            color: AppColors.emerald500.withValues(alpha: 0.4),
                          ),
                          SizedBox(height: 12),
                          Text(
                            filter == 'expiring'
                                ? 'Không có cửa hàng sắp hết hạn'
                                : filter == 'online'
                                ? 'Không có cửa hàng đang online'
                                : 'Không có cửa hàng cần chú ý',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: rowCount,
                  itemBuilder: (context, rowIndex) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(colCount, (colIndex) {
                          final itemIndex = rowIndex * colCount + colIndex;
                          Widget buildItem(int idx) {
                            if (showAddCard) {
                              if (idx == 0)
                                return _AddStoreCard(
                                  store: store,
                                  compact: useCompactCard,
                                );
                              final storeIdx = idx - 1;
                              if (storeIdx < storeEntries.length) {
                                return _StoreCard(
                                  storeId: storeEntries[storeIdx].key,
                                  info: storeEntries[storeIdx].value,
                                  store: store,
                                  colorIndex: storeIdx,
                                  compact: useCompactCard,
                                );
                              }
                            } else {
                              if (idx < storeEntries.length) {
                                return _StoreCard(
                                  storeId: storeEntries[idx].key,
                                  info: storeEntries[idx].value,
                                  store: store,
                                  colorIndex: idx,
                                  compact: useCompactCard,
                                );
                              }
                            }
                            return SizedBox();
                          }

                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: colIndex > 0 ? 12 : 0,
                              ),
                              child: buildItem(itemIndex),
                            ),
                          );
                        }),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

// ── Stat Card Widget ──
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor;
  final String value, label;
  final String? subtitle;

  const _StatCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.value,
    required this.label,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 15, color: iconColor),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: iconColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.slate400,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: AppColors.slate500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// LANDSCAPE LAYOUT
// ═══════════════════════════════════════════════════════════
class _LandscapeLayout extends StatelessWidget {
  final ManagementStore store;
  final List<MapEntry<String, StoreInfoModel>> storeEntries;
  final List<MapEntry<String, StoreInfoModel>> allEntries;
  final int totalStores, totalStaff, totalProducts, pendingVipCount;
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final DateTimeRange dateRange;
  final VoidCallback onPickDateRange;
  final int totalRevenue, yearlyRevenue, monthlyRevenue;
  final int yearlyCount, monthlyCount;
  final List<double> revenuePoints;

  const _LandscapeLayout({
    required this.store,
    required this.storeEntries,
    required this.allEntries,
    required this.totalStores,
    required this.totalStaff,
    required this.totalProducts,
    required this.pendingVipCount,
    required this.filter,
    required this.onFilterChanged,
    required this.dateRange,
    required this.onPickDateRange,
    required this.totalRevenue,
    required this.yearlyRevenue,
    required this.monthlyRevenue,
    required this.yearlyCount,
    required this.monthlyCount,
    required this.revenuePoints,
  });

  @override
  Widget build(BuildContext context) {
    final premiumCount = allEntries.where((e) => e.value.isPremium).length;
    final basicCount = allEntries.length - premiumCount;
    final allStaffCount = context
        .watch<ManagementStore>()
        .users
        .where((u) => u.role != 'sadmin')
        .length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Left Panel ──
        Container(
          width: 300,
          color: AppColors.cardBg,
          padding: EdgeInsets.fromLTRB(9, 16, 9, 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quản lý hệ thống',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slate800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Super Admin Dashboard',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.slate400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // Date picker
                GestureDetector(
                  onTap: onPickDateRange,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.scaffoldBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.dividerColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                          color: AppColors.slate400,
                        ),
                        SizedBox(width: 6),
                        Text(
                          '${_formatDate(dateRange.start)} - ${_formatDate(dateRange.end)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slate500,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 14,
                          color: AppColors.slate400,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 12),

                // Revenue summary
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.orange50, AppColors.amber100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            size: 14,
                            color: Color(0xFFD97706),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Doanh thu Premium',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        _formatCurrency(totalRevenue),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slate800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Gói Năm ($yearlyCount)',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.slate400,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  _formatCurrency(yearlyRevenue),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.slate800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Gói Tháng ($monthlyCount)',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.slate400,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  _formatCurrency(monthlyRevenue),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.slate800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),

                // Stats pills
                _LandscapeStatPill(
                  icon: Icons.storefront,
                  label:
                      '$totalStores CH ($premiumCount Premium • $basicCount Basic)',
                  color: AppColors.emerald500,
                  bg: AppColors.emerald50,
                ),
                SizedBox(height: 8),
                _LandscapeStatPill(
                  icon: Icons.group,
                  label: '$allStaffCount Nhân viên',
                  color: Color(0xFF6366F1),
                  bg: Color(0xFFF0F5FF),
                ),
              ],
            ),
          ),
        ),

        // ── Right Panel ──
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(9, 14, 9, 14),
            child: Column(
              children: [
                // Header + Filter
                Row(
                  children: [
                    Text(
                      'Danh sách cửa hàng',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate800,
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.emerald50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$totalStores cửa hàng',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.emerald500,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                // Filter chips
                Align(
                  alignment: Alignment.centerLeft,
                  child: _FilterChipsRow(
                    filter: filter,
                    totalCount: allEntries.length,
                    pendingVipCount: pendingVipCount,
                    onFilterChanged: onFilterChanged,
                  ),
                ),
                SizedBox(height: 10),

                // Empty state
                if (storeEntries.isEmpty && filter == 'pending_vip')
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 48,
                            color: AppColors.emerald500.withValues(alpha: 0.5),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Không có yêu cầu chờ duyệt',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  // Content Grid
                  Expanded(child: _buildLandscapeGrid(context)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final colCount = width > 1200
            ? 6
            : (width > 1000
                  ? 5
                  : (width > 800
                        ? 4
                        : (width > 600 ? 3 : (width > 340 ? 2 : 1))));

        final bool showAddCard = filter == 'all';
        final totalItems = storeEntries.length + (showAddCard ? 1 : 0);
        final rowCount = (totalItems / colCount).ceil();

        return ListView.builder(
          itemCount: rowCount,
          itemBuilder: (context, rowIndex) {
            return Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: List.generate(colCount, (colIndex) {
                    final itemIndex = rowIndex * colCount + colIndex;
                    Widget child;

                    if (showAddCard) {
                      if (itemIndex == 0) {
                        child = _AddStoreCard(store: store, compact: true);
                      } else {
                        final storeIdx = itemIndex - 1;
                        if (storeIdx < storeEntries.length) {
                          child = _StoreCard(
                            storeId: storeEntries[storeIdx].key,
                            info: storeEntries[storeIdx].value,
                            store: store,
                            colorIndex: storeIdx,
                            compact: true,
                          );
                        } else {
                          child = SizedBox();
                        }
                      }
                    } else {
                      if (itemIndex < storeEntries.length) {
                        child = _StoreCard(
                          storeId: storeEntries[itemIndex].key,
                          info: storeEntries[itemIndex].value,
                          store: store,
                          colorIndex: itemIndex,
                          compact: true,
                        );
                      } else {
                        child = SizedBox();
                      }
                    }

                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: colIndex > 0 ? 10 : 0),
                        child: child,
                      ),
                    );
                  }),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// STORE CARD — Scientific Data-Driven Format
// ═══════════════════════════════════════════════════════════
class _StoreCard extends StatelessWidget {
  final String storeId;
  final StoreInfoModel info;
  final ManagementStore store;
  final int colorIndex;
  final bool compact;

  const _StoreCard({
    required this.storeId,
    required this.info,
    required this.store,
    required this.colorIndex,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _storeColors[colorIndex % _storeColors.length];
    final staffCount = context
        .watch<ManagementStore>()
        .users
        .where((u) => u.createdBy == storeId && u.role != 'admin')
        .length;
    final storeName = info.name.isNotEmpty ? info.name : storeId;
    final isPremium = info.isPremium;

    final adminUser = context
        .watch<ManagementStore>()
        .users
        .where((u) => u.username == storeId)
        .firstOrNull;
    final isOnline = adminUser?.isOnline ?? false;

    // Use the model's correct getter for offline days
    final offlineDays = isOnline ? 0 : info.consecutiveOfflineDays;

    final hasPendingUpgrade = store.upgradeRequests.any((r) => r.storeId == storeId && r.status == 'pending');

    final cardRadius = compact ? 16.0 : 20.0;
    final cardPad = compact ? 12.0 : 16.0;
    final iconSize = compact ? 36.0 : 48.0;
    final iconInnerSize = compact ? 18.0 : 24.0;
    final iconRadius = compact ? 10.0 : 14.0;
    final nameSize = compact ? 13.0 : 15.0;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StoreDetailPage(
            storeId: storeId,
            info: info,
            store: store,
            colorIndex: colorIndex,
          ),
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(cardPad),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(cardRadius),
          border: Border.all(
            color: isOnline ? AppColors.emerald100 : AppColors.slate200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header: Icon + Name + Status ──
            Row(
              children: [
                // Store Logo/Icon
                Builder(
                  builder: (_) {
                    final hasLogo = info.logoUrl.isNotEmpty;
                    if (hasLogo) {
                      try {
                        final base64Part = info.logoUrl.split(',').last;
                        final bytes = base64Decode(base64Part);
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(iconRadius),
                          child: Image.memory(
                            bytes,
                            width: iconSize,
                            height: iconSize,
                            fit: BoxFit.cover,
                          ),
                        );
                      } catch (_) {}
                    }
                    return Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(iconRadius),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.storefront,
                        size: iconInnerSize,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              storeName,
                              style: TextStyle(
                                fontSize: nameSize + 1,
                                fontWeight: FontWeight.w800,
                                color: AppColors.slate900,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8),
                          if (hasPendingUpgrade)
                            _badge(
                              '',
                              'Chờ duyệt',
                              Color(0xFFD97706),
                              AppColors.orange50,
                            )
                          else if (isPremium)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFFDE68A),
                                    Color(0xFFF59E0B),
                                  ], // Gold gradient
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(
                                      0xFFF59E0B,
                                    ).withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                'Premium',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          else
                            _badge(
                              '',
                              'Cơ bản',
                              Color(0xFF6B7280),
                              Color(0xFFF3F4F6),
                            ),
                        ],
                      ),
                      SizedBox(height: 6),
                      // Online/Offline badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isOnline
                              ? AppColors.emerald50
                              : Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isOnline ? 'Online' : 'Ngoại tuyến',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isOnline
                                ? AppColors.emerald600
                                : Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // ── Body: Expiry & Revenue ──
            Row(
              children: [
                Expanded(
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      text: 'Hết hạn: ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate500,
                      ),
                      children: [
                        TextSpan(
                          text: info.daysUntilExpiry != null
                              ? _formatDate(DateTime.now().add(Duration(days: info.daysUntilExpiry!)))
                              : 'Không có',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      text: 'DT: ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate500,
                      ),
                      children: [
                        TextSpan(
                          text: 'N/A', // Assuming no per-store revenue info yet
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // ── Footer: Last online & Action Buttons ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    info.lastLoginAt != null
                        ? 'Đăng nhập: \n${_formatDate(info.lastLoginAt!)}'
                        : 'Chưa đăng nhập',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate400,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Gia hạn button
                    InkWell(
                      onTap: () => _showPremiumPopup(context, storeName),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.emerald500),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Gia hạn ngay',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.emerald600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    // Chi tiết button
                    InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StoreDetailPage(
                            storeId: storeId,
                            info: info,
                            store: store,
                            colorIndex: colorIndex,
                          ),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.emerald500,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.emerald500.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Chi tiết',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPremiumPopup(BuildContext context, String storeName) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.amber100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.workspace_premium,
                  size: 32,
                  color: Color(0xFFD97706),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Gia hạn Premium',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Bạn đang gia hạn/nâng cấp gói Premium cho cửa hàng "$storeName". Tính năng này hiện đang được phát triển.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.slate500,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.read<UIStore>().showToast(
                      'Tính năng gia hạn đang được phát triển',
                      'info',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Đã hiểu',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String emoji, String label, Color textColor, Color bg) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji.isNotEmpty) ...[
            Text(emoji, style: TextStyle(fontSize: 12)),
            SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        SizedBox(width: 3),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _expiryBadge(String text, Color color, Color bg) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _metricRow(
    IconData icon,
    String label,
    String value,
    double fontSize, {
    Color? color,
  }) {
    final c = color ?? Color(0xFF6B7280);
    return Row(
      children: [
        Icon(icon, size: fontSize + 2, color: AppColors.slate400),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            '$label $value',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: c,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showStoreMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final storeName = info.name.isNotEmpty ? info.name : storeId;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(9, 24, 9, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  storeName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate800,
                  ),
                ),
                SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.emerald50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: AppColors.emerald500,
                    ),
                  ),
                  title: Text(
                    'Sửa cửa hàng',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Đổi tên cửa hàng',
                    style: TextStyle(fontSize: 12, color: AppColors.slate400),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditDialog(context);
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.red50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: AppColors.red500,
                    ),
                  ),
                  title: Text(
                    'Xoá cửa hàng',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.red500,
                    ),
                  ),
                  subtitle: Text(
                    'Xoá vĩnh viễn cửa hàng và dữ liệu',
                    style: TextStyle(fontSize: 12, color: AppColors.slate400),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDeleteConfirm(context);
                  },
                ),
                SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: info.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sửa cửa hàng',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: TextField(
          controller: nameCtrl,
          decoration: InputDecoration(
            labelText: 'Tên cửa hàng',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: Icon(Icons.store),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Hủy', style: TextStyle(color: AppColors.slate400)),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              store.updateStoreInfoById(
                storeId,
                info.copyWith(name: nameCtrl.text.trim()),
              );
              context.read<UIStore>().showToast('Đã cập nhật cửa hàng!');
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Lưu', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context) {
    final storeName = info.name.isNotEmpty ? info.name : storeId;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Xoá cửa hàng?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: Text(
          'Bạn có chắc muốn xoá "$storeName"?\n\nThao tác này sẽ xoá vĩnh viễn cửa hàng, tài khoản admin và tất cả nhân viên liên quan.',
          style: TextStyle(fontSize: 14, color: AppColors.slate500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Hủy', style: TextStyle(color: AppColors.slate400)),
          ),
          ElevatedButton(
            onPressed: () {
              store.deleteStore(storeId);
              context.read<UIStore>().showToast('Đã xoá cửa hàng "$storeName"');
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Xoá', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ADD STORE CARD
// ═══════════════════════════════════════════════════════════
class _AddStoreCard extends StatelessWidget {
  final ManagementStore store;
  final bool compact;

  const _AddStoreCard({required this.store, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 40.0 : 48.0;
    final iconInnerSize = compact ? 20.0 : 24.0;
    final iconRadius = compact ? 14.0 : 16.0;
    final textSize = compact ? 11.0 : 12.0;
    final cardRadius = compact ? 16.0 : 20.0;
    final cardPad = compact ? 14.0 : 16.0;

    return GestureDetector(
      onTap: () => _showAddStoreDialog(context, store),
      child: Container(
        padding: EdgeInsets.all(cardPad),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(cardRadius),
          border: Border.all(color: AppColors.dividerColor, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: AppColors.emerald50,
                borderRadius: BorderRadius.circular(iconRadius),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.add,
                size: iconInnerSize,
                color: AppColors.emerald500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Thêm cửa hàng',
              style: TextStyle(
                fontSize: textSize,
                fontWeight: FontWeight.w600,
                color: AppColors.emerald500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddStoreDialog(BuildContext ctx, ManagementStore store) {
    final storeNameCtrl = TextEditingController();
    final fullnameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    bool obscurePassword = true;

    showGeneralDialog(
      context: ctx,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: Duration(milliseconds: 200),
      pageBuilder: (dialogCtx, anim1, anim2) {
        return StatefulBuilder(
          builder: (stfCtx, setState) {
            return Material(
              type: MaterialType.transparency,
              child: Center(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: 480,
                      maxHeight: MediaQuery.of(stfCtx).size.height - 40,
                    ),
                    margin: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 20,
                      bottom: MediaQuery.of(stfCtx).viewInsets.bottom + 20,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 30,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Header ──
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 22,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFECFDF5), AppColors.cardBg],
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardBg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColors.emerald100,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.storefront,
                                    color: AppColors.emerald600,
                                    size: 24,
                                  ),
                                ),
                                SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Thêm cửa hàng mới',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.slate800,
                                        ),
                                      ),
                                      Text(
                                        'Tạo tài khoản admin & thông tin shop',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.slate500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(dialogCtx),
                                  icon: Icon(
                                    Icons.close,
                                    color: AppColors.slate400,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── Body ──
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              children: [
                                _buildModernField(
                                  'Tên cửa hàng',
                                  Icons.store,
                                  storeNameCtrl,
                                  'Nhập tên cửa hàng',
                                ),
                                SizedBox(height: 14),
                                _buildModernField(
                                  'Họ tên đại diện',
                                  Icons.person_outline,
                                  fullnameCtrl,
                                  'Tên chủ shop hoặc quản lý',
                                ),
                                SizedBox(height: 14),
                                _buildModernField(
                                  'Số điện thoại',
                                  Icons.phone_outlined,
                                  phoneCtrl,
                                  'VD: 0123456789',
                                  keyboardType: TextInputType.phone,
                                ),
                                SizedBox(height: 14),
                                _buildModernField(
                                  'Địa chỉ',
                                  Icons.location_on_outlined,
                                  addressCtrl,
                                  'Địa chỉ cửa hàng (tùy chọn)',
                                ),
                                SizedBox(height: 20),
                                Container(height: 1, color: AppColors.slate100),
                                SizedBox(height: 20),
                                _buildModernField(
                                  'Tên đăng nhập',
                                  Icons.alternate_email,
                                  usernameCtrl,
                                  'Tên đăng nhập admin',
                                ),
                                SizedBox(height: 14),
                                _buildModernPasswordField(
                                  'Mật khẩu',
                                  passwordCtrl,
                                  obscurePassword,
                                  () => setState(
                                    () => obscurePassword = !obscurePassword,
                                  ),
                                ),
                                SizedBox(height: 24),
                              ],
                            ),
                          ),

                          // ── Footer ──
                          Padding(
                            padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _dialogButton(
                                    'Hủy',
                                    Colors.white,
                                    AppColors.slate600,
                                    border: AppColors.slate200,
                                    onTap: () => Navigator.pop(dialogCtx),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: _dialogButton(
                                    'Tạo ngay',
                                    AppColors.emerald500,
                                    Colors.white,
                                    isPrimary: true,
                                    onTap: () async {
                                      final username = usernameCtrl.text
                                          .trim()
                                          .toLowerCase();
                                      final password = passwordCtrl.text.trim();
                                      final fullname = fullnameCtrl.text.trim();
                                      final phone = phoneCtrl.text.trim();
                                      final storeName = storeNameCtrl.text
                                          .trim();

                                      if (username.isEmpty ||
                                          password.isEmpty ||
                                          storeName.isEmpty) {
                                        stfCtx.read<UIStore>().showToast(
                                          'Vui lòng nhập đầy đủ thông tin',
                                          'error',
                                        );
                                        return;
                                      }

                                      await stfCtx
                                          .read<ManagementStore>()
                                          .addStaff(
                                            fullname: fullname,
                                            phone: phone,
                                            username: username,
                                            password: password,
                                            storeName: storeName,
                                            role: 'admin',
                                            createdBy:
                                                store.currentUser?.username,
                                          );

                                      if (dialogCtx.mounted) {
                                        Navigator.pop(dialogCtx);
                                      }
                                    },
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
            );
          },
        );
      },
    );
  }

  Widget _buildModernField(
    String label,
    IconData icon,
    TextEditingController ctrl,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.slate700,
          ),
        ),
        SizedBox(height: 6),
        Container(
          constraints: BoxConstraints(minHeight: 50),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.slate50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.slate200),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.slate400),
              SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  keyboardType: keyboardType,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: AppColors.slate400,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  style: TextStyle(fontSize: 14, color: AppColors.slate800),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernPasswordField(
    String label,
    TextEditingController ctrl,
    bool obscure,
    VoidCallback onToggle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.slate700,
          ),
        ),
        SizedBox(height: 6),
        Container(
          constraints: BoxConstraints(minHeight: 50),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.slate50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.slate200),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 20, color: AppColors.slate400),
              SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    hintText: 'Nhập mật khẩu',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: AppColors.slate400,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  style: TextStyle(fontSize: 14, color: AppColors.slate800),
                ),
              ),
              IconButton(
                onPressed: onToggle,
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: AppColors.slate400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dialogButton(
    String label,
    Color bg,
    Color textColor, {
    Color? border,
    bool isPrimary = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: 50),
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: border != null ? Border.all(color: border, width: 1.5) : null,
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: bg.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

// ── Currency formatter ──
String _formatCurrency(int amount) {
  if (amount == 0) return '0đ';
  final formatted = amount.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return '$formattedđ';
}

// ── Date formatter (dd/MM/yyyy) ──
String _formatDate(DateTime date) {
  final utc = date.toUtc();
  return '${utc.day.toString().padLeft(2, '0')}/${utc.month.toString().padLeft(2, '0')}/${utc.year}';
}

class _LandscapeStatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, bg;
  const _LandscapeStatPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// STORE DETAIL PAGE (Sadmin → Tap on store card)
// ═══════════════════════════════════════════════════════════

