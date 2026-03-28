import 'package:flutter/material.dart';
import 'package:moimoi_pos/features/settings/presentation/menu_management.dart';
import 'package:moimoi_pos/core/utils/constants.dart';

/// Standalone inventory page that directly shows the menu management section.
/// This is used as the target for the "Quản lý kho" nav bar item.
class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.emerald50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.restaurant_menu,
                    size: 22, color: AppColors.emerald600),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quản Lý Danh Mục & Sản Phẩm',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slate800)),
                    SizedBox(height: 2),
                    Text('Thêm/sửa sản phẩm, danh mục',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.slate500)),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Content
        const Expanded(child: MenuManagementSection()),
      ],
    );
  }
}
