import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moimoi_pos/core/state/app_store.dart';
import 'package:moimoi_pos/core/utils/constants.dart';

/// Store selector dropdown for SuperAdmin to switch between stores
class StoreSelector extends StatelessWidget {
  const StoreSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    if (store.currentUser?.role != 'sadmin') {
      return const SizedBox.shrink();
    }

    // Get all stores from storeInfos (excluding 'sadmin' default entry)
    final storeEntries = store.storeInfos.entries
        .where((e) => e.key != 'sadmin')
        .toList();
    final currentStoreId = store.sadminViewStoreId;
    final fieldKey = GlobalKey();

    // Get display text for current selection
    String displayText = '👑 Tất cả cửa hàng';
    if (currentStoreId != 'all') {
      final info = store.storeInfos[currentStoreId];
      displayText = info?.name ?? currentStoreId;
    }

    return GestureDetector(
      key: fieldKey,
      onTap: () {
        final renderBox = fieldKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) return;
        final position = renderBox.localToGlobal(Offset.zero);
        final fieldSize = renderBox.size;
        final screenHeight = MediaQuery.of(fieldKey.currentContext!).size.height;

        final items = <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: 'all',
            height: 48,
            child: Row(
              children: [
                Icon(Icons.all_inclusive, size: 18, color: AppColors.violet500),
                SizedBox(width: 8),
                Text('👑 Tất cả cửa hàng'),
              ],
            ),
          ),
          ...storeEntries.map((entry) {
            final storeId = entry.key;
            final info = entry.value;
            final storeName = info.name.isNotEmpty ? info.name : storeId;
            final isPremium = info.isPremium;
            return PopupMenuItem<String>(
              value: storeId,
              height: 48,
              child: Row(
                children: [
                  const Icon(Icons.store, size: 18, color: AppColors.emerald500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      storeName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: storeId == currentStoreId ? FontWeight.w700 : FontWeight.w500,
                        color: storeId == currentStoreId ? AppColors.emerald600 : AppColors.slate800,
                      ),
                    ),
                  ),
                  if (isPremium)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                  if (storeId == currentStoreId)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.check_circle, size: 18, color: AppColors.emerald600),
                    ),
                ],
              ),
            );
          }),
        ];

        final totalMenuHeight = items.length * 48.0 + 16;
        final spaceBelow = screenHeight - position.dy - fieldSize.height;
        final dropUp = spaceBelow < totalMenuHeight && position.dy > totalMenuHeight;
        final menuTop = dropUp
            ? position.dy - totalMenuHeight
            : position.dy + fieldSize.height;

        showMenu<String>(
          context: fieldKey.currentContext!,
          position: RelativeRect.fromLTRB(
            position.dx,
            menuTop,
            position.dx + fieldSize.width,
            menuTop + totalMenuHeight,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 8,
          constraints: BoxConstraints(
            minWidth: fieldSize.width,
            maxWidth: fieldSize.width,
          ),
          items: items,
        ).then((v) {
          if (v != null) store.setSadminViewStoreId(v);
        });
      },
      child: Container(
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.violet50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.violet200),
        ),
        child: Row(
          children: [
            Icon(
              currentStoreId == 'all' ? Icons.all_inclusive : Icons.store,
              size: 18,
              color: AppColors.violet500,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                displayText,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.violet700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.unfold_more, color: AppColors.violet500),
          ],
        ),
      ),
    );
  }
}
