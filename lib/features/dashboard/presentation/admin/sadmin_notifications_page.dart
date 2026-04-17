import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:moimoi_pos/core/state/ui_store.dart';
import 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';
import 'package:moimoi_pos/features/auth/models/user_model.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:uuid/uuid.dart';

class SadminNotificationsPage extends StatefulWidget {
  const SadminNotificationsPage({super.key});

  @override
  State<SadminNotificationsPage> createState() =>
      _SadminNotificationsPageState();
}

class _SadminNotificationsPageState extends State<SadminNotificationsPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _targetAudience = 'all_shops'; // 'all_shops', 'all_users'
  bool _isSending = false;

  void _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);
    final store = context.read<UIStore>();
    final mStore = context.read<ManagementStore>();
    final List<UserModel> users = mStore.users;
    final supabase = Supabase.instance.client;

    try {
      // Determine target users
      final targetUsers = users.where((user) {
        if (_targetAudience == 'all_shops') return user.role! == 'admin';
        return user.role! != 'sadmin';
      }).toList();

      if (targetUsers.isEmpty) {
        store.showToast('Không có người dùng nào phù hợp để nhận thông báo.');
        setState(() => _isSending = false);
        return;
      }

      final now = DateTime.now().toIso8601String();
      final uuid = const Uuid();
      final List<Map<String, dynamic>> payload = targetUsers
          .map(
            (u) => {
              'id': uuid.v4(),
              'user_id': u.username,
              'title': _titleController.text.trim(),
              'message': _messageController.text.trim(),
              'read': false,
              'time': now,
            },
          )
          .toList();

      // Bulk insert
      await supabase.from('notifications').insert(payload);

      _titleController.clear();
      _messageController.clear();
      if (mounted) {
        store.showToast(
          'Đã gửi thông báo thành công đến ${targetUsers.length} người!',
        );
      }
    } catch (e) {
      if (mounted) store.showToast('Có lỗi xảy ra: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Gửi Thông Báo Hệ Thống',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.cardBg,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.0),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.blue50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        PhosphorIconsFill.bellRinging,
                        color: AppColors.blue600,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Soạn Thông Báo Mới',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Gửi tin nhắn trực tiếp đến các chủ cửa hàng hoặc toàn bộ nhân viên',
                            style: TextStyle(
                              color: AppColors.slate500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 32),

                // Form fields
                Text(
                  'Tiêu đề thông báo',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  validator: (v) => v!.isEmpty ? 'Vui lòng nhập tiêu đề' : null,
                  decoration: InputDecoration(
                    hintText: 'VD: Cập nhật tính năng mới POS...',
                    filled: true,
                    fillColor: AppColors.slate50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                SizedBox(height: 20),

                Text(
                  'Nội dung chi tiết',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _messageController,
                  maxLines: 5,
                  validator: (v) =>
                      v!.isEmpty ? 'Vui lòng nhập nội dung' : null,
                  decoration: InputDecoration(
                    hintText: 'Nội dung thông báo...',
                    filled: true,
                    fillColor: AppColors.slate50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                SizedBox(height: 20),

                Text(
                  'Đối tượng nhận',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile(
                        value: 'all_shops',
                        groupValue: _targetAudience,
                        onChanged: (v) =>
                            setState(() => _targetAudience = v.toString()),
                        title: Text('Tất cả Chủ Cửa Hàng'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.emerald500,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile(
                        value: 'all_users',
                        groupValue: _targetAudience,
                        onChanged: (v) =>
                            setState(() => _targetAudience = v.toString()),
                        title: Text('Toàn bộ người dùng'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.emerald500,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSending ? null : _sendNotification,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald500,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSending
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: AppColors.cardBg,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(PhosphorIconsBold.paperPlaneRight),
                              SizedBox(width: 8),
                              Text(
                                'Phát sóng Thông báo',
                                style: TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
