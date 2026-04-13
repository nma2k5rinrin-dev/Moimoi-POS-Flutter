import 'package:flutter/material.dart';

/// Safely get the barrier label, falling back to a default string
/// if MaterialLocalizations is not available in the context.
String _safeBarrierLabel(BuildContext context) {
  try {
    return MaterialLocalizations.of(context).modalBarrierDismissLabel;
  } catch (_) {
    return 'Dismiss';
  }
}

/// Shows a dialog with a smooth scale + fade animation.
/// Drop-in replacement for `showDialog` with better UX.
Future<T?> showAnimatedDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool barrierDismissible = true,
  Color barrierColor = const Color(0x66000000),
  Duration transitionDuration = const Duration(milliseconds: 250),
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: _safeBarrierLabel(context),
    barrierColor: barrierColor,
    transitionDuration: transitionDuration,
    pageBuilder: (context, animation, secondaryAnimation) {
      return builder(context);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return ScaleTransition(
        scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

/// Shows a bottom sheet with a smooth slide + fade animation.
/// Drop-in replacement for `showModalBottomSheet` with smoother entry.
Future<T?> showAnimatedBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool isScrollControlled = true,
  bool isDismissible = true,
  Color? backgroundColor,
  double? elevation,
  ShapeBorder? shape,
  BoxConstraints? constraints,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    backgroundColor: backgroundColor ?? Colors.transparent,
    elevation: elevation,
    shape: shape,
    constraints: constraints,
    transitionAnimationController: AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 200),
    ),
    builder: builder,
  );
}
