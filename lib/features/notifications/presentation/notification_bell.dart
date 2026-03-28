import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moimoi_pos/core/state/app_store.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/widgets/animated_dialogs.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final unreadCount =
        store.notifications.where((n) => !n.read).length;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined,
              color: AppColors.slate500, size: 24),
          onPressed: () => _showNotificationDialog(context, store),
        ),
        if (unreadCount > 0)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.red500,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 2),
              ),
              constraints:
                  const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                '${unreadCount > 99 ? '99+' : unreadCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  void _showNotificationDialog(BuildContext context, AppStore store) {
    showAnimatedDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: _NotificationDialogContent(store: store),
      ),
    );
  }
}

class _NotificationDialogContent extends StatefulWidget {
  final AppStore store;
  const _NotificationDialogContent({required this.store});

  @override
  State<_NotificationDialogContent> createState() =>
      _NotificationDialogContentState();
}

class _NotificationDialogContentState
    extends State<_NotificationDialogContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.store,
      child: Consumer<AppStore>(
        builder: (context, store, _) {
          final unread =
              store.notifications.where((n) => !n.read).toList();
          final read =
              store.notifications.where((n) => n.read).toList();

          return Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxWidth: 480,
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.notifications_rounded,
                            color: Color(0xFFF59E0B), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Thông Báo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slate800,
                          ),
                        ),
                      ),
                      if (unread.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            for (final n in unread) {
                              store.markNotificationAsRead(n.id);
                            }
                          },
                          child: const Text(
                            'Đọc tất cả',
                            style: TextStyle(
                              color: AppColors.blue500,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded,
                            color: AppColors.slate400, size: 22),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ),

                // ── Tabs ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TabBar(
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
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Chưa đọc'),
                            if (unread.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.red500,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${unread.length > 99 ? '99+' : unread.length}',
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
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Đã đọc'),
                            if (read.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.slate300,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${read.length}',
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
                    ],
                  ),
                ),

                // ── Tab content ──
                Flexible(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Chưa đọc
                      _buildNotificationList(
                        store,
                        unread,
                        emptyIcon: Icons.mark_email_read_rounded,
                        emptyText: 'Không có thông báo chưa đọc',
                        isUnread: true,
                      ),
                      // Tab 2: Đã đọc
                      _buildNotificationList(
                        store,
                        read,
                        emptyIcon: Icons.notifications_none_rounded,
                        emptyText: 'Chưa có thông báo đã đọc',
                        isUnread: false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationList(
    AppStore store,
    List notifications, {
    required IconData emptyIcon,
    required String emptyText,
    required bool isUnread,
  }) {
    if (notifications.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(emptyIcon, size: 48, color: AppColors.slate300),
            const SizedBox(height: 12),
            Text(
              emptyText,
              style: const TextStyle(
                color: AppColors.slate400,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: notifications.length,
      itemBuilder: (_, i) {
        final noti = notifications[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isUnread ? const Color(0xFFF0F7FF) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isUnread
                  ? const Color(0xFFBFDBFE)
                  : AppColors.slate200,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              if (isUnread) {
                store.markNotificationAsRead(noti.id);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isUnread
                          ? const Color(0xFFDBEAFE)
                          : AppColors.slate100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getIcon(noti.type),
                      color: isUnread
                          ? AppColors.blue500
                          : AppColors.slate400,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          noti.title,
                          style: TextStyle(
                            fontWeight: isUnread
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: AppColors.slate800,
                            fontSize: 14,
                          ),
                        ),
                        if (noti.message.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              noti.message,
                              style: const TextStyle(
                                color: AppColors.slate500,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(noti.time),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.slate400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isUnread)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: const BoxDecoration(
                        color: AppColors.blue500,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'order':
        return Icons.shopping_bag_outlined;
      case 'upgrade':
        return Icons.diamond_outlined;
      case 'system':
        return Icons.info_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _formatTime(String timeStr) {
    final dt = DateTime.tryParse(timeStr);
    if (dt == null) return timeStr;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
