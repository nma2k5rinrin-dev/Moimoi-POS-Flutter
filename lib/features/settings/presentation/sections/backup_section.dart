import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';

import 'package:intl/intl.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/features/settings/presentation/sections/shared_widgets.dart';

class BackupSection extends StatefulWidget {
  const BackupSection({super.key});

  @override
  State<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<BackupSection> {
  bool _isSyncing = false;
  String _lastSyncTime = '14:05, 03/04/2026';

  Future<void> _handleSync() async {
    setState(() => _isSyncing = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isSyncing = false;
        _lastSyncTime = DateFormat('HH:mm, dd/MM/yyyy').format(DateTime.now());
      });
      context.read<ManagementStore>().showToast('Đồng bộ dữ liệu thành công!');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 9),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 12),

                  // 1. Card Trạng Thái Đồng Bộ (Sync Status Card)
                  SettingsSectionCard(
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.emerald50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.cloud_done_rounded,
                            size: 40,
                            color: AppColors.emerald500,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Đã đồng bộ an toàn',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate800,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Đồng bộ lần cuối: $_lastSyncTime',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.slate500,
                          ),
                        ),
                        SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isSyncing ? null : _handleSync,
                            icon: _isSyncing
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.cardBg,
                                    ),
                                  )
                                : Icon(Icons.sync_rounded, size: 20),
                            label: Text(
                              _isSyncing ? 'Đang đồng bộ...' : 'Đồng bộ ngay',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.emerald500,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              disabledBackgroundColor: AppColors.emerald200,
                              disabledForegroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),

                  // 2. Thống Kê Dữ Liệu Đám Mây (Data Stats Section)
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: 'Thông tin cửa hàng, doanh thu',
                          value: 'Dữ liệu cửa hàng',
                          icon: Icons.store_rounded,
                          color: Colors.orange,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Các khoản thu chi, báo cáo thu chi',
                          value: 'Nhập/xuất',
                          icon: Icons.analytics_rounded,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: 'Tất cả các đơn hàng, trạng thái đơn hàng',
                          value: 'Đơn hàng',
                          icon: Icons.receipt_long_rounded,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Danh mục, sản phẩm, tồn kho, giá vốn',
                          value: 'Kho Hàng',
                          icon: Icons.inventory_2_rounded,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required MaterialColor color,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color.shade600),
          ),
          SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.slate800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.slate500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
