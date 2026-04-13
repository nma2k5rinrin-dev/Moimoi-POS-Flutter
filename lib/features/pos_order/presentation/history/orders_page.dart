import 'dart:async';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:moimoi_pos/services/api/cloudflare_service.dart';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moimoi_pos/core/state/ui_store.dart';
import 'package:moimoi_pos/core/state/order_filter_store.dart';
import 'package:moimoi_pos/core/state/audio_store_standalone.dart';
import 'package:moimoi_pos/features/pos_order/logic/order_store_standalone.dart';
import 'package:moimoi_pos/features/auth/logic/auth_store_standalone.dart';
import 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';
import 'package:moimoi_pos/features/inventory/logic/inventory_store_standalone.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/utils/format.dart';
import 'package:moimoi_pos/features/pos_order/models/order_model.dart';
import 'package:moimoi_pos/core/widgets/date_range_picker_dialog.dart';
import 'package:moimoi_pos/core/utils/image_helper.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _statusFilter = 'pending';
  bool _sortNewestFirst = false;

  DateTimeRange? _selectedDateRange;
  List<OrderModel>? _customOrders;
  bool _isLoadingDateRange = false;
  bool _isLoadingMore = false;
  bool _hasMoreHistory = true;

  // Track collapsed order IDs so state persists across tab switches
  final Set<String> _collapsedOrderIds = {};

  late ScrollController _scrollController;
  StreamSubscription<String>? _scrollToTopSub;
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_selectedDateRange != null && !_isLoadingMore && _hasMoreHistory) {
        _loadMoreHistory(context.read<OrderFilterStore>());
      }
    }
  }

  Future<void> _loadMoreHistory(OrderFilterStore filterStore) async {
    if (_selectedDateRange == null || _customOrders == null) return;
    setState(() => _isLoadingMore = true);
    try {
      final endOfDay = _selectedDateRange!.end.add(
        const Duration(hours: 23, minutes: 59, seconds: 59),
      );
      final moreOrders = await filterStore.fetchOrdersByDateRange(
        _selectedDateRange!.start,
        endOfDay,
        offset: _customOrders!.length,
        limit: 10,
      );
      if (mounted) {
        setState(() {
          if (moreOrders.isEmpty || moreOrders.length < 10) {
            _hasMoreHistory = false;
          }
          _customOrders!.addAll(moreOrders);
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final picked = await showCompactDateRangePicker(
      context: context,
      initialStart: _selectedDateRange?.start ?? DateTime.now(),
      initialEnd: _selectedDateRange?.end ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      final now = DateTime.now();
      if (picked.start.year == now.year &&
          picked.start.month == now.month &&
          picked.start.day == now.day &&
          picked.end.year == now.year &&
          picked.end.month == now.month &&
          picked.end.day == now.day) {
        setState(() {
          _selectedDateRange = null;
          _customOrders = null;
          _isLoadingDateRange = false;
        });
        return;
      }

      final filterStore = context.read<OrderFilterStore>();
      setState(() {
        _selectedDateRange = picked;
        _isLoadingDateRange = true;
      });
      try {
        final endOfDay = picked.end.add(
          const Duration(hours: 23, minutes: 59, seconds: 59),
        );
        final orders = await filterStore.fetchOrdersByDateRange(
          picked.start,
          endOfDay,
          offset: 0,
          limit: 10,
        );
        if (mounted) {
          setState(() {
            _customOrders = orders;
            _hasMoreHistory = orders.length == 10;
            _isLoadingDateRange = false;
          });
        }
      } catch (e) {
        if (mounted) {
          context.read<UIStore>().showToast('Lỗi tải dữ liệu: $e');
          setState(() => _isLoadingDateRange = false);
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToTopSub = context.read<UIStore>().scrollToTopStream.listen((
        path,
      ) {
        if (path == '/orders' && mounted) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        }
      });
    });
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _statusFilter = [
            'pending',
            'processing',
            'completed',
            'cancelled',
          ][_tabController.index];
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollToTopSub?.cancel();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderFilter = context.watch<OrderFilterStore>();
    final orderStore = context.watch<OrderStore>();
    final auth = context.watch<AuthStore>();
    final allOrders = _selectedDateRange != null
        ? (_customOrders ?? []).map((co) {
            final liveIdx = orderStore.orders.indexWhere((o) => o.id == co.id);
            return liveIdx != -1 ? orderStore.orders[liveIdx] : co;
          }).toList()
        : orderFilter.visibleOrders;
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    final filteredOrders =
        allOrders.where((o) {
          if (o.status != _statusFilter) return false;
          // Completed and cancelled orders only show today's if NOT using custom date
          if (_selectedDateRange == null &&
              (o.status == 'completed' || o.status == 'cancelled')) {
            return o.time.startsWith(todayStr);
          }
          return true;
        }).toList()..sort(
          (a, b) => _sortNewestFirst
              ? b.time.compareTo(a.time) // newest first
              : a.time.compareTo(b.time),
        ); // oldest first
    final pendingCount = allOrders.where((o) => o.status == 'pending').length;
    final processingCount = allOrders.where((o) => o.status == 'processing').length;
    final completedCount = allOrders
        .where(
          (o) =>
              o.status == 'completed' &&
              (_selectedDateRange != null || o.time.startsWith(todayStr)),
        )
        .length;
    final cancelledCount = allOrders
        .where(
          (o) =>
              o.status == 'cancelled' &&
              (_selectedDateRange != null || o.time.startsWith(todayStr)),
        )
        .length;

    return Skeletonizer(
      enabled: _isLoadingDateRange || orderStore.isLoading,
      child: Container(
        color: AppColors.scaffoldBg,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.fromLTRB(9, 20, 9, 0),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                border: Border(
                  bottom: BorderSide(color: AppColors.slate100, width: 1),
                ),
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
                        child: Icon(
                          Icons.receipt_long_rounded,
                          color: Color(0xFF3B82F6),
                          size: 22,
                        ),
                      ),
                      SizedBox(width: 12),
                      Column(
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
                      Spacer(),
                      if (auth.currentUser?.role == 'admin') ...[
                        if (_selectedDateRange != null)
                          IconButton(
                            icon: Icon(Icons.clear, color: AppColors.slate400),
                            tooltip: 'Xóa bộ lọc ngày',
                            onPressed: () => setState(() {
                              _selectedDateRange = null;
                              _customOrders = null;
                              _hasMoreHistory = false;
                            }),
                          ),
                        OutlinedButton.icon(
                          onPressed: () => _pickDateRange(context),
                          icon: Icon(Icons.date_range_rounded, size: 18),
                          label: Text(
                            _selectedDateRange == null
                                ? 'Hôm nay'
                                : '${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _selectedDateRange == null
                                ? AppColors.slate700
                                : AppColors.emerald600,
                            side: BorderSide(
                              color: _selectedDateRange == null
                                  ? AppColors.slate300
                                  : AppColors.emerald500,
                            ),
                            backgroundColor: _selectedDateRange == null
                                ? AppColors.cardBg
                                : AppColors.emerald50,
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 16),
                  TabBar(
                    controller: _tabController,
                    labelColor: AppColors.slate800,
                    unselectedLabelColor: AppColors.slate400,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
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
                        processingCount,
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
              padding: EdgeInsets.symmetric(horizontal: 9, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    _statusFilter == 'pending'
                        ? Icons.pending_actions_rounded
                        : _statusFilter == 'processing'
                        ? Icons.local_fire_department_rounded
                        : _statusFilter == 'cancelled'
                        ? Icons.cancel_rounded
                        : Icons.task_alt_rounded,
                    size: 16,
                    color: AppColors.slate400,
                  ),
                  SizedBox(width: 6),
                  Text(
                    '${filteredOrders.length} đơn hàng',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate500,
                    ),
                  ),
                  Spacer(),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _sortNewestFirst = !_sortNewestFirst),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.slate50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.slate200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _sortNewestFirst
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                            size: 14,
                            color: AppColors.slate600,
                          ),
                          SizedBox(width: 4),
                          Text(
                            _sortNewestFirst ? 'Mới nhất' : 'Cũ nhất',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Orders List
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTabList(
                      context,
                      'pending',
                      allOrders,
                      todayStr,
                    ),
                    _buildTabList(
                      context,
                      'processing',
                      allOrders,
                      todayStr,
                    ),
                    _buildTabList(
                      context,
                      'completed',
                      allOrders,
                      todayStr,
                    ),
                    _buildTabList(
                      context,
                      'cancelled',
                      allOrders,
                      todayStr,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabList(
    BuildContext context,
    String status,
    List<OrderModel> allOrders,
    String todayStr,
  ) {
    var items =
        allOrders.where((o) {
          if (o.status != status) return false;
          if (_selectedDateRange == null &&
              (o.status == 'completed' || o.status == 'cancelled')) {
            return o.time.startsWith(todayStr);
          }
          return true;
        }).toList()..sort(
          (a, b) => _sortNewestFirst
              ? b.time.compareTo(a.time)
              : a.time.compareTo(b.time),
        );

    if (items.isEmpty) return _buildEmptyState();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount;
        if (width >= 1200) {
          crossAxisCount = 3;
        } else if (width >= 700) {
          crossAxisCount = 2;
        } else {
          crossAxisCount = 1;
        }

        final showSummary =
            status == 'processing' && context.read<ManagementStore>().currentStoreInfo.showTotalProducts;

        if (crossAxisCount == 1) {
          return ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(9, 0, 9, 20),
            itemCount:
                items.length + (showSummary ? 1 : 0) + (_isLoadingMore ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (showSummary && i == 0) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: _SummaryPanel(processingOrders: items),
                );
              }
              final orderIdx = showSummary ? i - 1 : i;

              if (orderIdx >= items.length) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              return _OrderCard(
                key: ValueKey(items[orderIdx].id),
                order: items[orderIdx],
                isExpanded: !_collapsedOrderIds.contains(items[orderIdx].id),
                onToggleExpand: () {
                  setState(() {
                    final id = items[orderIdx].id;
                    if (_collapsedOrderIds.contains(id)) {
                      _collapsedOrderIds.remove(id);
                    } else {
                      _collapsedOrderIds.add(id);
                    }
                  });
                },
                onDelete: () {
                  if (_customOrders != null) {
                    setState(
                      () => _customOrders!.removeWhere(
                        (o) => o.id == items[orderIdx].id,
                      ),
                    );
                  }
                },
              );
            },
          );
        }

        final cardWidth =
            (width - 18 - (crossAxisCount - 1) * 12) / crossAxisCount;

        return SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(9, 0, 9, 20),
          child: Wrap(
            spacing: 12,
            runSpacing: 0,
            children: [
              if (showSummary)
                SizedBox(
                  width: cardWidth,
                  child: _SummaryPanel(processingOrders: items),
                ),
              ...items.map((order) {
                return SizedBox(
                  width: cardWidth,
                  child: _OrderCard(
                    key: ValueKey(order.id),
                    order: order,
                    isExpanded: !_collapsedOrderIds.contains(order.id),
                    onToggleExpand: () {
                      setState(() {
                        if (_collapsedOrderIds.contains(order.id)) {
                          _collapsedOrderIds.remove(order.id);
                        } else {
                          _collapsedOrderIds.add(order.id);
                        }
                      });
                    },
                    onDelete: () {
                      if (_customOrders != null) {
                        setState(
                          () => _customOrders!.removeWhere(
                            (o) => o.id == order.id,
                          ),
                        );
                      }
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTab(String label, IconData icon, int count, Color badgeColor) {
    return Tab(
      height: 52,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 14)),
            if (count > 0) ...[
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
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
                  : _statusFilter == 'processing'
                  ? Icons.local_fire_department_rounded
                  : Icons.task_alt_rounded,
              size: 36,
              color: AppColors.slate300,
            ),
          ),
          SizedBox(height: 16),
          Text(
            _statusFilter == 'pending'
                ? 'Không có đơn chờ xử lý'
                : _statusFilter == 'processing'
                ? 'Không có đơn đang xử lý'
                : _statusFilter == 'cancelled'
                ? 'Không có đơn đã hủy'
                : 'Chưa có đơn hoàn tất',
            style: TextStyle(
              color: AppColors.slate500,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 6),
          Text(
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
  final VoidCallback? onDelete;
  final bool isExpanded;
  final VoidCallback? onToggleExpand;
  const _OrderCard({super.key, required this.order, this.onDelete, this.isExpanded = true, this.onToggleExpand});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool get _isExpanded => widget.isExpanded;
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
    final orderStore = context.read<OrderStore>();
    final ui = context.read<UIStore>();
    final auth = context.read<AuthStore>();
    final isLate = order.status == 'pending' && _isLate(order.time);
    final statusColor = _statusColor(order.status);
    final totalItems = order.items.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );

    final isStaff = auth.currentUser?.role != 'sadmin' && auth.currentUser?.role != 'admin';

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
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
          // ── Header (tap to expand/collapse, swipe/long_press to delete) ──
          Dismissible(
            key: Key('order_header_${order.id}'),
            direction: isStaff ? DismissDirection.none : DismissDirection.endToStart,
            confirmDismiss: (_) async {
              final completer = Completer<bool>();
              ui.showConfirm(
                'Bạn có chắc chắn muốn xóa đơn hàng này không? Hành động này không thể hoàn tác.',
                () {
                  completer.complete(true);
                },
                onCancel: () {
                  if (!completer.isCompleted) completer.complete(false);
                },
                title: 'Xóa đơn hàng?',
                confirmLabel: 'Xóa',
                icon: Icons.delete_rounded,
              );
              return await completer.future;
            },
            onDismissed: (_) {
              orderStore.deleteOrder(order.id);
              widget.onDelete?.call();
              ui.showToast('Đã xóa đơn hàng');
            },
            background: Container(
              decoration: BoxDecoration(
                color: AppColors.red500,
                borderRadius: _isExpanded
                    ? BorderRadius.vertical(top: Radius.circular(20))
                    : BorderRadius.circular(20),
              ),
              alignment: Alignment.centerRight,
              padding: EdgeInsets.only(right: 24),
              child: Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 32),
            ),
            child: GestureDetector(
              onLongPress: () {
                if (isStaff) {
                  ui.showToast('Chỉ admin mới được xóa đơn hàng', 'error');
                  return;
                }
                ui.showConfirm(
                  'Bạn có chắc chắn muốn xóa đơn hàng này không? Hành động này không thể hoàn tác.',
                  () {
                    orderStore.deleteOrder(order.id);
                    widget.onDelete?.call();
                    ui.showToast('Đã xóa đơn hàng');
                  },
                  title: 'Xóa đơn hàng?',
                  confirmLabel: 'Xóa',
                  icon: Icons.delete_rounded,
                );
              },
              onTap: () => widget.onToggleExpand?.call(),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: order.status == 'pending'
                      ? AppColors.red50
                      : order.status == 'processing'
                      ? AppColors.orange50
                      : order.status == 'cancelled'
                      ? AppColors.slate50
                      : AppColors.emerald50,
                  borderRadius: _isExpanded
                      ? BorderRadius.vertical(top: Radius.circular(20))
                      : BorderRadius.circular(20),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Animated left bar
                      _StatusBar(color: statusColor, height: 36),
                      SizedBox(width: 12),
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
                                  order.table.isNotEmpty &&
                                          !isDefaultTable(order.table)
                                      ? order.table
                                      : '🛍️ ${displayTableName(order.table)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: AppColors.slate800,
                                  ),
                                ),
                                if (order.status == 'pending' ||
                                    order.status == 'processing')
                                  GestureDetector(
                                    onTap: () => _showChangeTableDialog(
                                      context,
                                      order,
                                    ),
                                    child: Container(
                                      padding: EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppColors.slate100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.swap_horiz_rounded,
                                        size: 16,
                                        color: AppColors.slate600,
                                      ),
                                    ),
                                  ),
                                if (isLate)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.red500,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.timer_off_outlined,
                                          size: 12,
                                          color: Colors.white,
                                        ),
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
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: order.status == 'pending'
                                        ? AppColors.red100
                                        : order.status == 'processing'
                                        ? AppColors.amber100
                                        : AppColors.emerald50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$totalItems món',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 2),
                            // Time with elapsed minutes
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '${_formatTime(order.time)}${_elapsedBadge(order.time)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.slate400,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            // Orderer (fullname)
                            if (order.createdBy.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: 1),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.person_rounded,
                                      size: 13,
                                      color: AppColors.slate400,
                                    ),
                                    SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        order.createdBy,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.slate400,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
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
                            child: Text(
                              formatCurrency(order.calculatedTotal),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: AppColors.emerald600,
                              ),
                            ),
                          ),
                          SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
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
                                        SizedBox(width: 3),
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
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                _isExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: AppColors.slate400,
                                size: 18,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ),

              // ── Expandable body ──
              AnimatedCrossFade(
                firstChild: SizedBox.shrink(),
                secondChild: _buildExpandedBody(context, order),
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

  Widget _buildExpandedBody(BuildContext context, OrderModel order) {
    return Column(
      children: [
        // Divider
        Container(height: 1, color: AppColors.slate100),

        // ── Items ──
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: order.items.map((item) {
              final isEditing = _editingItemId == item.id;
              return Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Slidable(
                  key: ValueKey(item.id),
                  endActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    extentRatio: 0.5,
                    children: [
                      SlidableAction(
                        onPressed: (context) {
                          setState(() {
                            if (isEditing) {
                              _editingItemId = null;
                            } else {
                              _editingItemId = item.id;
                              _noteController.text = item.note;
                            }
                          });
                        },
                        backgroundColor: AppColors.blue500,
                        foregroundColor: Colors.white,
                        icon: Icons.edit_note_rounded,
                        label: 'Ghi chú',
                        borderRadius: order.status != 'pending' && order.status != 'processing' ? BorderRadius.horizontal(right: Radius.circular(14)) : BorderRadius.zero,
                      ),
                      if (order.status == 'pending' || order.status == 'processing') ...[
                        SlidableAction(
                          onPressed: (context) {
                            _showEditItemQuantityDialog(context, order, item);
                          },
                          backgroundColor: AppColors.orange500,
                          foregroundColor: Colors.white,
                          icon: Icons.edit_rounded,
                          label: 'Sửa',
                        ),
                        SlidableAction(
                          onPressed: (context) {
                            context.read<UIStore>().showConfirm(
                              'Bạn có chắc chắn muốn xóa "${item.name}" khỏi đơn hàng không?',
                              () => context.read<OrderStore>().removeOrderItem(order.id, item.id),
                              title: 'Xóa sản phẩm',
                              confirmLabel: 'Xóa',
                              icon: Icons.remove_shopping_cart_rounded,
                            );
                          },
                          backgroundColor: AppColors.red500,
                          foregroundColor: Colors.white,
                          icon: Icons.delete_outline_rounded,
                          label: 'Xóa',
                          borderRadius: BorderRadius.horizontal(right: Radius.circular(14)),
                        ),
                      ],
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.slate50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => context.read<OrderStore>().updateOrderItemStatus(
                            order,
                            item.id,
                            !item.isDone,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Checkmark outside
                                  Icon(
                                    item.isDone
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    size: 20,
                                    color: item.isDone
                                        ? AppColors.emerald500
                                        : AppColors.slate300,
                                  ),
                                  SizedBox(width: 10),
                                  // Qty
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: item.isDone
                                          ? AppColors.slate200
                                          : AppColors.emerald100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'x${item.quantity}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: item.isDone
                                            ? AppColors.slate500
                                            : AppColors.emerald700,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  // Name
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              item.name,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: item.isDone
                                                    ? AppColors.slate400
                                                    : AppColors.slate800,
                                                decoration: isEditing
                                                    ? TextDecoration.underline
                                                    : null,
                                                decorationColor: AppColors.emerald500,
                                              ),
                                            ),
                                          ),
                                          if (item.isNewlyAdded)
                                            Container(
                                              margin: const EdgeInsets.only(left: 6),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEE2E2),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(
                                                    color: const Color(0xFFFCA5A5)),
                                              ),
                                              child: const Text(
                                                'Mới thêm',
                                                style: TextStyle(
                                                  color: Color(0xFFEF4444),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Price + Status wrapped
                                  Wrap(
                                    alignment: WrapAlignment.end,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        formatCurrency(item.price * item.quantity),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.emerald600,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: item.isDone ? AppColors.emerald50 : AppColors.red50,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: item.isDone ? AppColors.emerald200 : Colors.transparent),
                                        ),
                                        child: Text(
                                          item.isDone ? 'Đã xong' : 'Chưa xong',
                                          style: TextStyle(
                                            color: item.isDone ? AppColors.emerald600 : AppColors.red500,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              // Note display (when not editing)
                              if (item.note.isNotEmpty && !isEditing)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8, top: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.subdirectory_arrow_right_rounded,
                                        size: 14,
                                        color: Color(0xFFD97706),
                                      ),
                                      SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          item.note,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            fontStyle: FontStyle.italic,
                                            color: Color(0xFFD97706),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Inline note editor (when editing)
                        if (isEditing)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, top: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _noteController,
                                    autofocus: true,
                                    style: TextStyle(fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: 'Nhập ghi chú...',
                                      hintStyle: TextStyle(
                                        color: AppColors.slate400,
                                        fontSize: 13,
                                      ),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: AppColors.slate300,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: AppColors.emerald500,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                    onSubmitted: (val) {
                                      context.read<OrderStore>().updateOrderItemNote(
                                        order.id,
                                        item.id,
                                        val.trim(),
                                      );
                                      setState(() => _editingItemId = null);
                                    },
                                  ),
                                ),
                                SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () {
                                    context.read<OrderStore>().updateOrderItemNote(
                                      order.id,
                                      item.id,
                                      _noteController.text.trim(),
                                    );
                                    setState(() => _editingItemId = null);
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.emerald500,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _editingItemId = null),
                                  child: Container(
                                    padding: EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.slate200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: AppColors.slate500,
                                      size: 16,
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
              );
            }).toList(),
          ),
        ),

        // ── Actions ──
        Container(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  if (order.status == 'pending' || order.status == 'processing')
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.read<UIStore>().showConfirm(
                          'Bạn có chắc chắn muốn hủy đơn hàng #${order.id.substring(order.id.length - 4)} không?',
                          () => context.read<OrderStore>().cancelOrder(order.id),
                          title: 'Hủy đơn hàng',
                          confirmLabel: 'Hủy đơn',
                          icon: Icons.cancel_rounded,
                        ),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: AppColors.red500,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Hủy đơn',
                                style: TextStyle(
                                  color: AppColors.red500,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (order.status == 'pending' || order.status == 'processing')
                    SizedBox(width: 10),
                  if (order.status == 'pending')
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            context.read<OrderStore>().updateOrderStatus(order.id, 'processing'),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.amber500,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.play_circle_outline_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Xác nhận đơn hàng',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (order.status == 'processing')
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (order.paymentStatus == 'paid') {
                            context.read<OrderStore>().updateOrderStatus(order.id, 'completed');
                          } else {
                            _showPaymentToComplete(context, order);
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.emerald500,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Hoàn tất',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              // ── Thêm món button ──
              if (order.status == 'pending' || order.status == 'processing') ...[
                SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _showAddItemsDialog(context, order),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.emerald50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.emerald200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline_rounded,
                          size: 20,
                          color: AppColors.emerald600,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Thêm sản phẩm',
                          style: TextStyle(
                            color: AppColors.emerald600,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (order.paymentStatus != 'paid' &&
                  order.status != 'cancelled') ...[
                SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _showPaymentQR(context, order),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.payments_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Thanh toán trước',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showChangeTableDialog(
    BuildContext context,
    OrderModel order,
  ) {
    final tables = context.read<ManagementStore>().currentTables;
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

    // Compute occupied tables (by other orders)
    final activeOrders = context.read<OrderFilterStore>().visibleOrders.where(
      (o) =>
          (o.status == 'pending' || o.status == 'processing') && o.id != order.id,
    );
    final occupiedTables = <String>{};
    for (final o in activeOrders) {
      if (o.table.isNotEmpty && !o.table.startsWith('★')) {
        occupiedTables.add(o.table);
      }
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogCtx, _, _) {
        return Material(
          type: MaterialType.transparency,
          child: GestureDetector(
            onTap: () => Navigator.of(dialogCtx).pop(),
            child: Container(
              color: Colors.black.withValues(alpha: 0.4),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Center(
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: 480,
                        maxHeight: MediaQuery.of(context).size.height * 0.75,
                      ),
                      margin: EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 40,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Header ──
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 20,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [AppColors.emerald50, AppColors.cardBg],
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.swap_horiz_rounded,
                                  color: AppColors.emerald600,
                                  size: 22,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Đổi bàn',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.slate800,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.emerald50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.emerald200,
                                    ),
                                  ),
                                  child: Text(
                                    order.table.isNotEmpty
                                        ? displayTableName(order.table)
                                        : 'Mang về',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.emerald600,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => Navigator.of(dialogCtx).pop(),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppColors.slate100,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      size: 18,
                                      color: AppColors.slate500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── Table List ──
                          Flexible(
                            child: ListView(
                              padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
                              shrinkWrap: true,
                              children: [
                                // Default tables at top (full width)
                                ...defaultTables.map((raw) {
                                  final displayName = raw.substring(
                                    1,
                                  ); // strip ★
                                  final isSelected =
                                      order.table == raw ||
                                      (order.table.isEmpty &&
                                          defaultTables.indexOf(raw) == 0);
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: 8),
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.of(dialogCtx).pop();
                                        context.read<OrderStore>().updateOrderTable(order.id, raw);
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppColors.emerald50
                                              : AppColors.slate50,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: isSelected
                                              ? Border.all(
                                                  color: AppColors.emerald200,
                                                )
                                              : null,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.shopping_bag_outlined,
                                              size: 18,
                                              color: isSelected
                                                  ? AppColors.emerald600
                                                  : AppColors.orange500,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              displayName,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: isSelected
                                                    ? AppColors.emerald600
                                                    : AppColors.slate800,
                                              ),
                                            ),
                                            if (isSelected) ...[
                                              SizedBox(width: 8),
                                              Icon(
                                                Icons.check_circle,
                                                size: 16,
                                                color: AppColors.emerald500,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                                if (defaultTables.isNotEmpty)
                                  SizedBox(height: 4),

                                // Area groups with 3-column grid
                                ...areaGroups.entries.map((entry) {
                                  final areaName = entry.key;
                                  final areaTables = entry.value;
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.only(
                                          bottom: 8,
                                          top: 4,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.location_on_rounded,
                                              size: 14,
                                              color: AppColors.emerald600,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              areaName,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.slate500,
                                              ),
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              '${areaTables.length} bàn',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.slate400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // 2-column grid
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          const crossAxisCount = 2;
                                          const spacing = 8.0;
                                          final itemWidth =
                                              (constraints.maxWidth -
                                                  spacing *
                                                      (crossAxisCount - 1)) /
                                              crossAxisCount;
                                          return Wrap(
                                            spacing: spacing,
                                            runSpacing: spacing,
                                            children: areaTables.map((t) {
                                              final parts = t.split(' · ');
                                              final tableName = parts.length > 1
                                                  ? parts.sublist(1).join(' · ')
                                                  : t;
                                              final isCurrent =
                                                  order.table == t;
                                              final isBusy = occupiedTables
                                                  .contains(t);
                                              return SizedBox(
                                                width: itemWidth,
                                                child: GestureDetector(
                                                  onTap: () {
                                                    Navigator.of(
                                                      dialogCtx,
                                                    ).pop();
                                                    context.read<OrderStore>().updateOrderTable(
                                                      order.id,
                                                      t,
                                                    );
                                                  },
                                                  child: Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          vertical: 10,
                                                          horizontal: 10,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: isCurrent
                                                          ? AppColors.emerald50
                                                          : (isBusy
                                                                ? AppColors
                                                                      .slate100
                                                                : AppColors
                                                                      .slate50),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
                                                      border: isCurrent
                                                          ? Border.all(
                                                              color: AppColors
                                                                  .emerald200,
                                                              width: 1.5,
                                                            )
                                                          : null,
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          width: 36,
                                                          height: 36,
                                                          decoration: BoxDecoration(
                                                            color:
                                                                (isCurrent
                                                                        ? AppColors
                                                                              .emerald500
                                                                        : AppColors
                                                                              .slate400)
                                                                    .withValues(
                                                                      alpha:
                                                                          0.15,
                                                                    ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  18,
                                                                ),
                                                          ),
                                                          child: Icon(
                                                            Icons
                                                                .table_restaurant_outlined,
                                                            size: 18,
                                                            color: isBusy
                                                                ? AppColors
                                                                      .slate400
                                                                : isCurrent
                                                                ? AppColors
                                                                      .emerald500
                                                                : AppColors
                                                                      .slate400,
                                                          ),
                                                        ),
                                                        SizedBox(width: 8),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Text(
                                                                tableName,
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: TextStyle(
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      isCurrent
                                                                      ? FontWeight
                                                                            .w700
                                                                      : FontWeight
                                                                            .w600,
                                                                  color: isBusy
                                                                      ? AppColors
                                                                            .slate400
                                                                      : isCurrent
                                                                      ? AppColors
                                                                            .emerald600
                                                                      : AppColors
                                                                            .slate800,
                                                                ),
                                                              ),
                                                              SizedBox(
                                                                height: 2,
                                                              ),
                                                              if (isBusy)
                                                                Container(
                                                                  padding:
                                                                      EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            5,
                                                                        vertical:
                                                                            1,
                                                                      ),
                                                                  decoration: BoxDecoration(
                                                                    color: AppColors
                                                                        .red50,
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          4,
                                                                        ),
                                                                  ),
                                                                  child: Text(
                                                                    'Đang dùng',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          9,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                      color: AppColors
                                                                          .red500,
                                                                    ),
                                                                  ),
                                                                )
                                                              else if (isCurrent)
                                                                Text(
                                                                  'Bàn hiện tại',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    color: AppColors
                                                                        .emerald500,
                                                                  ),
                                                                )
                                                              else
                                                                Text(
                                                                  'Trống',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                    color: AppColors
                                                                        .slate400,
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        ),
                                                        if (isCurrent)
                                                          Icon(
                                                            Icons.check_circle,
                                                            size: 16,
                                                            color: AppColors
                                                                .emerald500,
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          );
                                        },
                                      ),
                                      SizedBox(height: 12),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Show payment dialog that REQUIRES payment before completing the order.
  /// Cash: always allowed → completes order immediately.
  /// Transfer: only if QR or bank info configured → completes order.
  void _showPaymentToComplete(
    BuildContext context,
    OrderModel order,
  ) {
    final storeInfo = context.read<ManagementStore>().currentStoreInfo;
    final hasQr = storeInfo.qrImageUrl.isNotEmpty;
    final hasBank =
        storeInfo.bankId.isNotEmpty &&
        storeInfo.bankAccount.isNotEmpty &&
        storeInfo.bankOwner.isNotEmpty;
    final canTransfer = hasQr || hasBank;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'payment-complete',
      barrierColor: Colors.transparent,
      pageBuilder: (ctx, _, _) => Stack(
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
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              margin: EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
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
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Thanh toán để hoàn tất',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                    color: AppColors.slate800,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  order.table.isNotEmpty &&
                                          !isDefaultTable(order.table)
                                      ? order.table
                                      : '🛍️ ${displayTableName(order.table)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.slate400,
                                  ),
                                ),
                              ],
                            ),
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
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: AppColors.slate500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 1, color: AppColors.slate100),

                    // Warning notice
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.fromLTRB(20, 16, 20, 0),
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.orange50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: Color(0xFFF59E0B),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Vui lòng chọn phương thức thanh toán trước khi hoàn tất đơn hàng',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // QR / bank info
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Column(
                        children: [
                          _buildPaymentQRContent(storeInfo),
                          SizedBox(height: 8),
                          Text(
                            'Cần thanh toán',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.slate500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            formatCurrency(order.calculatedTotal),
                            style: TextStyle(
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
                      padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Cash — always works
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    context.read<OrderStore>().completeOrderWithPayment(
                                      order.id,
                                      'cash',
                                    );
                                    context.read<AudioStore>().playPaymentSound();
                                    context.read<UIStore>().showToast(
                                      'Đã hoàn tất đơn (tiền mặt)',
                                    );
                                  },
                                  child: Container(
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF10B981),
                                          Color(0xFF059669),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF10B981,
                                          ).withValues(alpha: 0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.payments_rounded,
                                          size: 20,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Tiền mặt',
                                          style: TextStyle(
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
                              SizedBox(width: 10),
                              // Transfer — only if QR/bank configured
                              Expanded(
                                child: GestureDetector(
                                  onTap: canTransfer
                                      ? () {
                                          Navigator.pop(ctx);
                                          context.read<OrderStore>().completeOrderWithPayment(
                                            order.id,
                                            'transfer',
                                          );
                                          context.read<AudioStore>().playPaymentSound();
                                          context.read<UIStore>().showToast(
                                            'Đã hoàn tất đơn (chuyển khoản)',
                                          );
                                        }
                                      : () {
                                          context.read<UIStore>().showToast(
                                            'Chưa có thông tin QR/STK. Vào Cài đặt để thêm.',
                                            'error',
                                          );
                                        },
                                  child: Container(
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: canTransfer
                                            ? [
                                                const Color(0xFF3B82F6),
                                                const Color(0xFF2563EB),
                                              ]
                                            : [
                                                AppColors.slate300,
                                                AppColors.slate400,
                                              ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: canTransfer
                                          ? [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFF3B82F6,
                                                ).withValues(alpha: 0.3),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.account_balance_rounded,
                                          size: 20,
                                          color: canTransfer
                                              ? Colors.white
                                              : AppColors.slate100,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Chuyển khoản',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: canTransfer
                                                ? Colors.white
                                                : AppColors.slate100,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentQR(BuildContext context, OrderModel order) {
    final storeInfo = context.read<ManagementStore>().currentStoreInfo;
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
              margin: EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
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
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Thanh toán đơn hàng',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  color: AppColors.slate800,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                order.table.isNotEmpty
                                    ? order.table
                                    : displayTableName(order.table),
                                style: TextStyle(
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
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: AppColors.slate500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 1, color: AppColors.slate100),

                    // QR Body
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
                      child: Column(
                        children: [
                          // QR / bank info / prompt
                          _buildPaymentQRContent(storeInfo),
                          SizedBox(height: 8),
                          Text(
                            'Cần thanh toán',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.slate500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            formatCurrency(order.calculatedTotal),
                            style: TextStyle(
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
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Column(
                        children: [
                          // Two paid buttons side by side
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    context.read<OrderStore>().updateOrderPaymentStatus(
                                      order.id,
                                      'paid',
                                      paymentMethod: 'cash',
                                    );
                                    context.read<AudioStore>().playPaymentSound();
                                    context.read<UIStore>().showToast(
                                      'Đã thanh toán trước (tiền mặt)',
                                    );
                                  },
                                  child: Container(
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF10B981),
                                          Color(0xFF059669),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF10B981,
                                          ).withValues(alpha: 0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.payments_rounded,
                                          size: 20,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Tiền mặt',
                                          style: TextStyle(
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
                              SizedBox(width: 10),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    context.read<OrderStore>().updateOrderPaymentStatus(
                                      order.id,
                                      'paid',
                                      paymentMethod: 'transfer',
                                    );
                                    context.read<AudioStore>().playPaymentSound();
                                    context.read<UIStore>().showToast(
                                      'Đã thanh toán trước (chuyển khoản)',
                                    );
                                  },
                                  child: Container(
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF3B82F6),
                                          Color(0xFF2563EB),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF3B82F6,
                                          ).withValues(alpha: 0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.account_balance_rounded,
                                          size: 20,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Chuyển khoản',
                                          style: TextStyle(
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
                          ),
                          SizedBox(height: 10),
                          // Pay later
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              width: double.infinity,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.amber50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFF59E0B),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    size: 18,
                                    color: Color(0xFFF59E0B),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Thanh toán sau',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Color(0xFFF59E0B),
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
          ),
        ],
      ),
    );
  }

  /// Builds QR / bank info / prompt — matches payment_confirmation_dialog.
  Widget _buildPaymentQRContent(storeInfo) {
    final hasQr = storeInfo.qrImageUrl.isNotEmpty;
    final hasBank =
        storeInfo.bankId.isNotEmpty &&
        storeInfo.bankAccount.isNotEmpty &&
        storeInfo.bankOwner.isNotEmpty;

    if (hasQr) {
      Widget qrWidget;
      if (CloudflareService.isUrl(storeInfo.qrImageUrl)) {
        qrWidget = CachedNetworkImage(
          imageUrl: storeInfo.qrImageUrl,
          fit: BoxFit.contain,
          errorWidget: (_, _, _) => Center(
            child: Icon(
              Icons.broken_image,
              size: 40,
              color: AppColors.slate300,
            ),
          ),
        );
      } else {
        Uint8List? qrBytes;
        try {
          final base64Part = storeInfo.qrImageUrl.split(',').last;
          qrBytes = base64Decode(base64Part);
        } catch (_) {}

        qrWidget = qrBytes != null
            ? Image.memory(
                qrBytes,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Center(
                  child: Icon(
                    Icons.broken_image,
                    size: 40,
                    color: AppColors.slate300,
                  ),
                ),
              )
            : Center(
                child: Icon(
                  Icons.qr_code_rounded,
                  size: 80,
                  color: AppColors.slate300,
                ),
              );
      }

      return Container(
        width: 280,
        height: 280,
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.slate200),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: qrWidget,
        ),
      );
    }

    if (hasBank) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.slate50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Column(
          children: [
            Icon(
              Icons.account_balance_rounded,
              size: 28,
              color: AppColors.emerald500,
            ),
            SizedBox(height: 8),
            Text(
              storeInfo.bankId,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.slate700,
              ),
            ),
            SizedBox(height: 4),
            Text(
              storeInfo.bankAccount,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.slate800,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 4),
            Text(
              storeInfo.bankOwner,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.slate500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.orange50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline_rounded, size: 28, color: Color(0xFFF59E0B)),
          SizedBox(height: 8),
          Text(
            'Chưa có thông tin thanh toán',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFFB45309),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Vào Cài đặt → Thông tin cửa hàng để chọn ảnh QR hoặc nhập STK',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFFD97706)),
          ),
        ],
      ),
    );
  }

  // ── Add Items Dialog ────────────────────────────────
  void _showAddItemsDialog(
    BuildContext context,
    OrderModel order,
  ) {
    // Get products from the order's store specifically
    final allProducts = (context.read<InventoryStore>().products[order.storeId] ?? context.read<InventoryStore>().currentProducts)
        .where((p) => !p.isOutOfStock)
        .toList();
    // Extract unique category IDs from available products
    final allCategoryIds =
        allProducts
            .map((p) => p.category)
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    // Build category ID → name map from store categories
    final storeCategories =
        context.read<InventoryStore>().categories[order.storeId] ?? context.read<InventoryStore>().currentCategories;
    final catNameMap = <String, String>{
      for (final cat in storeCategories) cat.id: cat.name,
    };
    // Temp cart for new items
    final Map<String, int> tempCart = {};
    final Map<String, String> tempNotes = {};
    String selectedCategory = '';

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
                    final screenWidth = MediaQuery.of(context).size.width;
                    final isLandscape = screenWidth > 600;
                    // Filter products by category
                    final filtered = selectedCategory.isEmpty
                        ? allProducts
                        : allProducts
                              .where((p) => p.category == selectedCategory)
                              .toList();
                    // Calculate temp cart total
                    double addedTotal = 0;
                    int addedCount = 0;
                    tempCart.forEach((id, qty) {
                      final p = allProducts
                          .where((x) => x.id == id)
                          .firstOrNull;
                      if (p != null) {
                        addedTotal += p.price * qty;
                        addedCount += qty;
                      }
                    });

                    final crossAxisCount = isLandscape ? 4 : 2;

                    return Container(
                      width: isLandscape
                          ? screenWidth * 0.85
                          : screenWidth - 32,
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.85,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
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
                            padding: EdgeInsets.fromLTRB(20, 18, 12, 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [AppColors.emerald50, AppColors.cardBg],
                              ),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.add_shopping_cart_rounded,
                                  color: AppColors.emerald600,
                                  size: 22,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
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
                                        style: TextStyle(
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
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      size: 18,
                                      color: AppColors.slate500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Category chips
                          Padding(
                            padding: EdgeInsets.fromLTRB(12, 4, 12, 8),
                            child: SizedBox(
                              height: 34,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  _buildCategoryChip(
                                    label: 'Tất cả',
                                    isSelected: selectedCategory.isEmpty,
                                    onTap: () =>
                                        setState2(() => selectedCategory = ''),
                                  ),
                                  ...allCategoryIds.map(
                                    (catId) => _buildCategoryChip(
                                      label: catNameMap[catId] ?? catId,
                                      isSelected: selectedCategory == catId,
                                      onTap: () => setState2(
                                        () => selectedCategory = catId,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          Container(height: 1, color: AppColors.slate100),

                          // Product grid (responsive)
                          Flexible(
                            child: filtered.isEmpty
                                ? Padding(
                                    padding: EdgeInsets.all(40),
                                    child: Center(
                                      child: Text(
                                        'Không có sản phẩm',
                                        style: TextStyle(
                                          color: AppColors.slate400,
                                        ),
                                      ),
                                    ),
                                  )
                                : GridView.builder(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: crossAxisCount,
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
                                            tempCart[p.id] =
                                                (tempCart[p.id] ?? 0) + 1;
                                          });
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.cardBg,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: qty > 0
                                                  ? AppColors.emerald500
                                                  : AppColors.slate100,
                                              width: qty > 0 ? 2 : 1,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.04,
                                                ),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Stack(
                                            children: [
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  // Product image (fills top)
                                                  Expanded(
                                                    child: Container(
                                                      width: double.infinity,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            AppColors.slate50,
                                                        borderRadius:
                                                            BorderRadius.vertical(
                                                              top:
                                                                  Radius.circular(
                                                                    16,
                                                                  ),
                                                            ),
                                                      ),
                                                      child: SmartImage(
                                                        imageData: p.image,
                                                        borderRadius:
                                                            BorderRadius.vertical(
                                                              top:
                                                                  Radius.circular(
                                                                    16,
                                                                  ),
                                                            ),
                                                        placeholder: Center(
                                                          child: Icon(
                                                            Icons
                                                                .inventory_2_rounded,
                                                            color: AppColors
                                                                .slate300
                                                                .withValues(
                                                                  alpha: 0.6,
                                                                ),
                                                            size: 36,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  // Name
                                                  Padding(
                                                    padding:
                                                        EdgeInsets.fromLTRB(
                                                          10,
                                                          8,
                                                          10,
                                                          2,
                                                        ),
                                                    child: Text(
                                                      p.name,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            AppColors.slate800,
                                                        height: 1.3,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  // Price
                                                  Padding(
                                                    padding:
                                                        EdgeInsets.fromLTRB(
                                                          10,
                                                          0,
                                                          10,
                                                          6,
                                                        ),
                                                    child: Text(
                                                      formatCurrency(p.price),
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: AppColors
                                                            .emerald500,
                                                      ),
                                                    ),
                                                  ),
                                                  // Qty stepper row
                                                  if (qty > 0)
                                                    GestureDetector(
                                                      onTap:
                                                          () {}, // absorb tap
                                                      child: Container(
                                                        height: 36,
                                                        margin:
                                                            EdgeInsets.fromLTRB(
                                                              8,
                                                              0,
                                                              8,
                                                              8,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              AppColors.slate50,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                          border: Border.all(
                                                            color: AppColors
                                                                .slate200,
                                                          ),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            Expanded(
                                                              child: InkWell(
                                                                onTap: () {
                                                                  setState2(() {
                                                                    if (qty <=
                                                                        1) {
                                                                      tempCart
                                                                          .remove(
                                                                            p.id,
                                                                          );
                                                                      tempNotes
                                                                          .remove(
                                                                            p.id,
                                                                          );
                                                                    } else {
                                                                      tempCart[p
                                                                              .id] =
                                                                          qty -
                                                                          1;
                                                                    }
                                                                  });
                                                                },
                                                                child: Center(
                                                                  child: Icon(
                                                                    qty <= 1
                                                                        ? Icons
                                                                              .delete_outline_rounded
                                                                        : Icons
                                                                              .remove_rounded,
                                                                    size: 18,
                                                                    color:
                                                                        qty <= 1
                                                                        ? AppColors
                                                                              .red400
                                                                        : AppColors
                                                                              .slate600,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            Container(
                                                              width: 1,
                                                              height: 18,
                                                              color: AppColors
                                                                  .slate200,
                                                            ),
                                                            Expanded(
                                                              child: Center(
                                                                child: Text(
                                                                  '$qty',
                                                                  style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    fontSize:
                                                                        15,
                                                                    color: AppColors
                                                                        .slate800,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            Container(
                                                              width: 1,
                                                              height: 18,
                                                              color: AppColors
                                                                  .slate200,
                                                            ),
                                                            Expanded(
                                                              child: InkWell(
                                                                onTap: () {
                                                                  setState2(() {
                                                                    tempCart[p
                                                                            .id] =
                                                                        qty + 1;
                                                                  });
                                                                },
                                                                child: Center(
                                                                  child: Icon(
                                                                    Icons
                                                                        .add_rounded,
                                                                    size: 18,
                                                                    color: AppColors
                                                                        .slate600,
                                                                  ),
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
                                                      margin:
                                                          EdgeInsets.fromLTRB(
                                                            8,
                                                            0,
                                                            8,
                                                            8,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            AppColors.slate50,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        border: Border.all(
                                                          color: AppColors
                                                              .slate200,
                                                        ),
                                                      ),
                                                      child: Center(
                                                        child: Icon(
                                                          Icons.add_rounded,
                                                          size: 20,
                                                          color: AppColors
                                                              .slate400,
                                                        ),
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
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 7,
                                                          vertical: 3,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          AppColors.emerald500,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      'x$qty',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
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
                              padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
                              child: GestureDetector(
                                onTap: () {
                                  // Merge new items into existing order
                                  final newItems = List<OrderItemModel>.from(
                                    order.items,
                                  );
                                  tempCart.forEach((productId, qty) {
                                    final product = allProducts
                                        .where((p) => p.id == productId)
                                        .firstOrNull;
                                    if (product == null) return;
                                    final existingIdx = newItems.indexWhere(
                                      (i) => i.id == productId,
                                    );
                                    if (existingIdx >= 0) {
                                      newItems[existingIdx] =
                                          newItems[existingIdx].copyWith(
                                            quantity:
                                                newItems[existingIdx].quantity +
                                                qty,
                                          );
                                    } else {
                                      newItems.add(
                                        OrderItemModel(
                                          id: productId,
                                          name: product.name,
                                          price: product.price,
                                          quantity: qty,
                                          image: product.image,
                                          note: tempNotes[productId] ?? '',
                                        ),
                                      );
                                    }
                                  });
                                  final newTotal = newItems.fold<double>(
                                    0,
                                    (sum, i) => sum + (i.price * i.quantity),
                                  );
                                  context.read<OrderStore>().updateOrderItems(
                                    order.id,
                                    newItems,
                                    newTotal,
                                  );
                                  Navigator.pop(ctx);
                                  context.read<UIStore>().showToast(
                                    'Đã thêm $addedCount món vào đơn!',
                                  );
                                },
                                child: Container(
                                  width: double.infinity,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF10B981),
                                        Color(0xFF059669),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF10B981,
                                        ).withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_circle_outline_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Thêm $addedCount món · ${formatCurrency(addedTotal)}',
                                        style: TextStyle(
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
          scale: CurvedAnimation(parent: a1, curve: Curves.easeOutCubic),
          child: FadeTransition(opacity: a1, child: child),
        );
      },
    );
  }

  Widget _miniBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
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

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.emerald500 : AppColors.slate50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.emerald500 : AppColors.slate200,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.slate600,
            ),
          ),
        ),
      ),
    );
  }

  /// Timestamps stored as local values but Supabase may return with +00:00,
  /// so DateTime.tryParse treats them as UTC epoch. Reconstruct as local
  /// DateTime for correct difference/comparison calculations.
  DateTime? _parseAsLocal(String time) {
    final dt = DateTime.tryParse(time);
    if (dt == null) return null;
    return DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second);
  }

  bool _isLate(String time) {
    if (time.isEmpty) return false;
    final orderTime = _parseAsLocal(time);
    if (orderTime == null) return false;
    return DateTime.now().difference(orderTime).inMinutes > 15;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.red500;
      case 'processing':
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
    final dt = _parseAsLocal(time);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative) return '';
    if (diff.inMinutes < 1) return ' · < 1 phút';
    if (diff.inMinutes < 60) return ' · ${diff.inMinutes} phút';
    return ' · ${diff.inHours} giờ ${diff.inMinutes % 60} phút';
  }

  // ─────────────────────────────────────────────────────────────────
  // SỬA SỐ LƯỢNG MÓN
  // ─────────────────────────────────────────────────────────────────
  void _showEditItemQuantityDialog(
    BuildContext context,
    OrderModel order,
    OrderItemModel item,
  ) {
    int currentQuantity = item.quantity;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogCtx, _, _) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Material(
              type: MaterialType.transparency,
              child: GestureDetector(
                onTap: () => Navigator.of(dialogCtx).pop(),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.4),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                    child: Center(
                      child: GestureDetector(
                        onTap: () {},
                        child: Container(
                          width: 340,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(color: AppColors.blue50, shape: BoxShape.circle),
                                child: Icon(Icons.edit_note_rounded, color: AppColors.blue600, size: 32),
                              ),
                              SizedBox(height: 16),
                              Text('Sửa món', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.slate800)),
                              SizedBox(height: 8),
                              Text(item.name, style: TextStyle(fontSize: 16, color: AppColors.slate500), textAlign: TextAlign.center),
                              SizedBox(height: 32),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Nút trừ
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(color: AppColors.slate100, shape: BoxShape.circle),
                                    child: IconButton(
                                      iconSize: 28,
                                      icon: Icon(Icons.remove_rounded, color: AppColors.slate700),
                                      onPressed: currentQuantity > 0 ? () {
                                        setDialogState(() {
                                          currentQuantity--;
                                        });
                                      } : null,
                                    ),
                                  ),
                                  SizedBox(width: 32),
                                  Text('$currentQuantity', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.slate800)),
                                  SizedBox(width: 32),
                                  // Nút cộng
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(color: AppColors.emerald100, shape: BoxShape.circle),
                                    child: IconButton(
                                      iconSize: 28,
                                      icon: Icon(Icons.add_rounded, color: AppColors.emerald700),
                                      onPressed: () {
                                        setDialogState(() {
                                          currentQuantity++;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 40),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextButton(
                                      onPressed: () => Navigator.of(dialogCtx).pop(),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 18),
                                        backgroundColor: AppColors.slate100,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      child: Text('Hủy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.slate700)),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(dialogCtx).pop();
                                        if (currentQuantity == 0) {
                                          context.read<OrderStore>().removeOrderItem(order.id, item.id);
                                        } else if (currentQuantity != item.quantity) {
                                          final updatedItems = order.items.map((i) {
                                            if (i.id == item.id) {
                                              return i.copyWith(quantity: currentQuantity);
                                            }
                                            return i;
                                          }).toList();
                                          final newTotal = updatedItems.fold(0.0, (sum, i) => sum + (i.price * i.quantity));
                                          context.read<OrderStore>().updateOrderItems(order.id, updatedItems, newTotal);
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 18),
                                        backgroundColor: AppColors.blue600,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      child: Text('Cập nhật', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, anim, secondaryAnim, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
            child: child,
          ),
        );
      },
    );
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
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        elevation: 0,
      ),
    );
  }
}

// ─── Summary Panel (aggregated product list for processing tab) ──
class _SummaryPanel extends StatefulWidget {
  final List<OrderModel> processingOrders;
  const _SummaryPanel({required this.processingOrders});

  @override
  State<_SummaryPanel> createState() => _SummaryPanelState();
}

class _SummaryPanelState extends State<_SummaryPanel> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    // store replaced — read individual stores from context as needed

    // Aggregate items by product name
    final Map<String, _AggregatedProduct> aggregated = {};
    for (final order in widget.processingOrders) {
      for (final item in order.items) {
        final existing = aggregated[item.name];
        if (existing != null) {
          existing.totalQty += item.quantity;
          existing.doneQty += item.doneQuantity;
          existing.orderRefs.add(
            _OrderItemRef(
              orderId: order.id,
              itemId: item.id,
              isDone: item.isDone,
            ),
          );
        } else {
          aggregated[item.name] = _AggregatedProduct(
            name: item.name,
            totalQty: item.quantity,
            doneQty: item.doneQuantity,
            orderRefs: [
              _OrderItemRef(
                orderId: order.id,
                itemId: item.id,
                isDone: item.isDone,
              ),
            ],
          );
        }
      }
    }

    final products = aggregated.values.toList()
      ..sort((a, b) {
        // Undone first, then by name
        final aDone = a.isAllDone ? 1 : 0;
        final bDone = b.isAllDone ? 1 : 0;
        if (aDone != bDone) return aDone - bDone;
        return a.name.compareTo(b.name);
      });

    final totalItems = products.fold<int>(0, (s, p) => s + p.totalQty);
    final doneItems = products.fold<int>(0, (s, p) => s + p.doneQty);
    final progress = totalItems > 0 ? doneItems / totalItems : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: progress >= 1.0
              ? AppColors.emerald200
              : const Color(0xFF3B82F6).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: progress >= 1.0
                    ? AppColors.emerald50
                    : const Color(0xFFEFF6FF),
                borderRadius: _isExpanded
                    ? BorderRadius.vertical(top: Radius.circular(20))
                    : BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: progress >= 1.0
                              ? AppColors.emerald100
                              : const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          progress >= 1.0
                              ? Icons.check_circle_rounded
                              : Icons.playlist_add_check_rounded,
                          size: 18,
                          color: progress >= 1.0
                              ? AppColors.emerald600
                              : const Color(0xFF3B82F6),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              progress >= 1.0
                                  ? 'Đã hoàn tất tất cả!'
                                  : 'Tổng sản phẩm cần xử lý',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: progress >= 1.0
                                    ? AppColors.emerald700
                                    : AppColors.slate800,
                              ),
                            ),
                            SizedBox(height: 1),
                            Text(
                              '$doneItems/$totalItems sản phẩm đã xong',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: progress >= 1.0
                                    ? AppColors.emerald500
                                    : AppColors.slate400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Progress percentage
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: progress >= 1.0
                              ? AppColors.emerald500
                              : progress >= 0.5
                              ? AppColors.amber500
                              : AppColors.slate200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${(progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: progress >= 0.5 || progress >= 1.0
                                ? Colors.white
                                : AppColors.slate600,
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.slate400,
                        size: 20,
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: AppColors.slate100,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 1.0
                            ? AppColors.emerald500
                            : const Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable product list
          AnimatedCrossFade(
            firstChild: SizedBox.shrink(),
            secondChild: Column(
              children: [
                Container(height: 1, color: AppColors.slate100),
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    children: products.map((product) {
                      final allDone = product.isAllDone;
                      return Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: GestureDetector(
                          onTap: () {
                            if (allDone) {
                              context.read<OrderStore>().setAllProductDoneAcrossOrders(
                                product.name,
                                false,
                                targetOrders: widget.processingOrders,
                              );
                            } else {
                              context.read<OrderStore>().markProductDoneAcrossOrders(
                                product.name,
                                true,
                                targetOrders: widget.processingOrders,
                              );
                            }
                          },
                          onLongPress: product.doneQty <= 0
                              ? null
                              : () => context.read<OrderStore>().markProductDoneAcrossOrders(
                                  product.name,
                                  false,
                                  targetOrders: widget.processingOrders,
                                ),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: allDone
                                  ? AppColors.emerald50
                                  : AppColors.slate50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: allDone
                                    ? AppColors.emerald200
                                    : AppColors.slate200,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Checkbox
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: allDone
                                        ? AppColors.emerald500
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: allDone
                                          ? AppColors.emerald500
                                          : AppColors.slate300,
                                      width: 2,
                                    ),
                                  ),
                                  child: allDone
                                      ? Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        )
                                      : null,
                                ),
                                SizedBox(width: 10),
                                // Product name
                                Expanded(
                                  child: Text(
                                    product.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: allDone
                                          ? AppColors.slate400
                                          : AppColors.slate800,
                                      decoration: allDone
                                          ? TextDecoration.lineThrough
                                          : null,
                                      decorationColor: AppColors.slate400,
                                    ),
                                  ),
                                ),
                                // Quantity badge
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: allDone
                                        ? AppColors.emerald100
                                        : const Color(0xFFDBEAFE),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${product.doneQty}/${product.totalQty}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: allDone
                                          ? AppColors.emerald600
                                          : const Color(0xFF3B82F6),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 6),
                                // Status
                                Icon(
                                  allDone
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  size: 18,
                                  color: allDone
                                      ? AppColors.emerald500
                                      : AppColors.slate300,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
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
}

// Helper data classes for aggregation
class _AggregatedProduct {
  final String name;
  int totalQty;
  int doneQty;
  final List<_OrderItemRef> orderRefs;

  _AggregatedProduct({
    required this.name,
    required this.totalQty,
    required this.doneQty,
    required this.orderRefs,
  });

  bool get isAllDone => totalQty > 0 && doneQty >= totalQty;
}

class _OrderItemRef {
  final String orderId;
  final String itemId;
  final bool isDone;

  const _OrderItemRef({
    required this.orderId,
    required this.itemId,
    required this.isDone,
    });
}

