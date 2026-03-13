import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../store/app_store.dart';
import '../utils/constants.dart';

/// Store selector dropdown for SuperAdmin to switch between stores
class StoreSelector extends StatelessWidget {
  const StoreSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    if (store.currentUser?.role != 'sadmin') {
      return const SizedBox.shrink();
    }

    final adminUsers =
        store.users.where((u) => u.role == 'admin').toList();
    final currentStoreId = store.sadminViewStoreId;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.violet50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.violet200),
      ),
      child: DropdownButton<String>(
        value: currentStoreId,
        isExpanded: true,
        underline: const SizedBox(),
        icon: const Icon(Icons.unfold_more, color: AppColors.violet500),
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: AppColors.violet700,
        ),
        dropdownColor: Colors.white,
        items: [
          const DropdownMenuItem(
            value: 'all',
            child: Row(
              children: [
                Icon(Icons.all_inclusive,
                    size: 18, color: AppColors.violet500),
                SizedBox(width: 8),
                Text('👑 Tất cả cửa hàng'),
              ],
            ),
          ),
          ...adminUsers.map((admin) {
            final storeName = store.storeInfos[admin.username]?.name ??
                admin.fullname;
            return DropdownMenuItem(
              value: admin.username,
              child: Row(
                children: [
                  const Icon(Icons.store,
                      size: 18, color: AppColors.emerald500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      storeName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (admin.isPremium)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.amber500, AppColors.orange500],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'VIP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
        onChanged: (v) {
          if (v != null) store.setSadminViewStoreId(v);
        },
      ),
    );
  }
}
