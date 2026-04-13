import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:vector_math/vector_math_64.dart' as vm;

import 'package:flutter/material.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/utils/avatar_picker.dart';

/// Custom avatar crop dialog with emerald-themed UI.
/// Shows a circle overlay on top of the image. User can zoom/pan to position
/// the desired crop area. A live preview badge shows the final result.
///
/// Returns the cropped image as base64 data URI, or null if cancelled.
Future<String?> showAvatarCropDialog(
  BuildContext context,
  Uint8List imageBytes,
) {
  return showGeneralDialog<String?>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (ctx, a1, a2) => _AvatarCropDialog(imageBytes: imageBytes),
    transitionBuilder: (ctx, a1, a2, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: a1, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(
            begin: 0.9,
            end: 1.0,
          ).animate(CurvedAnimation(parent: a1, curve: Curves.easeOut)),
          child: child,
        ),
      );
    },
  );
}

class _AvatarCropDialog extends StatefulWidget {
  final Uint8List imageBytes;
  const _AvatarCropDialog({required this.imageBytes});

  @override
  State<_AvatarCropDialog> createState() => _AvatarCropDialogState();
}

class _AvatarCropDialogState extends State<_AvatarCropDialog> {
  final TransformationController _controller = TransformationController();
  final GlobalKey _cropAreaKey = GlobalKey();

