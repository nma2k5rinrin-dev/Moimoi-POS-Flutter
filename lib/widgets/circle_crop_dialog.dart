import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../utils/constants.dart';
import '../utils/avatar_picker.dart';

/// Shows a circular crop dialog matching the app's emerald theme.
/// Takes raw image [bytes] and returns the cropped circular image as a
/// base64 data-URI string, or null if the user cancels.
Future<String?> showCircleCropDialog(
  BuildContext context, {
  required Uint8List imageBytes,
}) {
  return showGeneralDialog<String?>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0xCC000000),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, anim1, anim2) {
      return _CircleCropDialog(imageBytes: imageBytes);
    },
    transitionBuilder: (ctx, anim1, anim2, child) {
      return FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: child,
        ),
      );
    },
  );
}

class _CircleCropDialog extends StatefulWidget {
  final Uint8List imageBytes;
  const _CircleCropDialog({required this.imageBytes});

  @override
  State<_CircleCropDialog> createState() => _CircleCropDialogState();
}

class _CircleCropDialogState extends State<_CircleCropDialog> {
  final GlobalKey _repaintKey = GlobalKey();
  final TransformationController _transformController =
      TransformationController();
  bool _exporting = false;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    setState(() => _exporting = true);

    try {
      // Capture the visible area via RepaintBoundary
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        setState(() => _exporting = false);
        return;
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        setState(() => _exporting = false);
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();
      final base64Str = await convertToWebpBase64(pngBytes);

      if (mounted) Navigator.pop(context, base64Str);
    } catch (e) {
      debugPrint('[CircleCrop] export error: $e');
      setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    // Crop area = min(screenWidth - 48, 360)
    final cropSize = (screenSize.width - 48).clamp(200.0, 360.0);

    return Center(
      child: Container(
        width: cropSize + 48,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 32,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.crop_rounded,
                            size: 20, color: AppColors.emerald600),
                        SizedBox(width: 8),
                        Text(
                          'Cắt ảnh đại diện',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: AppColors.slate800,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.slate100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.close,
                            size: 18, color: AppColors.slate500),
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: AppColors.slate100),

              // Crop area
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Column(
                  children: [
                    // Instruction
                    const Text(
                      'Kéo & phóng to ảnh để chọn vùng hiển thị',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.slate500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // The crop viewport
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: cropSize,
                        height: cropSize,
                        color: AppColors.slate800,
                        child: Stack(
                          children: [
                            // Image with zoom/pan
                            RepaintBoundary(
                              key: _repaintKey,
                              child: ClipOval(
                                child: SizedBox(
                                  width: cropSize,
                                  height: cropSize,
                                  child: InteractiveViewer(
                                    transformationController:
                                        _transformController,
                                    clipBehavior: Clip.none,
                                    minScale: 0.5,
                                    maxScale: 4.0,
                                    child: Image.memory(
                                      widget.imageBytes,
                                      fit: BoxFit.cover,
                                      width: cropSize,
                                      height: cropSize,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Circle overlay guide
                            IgnorePointer(
                              child: CustomPaint(
                                size: Size(cropSize, cropSize),
                                painter: _CircleOverlayPainter(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Row(
                  children: [
                    // Cancel
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.slate100,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Text(
                              'Hủy',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.slate600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Confirm
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: _exporting ? null : _handleConfirm,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFF10B981),
                                Color(0xFF059669),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x4010B981),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _exporting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle_rounded,
                                          size: 20, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text(
                                        'Xác nhận',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
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
    );
  }
}

/// Draws a dark overlay with a circular transparent cutout in the center,
/// plus a dashed circle border for visual guidance.
class _CircleOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // Dashed circle guide
    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, radius, guidePaint);

    // Corner brackets for visual appeal
    final bracketPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const arcLength = 0.3; // fraction of circle for each bracket
    for (int i = 0; i < 4; i++) {
      final startAngle = (i * 3.14159 / 2) - (arcLength / 2);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        arcLength,
        false,
        bracketPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
