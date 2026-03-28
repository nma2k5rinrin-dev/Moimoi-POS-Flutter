import 'package:flutter/material.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/features/settings/presentation/sections/shared_widgets.dart';

class BackupSection extends StatelessWidget {
  const BackupSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  SettingsSectionCard(
                    child: Column(
                      children: [
                        Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.emerald50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.cloud_done_outlined, size: 36, color: AppColors.emerald400),
                        ),
                        const SizedBox(height: 16),
                        const Text('Dữ liệu tự động đồng bộ',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.slate800)),
                        const SizedBox(height: 8),
                        const Text('Dữ liệu của bạn được tự động lưu trữ trên đám mây thông qua Supabase. Tính năng xuất/nhập dữ liệu thủ công sẽ sớm được bổ sung.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: AppColors.slate500, height: 1.5)),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.emerald50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.emerald200),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline, color: AppColors.emerald600, size: 18),
                              SizedBox(width: 8),
                              Text('Đang hoạt động', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.emerald600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
