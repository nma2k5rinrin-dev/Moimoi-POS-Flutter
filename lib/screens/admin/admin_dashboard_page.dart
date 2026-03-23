import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../store/app_store.dart';
import '../../models/upgrade_request_model.dart';
import '../../utils/constants.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStore>(
      builder: (context, store, _) {
        final allUsers = store.users;
        final storeInfos = store.storeInfos;
        final upgradeRequests = store.upgradeRequests;

        // Group users by role
        final admins = allUsers.where((u) => u.role == 'admin').toList();
        final staffList = allUsers.where((u) => u.role == 'staff').toList();
        final totalStores = storeInfos.entries.where((e) => e.key != 'sadmin').length;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: CustomScrollView(
            slivers: [
              // ── Summary Cards ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quản lý hệ thống',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slate800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tổng quan tài khoản & cửa hàng',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.slate400,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(builder: (context, constraints) {
                        final isLandscape = constraints.maxWidth > 600;
                        if (isLandscape) {
                          return Row(
                            children: [
                              Expanded(child: _StatCard(
                                icon: Icons.store, color: AppColors.emerald500,
                                bg: AppColors.emerald50, label: 'Cửa hàng', value: '$totalStores',
                              )),
                              const SizedBox(width: 10),
                              Expanded(child: _StatCard(
                                icon: Icons.admin_panel_settings, color: AppColors.violet500,
                                bg: AppColors.violet50, label: 'Admin', value: '${admins.length}',
                              )),
                              const SizedBox(width: 10),
                              Expanded(child: _StatCard(
                                icon: Icons.people, color: AppColors.blue500,
                                bg: const Color(0xFFEFF6FF), label: 'Nhân viên', value: '${staffList.length}',
                              )),
                              const SizedBox(width: 10),
                              Expanded(child: _StatCard(
                                icon: Icons.pending_actions, color: AppColors.amber500,
                                bg: const Color(0xFFFFF7ED), label: 'Chờ duyệt', value: '${upgradeRequests.length}',
                              )),
                            ],
                          );
                        }
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SizedBox(
                              width: (constraints.maxWidth - 10) / 2,
                              child: _StatCard(
                                icon: Icons.store, color: AppColors.emerald500,
                                bg: AppColors.emerald50, label: 'Cửa hàng', value: '$totalStores',
                              ),
                            ),
                            SizedBox(
                              width: (constraints.maxWidth - 10) / 2,
                              child: _StatCard(
                                icon: Icons.admin_panel_settings, color: AppColors.violet500,
                                bg: AppColors.violet50, label: 'Admin', value: '${admins.length}',
                              ),
                            ),
                            SizedBox(
                              width: (constraints.maxWidth - 10) / 2,
                              child: _StatCard(
                                icon: Icons.people, color: AppColors.blue500,
                                bg: const Color(0xFFEFF6FF), label: 'Nhân viên', value: '${staffList.length}',
                              ),
                            ),
                            SizedBox(
                              width: (constraints.maxWidth - 10) / 2,
                              child: _StatCard(
                                icon: Icons.pending_actions, color: AppColors.amber500,
                                bg: const Color(0xFFFFF7ED), label: 'Chờ duyệt', value: '${upgradeRequests.length}',
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // ── Upgrade Requests Section ──
              if (upgradeRequests.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.amber50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.pending_actions, size: 16, color: AppColors.amber500),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Yêu cầu nâng cấp',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.slate800),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.amber500,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${upgradeRequests.length}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final req = upgradeRequests[index];
                      return _UpgradeRequestCard(req: req, store: store);
                    },
                    childCount: upgradeRequests.length,
                  ),
                ),
              ],

              // ── Quick Actions ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.emerald50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.flash_on, size: 16, color: AppColors.emerald500),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Truy cập nhanh',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.slate800),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _QuickActionTile(
                        icon: Icons.settings_outlined,
                        label: 'Cài đặt hệ thống',
                        subtitle: 'Quản lý cửa hàng, nhân viên, thực đơn',
                        onTap: () => context.push('/settings'),
                      ),
                      _QuickActionTile(
                        icon: Icons.workspace_premium,
                        label: 'Quản lý Premium',
                        subtitle: 'Gia hạn, nâng cấp gói dịch vụ',
                        onTap: () => context.push('/premium'),
                      ),
                      _QuickActionTile(
                        icon: Icons.trending_up,
                        label: 'Nhập thu',
                        subtitle: 'Ghi nhận khoản thu ngoài đơn hàng',
                        onTap: () => context.push('/nhap-thu'),
                      ),
                      _QuickActionTile(
                        icon: Icons.trending_down,
                        label: 'Nhập chi',
                        subtitle: 'Ghi nhận các khoản chi phí',
                        onTap: () => context.push('/nhap-chi'),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Store List ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.emerald50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.store, size: 16, color: AppColors.emerald500),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Danh sách cửa hàng',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.slate800),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final entries = storeInfos.entries.where((e) => e.key != 'sadmin').toList();
                    final entry = entries[index];
                    final storeId = entry.key;
                    final info = entry.value;
                    final admin = allUsers.where((u) => u.username == storeId).firstOrNull;
                    final staffCount = staffList.where((u) => u.createdBy == storeId).length;

                    return _StoreCard(
                      storeName: info.name.isNotEmpty ? info.name : storeId,
                      adminName: admin?.fullname ?? storeId,
                      isPremium: info.isPremium,
                      staffCount: staffCount,
                      expiresAt: admin?.expiresAt,
                    );
                  },
                  childCount: storeInfos.entries.where((e) => e.key != 'sadmin').length,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        );
      },
    );
  }
}

