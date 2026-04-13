import 'dart:ui';
import 'package:flutter/material.dart';

class ToastOverlay extends StatelessWidget {
  final String message;
  final String type;

  const ToastOverlay({super.key, required this.message, this.type = 'success'});

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding > 0 ? topPadding + 8 : 24,
      left: 16,
      right: 16,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.translate(
              // Slide down from -100px to 0 with a bouncy elastic effect
              offset: Offset(0, -100 * (1 - value)),
              child: Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: config.accentColor.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: config.accentColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: config.accentColor.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Icon(
                            config.icon,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                config.title,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              if (message.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    message,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
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
          ),
        ),
      ),
    );
  }

  _ToastConfig _getConfig() {
    switch (type) {
      case 'error':
        return const _ToastConfig(
          title: 'Thất bại',
          icon: Icons.close_rounded,
          accentColor: Color(0xFFEF4444),
        );
      case 'warning':
        return const _ToastConfig(
          title: 'Cảnh báo',
          icon: Icons.priority_high_rounded,
          accentColor: Color(0xFFF59E0B),
        );
      case 'info':
        return const _ToastConfig(
          title: 'Thông tin',
          icon: Icons.info_outline_rounded,
          accentColor: Color(0xFF3B82F6),
        );
      default:
        return const _ToastConfig(
          title: 'Thành công',
          icon: Icons.check_rounded,
          accentColor: Color(0xFF10B981),
        );
    }
  }
}

class _ToastConfig {
  final String title;
  final IconData icon;
  final Color accentColor;

  const _ToastConfig({
    required this.title,
    required this.icon,
    required this.accentColor,
  });
}
