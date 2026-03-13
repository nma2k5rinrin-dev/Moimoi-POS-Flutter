import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../store/app_store.dart';
import '../utils/constants.dart';

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
          onPressed: () => _showNotifications(context, store),
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

  void _showNotifications(BuildContext context, AppStore store) {
    final notifications = store.notifications;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🔔 Thông Báo',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slate800,
                    ),
                  ),
                  if (notifications.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        store.clearNotifications(
                            store.currentUser?.username ?? '');
                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        'Xoá tất cả',
                        style: TextStyle(
                          color: AppColors.red500,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            // List
            Flexible(
              child: notifications.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_none,
                              size: 56, color: AppColors.slate300),
                          const SizedBox(height: 12),
                          const Text(
                            'Không có thông báo nào',
                            style: TextStyle(
                              color: AppColors.slate400,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: notifications.length,
                      itemBuilder: (_, i) {
                        final noti = notifications[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: noti.read
                                ? Colors.white
                                : AppColors.blue50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: noti.read
                                  ? AppColors.slate200
                                  : AppColors.blue200,
                            ),
                          ),
                          child: InkWell(
                            onTap: () {
                              if (!noti.read) {
                                store.markNotificationAsRead(noti.id);
                              }
                            },
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: noti.read
                                        ? AppColors.slate100
                                        : AppColors.blue100,
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _getIcon(noti.type),
                                    color: noti.read
                                        ? AppColors.slate400
                                        : AppColors.blue500,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        noti.title,
                                        style: TextStyle(
                                          fontWeight: noti.read
                                              ? FontWeight.w500
                                              : FontWeight.w700,
                                          color: AppColors.slate800,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (noti.message.isNotEmpty)
                                        Text(
                                          noti.message,
                                          style: const TextStyle(
                                            color: AppColors.slate500,
                                            fontSize: 12,
                                          ),
                                          maxLines: 2,
                                          overflow:
                                              TextOverflow.ellipsis,
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
                                if (!noti.read)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.blue500,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
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
