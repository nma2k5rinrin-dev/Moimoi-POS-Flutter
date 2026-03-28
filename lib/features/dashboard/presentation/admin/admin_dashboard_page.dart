import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moimoi_pos/core/state/app_store.dart';
import 'package:moimoi_pos/features/settings/models/store_info_model.dart';
import 'package:moimoi_pos/features/premium/models/upgrade_request_model.dart';
import 'package:moimoi_pos/features/premium/models/premium_payment_model.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/widgets/date_range_picker_dialog.dart';
import 'package:moimoi_pos/services/api/cloudflare_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ── Color palette for store icons ──
const _storeColors = [
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
  String _filter = 'all'; // 'all' | 'pending_vip'

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
  List<PremiumPaymentModel> _filteredPayments(AppStore store) {
    return store.premiumPayments.where((p) {
      return !p.paidAt.isBefore(_dateRange.start) &&
          !p.paidAt.isAfter(_dateRange.end.add(const Duration(days: 1)));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStore>(
      builder: (context, store, _) {
        final storeEntries = store.storeInfos.entries
            .where((e) => e.key != 'sadmin')
            .toList();

        // Apply filter
        final filteredEntries = _filter == 'pending_vip'
            ? storeEntries.where((e) =>
                store.upgradeRequests.any((r) => r.username == e.key)).toList()
            : storeEntries;

        final totalStores = storeEntries.length;
        final totalStaff = store.users.where((u) => u.role == 'staff').length;
        final totalProducts = store.products.values
            .fold<int>(0, (sum, list) => sum + list.length);
        final pendingVipCount = store.upgradeRequests.length;

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

        return Scaffold(
          backgroundColor: AppColors.slate50,
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
                  pendingVipCount: pendingVipCount,
                  filter: _filter,
                  onFilterChanged: (f) => setState(() => _filter = f),
                  dateRange: _dateRange,
                  onPickDateRange: _pickDateRange,
                  totalRevenue: totalRevenue,
                  yearlyRevenue: yearlyRevenue,
                  monthlyRevenue: monthlyRevenue,
                  yearlyCount: yearlyCount,
                  monthlyCount: monthlyCount,
                );
              }
              return _PortraitLayout(
                store: store,
                storeEntries: filteredEntries,
                allEntries: storeEntries,
                totalStores: totalStores,
                totalStaff: totalStaff,
                totalProducts: totalProducts,
                pendingVipCount: pendingVipCount,
                filter: _filter,
                onFilterChanged: (f) => setState(() => _filter = f),
                dateRange: _dateRange,
                onPickDateRange: _pickDateRange,
                totalRevenue: totalRevenue,
                yearlyRevenue: yearlyRevenue,
                monthlyRevenue: monthlyRevenue,
                yearlyCount: yearlyCount,
                monthlyCount: monthlyCount,
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
          activeBg: const Color(0xFFF0FDF4),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'Chờ duyệt VIP',
          count: pendingVipCount,
          isActive: filter == 'pending_vip',
          onTap: () => onFilterChanged('pending_vip'),
          activeColor: const Color(0xFFF59E0B),
          activeBg: const Color(0xFFFFF7ED),
          icon: Icons.workspace_premium,
          highlight: pendingVipCount > 0,
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
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeBg : (isHighlighted ? const Color(0xFFFFF7ED) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? activeColor : (isHighlighted ? const Color(0xFFFDE68A) : const Color(0xFFE5E7EB)),
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: isActive ? [
            BoxShadow(
              color: activeColor.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isActive ? activeColor : (isHighlighted ? const Color(0xFFF59E0B) : const Color(0xFF9CA3AF))),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? activeColor : (isHighlighted ? const Color(0xFFD97706) : const Color(0xFF6B7280)),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive ? activeColor : (isHighlighted ? const Color(0xFFF59E0B) : const Color(0xFF9CA3AF)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// PORTRAIT LAYOUT
// ═══════════════════════════════════════════════════════════
class _PortraitLayout extends StatelessWidget {
  final AppStore store;
  final List<MapEntry<String, StoreInfoModel>> storeEntries;
  final List<MapEntry<String, StoreInfoModel>> allEntries;
  final int totalStores, totalStaff, totalProducts, pendingVipCount;
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final DateTimeRange dateRange;
  final VoidCallback onPickDateRange;
  final int totalRevenue, yearlyRevenue, monthlyRevenue;
  final int yearlyCount, monthlyCount;

  const _PortraitLayout({
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
  });

  @override
  Widget build(BuildContext context) {
    // ── Computed values for overview cards ──
    final premiumCount = allEntries.where((e) => e.value.isPremium).length;
    final basicCount = allEntries.length - premiumCount;

    // ── All employees across all stores (excluding sadmin) ──
    final allStaffCount = store.users.where((u) => u.role != 'sadmin').length;


    return CustomScrollView(
      slivers: [
        // ── Header ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quản lý tài khoản hệ thống',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Super Admin Dashboard',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Overview Section ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                // Date picker (interactive)
                GestureDetector(
                  onTap: onPickDateRange,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 8),
                        Text(
                          '${_formatDate(dateRange.start)} - ${_formatDate(dateRange.end)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF9CA3AF)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Revenue Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Icon
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.account_balance_wallet, size: 24, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Doanh thu gói Premium',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF9CA3AF)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatCurrency(totalRevenue),
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
                            ),
                            const SizedBox(height: 8),
                            Container(height: 1, color: const Color(0xFFF3F4F6)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Gói Năm ($yearlyCount)', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Color(0xFF9CA3AF))),
                                      const SizedBox(height: 2),
                                      Text(_formatCurrency(yearlyRevenue), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Gói Tháng ($monthlyCount)', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Color(0xFF9CA3AF))),
                                      const SizedBox(height: 2),
                                      Text(_formatCurrency(monthlyRevenue), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
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
                const SizedBox(height: 12),

                // 2-column stat grid: Stores + Staff
                Row(
                  children: [
                    // Store Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
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
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(Icons.storefront, size: 18, color: AppColors.emerald500),
                                ),
                                Text(
                                  '$totalStores',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.emerald500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text('Cửa hàng', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF9CA3AF))),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text('$premiumCount Premium', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF8B5CF6))),
                                const Text(' • ', style: TextStyle(fontSize: 10, color: Color(0xFFE5E7EB))),
                                Text('$basicCount Basic', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Premium/Basic ratio bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: Row(
                                children: [
                                  if (premiumCount > 0)
                                    Expanded(
                                      flex: premiumCount,
                                      child: Container(height: 6, color: const Color(0xFF8B5CF6)),
                                    ),
                                  if (basicCount > 0)
                                    Expanded(
                                      flex: basicCount,
                                      child: Container(height: 6, color: const Color(0xFFE5E7EB)),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Staff Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
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
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.group, size: 18, color: Color(0xFF6366F1)),
                                ),
                                Text(
                                  '$allStaffCount',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF6366F1)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text('Nhân viên', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF9CA3AF))),
                            const SizedBox(height: 6),
                            Text(
                              'Tổng nhân viên tất cả cửa hàng',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),


        // ── Section Title + Filter ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Danh sách cửa hàng',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 10),
                _FilterChipsRow(
                  filter: filter,
                  totalCount: allEntries.length,
                  pendingVipCount: pendingVipCount,
                  onFilterChanged: onFilterChanged,
                ),
              ],
            ),
          ),
        ),

        // ── Empty state when filter yields nothing ──
        if (storeEntries.isEmpty && filter == 'pending_vip')
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline, size: 48, color: AppColors.emerald500.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    const Text(
                      'Không có yêu cầu chờ duyệt',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── 2-Column Grid ──
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final colCount = width > 1200 ? 6 : (width > 1000 ? 5 : (width > 800 ? 4 : (width > 600 ? 3 : (width > 340 ? 2 : 1))));
                final useCompactCard = width < 500;
                
                final bool showAddCard = filter == 'all';
                final totalItems = storeEntries.length + (showAddCard ? 1 : 0);
                final rowCount = (totalItems / colCount).ceil();

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rowCount,
                  itemBuilder: (context, rowIndex) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                          children: List.generate(colCount, (colIndex) {
                            final itemIndex = rowIndex * colCount + colIndex;

                            Widget buildItem(int idx) {
                              if (showAddCard) {
                                if (idx == 0) return _AddStoreCard(store: store, compact: useCompactCard);
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
                              return const SizedBox();
                            }

                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(left: colIndex > 0 ? 12 : 0),
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

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// LANDSCAPE LAYOUT
// ═══════════════════════════════════════════════════════════
class _LandscapeLayout extends StatelessWidget {
  final AppStore store;
  final List<MapEntry<String, StoreInfoModel>> storeEntries;
  final List<MapEntry<String, StoreInfoModel>> allEntries;
  final int totalStores, totalStaff, totalProducts, pendingVipCount;
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final DateTimeRange dateRange;
  final VoidCallback onPickDateRange;
  final int totalRevenue, yearlyRevenue, monthlyRevenue;
  final int yearlyCount, monthlyCount;

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
  });

  @override
  Widget build(BuildContext context) {
    final premiumCount = allEntries.where((e) => e.value.isPremium).length;
    final basicCount = allEntries.length - premiumCount;
    final allStaffCount = store.users.where((u) => u.role != 'sadmin').length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Left Panel ──
        Container(
          width: 300,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                const Text(
                  'Quản lý hệ thống',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Super Admin Dashboard',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 12),

                // Date picker
                GestureDetector(
                  onTap: onPickDateRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 6),
                        Text(
                          '${_formatDate(dateRange.start)} - ${_formatDate(dateRange.end)}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down, size: 14, color: Color(0xFF9CA3AF)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Revenue summary
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
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
                          const Icon(Icons.account_balance_wallet, size: 14, color: Color(0xFFD97706)),
                          const SizedBox(width: 6),
                          const Text('Doanh thu Premium', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFD97706))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatCurrency(totalRevenue),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Gói Năm ($yearlyCount)', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Color(0xFF9CA3AF))),
                                const SizedBox(height: 2),
                                Text(_formatCurrency(yearlyRevenue), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Gói Tháng ($monthlyCount)', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Color(0xFF9CA3AF))),
                                const SizedBox(height: 2),
                                Text(_formatCurrency(monthlyRevenue), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Stats pills
                _LandscapeStatPill(
                  icon: Icons.storefront,
                  label: '$totalStores CH ($premiumCount Premium • $basicCount Basic)',
                  color: AppColors.emerald500,
                  bg: const Color(0xFFF0FDF4),
                ),
                const SizedBox(height: 8),
                _LandscapeStatPill(
                  icon: Icons.group,
                  label: '$allStaffCount Nhân viên',
                  color: const Color(0xFF6366F1),
                  bg: const Color(0xFFF0F5FF),
                ),

                // Upgrade requests summary
                if (store.upgradeRequests.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'Chờ duyệt',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.amber500,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${store.upgradeRequests.length}',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: store.upgradeRequests.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _CompactUpgradeCard(req: store.upgradeRequests[i], store: store),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),


        // ── Right Panel ──
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              children: [
                // Header + Filter
                Row(
                  children: [
                    const Text(
                      'Danh sách cửa hàng',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$totalStores cửa hàng',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.emerald500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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
                const SizedBox(height: 10),

                // Empty state
                if (storeEntries.isEmpty && filter == 'pending_vip')
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 48, color: AppColors.emerald500.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          const Text(
                            'Không có yêu cầu chờ duyệt',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF)),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  // 3-Column Grid
                  Expanded(
                    child: _buildLandscapeGrid(context),
                  ),
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
        final colCount = width > 1200 ? 6 : (width > 1000 ? 5 : (width > 800 ? 4 : (width > 600 ? 3 : (width > 340 ? 2 : 1))));
        
        final bool showAddCard = filter == 'all';
        final totalItems = storeEntries.length + (showAddCard ? 1 : 0);
        final rowCount = (totalItems / colCount).ceil();

        return ListView.builder(
          itemCount: rowCount,
          itemBuilder: (context, rowIndex) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
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
                          child = const SizedBox();
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
                        child = const SizedBox();
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
  final AppStore store;
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
    final staffCount = store.users.where((u) => u.createdBy == storeId && u.role == 'staff').length;
    final productCount = store.products[storeId]?.length ?? 0;
    final storeName = info.name.isNotEmpty ? info.name : storeId;
    final isPremium = info.isPremium;
    final isOnline = info.isOnline;
    final hasPendingUpgrade = store.upgradeRequests.any((r) => r.username == storeId);

    final cardRadius = compact ? 16.0 : 20.0;
    final cardPad = compact ? 12.0 : 16.0;
    final iconSize = compact ? 40.0 : 52.0;
    final iconInnerSize = compact ? 20.0 : 26.0;
    final iconRadius = compact ? 12.0 : 16.0;
    final nameSize = compact ? 12.0 : 15.0;
    final metricFontSize = compact ? 8.0 : 10.0;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _StoreDetailPage(storeId: storeId, info: info, store: store, colorIndex: colorIndex)),
      ),
      onLongPress: () => _showStoreMenu(context),
      child: Container(
        padding: EdgeInsets.all(cardPad),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(cardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: compact ? 8 : 12,
              offset: Offset(0, compact ? 1 : 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header: Icon + Badges ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Store Logo/Icon
                Builder(builder: (_) {
                  final hasLogo = info.logoUrl.isNotEmpty;
                  if (hasLogo) {
                    try {
                      final base64Part = info.logoUrl.split(',').last;
                      final bytes = base64Decode(base64Part);
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(iconRadius),
                        child: Image.memory(bytes, width: iconSize, height: iconSize, fit: BoxFit.cover),
                      );
                    } catch (_) {}
                  }
                  return Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: colors, begin: Alignment.topCenter, end: Alignment.bottomCenter),
                      borderRadius: BorderRadius.circular(iconRadius),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.storefront, size: iconInnerSize, color: Colors.white),
                  );
                }),
                const SizedBox(width: 4),
                // Stacked badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Tier badge
                      if (hasPendingUpgrade)
                        _badge('⏳', 'Chờ duyệt', const Color(0xFFD97706), const Color(0xFFFFF7ED))
                      else if (isPremium)
                        _badge('👑', 'Premium', AppColors.emerald500, const Color(0xFFF0FDF4))
                      else
                        _badge('', 'Cơ bản', const Color(0xFF9CA3AF), const Color(0xFFF6F7F8)),
                      const SizedBox(height: 4),
                      // Status badge
                      _badge(
                        isOnline ? '●' : '●',
                        isOnline ? 'Hoạt động' : 'Ngoại tuyến',
                        isOnline ? AppColors.emerald500 : const Color(0xFFEF4444),
                        isOnline ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 2 : 8),

            // ── Store Name ──
            Text(
              storeName,
              style: TextStyle(fontSize: nameSize, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // ── Premium/Activity Status Badge ──
            SizedBox(height: compact ? 2 : 4),
            _expiryBadge(
              isPremium 
                ? '⏳ Còn ${info.daysUntilExpiry ?? 0} ngày' 
                : '🕒 Hoạt động ${info.activeDays} ngày', 
              isPremium ? AppColors.emerald500 : const Color(0xFF6366F1), 
              isPremium ? const Color(0xFFF0FDF4) : const Color(0xFFEEF2FF)),
            SizedBox(height: compact ? 4 : 10),

            // ── Separator ──
            Container(height: 1, color: const Color(0xFFF3F4F6)),
            SizedBox(height: compact ? 4 : 8),

            // ── Activity Stats Grid ──
            _metricRow(Icons.calendar_today, 'Ngày kích hoạt:', _formatDate(info.createdAt ?? DateTime.now()), metricFontSize),
            SizedBox(height: compact ? 2 : 4),
            _metricRow(Icons.schedule, 'Hoạt động:', '${info.activeDays} ngày', metricFontSize, color: const Color(0xFF6366F1)),
            SizedBox(height: compact ? 2 : 4),
            _metricRow(
              Icons.wifi_off,
              'Offline:',
              '${info.consecutiveOfflineDays} ngày',
              metricFontSize,
              color: info.consecutiveOfflineDays > 0 ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF),
            ),
            SizedBox(height: compact ? 2 : 4),
            _metricRow(Icons.people_outline, 'Nhân viên:', '$staffCount nhân viên', metricFontSize, color: const Color(0xFF6B7280)),
            SizedBox(height: compact ? 2 : 4),
            _metricRow(Icons.inventory_2_outlined, 'Sản phẩm:', '$productCount sản phẩm', metricFontSize, color: const Color(0xFFF59E0B)),
          ],
        ),
      ),
    );
  }

  Widget _badge(String emoji, String label, Color textColor, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji.isNotEmpty) ...[
            Text(emoji, style: const TextStyle(fontSize: 10)),
            const SizedBox(width: 3),
          ],
          Text(
            label, 
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: textColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _expiryBadge(String text, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text, 
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _metricRow(IconData icon, String label, String value, double fontSize, {Color? color}) {
    final c = color ?? const Color(0xFF6B7280);
    return Row(
      children: [
        Icon(icon, size: fontSize + 2, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$label $value',
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500, color: c),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  void _showStoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final storeName = info.name.isNotEmpty ? info.name : storeId;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.slate200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(storeName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.edit_outlined, size: 20, color: AppColors.emerald500),
                  ),
                  title: const Text('Sửa cửa hàng', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Đổi tên cửa hàng', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditDialog(context);
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_outline, size: 20, color: AppColors.red500),
                  ),
                  title: const Text('Xoá cửa hàng', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.red500)),
                  subtitle: const Text('Xoá vĩnh viễn cửa hàng và dữ liệu', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDeleteConfirm(context);
                  },
                ),
                const SizedBox(height: 8),
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
        title: const Text('Sửa cửa hàng', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: TextField(
          controller: nameCtrl,
          decoration: InputDecoration(
            labelText: 'Tên cửa hàng',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.store),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF9CA3AF))),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              store.updateStoreInfoById(storeId, info.copyWith(name: nameCtrl.text.trim()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã cập nhật cửa hàng!')),
              );
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Lưu', style: TextStyle(fontWeight: FontWeight.w700)),
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
        title: const Text('Xoá cửa hàng?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: Text(
          'Bạn có chắc muốn xoá "$storeName"?\n\nThao tác này sẽ xoá vĩnh viễn cửa hàng, tài khoản admin và tất cả nhân viên liên quan.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF9CA3AF))),
          ),
          ElevatedButton(
            onPressed: () {
              store.deleteStore(storeId);
              store.showToast('Đã xoá cửa hàng "$storeName"');
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Xoá', style: TextStyle(fontWeight: FontWeight.w700)),
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
  final AppStore store;
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(cardRadius),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(iconRadius),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.add, size: iconInnerSize, color: AppColors.emerald500),
            ),
            const SizedBox(height: 8),
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

  void _showAddStoreDialog(BuildContext ctx, AppStore store) {
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
      transitionDuration: const Duration(milliseconds: 200),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 30, offset: const Offset(0, 10)),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Header ──
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFECFDF5), Colors.white],
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.emerald100)),
                                  child: const Icon(Icons.storefront, color: AppColors.emerald600, size: 24),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Thêm cửa hàng mới', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.slate800)),
                                      Text('Tạo tài khoản admin & thông tin shop', style: TextStyle(fontSize: 12, color: AppColors.slate500)),
                                    ],
                                  ),
                                ),
                                IconButton(onPressed: () => Navigator.pop(dialogCtx), icon: const Icon(Icons.close, color: AppColors.slate400, size: 20)),
                              ],
                            ),
                          ),

                          // ── Body ──
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              children: [
                                _buildModernField('Tên cửa hàng', Icons.store, storeNameCtrl, 'Nhập tên cửa hàng'),
                                const SizedBox(height: 14),
                                _buildModernField('Họ tên đại diện', Icons.person_outline, fullnameCtrl, 'Tên chủ shop hoặc quản lý'),
                                const SizedBox(height: 14),
                                _buildModernField('Số điện thoại', Icons.phone_outlined, phoneCtrl, 'VD: 0123456789', keyboardType: TextInputType.phone),
                                const SizedBox(height: 14),
                                _buildModernField('Địa chỉ', Icons.location_on_outlined, addressCtrl, 'Địa chỉ cửa hàng (tùy chọn)'),
                                const SizedBox(height: 20),
                                Container(height: 1, color: AppColors.slate100),
                                const SizedBox(height: 20),
                                _buildModernField('Tên đăng nhập', Icons.alternate_email, usernameCtrl, 'Tên đăng nhập admin'),
                                const SizedBox(height: 14),
                                _buildModernPasswordField('Mật khẩu', passwordCtrl, obscurePassword, () => setState(() => obscurePassword = !obscurePassword)),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),

                          // ── Footer ──
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _dialogButton('Hủy', Colors.white, AppColors.slate600, border: AppColors.slate200, onTap: () => Navigator.pop(dialogCtx)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _dialogButton('Tạo ngay', AppColors.emerald500, Colors.white, isPrimary: true, onTap: () async {
                                    final username = usernameCtrl.text.trim().toLowerCase();
                                    final password = passwordCtrl.text.trim();
                                    final fullname = fullnameCtrl.text.trim();
                                    final phone = phoneCtrl.text.trim();
                                    final storeName = storeNameCtrl.text.trim();
                                    final address = addressCtrl.text.trim();

                                    if (username.isEmpty || password.isEmpty || storeName.isEmpty) {
                                      store.showToast('Vui lòng nhập đầy đủ thông tin', 'error');
                                      return;
                                    }

                                    await store.addStaff(
                                      fullname: fullname,
                                      phone: phone,
                                      username: username,
                                      password: password,
                                      storeName: storeName,
                                      role: 'admin',
                                      createdBy: store.currentUser?.username,
                                    );

                                    if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                                  }),
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

  Widget _buildModernField(String label, IconData icon, TextEditingController ctrl, String hint, {TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate700)),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.slate200)),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.slate400),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  keyboardType: keyboardType,
                  decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(fontSize: 14, color: AppColors.slate400), border: InputBorder.none, isDense: true),
                  style: const TextStyle(fontSize: 14, color: AppColors.slate800),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernPasswordField(String label, TextEditingController ctrl, bool obscure, VoidCallback onToggle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate700)),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.slate200)),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, size: 20, color: AppColors.slate400),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  obscureText: obscure,
                  decoration: const InputDecoration(hintText: 'Nhập mật khẩu', hintStyle: TextStyle(fontSize: 14, color: AppColors.slate400), border: InputBorder.none, isDense: true),
                  style: const TextStyle(fontSize: 14, color: AppColors.slate800),
                ),
              ),
              IconButton(onPressed: onToggle, icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppColors.slate400)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dialogButton(String label, Color bg, Color textColor, {Color? border, bool isPrimary = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: border != null ? Border.all(color: border, width: 1.5) : null,
          boxShadow: isPrimary ? [BoxShadow(color: bg.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
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
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
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


class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;
  final bool obscure;

  const _DialogField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: Icon(icon),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// UPGRADE REQUEST CARDS
// ═══════════════════════════════════════════════════════════
class _CompactUpgradeCard extends StatelessWidget {
  final UpgradeRequestModel req;
  final AppStore store;
  const _CompactUpgradeCard({required this.req, required this.store});

  @override
  Widget build(BuildContext context) {
    final storeName = store.storeInfos[req.username]?.name ?? req.username;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(storeName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('Gói ${req.planName} (${req.months}th)', style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => store.approveUpgrade(req.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.emerald500,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: const Text('Duyệt', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  onTap: () => store.rejectUpgrade(req.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: const Text('Từ chối', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF))),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// STORE DETAIL PAGE (Sadmin → Tap on store card)
// ═══════════════════════════════════════════════════════════
class _StoreDetailPage extends StatelessWidget {
  final String storeId;
  final StoreInfoModel info;
  final AppStore store;
  final int colorIndex;

  const _StoreDetailPage({
    required this.storeId,
    required this.info,
    required this.store,
    required this.colorIndex,
  });

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    final d = dt.toUtc();
    return '${d.day.toString().padLeft(2, '0')} Tháng ${d.month.toString().padLeft(2, '0')}, ${d.year}';
  }

  String _fmtCurrency(double amount) {
    if (amount >= 1e9) return '${(amount / 1e9).toStringAsFixed(1)}B';
    if (amount >= 1e6) return '${(amount / 1e6).toStringAsFixed(1)}M';
    if (amount >= 1e3) return '${(amount / 1e3).toStringAsFixed(0)}K';
    return amount.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _storeColors[colorIndex % _storeColors.length];
    final storeName = info.name.isNotEmpty ? info.name : storeId;
    final isPremium = info.isPremium;
    final staffCount = store.users.where((u) => u.createdBy == storeId && u.role == 'staff').length;
    final productCount = store.products[storeId]?.length ?? 0;
    final orderCount = store.orders.where((o) => o.storeId == storeId).length;
    final totalRevenue = store.orders
        .where((o) => o.storeId == storeId && o.paymentStatus == 'paid')
        .fold<double>(0, (sum, o) => sum + o.totalAmount);
    final isActive = info.isOnline;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF1A1A1A)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(storeName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
                        const Text('Chi tiết cửa hàng', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Store Identity Card ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    // Avatar
                    Builder(builder: (_) {
                      final hasLogo = info.logoUrl.isNotEmpty;
                      if (hasLogo) {
                        if (CloudflareService.isUrl(info.logoUrl)) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: CachedNetworkImage(
                                imageUrl: info.logoUrl,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => const CircularProgressIndicator(strokeWidth: 2),
                                errorWidget: (_, _, _) => const Icon(Icons.error)),
                          );
                        }
                        try {
                          final base64Part = info.logoUrl.split(',').last;
                          final bytes = base64Decode(base64Part);
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.memory(bytes, width: 56, height: 56, fit: BoxFit.cover),
                          );
                        } catch (_) {}
                      }
                      return Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.storefront, size: 28, color: Colors.white),
                      );
                    }),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(storeName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
                          const SizedBox(height: 4),
                          Text('ID: MM-${storeId.hashCode.abs().toString().padLeft(8, '0')}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Date & Premium Badge Row ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmtDate(info.createdAt), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: isPremium ? const Color(0xFFF0FDF4) : const Color(0xFFF6F7F8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isPremium ? '👑 Premium' : 'Cơ bản',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isPremium ? AppColors.emerald500 : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Metrics Grid 2x2 ──
              Row(
                children: [
                  Expanded(child: _metricCard(Icons.attach_money, 'Doanh thu', '${_fmtCurrency(totalRevenue)}đ', const Color(0xFF10B981))),
                  const SizedBox(width: 12),
                  Expanded(child: _metricCard(Icons.people_outline, 'Nhân viên', '$staffCount', const Color(0xFF6366F1))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _metricCard(Icons.inventory_2_outlined, 'Sản phẩm', '$productCount', const Color(0xFFF59E0B))),
                  const SizedBox(width: 12),
                  Expanded(child: _metricCard(Icons.receipt_long_outlined, 'Đơn hàng', '$orderCount', const Color(0xFF3B82F6))),
                ],
              ),
              const SizedBox(height: 24),

              // ── Premium Management Section ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Gói Premium', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, size: 8, color: isActive ? AppColors.emerald500 : const Color(0xFFEF4444)),
                              const SizedBox(width: 4),
                              Text(
                                isActive ? 'Active' : 'Offline',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isActive ? AppColors.emerald500 : const Color(0xFFEF4444)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (isPremium && info.premiumExpiresAt != null) ...[
                      Row(
                        children: [
                          const Text('Hết hạn vào', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_fmtDate(info.premiumExpiresAt)} (Còn ${info.daysUntilExpiry ?? 0} ngày)',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
                      ),
                    ] else ...[
                      const Text('Cửa hàng đang dùng gói Cơ bản', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                    ],
                    const SizedBox(height: 16),
                    // Gia hạn Premium button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: Open premium extension flow
                          store.showToast('Tính năng gia hạn đang phát triển', 'info');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald500,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text('Gia hạn Premium', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Action Buttons ──
              _actionButton(
                icon: Icons.edit_outlined,
                label: 'Chỉnh sửa thông tin',
                color: const Color(0xFF1A1A1A),
                bgColor: Colors.white,
                onTap: () => _showEditStoreDialog(context),
              ),
              const SizedBox(height: 10),
              _actionButton(
                icon: Icons.lock_outline,
                label: 'Tạm khoá cửa hàng',
                color: const Color(0xFFD97706),
                bgColor: const Color(0xFFFFF7ED),
                onTap: () {
                  store.showToast('Tính năng tạm khoá đang phát triển', 'info');
                },
              ),
              const SizedBox(height: 10),
              _actionButton(
                icon: Icons.delete_outline,
                label: 'Xoá cửa hàng',
                color: const Color(0xFFEF4444),
                bgColor: const Color(0xFFFEF2F2),
                onTap: () => _showDeleteConfirm(context),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
            ),
            Icon(Icons.chevron_right, size: 20, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  void _showEditStoreDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: info.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sửa cửa hàng', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: TextField(
          controller: nameCtrl,
          decoration: InputDecoration(
            labelText: 'Tên cửa hàng',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.store),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF9CA3AF))),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              store.updateStoreInfoById(storeId, info.copyWith(name: nameCtrl.text.trim()));
              store.showToast('Đã cập nhật cửa hàng!');
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Lưu', style: TextStyle(fontWeight: FontWeight.w700)),
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
        title: const Text('Xoá cửa hàng?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: Text(
          'Bạn có chắc muốn xoá "$storeName"?\n\nThao tác này sẽ xoá vĩnh viễn cửa hàng, tài khoản admin và tất cả nhân viên liên quan.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF9CA3AF))),
          ),
          ElevatedButton(
            onPressed: () {
              store.deleteStore(storeId);
              store.showToast('Đã xoá cửa hàng "$storeName"');
              Navigator.pop(ctx);
              Navigator.of(context).pop(); // Back to dashboard
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Xoá', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
