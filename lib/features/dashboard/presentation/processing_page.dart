import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moimoi_pos/core/state/app_store.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/utils/format.dart';
import 'package:moimoi_pos/features/pos_order/models/order_model.dart';

class ProcessingPage extends StatefulWidget {
  const ProcessingPage({super.key});

  @override
  State<ProcessingPage> createState() => _ProcessingPageState();
}

class _ProcessingPageState extends State<ProcessingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _statusFilter = 'pending';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _statusFilter =
              ['pending', 'cooking', 'completed', 'cancelled'][_tabController.index];
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
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final filteredOrders = allOrders.where((o) {
      if (o.status != _statusFilter) return false;
      // Completed and cancelled orders only show today's
      if (o.status == 'completed' || o.status == 'cancelled') {
        return o.time.startsWith(todayStr);
      }
      return true;
    }).toList();
    final pendingCount =
        allOrders.where((o) => o.status == 'pending').length;
    final cookingCount =
        allOrders.where((o) => o.status == 'cooking').length;
    final completedCount =
        allOrders.where((o) => o.status == 'completed' && o.time.startsWith(todayStr)).length;
    final cancelledCount =
        allOrders.where((o) => o.status == 'cancelled' && o.time.startsWith(todayStr)).length;

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
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt_long_rounded,
                          color: Color(0xFF3B82F6), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quản Lý Đơn Hàng',
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
                const SizedBox(height: 16),
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.slate800,
                  unselectedLabelColor: AppColors.slate400,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13),
                  indicatorColor: AppColors.emerald500,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: AppColors.slate200,
                  tabs: [
                    _buildTab(
                      'Chờ xử lý',
                      Icons.schedule_rounded,
                      pendingCount,
                      AppColors.red500,
                    ),
                    _buildTab(
                      'Đang xử lý',
                      Icons.soup_kitchen_rounded,
                      cookingCount,
                      AppColors.amber500,
                    ),
                    _buildTab(
                      'Hoàn tất',
                      Icons.check_circle_rounded,
                      completedCount,
                      AppColors.emerald500,
                    ),
                    _buildTab(
                      'Đã hủy',
                      Icons.cancel_rounded,
                      cancelledCount,
                      AppColors.slate400,
                    ),
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
                          : _statusFilter == 'cancelled'
                              ? Icons.cancel_rounded
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
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      int crossAxisCount;
                      if (width >= 1400) {
                        crossAxisCount = 4;
                      } else if (width >= 1000) {
                        crossAxisCount = 3;
                      } else if (width >= 768) {
                        crossAxisCount = 2;
                      } else {
                        crossAxisCount = 1;
                      }

                      if (crossAxisCount == 1) {
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: filteredOrders.length,
                          itemBuilder: (ctx, i) {
                            return _OrderCard(order: filteredOrders[i]);
                          },
                        );
                      }

                      // Multi-column layout using Wrap
                      final cardWidth = (width - 40 - (crossAxisCount - 1) * 12) / crossAxisCount;

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 0,
                          children: filteredOrders.map((order) {
                            return SizedBox(
                              width: cardWidth,
                              child: _OrderCard(order: order),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(
      String label, IconData icon, int count, Color badgeColor) {
    return Tab(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
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
                    ? 'Không có đơn đang xử lý'
                    : _statusFilter == 'cancelled'
                        ? 'Không có đơn đã hủy'
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

// ─── Static Status Bar ────────
class _StatusBar extends StatelessWidget {
  final Color color;
  final double height;
  const _StatusBar({required this.color, this.height = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ─── Order Card (collapsible, matching Pencil design 65Kok) ──
class _OrderCard extends StatefulWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _isExpanded = false;
  // Track which item is being edited (null = none)
  String? _editingItemId;
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final store = context.read<AppStore>();
    final isLate = order.status == 'pending' && _isLate(order.time);
    final statusColor = _statusColor(order.status);
    final totalItems =
        order.items.fold<int>(0, (sum, item) => sum + item.quantity);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header (tap to expand/collapse) ──
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: order.status == 'pending'
                    ? AppColors.red50
                    : order.status == 'cooking'
                        ? AppColors.orange50
                        : order.status == 'cancelled'
                            ? AppColors.slate50
                            : AppColors.emerald50,
                borderRadius: _isExpanded
                    ? const BorderRadius.vertical(top: Radius.circular(20))
                    : BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Animated left bar
                  _StatusBar(color: statusColor, height: 36),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Table + badges
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              order.table.isNotEmpty && !isDefaultTable(order.table)
                                  ? order.table
                                  : '🛍️ ${displayTableName(order.table)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: AppColors.slate800,
                              ),
                            ),
                            if (order.status == 'pending' || order.status == 'cooking')
                              GestureDetector(
                                onTap: () => _showChangeTableDialog(context, order, store),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.slate100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.swap_horiz_rounded,
                                      size: 16, color: AppColors.slate600),
                                ),
                              ),
                            if (isLate)
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
                                    Text('Quá hạn',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 10)),
                                  ],
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: order.status == 'pending'
                                    ? const Color(0xFFFEE2E2)
                                    : order.status == 'cooking'
                                        ? const Color(0xFFFEF3C7)
                                        : AppColors.emerald50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('$totalItems món',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: statusColor)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Time with elapsed minutes
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${_formatTime(order.time)}${_elapsedBadge(order.time)}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.slate400,
                                    fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        // Orderer (fullname)
                        if (order.createdBy.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Row(children: [
                              const Icon(Icons.person_rounded,
                                  size: 13, color: AppColors.slate400),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(order.createdBy,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.slate400),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ]),
                          ),
                      ],
                    ),
                  ),
                  // Right: price + payment + expand icon
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        // Price
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(formatCurrency(order.calculatedTotal),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: AppColors.emerald600)),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: order.paymentStatus == 'paid'
                                      ? AppColors.emerald50
                                      : AppColors.orange50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: order.paymentStatus == 'paid'
                                        ? AppColors.emerald200
                                        : const Color(0xFFFED7AA),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      order.paymentStatus == 'paid'
                                          ? Icons.check_circle_rounded
                                          : Icons.schedule_rounded,
                                      size: 10,
                                      color: order.paymentStatus == 'paid'
                                          ? AppColors.emerald600
                                          : const Color(0xFFEA580C),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      order.paymentStatus == 'paid'
                                          ? 'Đã thanh toán'
                                          : 'Chưa thanh toán',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: order.paymentStatus == 'paid'
                                            ? AppColors.emerald600
                                            : const Color(0xFFEA580C),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _isExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: AppColors.slate400,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Expandable body ──
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedBody(order, store),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedBody(OrderModel order, AppStore store) {
    return Column(
      children: [
        // Divider
        Container(height: 1, color: AppColors.slate100),

        // ── Items ──
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: order.items.map((item) {
              final isEditing = _editingItemId == item.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      // Checkbox
                      GestureDetector(
                        onTap: () => store.updateOrderItemStatus(
                            order.id, item.id, !item.isDone),
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
                      // Qty
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: item.isDone
                              ? AppColors.slate100
                              : AppColors.emerald50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('x${item.quantity}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: item.isDone
                                    ? AppColors.slate400
                                    : AppColors.emerald600)),
                      ),
                      const SizedBox(width: 8),
                      // Name — tap to edit note
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isEditing) {
                                _editingItemId = null;
                              } else {
                                _editingItemId = item.id;
                                _noteController.text = item.note;
                              }
                            });
                          },
                          child: Text(item.name,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: item.isDone
                                      ? AppColors.slate400
                                      : AppColors.slate800,
                                  decoration: isEditing
                                      ? TextDecoration.underline
                                      : null,
                                  decorationColor: AppColors.emerald500)),
                        ),
                      ),
                      // Price
                      Text(
                        formatCurrency(item.price * item.quantity),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emerald600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: item.isDone
                              ? AppColors.emerald50
                              : AppColors.red50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: item.isDone
                                  ? AppColors.emerald200
                                  : Colors.transparent),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                                item.isDone
                                    ? Icons.check_circle_rounded
                                    : Icons.pending_rounded,
                                size: 12,
                                color: item.isDone
                                    ? AppColors.emerald600
                                    : AppColors.red500),
                            const SizedBox(width: 3),
                            Text(
                                item.isDone ? 'Đã xong' : 'Chưa xong',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: item.isDone
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: item.isDone
                                        ? AppColors.emerald600
                                        : AppColors.red500)),
                          ],
                        ),
                      ),
                    ]),
                    // Note display (when not editing)
                    if (item.note.isNotEmpty && !isEditing)
                      Padding(
                        padding: const EdgeInsets.only(left: 44, top: 4),
                        child: Row(children: [
                          const Icon(Icons.edit_note_rounded,
                              size: 13, color: Color(0xFFD97706)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(item.note,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFFD97706))),
                          ),
                        ]),
                      ),
                    // Inline note editor (when editing)
                    if (isEditing)
                      Padding(
                        padding: const EdgeInsets.only(left: 44, top: 6),
                        child: Row(children: [
                          Expanded(
                            child: TextField(
                              controller: _noteController,
                              autofocus: true,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Nhập ghi chú...',
                                hintStyle: TextStyle(
                                    color: AppColors.slate400, fontSize: 13),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: AppColors.slate200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: AppColors.emerald500, width: 1.5),
                                ),
                              ),
                              onSubmitted: (val) {
                                store.updateOrderItemNote(
                                    order.id, item.id, val.trim());
                                setState(() => _editingItemId = null);
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              store.updateOrderItemNote(order.id, item.id,
                                  _noteController.text.trim());
                              setState(() => _editingItemId = null);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.emerald500,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _editingItemId = null),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.slate200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.close_rounded,
                                  color: AppColors.slate500, size: 16),
                            ),
                          ),
                        ]),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),

        // ── Actions ──
        Container(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(children: [
            Row(children: [
              if (order.status == 'pending' || order.status == 'cooking')
                Expanded(
                  child: GestureDetector(
                    onTap: () => store.cancelOrder(order.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.close_rounded,
                              size: 14, color: AppColors.red500),
                          SizedBox(width: 4),
                          Text('Hủy đơn',
                              style: TextStyle(
                                  color: AppColors.red500,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              if (order.status == 'pending' || order.status == 'cooking')
                const SizedBox(width: 10),
              if (order.status == 'pending')
                Expanded(
                  child: GestureDetector(
                    onTap: () => store.updateOrderStatus(order.id, 'cooking'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.amber500,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_circle_outline_rounded,
                              size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Xác nhận đơn hàng',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              if (order.status == 'cooking')
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (order.paymentStatus != 'paid') {
                        _showPaymentQR(context, order, store);
                      } else {
                        store.updateOrderStatus(order.id, 'completed');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.emerald500,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                              size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Hoàn tất',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),

            ]),
            // ── Thêm món button ──
            if (order.status == 'pending' || order.status == 'cooking') ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _showAddItemsDialog(context, order, store),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.emerald200),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline_rounded,
                          size: 16, color: AppColors.emerald600),
                      SizedBox(width: 6),
                      Text('Thêm sản phẩm',
                          style: TextStyle(
                              color: AppColors.emerald600,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
            if (order.paymentStatus != 'paid' && order.status != 'cancelled') ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _showPaymentQR(context, order, store),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.payments_rounded,
                          size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Thu tiền ngay',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ],
          ]),
        ),
      ],
    );
  }

  void _showChangeTableDialog(BuildContext context, OrderModel order, AppStore store) {
    final tables = store.currentTables;
    if (tables.isEmpty) return;

    // Separate default (★) tables from area-grouped tables
    final defaultTables = tables.where((t) => t.startsWith('★')).toList();
    final nonDefaultTables = tables.where((t) => !t.startsWith('★')).toList();

    final Map<String, List<String>> areaGroups = {};
    for (final t in nonDefaultTables) {
      final parts = t.split(' · ');
      final area = parts.length > 1 ? parts[0] : 'Mặc định';
      areaGroups.putIfAbsent(area, () => []);
      areaGroups[area]!.add(t);
    }

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horiz_rounded, color: AppColors.emerald500),
                      const SizedBox(width: 8),
                      const Text(
                        'Đổi bàn',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      const Spacer(),
                      Text(
                        'Hiện tại: ${order.table.isNotEmpty ? displayTableName(order.table) : 'Mang về'}',
                        style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      // Default tables at top
                      ...defaultTables.map((raw) {
                        final displayName = raw.substring(1); // strip ★
                        final selected = order.table == raw || (order.table.isEmpty && defaultTables.indexOf(raw) == 0);
                        return ListTile(
                          leading: const Icon(Icons.shopping_bag_outlined,
                              color: AppColors.orange500),
                          title: Text(displayName,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          trailing: selected
                              ? const Icon(Icons.check_circle, color: AppColors.emerald500)
                              : null,
                          onTap: () {
                            Navigator.of(dialogCtx, rootNavigator: true).pop();
                            store.updateOrderTable(order.id, raw);
                          },
                        );
                      }),
                      ...areaGroups.entries.map((entry) {
                        final areaName = entry.key;
                        final areaTables = entry.value;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Text(
                                areaName.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.slate400,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            ...areaTables.map((t) {
                              final parts = t.split(' · ');
                              final tableName = parts.length > 1 ? parts.sublist(1).join(' · ') : t;
                              final isCurrent = order.table == t;
                              return ListTile(
                                leading: Icon(
                                    Icons.table_restaurant_outlined,
                                    color: isCurrent ? AppColors.emerald500 : AppColors.slate500),
                                title: Text(tableName,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isCurrent ? AppColors.emerald600 : AppColors.slate800)),
                                trailing: isCurrent
                                    ? const Icon(Icons.check_circle, color: AppColors.emerald500)
                                    : null,
                                onTap: () {
                                  Navigator.of(dialogCtx, rootNavigator: true).pop();
                                  store.updateOrderTable(order.id, t);
                                },
                              );
                            }),
                          ],
                        );
                      }),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPaymentQR(BuildContext context, OrderModel order, AppStore store) {
    final storeInfo = store.currentStoreInfo;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'payment',
      barrierColor: Colors.transparent,
      pageBuilder: (ctx, _, _) => Stack(
        children: [
          // Blur backdrop
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(color: const Color(0x66000000)),
              ),
            ),
          ),
          // Centered QR panel
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 32,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Thanh toán đơn hàng',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  color: AppColors.slate800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                order.table.isNotEmpty
                                    ? order.table
                                    : displayTableName(order.table),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.slate400,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () => Navigator.pop(ctx),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.slate100,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.close,
                                  size: 18, color: AppColors.slate500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 1, color: AppColors.slate100),

                    // QR Body
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                      child: Column(
                        children: [
                          // QR / bank info / prompt
                          _buildPaymentQRContent(storeInfo),
                          const SizedBox(height: 8),
                          const Text(
                            'Cần thanh toán',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.slate500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatCurrency(order.calculatedTotal),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Action buttons
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Column(
                        children: [
                          // Two paid buttons side by side
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    store.completeOrderWithPayment(order.id, 'cash');
                                  },
                                  child: Container(
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.payments_rounded, size: 20, color: Colors.white),
                                        SizedBox(width: 8),
                                        Text('Tiền mặt', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    store.completeOrderWithPayment(order.id, 'transfer');
                                  },
                                  child: Container(
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [BoxShadow(color: const Color(0xFF3B82F6).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.account_balance_rounded, size: 20, color: Colors.white),
                                        SizedBox(width: 8),
                                        Text('Chuyển khoản', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Pay later
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              width: double.infinity,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.schedule_rounded, size: 18, color: Color(0xFFF59E0B)),
                                  SizedBox(width: 8),
                                  Text('Thanh toán sau', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFFF59E0B))),
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
          ),
        ],
      ),
    );
  }

  /// Builds QR / bank info / prompt — matches payment_confirmation_dialog.
  Widget _buildPaymentQRContent(storeInfo) {
    final hasQr = storeInfo.qrImageUrl.isNotEmpty;
    final hasBank = storeInfo.bankId.isNotEmpty &&
        storeInfo.bankAccount.isNotEmpty &&
        storeInfo.bankOwner.isNotEmpty;

    if (hasQr) {
      Uint8List? qrBytes;
      try {
        final base64Part = storeInfo.qrImageUrl.split(',').last;
        qrBytes = base64Decode(base64Part);
      } catch (_) {}

      return Container(
        width: 280,
        height: 280,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.slate200),
        ),
        child: qrBytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.memory(
                  qrBytes,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(Icons.broken_image, size: 40, color: AppColors.slate300),
                  ),
                ),
              )
            : const Center(
                child: Icon(Icons.qr_code_rounded, size: 80, color: AppColors.slate300),
              ),
      );
    }

    if (hasBank) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.slate50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Column(
          children: [
            const Icon(Icons.account_balance_rounded, size: 28, color: AppColors.emerald500),
            const SizedBox(height: 8),
            Text(storeInfo.bankId, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate700)),
            const SizedBox(height: 4),
            Text(storeInfo.bankAccount, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.slate800, letterSpacing: 1.5)),
            const SizedBox(height: 4),
            Text(storeInfo.bankOwner, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.slate500)),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: const Column(
        children: [
          Icon(Icons.info_outline_rounded, size: 28, color: Color(0xFFF59E0B)),
          SizedBox(height: 8),
          Text('Chưa có thông tin thanh toán', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFB45309))),
          SizedBox(height: 4),
          Text('Vào Cài đặt → Thông tin cửa hàng để chọn ảnh QR hoặc nhập STK', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFFD97706))),
        ],
      ),
    );
  }

  // ── Add Items Dialog ────────────────────────────────
  void _showAddItemsDialog(
      BuildContext context, OrderModel order, AppStore store) {
    final allProducts = store.currentProducts
        .where((p) => !p.isOutOfStock)
        .toList();
    final allCategories = store.currentCategories;
    // Temp cart for new items
    final Map<String, int> tempCart = {};
    final Map<String, String> tempNotes = {};
    String searchQuery = '';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'add-items',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, a1, a2) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                  child: Container(color: const Color(0x66000000)),
                ),
              ),
            ),
            Center(
              child: Material(
                color: Colors.transparent,
                child: StatefulBuilder(
                  builder: (ctx2, setState2) {
                    // Filter products by search
                    final filtered = searchQuery.isEmpty
                        ? allProducts
                        : allProducts
                            .where((p) => p.name
                                .toLowerCase()
                                .contains(searchQuery.toLowerCase()))
                            .toList();
                    // Calculate temp cart total
                    double addedTotal = 0;
                    int addedCount = 0;
                    tempCart.forEach((id, qty) {
                      final p = allProducts.where((x) => x.id == id).firstOrNull;
                      if (p != null) {
                        addedTotal += p.price * qty;
                        addedCount += qty;
                      }
                    });

                    return Container(
                      width: MediaQuery.of(context).size.width > 600 ? 420 : MediaQuery.of(context).size.width - 32,
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.75,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 32,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFF0FDF4), Colors.white],
                              ),
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.add_shopping_cart_rounded,
                                    color: AppColors.emerald600, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Thêm sản phẩm vào đơn',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.slate800,
                                        ),
                                      ),
                                      Text(
                                        order.table.isNotEmpty
                                            ? order.table
                                            : displayTableName(order.table),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.slate400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.pop(ctx),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppColors.slate100,
                                      borderRadius:
                                          BorderRadius.circular(16),
                                    ),
                                    child: const Icon(Icons.close,
                                        size: 18,
                                        color: AppColors.slate500),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Search field
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: TextField(
                              onChanged: (v) => setState2(() => searchQuery = v),
                              decoration: InputDecoration(
                                hintText: 'Tìm sản phẩm...',
                                hintStyle: TextStyle(
                                  color: AppColors.slate400.withValues(alpha: 0.7),
                                  fontSize: 14,
                                ),
                                prefixIcon: const Icon(Icons.search_rounded,
                                    color: AppColors.slate400, size: 20),
                                prefixIconConstraints:
                                    const BoxConstraints(minWidth: 44),
                                filled: true,
                                fillColor: AppColors.slate50,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: AppColors.slate200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: AppColors.emerald500, width: 1.5),
                                ),
                              ),
                              style: const TextStyle(
                                  fontSize: 14, color: AppColors.slate800),
                            ),
                          ),

                          Container(height: 1, color: AppColors.slate100),

                          // Product grid (2 columns)
                          Flexible(
                            child: filtered.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(40),
                                    child: Center(
                                      child: Text('Không tìm thấy sản phẩm',
                                          style: TextStyle(
                                              color: AppColors.slate400)),
                                    ),
                                  )
                                : GridView.builder(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      childAspectRatio: 0.72,
                                    ),
                                    itemCount: filtered.length,
                                    itemBuilder: (_, i) {
                                      final p = filtered[i];
                                      final qty = tempCart[p.id] ?? 0;
                                      return GestureDetector(
                                        onTap: () {
                                          setState2(() {
                                            tempCart[p.id] = (tempCart[p.id] ?? 0) + 1;
                                          });
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: qty > 0
                                                  ? AppColors.emerald500
                                                  : AppColors.slate100,
                                              width: qty > 0 ? 2 : 1,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.04),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Stack(
                                            children: [
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  // Product image (fills top)
                                                  Expanded(
                                                    child: Container(
                                                      width: double.infinity,
                                                      decoration: const BoxDecoration(
                                                        color: AppColors.slate50,
                                                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                                      ),
                                                      child: p.image.isNotEmpty
                                                          ? ClipRRect(
                                                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                                              child: p.image.startsWith('data:')
                                                                  ? Image.memory(
                                                                      base64Decode(p.image.split(',').last),
                                                                      fit: BoxFit.cover,
                                                                      cacheWidth: 300,
                                                                      cacheHeight: 300,
                                                                      errorBuilder: (_, _, _) => Center(
                                                                        child: Icon(Icons.restaurant_rounded,
                                                                            color: AppColors.slate300.withValues(alpha: 0.6), size: 36),
                                                                      ),
                                                                    )
                                                                  : Image.network(
                                                                      p.image,
                                                                      fit: BoxFit.cover,
                                                                      cacheWidth: 300,
                                                                      cacheHeight: 300,
                                                                      errorBuilder: (_, _, _) => Center(
                                                                        child: Icon(Icons.restaurant_rounded,
                                                                            color: AppColors.slate300.withValues(alpha: 0.6), size: 36),
                                                                      ),
                                                                    ),
                                                            )
                                                          : Center(
                                                              child: Icon(Icons.restaurant_rounded,
                                                                  color: AppColors.slate300.withValues(alpha: 0.6), size: 36),
                                                            ),
                                                    ),
                                                  ),
                                                  // Name
                                                  Padding(
                                                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
                                                    child: Text(p.name,
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w700,
                                                          color: AppColors.slate800,
                                                          height: 1.3,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis),
                                                  ),
                                                  // Price
                                                  Padding(
                                                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                                                    child: Text(
                                                        formatCurrency(p.price),
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.w800,
                                                          color: AppColors.emerald500,
                                                        )),
                                                  ),
                                                  // Qty stepper row
                                                  if (qty > 0)
                                                    GestureDetector(
                                                      onTap: () {}, // absorb tap
                                                      child: Container(
                                                        height: 36,
                                                        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                                                        decoration: BoxDecoration(
                                                          color: AppColors.slate50,
                                                          borderRadius: BorderRadius.circular(10),
                                                          border: Border.all(color: AppColors.slate200),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            Expanded(
                                                              child: InkWell(
                                                                onTap: () {
                                                                  setState2(() {
                                                                    if (qty <= 1) {
                                                                      tempCart.remove(p.id);
                                                                      tempNotes.remove(p.id);
                                                                    } else {
                                                                      tempCart[p.id] = qty - 1;
                                                                    }
                                                                  });
                                                                },
                                                                child: Center(
                                                                  child: Icon(
                                                                    qty <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
                                                                    size: 18,
                                                                    color: qty <= 1 ? AppColors.red400 : AppColors.slate600,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            Container(width: 1, height: 18, color: AppColors.slate200),
                                                            Expanded(
                                                              child: Center(
                                                                child: Text('$qty',
                                                                    style: const TextStyle(
                                                                      fontWeight: FontWeight.w700,
                                                                      fontSize: 15,
                                                                      color: AppColors.slate800,
                                                                    )),
                                                              ),
                                                            ),
                                                            Container(width: 1, height: 18, color: AppColors.slate200),
                                                            Expanded(
                                                              child: InkWell(
                                                                onTap: () {
                                                                  setState2(() {
                                                                    tempCart[p.id] = qty + 1;
                                                                  });
                                                                },
                                                                child: const Center(
                                                                  child: Icon(Icons.add_rounded,
                                                                      size: 18, color: AppColors.slate600),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    )
                                                  else
                                                    Container(
                                                      height: 36,
                                                      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.slate50,
                                                        borderRadius: BorderRadius.circular(10),
                                                        border: Border.all(color: AppColors.slate200),
                                                      ),
                                                      child: const Center(
                                                        child: Icon(Icons.add_rounded, size: 20, color: AppColors.slate400),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              // Qty badge
                                              if (qty > 0)
                                                Positioned(
                                                  top: 8,
                                                  right: 8,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 7, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.emerald500,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text('x$qty',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700,
                                                        )),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),

                          // Footer - confirm
                          if (addedCount > 0) ...[
                            Container(height: 1, color: AppColors.slate100),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 16),
                              child: GestureDetector(
                                onTap: () {
                                  // Merge new items into existing order
                                  final newItems =
                                      List<OrderItemModel>.from(order.items);
                                  tempCart.forEach((productId, qty) {
                                    final product = allProducts
                                        .where((p) => p.id == productId)
                                        .firstOrNull;
                                    if (product == null) return;
                                    final existingIdx = newItems
                                        .indexWhere((i) => i.id == productId);
                                    if (existingIdx >= 0) {
                                      newItems[existingIdx] =
                                          newItems[existingIdx].copyWith(
                                        quantity:
                                            newItems[existingIdx].quantity +
                                                qty,
                                      );
                                    } else {
                                      newItems.add(OrderItemModel(
                                        id: productId,
                                        name: product.name,
                                        price: product.price,
                                        quantity: qty,
                                        image: product.image,
                                        note: tempNotes[productId] ?? '',
                                      ));
                                    }
                                  });
                                  final newTotal = newItems.fold<double>(
                                      0,
                                      (sum, i) =>
                                          sum + (i.price * i.quantity));
                                  store.updateOrderItems(
                                      order.id, newItems, newTotal);
                                  Navigator.pop(ctx);
                                  store.showToast(
                                      'Đã thêm $addedCount món vào đơn!');
                                },
                                child: Container(
                                  width: double.infinity,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF10B981),
                                        Color(0xFF059669)
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF10B981)
                                            .withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                          Icons.add_circle_outline_rounded,
                                          color: Colors.white,
                                          size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Thêm $addedCount món · ${formatCurrency(addedTotal)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (ctx, a1, a2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
              parent: a1, curve: Curves.easeOutCubic),
          child: FadeTransition(opacity: a1, child: child),
        );
      },
    );
  }

  Widget _miniBtn(
      {required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.slate100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
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

  /// Clock time only (e.g. "10:23")
  String _formatTime(String time) {
    if (time.isEmpty) return '';
    final dt = DateTime.tryParse(time);
    if (dt == null) return time;
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Elapsed minutes badge (e.g. " · 25 phút")
  String _elapsedBadge(String time) {
    if (time.isEmpty) return '';
    final dt = DateTime.tryParse(time);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return ' · < 1 phút';
    if (diff.inMinutes < 60) return ' · ${diff.inMinutes} phút';
    return ' · ${diff.inHours} giờ ${diff.inMinutes % 60} phút';
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
