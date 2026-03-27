import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../store/app_store.dart';
import '../../models/store_info_model.dart';
import '../../models/upgrade_request_model.dart';
import '../../utils/constants.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    // ── Computed values for overview cards ──
    final premiumCount = allEntries.where((e) => e.value.isPremium).length;
    final basicCount = allEntries.length - premiumCount;

    final expiringSoonCount = allEntries.where((e) => e.value.isExpiringSoon).length;
    final offlineCount = allEntries.where((e) => !e.value.isOnline).length;

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
                // Date picker (display only)
                Container(
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
                      Icon(Icons.calendar_today_outlined, size: 14, color: const Color(0xFF9CA3AF)),
                      const SizedBox(width: 8),
                      Text(
                        '01/03/2026 - 27/03/2026',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
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
                            const Text(
                              '52,850,000đ',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.trending_up, size: 10, color: AppColors.emerald500),
                                      const SizedBox(width: 2),
                                      Text(
                                        '+12.5%',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.emerald500),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'so với tháng trước',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF9CA3AF)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(height: 1, color: const Color(0xFFF3F4F6)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text('Gói Năm', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Color(0xFF9CA3AF))),
                                      SizedBox(height: 2),
                                      Text('38,500,000đ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text('Gói Tháng', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Color(0xFF9CA3AF))),
                                      SizedBox(height: 2),
                                      Text('14,350,000đ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
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
                            if (expiringSoonCount > 0) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFEF4444)),
                                  const SizedBox(width: 4),
                                  Text('$expiringSoonCount sắp hết hạn', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                                ],
                              ),
                            ],
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
                                  '$totalStaff',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF6366F1)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text('Nhân viên', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF9CA3AF))),
                            const SizedBox(height: 6),
                            Text(
                              '${totalStaff - offlineCount}/$totalStaff Đang hoạt động',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.emerald500),
                            ),
                            const SizedBox(height: 6),
                            // Active ratio bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: Row(
                                children: [
                                  if (totalStaff - offlineCount > 0)
                                    Expanded(
                                      flex: totalStaff - offlineCount,
                                      child: Container(height: 6, color: AppColors.emerald500),
                                    ),
                                  if (offlineCount > 0)
                                    Expanded(
                                      flex: offlineCount,
                                      child: Container(height: 6, color: const Color(0xFFE5E7EB)),
                                    ),
                                ],
                              ),
                            ),
                            if (offlineCount > 0) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.person_off, size: 12, color: Color(0xFFEF4444)),
                                  const SizedBox(width: 4),
                                  Text('$offlineCount ngoại tuyến', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                                ],
                              ),
                            ],
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
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, rowIndex) {
                final totalItems = storeEntries.length + (filter == 'all' ? 1 : 0);
                final rowCount = (totalItems / 2).ceil();
                if (rowIndex >= rowCount) return null;

                final i1 = rowIndex * 2;
                final i2 = i1 + 1;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: i1 < storeEntries.length
                            ? _StoreCard(
                                storeId: storeEntries[i1].key,
                                info: storeEntries[i1].value,
                                store: store,
                                colorIndex: i1,
                                compact: false,
                              )
                            : (filter == 'all' ? _AddStoreCard(store: store, compact: false) : const SizedBox()),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: i2 < storeEntries.length
                            ? _StoreCard(
                                storeId: storeEntries[i2].key,
                                info: storeEntries[i2].value,
                                store: store,
                                colorIndex: i2,
                                compact: false,
                              )
                            : i2 == storeEntries.length && filter == 'all'
                                ? _AddStoreCard(store: store, compact: false)
                                : const SizedBox(),
                      ),
                    ],
                  ),
                );
              },
              childCount: ((storeEntries.length + (filter == 'all' ? 1 : 0)) / 2).ceil(),
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
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Left Panel ──
        Container(
          width: 280,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
                'Super Admin',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(height: 16),

              // Stats pills
              _LandscapeStatPill(
                icon: Icons.storefront,
                label: '$totalStores Cửa hàng',
                color: AppColors.emerald500,
                bg: const Color(0xFFF0FDF4),
              ),
              const SizedBox(height: 8),
              _LandscapeStatPill(
                icon: Icons.group,
                label: '$totalStaff Nhân viên',
                color: const Color(0xFF6366F1),
                bg: const Color(0xFFF0F5FF),
              ),
              const SizedBox(height: 8),
              _LandscapeStatPill(
                icon: Icons.inventory_2,
                label: '$totalProducts Sản phẩm',
                color: const Color(0xFFF59E0B),
                bg: const Color(0xFFFFFBEB),
              ),

              // Upgrade requests summary
              if (store.upgradeRequests.isNotEmpty) ...[
                const SizedBox(height: 20),
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
                Expanded(
                  child: ListView.builder(
                    itemCount: store.upgradeRequests.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _CompactUpgradeCard(req: store.upgradeRequests[i], store: store),
                    ),
                  ),
                ),
              ],
            ],
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
    final totalItems = storeEntries.length + (filter == 'all' ? 1 : 0);
    final colCount = 3;
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
                if (itemIndex < storeEntries.length) {
                  child = _StoreCard(
                    storeId: storeEntries[itemIndex].key,
                    info: storeEntries[itemIndex].value,
                    store: store,
                    colorIndex: itemIndex,
                    compact: true,
                  );
                } else if (itemIndex == storeEntries.length && filter == 'all') {
                  child = _AddStoreCard(store: store, compact: true);
                } else {
                  child = const SizedBox();
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
    final iconSize = compact ? 44.0 : 52.0;
    final iconInnerSize = compact ? 22.0 : 26.0;
    final iconRadius = compact ? 14.0 : 16.0;
    final nameSize = compact ? 13.0 : 15.0;
    final metricFontSize = compact ? 9.0 : 10.0;

    return GestureDetector(
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
                const Spacer(),
                // Stacked badges
                Column(
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
              ],
            ),
            const SizedBox(height: 8),

            // ── Store Name ──
            Text(
              storeName,
              style: TextStyle(fontSize: nameSize, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // ── Expiry Warning ──
            if (info.isExpired) ...[
              const SizedBox(height: 4),
              _expiryBadge('⚠️ Đã đóng cửa', const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
            ] else if (info.isExpiringSoon) ...[
              const SizedBox(height: 4),
              _expiryBadge('⏰ ${info.daysUntilExpiry} ngày hết hạn', const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
            ] else if (isPremium && info.daysUntilExpiry != null) ...[
              const SizedBox(height: 4),
              _expiryBadge('Còn ${info.daysUntilExpiry} ngày', AppColors.emerald500, const Color(0xFFF0FDF4)),
            ],
            const SizedBox(height: 10),

            // ── Separator ──
            Container(height: 1, color: const Color(0xFFF3F4F6)),
            const SizedBox(height: 8),

            // ── Scientific Stats Grid ──
            _metricRow(Icons.event_available, 'Kích hoạt:', _formatDateTime(info.premiumActivatedAt), metricFontSize),
            const SizedBox(height: 4),
            _metricRow(Icons.event_busy, 'Hết hạn:', _formatDateTime(info.premiumExpiresAt), metricFontSize),
            const SizedBox(height: 4),
            _metricRow(Icons.schedule, 'Hoạt động:', '${info.activeDays} ngày', metricFontSize),
            const SizedBox(height: 4),
            _metricRow(Icons.people_outline, 'Nhân viên:', '$staffCount nhân viên', metricFontSize, color: const Color(0xFF6366F1)),
            const SizedBox(height: 4),
            _metricRow(Icons.inventory_2_outlined, 'Sản phẩm:', '$productCount sản phẩm', metricFontSize, color: const Color(0xFFF59E0B)),
            const SizedBox(height: 4),
            _metricRow(
              Icons.wifi_off,
              'Offline:',
              '${info.totalOfflineDays} ngày',
              metricFontSize,
              color: info.totalOfflineDays > 0 ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF),
            ),
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
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: textColor)),
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
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
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
      onTap: () => _showAddStoreDialog(context),
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

  void _showAddStoreDialog(BuildContext context) {
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final fullnameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final storeNameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Thêm cửa hàng mới', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tạo tài khoản admin mới cho cửa hàng',
                style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 16),
              _DialogField(controller: storeNameCtrl, label: 'Tên cửa hàng', icon: Icons.store),
              const SizedBox(height: 12),
              _DialogField(controller: fullnameCtrl, label: 'Họ tên đại diện', icon: Icons.person),
              const SizedBox(height: 12),
              _DialogField(controller: phoneCtrl, label: 'Số điện thoại', icon: Icons.phone, keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _DialogField(controller: usernameCtrl, label: 'Tên đăng nhập', icon: Icons.alternate_email),
              const SizedBox(height: 12),
              _DialogField(controller: passwordCtrl, label: 'Mật khẩu', icon: Icons.lock_outline, obscure: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF9CA3AF))),
          ),
          ElevatedButton(
            onPressed: () async {
              final username = usernameCtrl.text.trim().toLowerCase();
              final password = passwordCtrl.text.trim();
              final fullname = fullnameCtrl.text.trim();
              final phone = phoneCtrl.text.trim();
              final storeName = storeNameCtrl.text.trim();

              if (username.isEmpty || password.isEmpty || storeName.isEmpty) {
                store.showToast('Vui lòng nhập đầy đủ thông tin', 'error');
                return;
              }
              if (password.length < 4) {
                store.showToast('Mật khẩu phải có ít nhất 4 ký tự', 'error');
                return;
              }

              Navigator.pop(ctx);
              await store.addStaff(
                fullname: fullname,
                phone: phone,
                username: username,
                password: password,
                role: 'admin',
                createdBy: store.currentUser?.username,
              );
              if (storeName.isNotEmpty && storeName != fullname) {
                final existingInfo = store.storeInfos[username];
                if (existingInfo != null) {
                  store.updateStoreInfoById(username, existingInfo.copyWith(name: storeName));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Tạo', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SHARED COMPONENTS
// ═══════════════════════════════════════════════════════════

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
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
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
