import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/utils/avatar_picker.dart';

/// Hộp thoại cắt ảnh vòng tròn (Modal Facebook Web style).
Future<String?> showCircleCropDialog(
  BuildContext context, {
  required Uint8List imageBytes,
}) {
  return showGeneralDialog<String?>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xCC000000),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, anim1, anim2) {
      return _CircleCropDialog(imageBytes: imageBytes);
    },
    transitionBuilder: (ctx, anim1, anim2, child) {
      return FadeTransition(opacity: anim1, child: child);
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
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _transformController.addListener(() {
      final double newScale = _transformController.value.getMaxScaleOnAxis();
      if (_currentScale != newScale) {
        setState(() {
          _currentScale = newScale;
        });
      }
    });
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    setState(() => _exporting = true);
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject()
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
    final double cropSize =
        (math.min(screenSize.width, screenSize.height) * 0.65).clamp(
          200.0,
          360.0,
        );

    final dialogWidth = cropSize + 48;
    final viewportSize = Size(dialogWidth, cropSize + 60);

    return Center(
      child: Container(
        width: dialogWidth,
        margin: EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
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
              // ── Header ─────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.crop_rounded,
                          size: 20,
                          color: AppColors.emerald600,
                        ),
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
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: AppColors.slate500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: AppColors.slate100),

              // ── Image Viewport ─────────────────────
              SizedBox(
                width: viewportSize.width,
                height: viewportSize.height,
                child: Stack(
                  children: [
                    // Base Interactive Viewer
                    SizedBox(
                      width: viewportSize.width,
                      height: viewportSize.height,
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            ui.PointerDeviceKind.touch,
                            ui.PointerDeviceKind.mouse,
                            ui.PointerDeviceKind.trackpad,
                          },
                        ),
                        child: InteractiveViewer(
                          transformationController: _transformController,
                          clipBehavior: Clip.none,
                          minScale: 0.5,
                          maxScale: 6.0,
                          child: Center(
                            child: Image.memory(
                              widget.imageBytes,
                              fit: BoxFit.contain,
                              width: viewportSize.width,
                              height: viewportSize.height,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Facebook style overlay mask inside dialog
                    IgnorePointer(
                      child: CustomPaint(
                        size: viewportSize,
                        painter: _CircleMaskPainter(cropSize: cropSize),
                      ),
                    ),

                    // Hidden RepaintBoundary perfectly aligned to the crop hole
                    IgnorePointer(
                      child: Center(
                        child: ClipOval(
                          child: RepaintBoundary(
                            key: _repaintKey,
                            child: Container(
                              color: Colors.transparent,
                              width: cropSize,
                              height: cropSize,
                              child: OverflowBox(
                                maxWidth: viewportSize.width,
                                maxHeight: viewportSize.height,
                                child: InteractiveViewer(
                                  transformationController:
                                      _transformController,
                                  clipBehavior: Clip.none,
                                  child: Center(
                                    child: Image.memory(
                                      widget.imageBytes,
                                      fit: BoxFit.contain,
                                      width: viewportSize.width,
                                      height: viewportSize.height,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Zoom slider ────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(32, 16, 32, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.photo_size_select_small,
                      size: 16,
                      color: AppColors.slate400,
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: AppColors.emerald500,
                          inactiveTrackColor: AppColors.slate200,
                          thumbColor: AppColors.emerald500,
                          overlayColor: AppColors.emerald500.withOpacity(0.15),
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7,
                          ),
                        ),
                        child: Slider(
                          value: _currentScale.clamp(0.5, 6.0),
                          min: 0.5,
                          max: 6.0,
                          onChanged: (v) {
                            final Matrix4 matrix = _transformController.value
                                .clone();
                            final double currentScale = matrix
                                .getMaxScaleOnAxis();

                            if (currentScale > 0) {
                              final double ratio = v / currentScale;
                              final center = Offset(
                                viewportSize.width / 2,
                                viewportSize.height / 2,
                              );
                              matrix.translate(center.dx, center.dy);
                              matrix.scale(ratio);
                              matrix.translate(-center.dx, -center.dy);
                              _transformController.value = matrix;
                            }
                          },
                        ),
                      ),
                    ),
                    Icon(
                      Icons.photo_size_select_large,
                      size: 16,
                      color: AppColors.slate400,
                    ),
                  ],
                ),
              ),

              // ── Buttons ────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.slate100,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
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
                    SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: _exporting ? null : _handleConfirm,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
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
                                ? SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 20,
                                        color: Colors.white,
                                      ),
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

class _CircleMaskPainter extends CustomPainter {
  final double cropSize;
  _CircleMaskPainter({required this.cropSize});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawColor(Colors.black.withOpacity(0.7), BlendMode.srcOver);

    // Punch hole
    final center = Offset(size.width / 2, size.height / 2);
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    canvas.drawCircle(center, cropSize / 2, clearPaint);
    canvas.restore();

    // Dashed border
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    const int dashCount = 36;
    for (int i = 0; i < dashCount; i++) {
      if (i % 2 == 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: cropSize / 2),
          i * (2 * math.pi / dashCount),
          (2 * math.pi / dashCount),
          false,
          borderPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CircleMaskPainter old) =>
      old.cropSize != cropSize;
}
