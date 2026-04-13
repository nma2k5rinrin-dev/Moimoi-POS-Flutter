import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:moimoi_pos/core/models/confirm_dialog_data.dart';
import 'package:moimoi_pos/core/utils/constants.dart';

class ConfirmModal extends StatelessWidget {
  final ConfirmDialogData data;
  final VoidCallback onCancel;

  const ConfirmModal({super.key, required this.data, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final title = data.title;
    final description = data.description ?? data.message;
    final confirmLabel = data.confirmLabel ?? 'Xóa';

    return DefaultTextStyle(
      style: TextStyle(decoration: TextDecoration.none),
      child: Stack(
        children: [
          // ── Blurred Dim Overlay ──────────────
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                data.onCancel?.call();
                onCancel();
              },
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 4 * value,
                      sigmaY: 4 * value,
                    ),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.4 * value),
                    ),
                  );
                },
              ),
            ),
          ),

          // ── Centered Panel with scale+fade animation ──
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.85 + (0.15 * value),
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Opacity(opacity: value, child: child),
                  ),
                );
              },
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 21),
                padding: EdgeInsets.all(28),
                constraints: const BoxConstraints(maxWidth: 360),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 40,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Warning Icon Circle ──────────
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.red50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        data.icon ?? Icons.person_remove_rounded,
                        color: AppColors.red500,
                        size: 32,
                      ),
                    ),
                    SizedBox(height: 20),

                    // ── Title ────────────────────────
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.slate800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),

                    // ── Description ──────────────────
                    Text(
                      description,
                      style: TextStyle(fontSize: 13, color: AppColors.slate600),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20),

                    // ── Item Info Card (optional) ────
                    if (data.itemName != null) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.slate50,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            // Avatar
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color:
                                    (data.avatarColor ??
                                            const Color(0xFF3B82F6))
                                        .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: Text(
                                  data.avatarInitials ?? 'N',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        data.avatarColor ??
                                        const Color(0xFF3B82F6),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data.itemName!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.slate800,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (data.itemSubtitle != null) ...[
                                    SizedBox(height: 2),
                                    Text(
                                      data.itemSubtitle!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.slate500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                    ],

                    // ── Buttons ──────────────────────
                    Row(
                      children: [
                        // Cancel
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              data.onCancel?.call();
                              onCancel();
                            },
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.slate200,
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Hủy bỏ',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.slate600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),

                        // Delete/Confirm
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              data.onConfirm();
                              onCancel();
                            },
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppColors.red500,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.red500.withValues(
                                      alpha: 0.25,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.delete_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    confirmLabel,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ], // Row children (buttons)
                    ), // Row
                  ], // Column children
                ), // Column
              ), // Container
            ), // TweenAnimationBuilder
          ), // Center
        ], // Stack children
      ), // Stack
    ); // DefaultTextStyle
  }
}
