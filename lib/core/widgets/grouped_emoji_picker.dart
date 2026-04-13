import 'package:flutter/material.dart';
import 'package:moimoi_pos/core/constants/app_emojis.dart';
import 'package:moimoi_pos/core/utils/constants.dart';

class GroupedEmojiPicker extends StatelessWidget {
  final String? selectedEmoji;
  final ValueChanged<String> onEmojiSelected;

  const GroupedEmojiPicker({
    super.key,
    this.selectedEmoji,
    required this.onEmojiSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 8),
      itemCount: AppEmojis.groups.length,
      itemBuilder: (context, index) {
        final group = AppEmojis.groups[index];
        return Padding(
          padding: EdgeInsets.only(bottom: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  group.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate600,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: group.emojis.map((emoji) {
                    final isSelected = emoji == selectedEmoji;
                    return GestureDetector(
                      onTap: () => onEmojiSelected(emoji),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.emerald100
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: AppColors.emerald200)
                              : null,
                        ),
                        child: Text(emoji, style: TextStyle(fontSize: 28)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
