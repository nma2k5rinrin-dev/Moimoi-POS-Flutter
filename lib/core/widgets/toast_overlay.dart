import 'package:flutter/material.dart';
import 'package:moimoi_pos/core/utils/constants.dart';

class ToastOverlay extends StatelessWidget {
  final String message;
  final String type;

  const ToastOverlay({
    super.key,
    required this.message,
    this.type = 'success',
  });

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, -20 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: config.bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: config.borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: config.shadowColor,
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: config.iconBgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(config.icon, color: config.iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          config.title,
                          style: TextStyle(
                            color: config.textColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        if (message.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              message,
                              style: TextStyle(
                                color: config.textColor.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _ToastConfig _getConfig() {
    switch (type) {
      case 'error':
        return _ToastConfig(
          title: 'Lỗi',
          icon: Icons.close_rounded,
          bgColor: const Color(0xFFFFF5F5),
          borderColor: const Color(0xFFFED7D7),
          iconBgColor: AppColors.red100,
          iconColor: AppColors.red500,
          textColor: AppColors.red600,
          shadowColor: AppColors.red500.withValues(alpha: 0.12),
        );
      case 'warning':
        return _ToastConfig(
          title: 'Cảnh báo',
          icon: Icons.warning_amber_rounded,
          bgColor: const Color(0xFFFFFBEB),
          borderColor: const Color(0xFFFDE68A),
          iconBgColor: AppColors.amber100,
          iconColor: AppColors.amber600,
          textColor: const Color(0xFF92400E),
          shadowColor: AppColors.amber500.withValues(alpha: 0.12),
        );
      default:
        return _ToastConfig(
          title: 'Thành công',
          icon: Icons.check_rounded,
          bgColor: const Color(0xFFF0FDF4),
          borderColor: const Color(0xFFBBF7D0),
          iconBgColor: AppColors.emerald100,
          iconColor: AppColors.emerald600,
          textColor: AppColors.emerald800,
          shadowColor: AppColors.emerald500.withValues(alpha: 0.12),
        );
    }
  }
}

class _ToastConfig {
  final String title;
  final IconData icon;
  final Color bgColor;
  final Color borderColor;
  final Color iconBgColor;
  final Color iconColor;
  final Color textColor;
  final Color shadowColor;

  const _ToastConfig({
    required this.title,
    required this.icon,
    required this.bgColor,
    required this.borderColor,
    required this.iconBgColor,
    required this.iconColor,
    required this.textColor,
    required this.shadowColor,
  });
}
