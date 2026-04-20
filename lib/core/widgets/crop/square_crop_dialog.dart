import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/utils/avatar_picker.dart';

/// Hộp thoại cắt ảnh dạng Modal (Facebook Web style).
/// Cung cấp lớp phủ mask và thanh trượt zoom.
Future<String?> showSquareCropDialog(
  BuildContext context, {
  required Uint8List imageBytes,
  double borderRadius = 24,
  String title = 'Cắt ảnh sản phẩm',
}) {
  return showGeneralDialog<String?>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xCC000000),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, anim1, anim2) {
      return _FbCropDialog(
        imageBytes: imageBytes,
        borderRadius: borderRadius,
        title: title,
      );
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

class _FbCropDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final double borderRadius;
  final String title;
  const _FbCropDialog({
    required this.imageBytes,
    required this.borderRadius,
    required this.title,
  });

  @override
  State<_FbCropDialog> createState() => _FbCropDialogState();
}

class _FbCropDialogState extends State<_FbCropDialog> {
  bool _exporting = false;
  int _imgW = 0;
  int _imgH = 0;

  Offset _offset = Offset.zero;
  double _scale = 1.0;

  Offset _startOffset = Offset.zero;
  double _startScale = 1.0;
  int _pointerCount = 0;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadImageDimensions();
  }

  Future<void> _loadImageDimensions() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    _imgW = frame.image.width;
    _imgH = frame.image.height;
    frame.image.dispose();
    if (mounted) setState(() {});
  }

  double _baseScale(double cropSize) {
    if (_imgW == 0 || _imgH == 0) return 1.0;
    final shorter = math.min(_imgW, _imgH).toDouble();
    return cropSize / shorter;
  }

  void _initIfNeeded(double cropSize, Size viewportSize) {
    if (_initialized || _imgW == 0) return;
    _initialized = true;

    final base = _baseScale(cropSize);
    _scale = base;

    // Center image inside the VIEWPORT (the Stack)
    _offset = Offset(
      (viewportSize.width - (_imgW * base)) / 2,
      (viewportSize.height - (_imgH * base)) / 2,
    );
  }

  void _clampOffset(double cropSize, Size viewportSize) {
    final imgDisplayW = _imgW * _scale;
    final imgDisplayH = _imgH * _scale;

    // The crop area is centered in the viewport
    final cropLeft = (viewportSize.width - cropSize) / 2;
    final cropTop = (viewportSize.height - cropSize) / 2;
    final cropRight = cropLeft + cropSize;
    final cropBottom = cropTop + cropSize;

    final minDx = cropRight - imgDisplayW;
    final maxDx = cropLeft;
    final clampedX = _offset.dx.clamp(minDx, maxDx);

    final minDy = cropBottom - imgDisplayH;
    final maxDy = cropTop;
    final clampedY = _offset.dy.clamp(minDy, maxDy);

    _offset = Offset(clampedX, clampedY);
  }

  void _clampScale(double cropSize) {
    final minScale = _baseScale(cropSize);
    _scale = _scale.clamp(minScale, minScale * 5.0);
  }

  void _onScaleStart(ScaleStartDetails d) {
    _startOffset = _offset;
    _startScale = _scale;
    _pointerCount = d.pointerCount;
  }

  void _onScaleUpdate(
    ScaleUpdateDetails d,
    double cropSize,
    Size viewportSize,
  ) {
    setState(() {
      if (_pointerCount >= 2) {
        final oldScale = _scale;
        _scale = _startScale * d.scale;
        _clampScale(cropSize);

        final viewportCenter = Offset(
          viewportSize.width / 2,
          viewportSize.height / 2,
        );

        _offset += d.focalPointDelta;
        _offset = Offset(
          viewportCenter.dx -
              (viewportCenter.dx - _offset.dx) * (_scale / oldScale),
          viewportCenter.dy -
              (viewportCenter.dy - _offset.dy) * (_scale / oldScale),
        );
      } else {
        _offset += d.focalPointDelta;
      }
      _clampOffset(cropSize, viewportSize);
    });
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _pointerCount = 0;
  }

  Future<void> _handleConfirm(double cropSize, Size viewportSize) async {
    setState(() => _exporting = true);
    try {
      final cropLeft = (viewportSize.width - cropSize) / 2;
      final cropTop = (viewportSize.height - cropSize) / 2;

      final srcX = ((cropLeft - _offset.dx) / _scale).round();
      final srcY = ((cropTop - _offset.dy) / _scale).round();
      final srcSize = (cropSize / _scale).round();

      final decoded = img.decodeImage(widget.imageBytes);
      if (decoded == null) {
        setState(() => _exporting = false);
        return;
      }

      final cropped = img.copyCrop(
        decoded,
        x: srcX.clamp(0, decoded.width - 1),
        y: srcY.clamp(0, decoded.height - 1),
        width: srcSize.clamp(
          1,
          decoded.width - srcX.clamp(0, decoded.width - 1),
        ),
        height: srcSize.clamp(
          1,
          decoded.height - srcY.clamp(0, decoded.height - 1),
        ),
      );

      img.Image processed = cropped;
      if (cropped.width > maxImageDimension ||
          cropped.height > maxImageDimension) {
        processed = img.copyResize(
          cropped,
          width: maxImageDimension,
          interpolation: img.Interpolation.linear,
        );
      }

      var quality = 85;
      var compressed = Uint8List.fromList(
        img.encodeJpg(processed, quality: quality),
      );
      while (compressed.length > maxImageFileBytes && quality > 30) {
        quality -= 10;
        compressed = Uint8List.fromList(
          img.encodeJpg(processed, quality: quality),
        );
      }

      final base64Str = 'data:image/webp;base64,${base64Encode(compressed)}';
      if (mounted) Navigator.pop(context, base64Str);
    } catch (e) {
      debugPrint('[FbCrop] export error: $e');
      setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final cropSize = (math.min(screenSize.width, screenSize.height) * 0.65)
        .clamp(200.0, 360.0);

    // Dialog dimensions
    final dialogWidth = cropSize + 48;
    final viewportSize = Size(dialogWidth, cropSize + 60);

    _initIfNeeded(cropSize, viewportSize);

    return Center(
      child: Container(
        width: dialogWidth,
        margin: EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E), // Dark theme FB style
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 40,
              offset: Offset(0, 12),
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
                padding: EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.crop_rounded,
                      size: 20,
                      color: AppColors.primary400,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.cardBg.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Image & Mask Viewport ───────────────────
              SizedBox(
                width: viewportSize.width,
                height: viewportSize.height,
                child: _imgW == 0
                    ? Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary400,
                        ),
                      )
                    : GestureDetector(
                        onScaleStart: _onScaleStart,
                        onScaleUpdate: (d) =>
                            _onScaleUpdate(d, cropSize, viewportSize),
                        onScaleEnd: _onScaleEnd,
                        child: Stack(
                          children: [
                            // 1. Zoomable Image covering the viewport
                            Container(
                              width: viewportSize.width,
                              height: viewportSize.height,
                              color: Colors.transparent,
                            ),
                            Positioned(
                              left: _offset.dx,
                              top: _offset.dy,
                              child: Image.memory(
                                widget.imageBytes,
                                width: _imgW * _scale,
                                height: _imgH * _scale,
                                fit: BoxFit.fill,
                              ),
                            ),

                            // 2. Facebook-style Mask Overlay with cutout
                            IgnorePointer(
                              child: CustomPaint(
                                size: viewportSize,
                                painter: _BoxMaskPainter(
                                  cropSize: cropSize,
                                  borderRadius: widget.borderRadius,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),

              // ── Zoom slider ────────────────────────
              if (_imgW > 0)
                Padding(
                  padding: EdgeInsets.fromLTRB(32, 16, 32, 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.photo_size_select_small,
                        size: 16,
                        color: Colors.white.withOpacity(0.4),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: AppColors.primary500,
                            inactiveTrackColor: Colors.white.withOpacity(0.12),
                            thumbColor: AppColors.primary400,
                            overlayColor: AppColors.primary500.withOpacity(
                              0.15,
                            ),
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7,
                            ),
                          ),
                          child: Slider(
                            value: _scale,
                            min: _baseScale(cropSize),
                            max: _baseScale(cropSize) * 5.0,
                            onChanged: (v) {
                              setState(() {
                                final oldScale = _scale;
                                _scale = v;
                                final center = Offset(
                                  viewportSize.width / 2,
                                  viewportSize.height / 2,
                                );
                                _offset = Offset(
                                  center.dx -
                                      (center.dx - _offset.dx) *
                                          (_scale / oldScale),
                                  center.dy -
                                      (center.dy - _offset.dy) *
                                          (_scale / oldScale),
                                );
                                _clampOffset(cropSize, viewportSize);
                              });
                            },
                          ),
                        ),
                      ),
                      Icon(
                        Icons.photo_size_select_large,
                        size: 16,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ],
                  ),
                ),

              // ── Buttons ────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.cardBg.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              'Hủy',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Colors.white70,
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
                        onTap: _exporting
                            ? null
                            : () => _handleConfirm(cropSize, viewportSize),
                        child: Container(
                          height: 46,
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

class _BoxMaskPainter extends CustomPainter {
  final double cropSize;
  final double borderRadius;

  _BoxMaskPainter({required this.cropSize, required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawColor(Colors.black.withOpacity(0.85), BlendMode.srcOver);

    // Punch hole
    final cropLeft = (size.width - cropSize) / 2;
    final cropTop = (size.height - cropSize) / 2;
    final holeRect = Rect.fromLTWH(cropLeft, cropTop, cropSize, cropSize);

    final clearPaint = Paint()..blendMode = BlendMode.clear;
    canvas.drawRRect(
      RRect.fromRectAndRadius(holeRect, Radius.circular(borderRadius)),
      clearPaint,
    );
    canvas.restore();

    // White border + grid
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final stepW = cropSize / 3;
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(cropLeft + stepW * i, cropTop),
        Offset(cropLeft + stepW * i, cropTop + cropSize),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropLeft, cropTop + stepW * i),
        Offset(cropLeft + cropSize, cropTop + stepW * i),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BoxMaskPainter old) => old.cropSize != cropSize;
}
