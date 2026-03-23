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
                  'Quản lý hệ thống',
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

        // ── Stats Row ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: _PortraitStatCard(
                    value: '$totalStores',
                    label: 'Cửa hàng',
                    color: AppColors.emerald500,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PortraitStatCard(
                    value: '$totalStaff',
                    label: 'Nhân viên',
                    color: const Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PortraitStatCard(
                    value: '$totalProducts',
                    label: 'Sản phẩm',
                    color: const Color(0xFFF59E0B),
                  ),
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
// STORE CARD — Enhanced with representative + phone + date info
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
    final admin = store.users.where((u) => u.username == storeId).firstOrNull;
    final staffCount = store.users.where((u) => u.createdBy == storeId && u.role == 'staff').length;
    final productCount = store.products[storeId]?.length ?? 0;
    final storeName = info.name.isNotEmpty ? info.name : storeId;

    // Representative info
    final representativeName = admin?.fullname ?? '';
    final representativePhone = admin?.phone ?? info.phone;

    // Badge logic
    final isPremium = info.isPremium;
    final hasPendingUpgrade = store.upgradeRequests.any((r) => r.username == storeId);

    // Expiry date for premium
    final expiresAt = admin?.expiresAt ?? '';

    final iconSize = compact ? 40.0 : 48.0;
    final iconInnerSize = compact ? 20.0 : 24.0;
    final iconRadius = compact ? 14.0 : 16.0;
    final nameSize = compact ? 12.0 : 14.0;
    final dateSize = compact ? 9.0 : 10.0;
    final badgeFontSize = compact ? 9.0 : 10.0;
    final statIconSize = compact ? 10.0 : 12.0;
    final statFontSize = compact ? 9.0 : 10.0;
    final statPadV = compact ? 4.0 : 5.0;
    final statPadH = compact ? 6.0 : 8.0;
    final statRadius = compact ? 6.0 : 8.0;
    final cardRadius = compact ? 16.0 : 20.0;
    final cardPad = compact ? 14.0 : 16.0;
    final cardGap = compact ? 6.0 : 8.0;
    final badgePadV = compact ? 2.0 : 3.0;
    final badgePadH = compact ? 6.0 : 8.0;
    final badgeRadius = compact ? 6.0 : 8.0;
    final badgeGap = compact ? 3.0 : 4.0;
    final emojiSize = compact ? 10.0 : 12.0;
    final infoFontSize = compact ? 9.0 : 10.0;

    return GestureDetector(
      onLongPress: () => _showStoreMenu(context),
      child: Container(
        padding: EdgeInsets.all(cardPad),
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
            // Badge row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (hasPendingUpgrade)
                  _buildIconBadge(Icons.hourglass_top, 'Đang chờ duyệt', const Color(0xFFF59E0B),
                      const Color(0xFFD97706), const Color(0xFFFFF7ED),
                      statIconSize, badgeFontSize, badgePadV, badgePadH, badgeRadius, badgeGap)
                else if (isPremium)
                  _buildBadge('👑', 'Premium', AppColors.emerald500, const Color(0xFFF0FDF4),
                      emojiSize, badgeFontSize, badgePadV, badgePadH, badgeRadius, badgeGap)
                else
                  _buildBadge('', 'Cơ bản', const Color(0xFF9CA3AF), const Color(0xFFF6F7F8),
                      emojiSize, badgeFontSize, badgePadV, badgePadH, badgeRadius, badgeGap),
              ],
            ),
            SizedBox(height: cardGap),

            // Store icon
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(iconRadius),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.storefront, size: iconInnerSize, color: Colors.white),
            ),
            SizedBox(height: cardGap),

            // Store name
            Text(
              storeName,
              style: TextStyle(
                fontSize: nameSize,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A1A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Date info — Premium shows "Ngày hết hạn: dd/mm/yyyy", others show creation date
            if (isPremium && expiresAt.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Hết hạn: ${_formatDate(expiresAt)}',
                  style: TextStyle(
                    fontSize: dateSize,
                    fontWeight: FontWeight.w500,
                    color: _isExpiringSoon(expiresAt)
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF9CA3AF),
                  ),
                ),
              )
            else if (admin?.createdAt?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  _formatDate(admin!.createdAt!),
                  style: TextStyle(
                    fontSize: dateSize,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ),

            SizedBox(height: cardGap),

            // Representative name + phone
            if (representativeName.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.person_outline, size: infoFontSize + 2, color: const Color(0xFF9CA3AF)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      representativeName,
                      style: TextStyle(
                        fontSize: infoFontSize,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            if (representativePhone.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Icon(Icons.phone_outlined, size: infoFontSize + 2, color: const Color(0xFF9CA3AF)),
                    const SizedBox(width: 4),
                    Text(
                      representativePhone,
                      style: TextStyle(
                        fontSize: infoFontSize,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: cardGap),

            // Stats row
            Row(
              children: [
                Expanded(
                  child: _StatPill(
                    icon: Icons.group,
                    iconColor: const Color(0xFF6366F1),
                    text: compact ? '$staffCount' : '$staffCount NV',
                    iconSize: statIconSize,
                    fontSize: statFontSize,
                    padV: statPadV,
                    padH: statPadH,
                    radius: statRadius,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _StatPill(
                    icon: Icons.inventory_2,
                    iconColor: const Color(0xFFF59E0B),
                    text: compact ? '$productCount' : '$productCount SP',
                    iconSize: statIconSize,
                    fontSize: statFontSize,
                    padV: statPadV,
                    padH: statPadH,
                    radius: statRadius,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isExpiringSoon(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return dt.difference(DateTime.now()).inDays <= 7;
    } catch (_) {
      return false;
    }
  }

  Widget _buildBadge(String emoji, String label, Color textColor, Color bg,
      double emojiSize, double fontSize, double padV, double padH, double radius, double gap) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: padV, horizontal: padH),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji.isNotEmpty) ...[
            Text(emoji, style: TextStyle(fontSize: emojiSize)),
            SizedBox(width: gap),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconBadge(IconData icon, String label, Color iconColor, Color textColor,
      Color bg, double iconSize, double fontSize, double padV, double padH, double radius, double gap) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: padV, horizontal: padH),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: iconColor),
          SizedBox(width: gap),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
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

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '';
    }
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

class _PortraitStatCard extends StatelessWidget {
  final String value, label;
  final Color color;
  const _PortraitStatCard({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
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

class _StatPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  final double iconSize, fontSize, padV, padH, radius;

  const _StatPill({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.iconSize,
    required this.fontSize,
    required this.padV,
    required this.padH,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: padV, horizontal: padH),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F8),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: iconColor),
          SizedBox(width: iconSize > 10 ? 4 : 3),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
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