// ── Stat Card ──
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final String label;
  final String value;

  const _StatCard({
    required this.icon, required this.color, required this.bg,
    required this.label, required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.slate400, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Upgrade Request Card ──
class _UpgradeRequestCard extends StatelessWidget {
  final UpgradeRequestModel req;
  final AppStore store;

  const _UpgradeRequestCard({required this.req, required this.store});

  @override
  Widget build(BuildContext context) {
    final user = store.users.where((u) => u.username == req.username).firstOrNull;
    final displayName = user?.fullname.isNotEmpty == true ? user!.fullname : req.username;
    final storeName = store.storeInfos[req.username]?.name ?? req.username;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.amber100),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.amber50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.workspace_premium, size: 20, color: AppColors.amber500),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate800),
                ),
                const SizedBox(height: 2),
                Text(
                  '$storeName • Gói ${req.planName} (${req.months} tháng)',
                  style: const TextStyle(fontSize: 12, color: AppColors.slate400),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => store.approveUpgrade(req.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.emerald500,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Duyệt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => store.rejectUpgrade(req.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.slate100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Từ chối', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.slate500)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Store Card ──
class _StoreCard extends StatelessWidget {
  final String storeName;
  final String adminName;
  final bool isPremium;
  final int staffCount;
  final String? expiresAt;

  const _StoreCard({
    required this.storeName, required this.adminName,
    required this.isPremium, required this.staffCount, this.expiresAt,
  });

  @override
  Widget build(BuildContext context) {
    String expiryText = '';
    if (expiresAt != null && expiresAt!.isNotEmpty) {
      try {
        final exp = DateTime.parse(expiresAt!);
        final daysLeft = exp.difference(DateTime.now()).inDays;
        expiryText = 'Hết hạn: ${exp.day.toString().padLeft(2, '0')}/${exp.month.toString().padLeft(2, '0')}/${exp.year} ($daysLeft ngày)';
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate100),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: AppColors.emerald50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.store, size: 22, color: AppColors.emerald500),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        storeName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isPremium) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppColors.amber500, AppColors.orange500]),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('VIP', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Admin: $adminName • $staffCount nhân viên',
                  style: const TextStyle(fontSize: 12, color: AppColors.slate400),
                ),
                if (expiryText.isNotEmpty)
                  Text(
                    expiryText,
                    style: const TextStyle(fontSize: 11, color: AppColors.slate400),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick Action Tile ──
class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon, required this.label,
    required this.subtitle, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.slate100),
            ),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.slate50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: AppColors.slate500),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate800)),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.slate400)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20, color: AppColors.slate300),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
