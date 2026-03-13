import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../store/app_store.dart';
import '../../utils/constants.dart';
import '../../utils/format.dart';
import '../../models/order_model.dart';

class KitchenPage extends StatefulWidget {
  const KitchenPage({super.key});

  @override
  State<KitchenPage> createState() => _KitchenPageState();
}

class _KitchenPageState extends State<KitchenPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _statusFilter = 'pending';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _statusFilter =
              ['pending', 'cooking', 'completed'][_tabController.index];
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final allOrders = store.visibleOrders;
    final filteredOrders =
        allOrders.where((o) => o.status == _statusFilter).toList();
    final pendingCount =
        allOrders.where((o) => o.status == 'pending').length;
    final cookingCount =
        allOrders.where((o) => o.status == 'cooking').length;
    final completedCount =
        allOrders.where((o) => o.status == 'completed').length;

    return Container(
      color: const Color(0xFFFAFBFC),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                  bottom: BorderSide(color: AppColors.slate100, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.orange50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.soup_kitchen_rounded,
                          color: AppColors.orange500, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quản Lý Bếp',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slate800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Theo dõi và xử lý đơn hàng',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.slate800,
                  unselectedLabelColor: AppColors.slate400,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  indicatorColor: AppColors.emerald500,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: [
                    _buildTab('Chờ xử lý', pendingCount, AppColors.red500),
                    _buildTab('Đang nấu', cookingCount, AppColors.amber500),
                    _buildTab('Hoàn tất', completedCount, AppColors.emerald500),
                  ],
                ),
              ],
            ),
          ),

          // Summary bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                Icon(
                  _statusFilter == 'pending'
                      ? Icons.pending_actions_rounded
                      : _statusFilter == 'cooking'
                          ? Icons.local_fire_department_rounded
                          : Icons.task_alt_rounded,
                  size: 16,
                  color: AppColors.slate400,
                ),
                const SizedBox(width: 6),
                Text(
                  '${filteredOrders.length} đơn hàng',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate500,
                  ),
                ),
              ],
            ),
          ),

          // Orders List
          Expanded(
            child: filteredOrders.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: filteredOrders.length,
                    itemBuilder: (ctx, i) {
                      return _OrderCard(order: filteredOrders[i]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int count, Color badgeColor) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.slate100,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              _statusFilter == 'pending'
                  ? Icons.pending_actions_rounded
                  : _statusFilter == 'cooking'
                      ? Icons.local_fire_department_rounded
                      : Icons.task_alt_rounded,
              size: 36,
              color: AppColors.slate300,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _statusFilter == 'pending'
                ? 'Không có đơn chờ xử lý'
                : _statusFilter == 'cooking'
                    ? 'Không có đơn đang nấu'
                    : 'Chưa có đơn hoàn tất',
            style: const TextStyle(
              color: AppColors.slate500,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Đơn hàng mới sẽ xuất hiện tại đây',
            style: TextStyle(color: AppColors.slate400, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final isLate = order.status == 'pending' && _isLate(order.time);
    final statusColor = _statusColor(order.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLate ? AppColors.red200 : AppColors.slate100,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isLate
                  ? AppColors.red50
                  : const Color(0xFFFAFBFC),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                // Status indicator
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                // Table name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            order.table.isNotEmpty
                                ? order.table
                                : '🛍️ Mang về',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.slate800,
                            ),
                          ),
                          if (isLate) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.red500,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.timer_off_outlined,
                                      size: 12, color: Colors.white),
                                  SizedBox(width: 3),
                                  Text(
                                    'Quá hạn',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTime(order.time),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.slate400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Total
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.emerald50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    formatCurrency(order.totalAmount),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.emerald600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Container(height: 1, color: AppColors.slate100),

          // Items
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: order.items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          store.updateOrderItemStatus(
                              order.id, item.id, !item.isDone);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: item.isDone
                                ? AppColors.emerald500
                                : Colors.white,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: item.isDone
                                  ? AppColors.emerald500
                                  : AppColors.slate300,
                              width: 2,
                            ),
                          ),
                          child: item.isDone
                              ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 14)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: item.isDone
                              ? AppColors.slate100
                              : AppColors.emerald50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'x${item.quantity}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: item.isDone
                                ? AppColors.slate400
                                : AppColors.emerald600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: item.isDone
                                ? AppColors.slate400
                                : AppColors.slate800,
                            decoration: item.isDone
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      if (item.note.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.amber100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.sticky_note_2_outlined,
                                  size: 12, color: AppColors.amber600),
                              const SizedBox(width: 3),
                              Text(
                                item.note,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.amber600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Actions
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                // Payment Status
                GestureDetector(
                  onTap: () {
                    final newStatus = order.paymentStatus == 'paid'
                        ? 'unpaid'
                        : 'paid';
                    store.updateOrderPaymentStatus(order.id, newStatus);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: order.paymentStatus == 'paid'
                          ? AppColors.emerald50
                          : AppColors.orange50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: order.paymentStatus == 'paid'
                            ? AppColors.emerald200
                            : AppColors.orange200,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          order.paymentStatus == 'paid'
                              ? Icons.check_circle_rounded
                              : Icons.access_time_rounded,
                          size: 14,
                          color: order.paymentStatus == 'paid'
                              ? AppColors.emerald600
                              : AppColors.orange600,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          order.paymentStatus == 'paid'
                              ? 'Đã thu'
                              : 'Chưa thu',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: order.paymentStatus == 'paid'
                                ? AppColors.emerald600
                                : AppColors.orange600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),

                // Status Action Buttons
                if (order.status == 'pending')
                  _ActionButton(
                    label: 'Bắt đầu nấu',
                    icon: Icons.local_fire_department_rounded,
                    color: AppColors.amber500,
                    onTap: () =>
                        store.updateOrderStatus(order.id, 'cooking'),
                  ),
                if (order.status == 'cooking')
                  _ActionButton(
                    label: 'Hoàn tất',
                    icon: Icons.check_circle_outline_rounded,
                    color: AppColors.emerald500,
                    onTap: () =>
                        store.updateOrderStatus(order.id, 'completed'),
                  ),
                if (order.status == 'completed')
                  _ActionButton(
                    label: 'Xoá đơn',
                    icon: Icons.delete_outline_rounded,
                    color: AppColors.red400,
                    onTap: () => store.cancelOrder(order.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isLate(String time) {
    if (time.isEmpty) return false;
    final orderTime = DateTime.tryParse(time);
    if (orderTime == null) return false;
    return DateTime.now().difference(orderTime).inMinutes > 15;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.red500;
      case 'cooking':
        return AppColors.amber500;
      case 'completed':
        return AppColors.emerald500;
      default:
        return AppColors.slate500;
    }
  }

  String _formatTime(String time) {
    if (time.isEmpty) return '';
    final dt = DateTime.tryParse(time);
    if (dt == null) return time;
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return 'Hôm nay ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        elevation: 0,
      ),
    );
  }
}