  // Crop area size (the circle diameter inside the view)
  static const double _cropSize = 280;
  static const double _previewSize = 64;

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Slight initial zoom-out so user sees entire image
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.value = Matrix4.identity();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<String?> _cropImage() async {
    setState(() => _isProcessing = true);

    try {
      // Decode the original image
      final codec = await ui.instantiateImageCodec(widget.imageBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // Get the transformation matrix
      final matrix = _controller.value;
      final inverted = Matrix4.copy(matrix)..invert();

      // The crop area center in widget coordinates
      // The InteractiveViewer is centered, so the crop circle center
      // is at the center of the _cropSize area
      final cropCenter = Offset(_cropSize / 2, _cropSize / 2);
      final radius = _cropSize / 2;

      // Convert crop corners to image coordinates
      final topLeft = _transformPoint(
        inverted,
        cropCenter - Offset(radius, radius),
      );
      final bottomRight = _transformPoint(
        inverted,
        cropCenter + Offset(radius, radius),
      );

      // Calculate source rectangle in image pixel space
      // The image is fitted to cover the crop area, so we need to account for
      // the aspect ratio fitting
      final imgW = image.width.toDouble();
      final imgH = image.height.toDouble();

      // The image is displayed filling the InteractiveViewer area which is _cropSize × _cropSize
      // with BoxFit.cover logic
      final scale = math.max(_cropSize / imgW, _cropSize / imgH);
      final displayW = imgW * scale;
      final displayH = imgH * scale;
      final offsetX = (_cropSize - displayW) / 2;
      final offsetY = (_cropSize - displayH) / 2;

      // Map widget coords → image pixel coords
      double toImgX(double wx) => (wx - offsetX) / scale;
      double toImgY(double wy) => (wy - offsetY) / scale;

      var srcLeft = toImgX(topLeft.dx);
      var srcTop = toImgY(topLeft.dy);
      var srcRight = toImgX(bottomRight.dx);
      var srcBottom = toImgY(bottomRight.dy);

      // Clamp
      srcLeft = srcLeft.clamp(0, imgW);
      srcTop = srcTop.clamp(0, imgH);
      srcRight = srcRight.clamp(0, imgW);
      srcBottom = srcBottom.clamp(0, imgH);

      final srcRect = Rect.fromLTRB(srcLeft, srcTop, srcRight, srcBottom);

      // Draw to a 512×512 canvas with circle clip
      const outSize = 512;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final dstRect = Rect.fromLTWH(
        0,
        0,
        outSize.toDouble(),
        outSize.toDouble(),
      );

      // Circle clip
      canvas.clipPath(Path()..addOval(dstRect));

      // Draw the source crop area into the destination
      canvas.drawImageRect(
        image,
        srcRect,
        dstRect,
        Paint()..filterQuality = FilterQuality.high,
      );

      final picture = recorder.endRecording();
      final outImage = await picture.toImage(outSize, outSize);
      final byteData = await outImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) return null;

      final pngBytes = byteData.buffer.asUint8List();
      return await convertToWebpBase64(pngBytes);
    } catch (_) {
      return null;
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Offset _transformPoint(Matrix4 matrix, Offset point) {
    final v = matrix.transform3(vm.Vector3(point.dx, point.dy, 0));
    return Offset(v.x, v.y);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = math.min(screenWidth - 32, 420.0);
    final cropDisplaySize = math.min(dialogWidth - 40, _cropSize);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: dialogWidth,
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──
              Container(
                padding: EdgeInsets.fromLTRB(24, 20, 16, 16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.emerald50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.crop_rounded,
                        color: AppColors.emerald600,
                        size: 22,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cắt ảnh đại diện',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Kéo và phóng to để chọn vùng hiển thị',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.slate400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppColors.slate400,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.scaffoldBg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Crop Area ──
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20),
                width: cropDisplaySize,
                height: cropDisplaySize,
                decoration: BoxDecoration(
                  color: AppColors.slate900,
                  borderRadius: BorderRadius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Interactive image
                    SizedBox(
                      width: cropDisplaySize,
                      height: cropDisplaySize,
                      key: _cropAreaKey,
                      child: InteractiveViewer(
                        transformationController: _controller,
                        minScale: 0.5,
                        maxScale: 4.0,
                        boundaryMargin: EdgeInsets.all(cropDisplaySize),
                        child: Image.memory(
                          widget.imageBytes,
                          fit: BoxFit.cover,
                          width: cropDisplaySize,
                          height: cropDisplaySize,
                        ),
                      ),
                    ),
                    // Circle mask overlay
                    IgnorePointer(
                      child: CustomPaint(
                        size: Size(cropDisplaySize, cropDisplaySize),
                        painter: _CircleMaskPainter(
                          circleRadius: cropDisplaySize / 2 - 16,
                        ),
                      ),
                    ),
                    // Corner guides
                    IgnorePointer(
                      child: SizedBox(
                        width: cropDisplaySize,
                        height: cropDisplaySize,
                        child: CustomPaint(
                          painter: _CornerGuidePainter(
                            circleRadius: cropDisplaySize / 2 - 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // ── Preview Badge ──
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.slate100),
                ),
                child: Row(
                  children: [
                    // Preview circle
                    Container(
                      width: _previewSize,
                      height: _previewSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.emerald200,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.emerald500.withValues(alpha: 0.15),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.memory(
                          widget.imageBytes,
                          fit: BoxFit.cover,
                          width: _previewSize,
                          height: _previewSize,
                        ),
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Xem trước',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Ảnh sẽ hiển thị dạng tròn',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.slate400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.emerald50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.zoom_in_rounded,
                            size: 14,
                            color: AppColors.emerald600,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Phóng to để cắt',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.emerald600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // ── Action Buttons ──
              Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    // Cancel
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _isProcessing
                              ? null
                              : () => Navigator.pop(context),
                          icon: Icon(Icons.close_rounded, size: 18),
                          label: Text('Hủy bỏ'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.slate600,
                            side: BorderSide(color: AppColors.slate200),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    // Confirm
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing
                              ? null
                              : () async {
                                  final result = await _cropImage();
                                  if (!context.mounted) return;
                                  Navigator.pop(context, result);
                                },
                          icon: _isProcessing
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(Icons.check_rounded, size: 20),
                          label: Text(
                            _isProcessing ? 'Đang xử lý...' : 'Xác nhận',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.emerald500,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.emerald500
                                .withValues(alpha: 0.7),
                            disabledForegroundColor: Colors.white.withValues(
                              alpha: 0.8,
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
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

/// Paints a semi-transparent dark overlay with a circular cutout in the center.
class _CircleMaskPainter extends CustomPainter {
  final double circleRadius;
  _CircleMaskPainter({required this.circleRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.55);

    // Draw full dark rect, then cut out the circle
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addOval(Rect.fromCircle(center: center, radius: circleRadius)),
      ),
      paint,
    );

    // Draw circle border
    canvas.drawCircle(
      center,
      circleRadius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Paints small corner guide marks around the circle to indicate drag handles.
class _CornerGuidePainter extends CustomPainter {
  final double circleRadius;
  _CornerGuidePainter({required this.circleRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = AppColors.emerald400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const arcLen = 0.35; // radians
    final r = circleRadius;

    // Draw small arcs at 4 corners (top-left, top-right, bottom-right, bottom-left)
    for (final angle in [
      -math.pi * 0.75, // top-left
      -math.pi * 0.25, // top-right
      math.pi * 0.25, //  bottom-right
      math.pi * 0.75, //  bottom-left
    ]) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        angle - arcLen / 2,
        arcLen,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
