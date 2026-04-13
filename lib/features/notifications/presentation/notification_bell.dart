import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moimoi_pos/features/auth/logic/auth_store_standalone.dart';
import 'package:moimoi_pos/core/state/ui_store.dart';
import 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/widgets/animated_dialogs.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<UIStore>();
    final unreadCount = context.watch<ManagementStore>().notifications.where((n) => !n.read).length;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(
            Icons.notifications_outlined,
            color: AppColors.slate500,
            size: 28,
          ),
          onPressed: () => _showNotificationDialog(context, store),
        ),
        if (unreadCount > 0)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.red500,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBg, width: 2),
              ),
              constraints: BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                '${unreadCount > 99 ? '99+' : unreadCount}',
                style: TextStyle(
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

  void _showNotificationDialog(BuildContext context, UIStore store) {
    showAnimatedDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(24),
        child: _NotificationDialogContent(store: store),
      ),
    );
  }
}

class _NotificationDialogContent extends StatefulWidget {
  final UIStore store;
  const _NotificationDialogContent({required this.store});

  @override
  State<_NotificationDialogContent> createState() =>
      _NotificationDialogContentState();
}

class _NotificationDialogContentState extends State<_NotificationDialogContent>
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
      child: Consumer<UIStore>(
        builder: (context, store, _) {
          final unread = context.watch<ManagementStore>().notifications.where((n) => !n.read).toList();
          final read = context.watch<ManagementStore>().notifications.where((n) => n.read).toList();

          return Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxWidth: 480,
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 12, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.amber100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.notifications_rounded,
                          color: Color(0xFFF59E0B),
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
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
                              context.read<ManagementStore>().markNotificationAsRead(n.id);
                            }
                          },
                          child: Text(
                            'Đọc tất cả',
                            style: TextStyle(
                              color: AppColors.blue500,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (context.watch<AuthStore>().currentUser?.role == 'sadmin')
                        IconButton(
                          onPressed: () {
                            Navigator.pop(
                              context,
                            ); // Close notification dialog first
                            _showBroadcastDialog(context, store);
                          },
                          icon: Icon(
                            Icons.campaign,
                            color: AppColors.blue500,
                            size: 24,
                          ),
                          splashRadius: 20,
                          tooltip: 'Phát sóng thông báo',
                        ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close_rounded,
                          color: AppColors.slate400,
                          size: 22,
                        ),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ),

                // ── Tabs ──
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppColors.slate800,
                    unselectedLabelColor: AppColors.slate400,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    indicatorColor: AppColors.emerald500,
                    indicatorWeight: 3,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: AppColors.slate200,
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Chưa đọc'),
                            if (unread.isNotEmpty) ...[
                              SizedBox(width: 6),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.red500,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${unread.length > 99 ? '99+' : unread.length}',
                                  style: TextStyle(
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
                            Text('Đã đọc'),
                            if (read.isNotEmpty) ...[
                              SizedBox(width: 6),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.slate300,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${read.length}',
                                  style: TextStyle(
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
    UIStore store,
    List notifications, {
    required IconData emptyIcon,
    required String emptyText,
    required bool isUnread,
  }) {
    if (notifications.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(emptyIcon, size: 48, color: AppColors.slate300),
            SizedBox(height: 12),
            Text(
              emptyText,
              style: TextStyle(
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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: notifications.length,
      itemBuilder: (_, i) {
        final noti = notifications[i];
        return Container(
          margin: EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isUnread ? AppColors.blue50 : AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isUnread ? Color(0xFFBFDBFE) : AppColors.slate200,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              if (isUnread) {
                context.read<ManagementStore>().markNotificationAsRead(noti.id);
              }
            },
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isUnread ? Color(0xFFDBEAFE) : AppColors.slate100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getIcon(noti.type),
                      color: isUnread ? AppColors.blue500 : AppColors.slate400,
                      size: 18,
                    ),
                  ),
                  SizedBox(width: 12),
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
                            padding: EdgeInsets.only(top: 2),
                            child: Text(
                              noti.message,
                              style: TextStyle(
                                color: AppColors.slate500,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        SizedBox(height: 4),
                        Text(
                          _formatTime(noti.time),
                          style: TextStyle(
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
                      margin: EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
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

// ═══════════════════════════════════════════════════════════
// BROADCAST DIALOG
// ═══════════════════════════════════════════════════════════
void _showBroadcastDialog(BuildContext context, UIStore store) {
  final titleCtrl = TextEditingController();
  final messageCtrl = TextEditingController();
  String target = 'all_stores';

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (stfCtx, setState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.campaign, color: AppColors.blue500, size: 24),
              SizedBox(width: 8),
              Text(
                'Phát sóng',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.slate800,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tiêu đề',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate600,
                  ),
                ),
                SizedBox(height: 6),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    hintText: 'VD: Bảo trì hệ thống',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: AppColors.slate400,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.slate200),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    isDense: true,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Nội dung',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate600,
                  ),
                ),
                SizedBox(height: 6),
                TextField(
                  controller: messageCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Nhập nội dung thông báo...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: AppColors.slate400,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.slate200),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Đối tượng nhận',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate600,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.scaffoldBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        value: 'all_stores',
                        groupValue: target,
                        onChanged: (val) => setState(() => target = val!),
                        title: Text(
                          'Tất cả cửa hàng (Admins)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        activeColor: AppColors.blue500,
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      Divider(height: 1, color: AppColors.slate200),
                      RadioListTile<String>(
                        value: 'all_users',
                        groupValue: target,
                        onChanged: (val) => setState(() => target = val!),
                        title: Text(
                          'Toàn bộ người dùng',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        activeColor: AppColors.blue500,
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Hủy',
                style: TextStyle(
                  color: AppColors.slate400,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleCtrl.text.trim();
                final msg = messageCtrl.text.trim();
                if (title.isEmpty || msg.isEmpty) {
                  store.showToast(
                    'Vui lòng nhập đầy đủ tiêu đề và nội dung',
                    'error',
                  );
                  return;
                }
                context.read<ManagementStore>().broadcastNotification(
                  title: title,
                  message: msg,
                  target: target,
                );
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue500,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text('Gửi', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    ),
  );
}
