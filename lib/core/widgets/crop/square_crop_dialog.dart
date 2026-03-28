import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/utils/avatar_picker.dart';

/// Facebook-style crop dialog.
/// Fixed square overlay in the center; user drags & pinch-zooms the image
/// behind the overlay. Returns base64 data-URI or null if cancelled.
Future<String?> showSquareCropDialog(
  BuildContext context, {
  required Uint8List imageBytes,
  double borderRadius = 24,
  String title = 'Cắt ảnh sản phẩm',
}) {
  return showGeneralDialog<String?>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
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

  // Image natural size
  int _imgW = 0;
  int _imgH = 0;

  // Transform state — image offset & scale
  Offset _offset = Offset.zero;
  double _scale = 1.0;

  // Gesture accumulation
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

  /// Compute base scale so image covers the crop square
  double _baseScale(double cropSize) {
    if (_imgW == 0 || _imgH == 0) return 1.0;
    final shorter = math.min(_imgW, _imgH).toDouble();
    return cropSize / shorter;
  }

  /// Initialize offset to center the image over the crop
  void _initIfNeeded(double cropSize) {
    if (_initialized || _imgW == 0) return;
    _initialized = true;
    final base = _baseScale(cropSize);
    _scale = base;
    // Center image over crop square
    _offset = Offset(
      -((_imgW * base) - cropSize) / 2,
      -((_imgH * base) - cropSize) / 2,
    );
  }

  /// Clamp offset so the crop square is always over image content
  void _clampOffset(double cropSize) {
    final imgDisplayW = _imgW * _scale;
    final imgDisplayH = _imgH * _scale;

    // image offset must be <= 0 (left/top edge at or before crop origin)
    // image offset + image size must be >= cropSize
    _offset = Offset(
      _offset.dx.clamp(cropSize - imgDisplayW, 0.0),
      _offset.dy.clamp(cropSize - imgDisplayH, 0.0),
    );
  }

  /// Enforce minimum scale = base (so image always covers crop)
  void _clampScale(double cropSize) {
    final minScale = _baseScale(cropSize);
    _scale = _scale.clamp(minScale, minScale * 5.0);
  }

  // ── Gesture handlers ───────────────────────────────
  void _onScaleStart(ScaleStartDetails d) {
    _startOffset = _offset;
    _startScale = _scale;
    _pointerCount = d.pointerCount;
  }

  void _onScaleUpdate(ScaleUpdateDetails d, double cropSize) {
    setState(() {
      if (_pointerCount >= 2) {
        // Pinch-to-zoom
        _scale = _startScale * d.scale;
        _clampScale(cropSize);
      }
      // Pan
      _offset = _startOffset + d.focalPointDelta;
      _clampOffset(cropSize);
    });
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _pointerCount = 0;
  }

  // ── Export cropped image ───────────────────────────
  Future<void> _handleConfirm(double cropSize) async {
    setState(() => _exporting = true);
    try {
      // Convert display coords to original image coords
      final srcX = (-_offset.dx / _scale).round();
      final srcY = (-_offset.dy / _scale).round();
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
        width: srcSize.clamp(1, decoded.width - srcX.clamp(0, decoded.width - 1)),
        height: srcSize.clamp(1, decoded.height - srcY.clamp(0, decoded.height - 1)),
      );

      // Resize to max dimension if needed
      img.Image processed = cropped;
      if (cropped.width > maxImageDimension || cropped.height > maxImageDimension) {
        processed = img.copyResize(cropped,
            width: maxImageDimension, interpolation: img.Interpolation.linear);
      }

      // Encode as JPEG, label as webp
      var quality = 85;
      var compressed = Uint8List.fromList(img.encodeJpg(processed, quality: quality));
      while (compressed.length > maxImageFileBytes && quality > 30) {
        quality -= 10;
        compressed = Uint8List.fromList(img.encodeJpg(processed, quality: quality));
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
    // Crop square size — responsive
    final cropSize = (math.min(screenSize.width, screenSize.height) * 0.65)
        .clamp(200.0, 420.0);

    _initIfNeeded(cropSize);

    return Center(
      child: Container(
        width: cropSize + 48,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
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
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    const Icon(Icons.crop_rounded, size: 20, color: AppColors.emerald400),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
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
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.close, size: 18, color: Colors.white54),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Hint ───────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Kéo để di chuyển • Chụm để phóng to',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // ── Crop viewport ──────────────────────
              Container(
                width: cropSize,
                height: cropSize,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  color: Colors.black,
                ),
                clipBehavior: Clip.antiAlias,
                child: _imgW == 0
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.emerald400))
                    : GestureDetector(
                        onScaleStart: _onScaleStart,
                        onScaleUpdate: (d) => _onScaleUpdate(d, cropSize),
                        onScaleEnd: _onScaleEnd,
                        child: Stack(
                          children: [
                            // Image (movable & zoomable)
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
                            // Grid overlay (rule of thirds)
                            CustomPaint(
                              size: Size(cropSize, cropSize),
                              painter: _GridPainter(),
                            ),
                          ],
                        ),
                      ),
              ),

              const SizedBox(height: 8),

              // ── Zoom slider ────────────────────────
              if (_imgW > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    children: [
                      Icon(Icons.photo_size_select_small,
                          size: 16, color: Colors.white.withValues(alpha: 0.4)),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: AppColors.emerald500,
                            inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                            thumbColor: AppColors.emerald400,
                            overlayColor: AppColors.emerald500.withValues(alpha: 0.15),
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                          ),
                          child: Slider(
                            value: _scale,
                            min: _baseScale(cropSize),
                            max: _baseScale(cropSize) * 5.0,
                            onChanged: (v) {
                              setState(() {
                                final oldScale = _scale;
                                _scale = v;
                                // Zoom toward center
                                final center = cropSize / 2;
                                _offset = Offset(
                                  center - (center - _offset.dx) * (_scale / oldScale),
                                  center - (center - _offset.dy) * (_scale / oldScale),
                                );
                                _clampOffset(cropSize);
                              });
                            },
                          ),
                        ),
                      ),
                      Icon(Icons.photo_size_select_large,
                          size: 16, color: Colors.white.withValues(alpha: 0.4)),
                    ],
                  ),
                ),

              const SizedBox(height: 4),

              // ── Buttons ────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
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
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: _exporting ? null : () => _handleConfirm(cropSize),
                        child: Container(
                          height: 46,
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
                                    width: 22, height: 22,
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

/// Draws rule-of-thirds grid lines
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 0.5;

    final thirdW = size.width / 3;
    final thirdH = size.height / 3;
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(thirdW * i, 0),
        Offset(thirdW * i, size.height),
        gridPaint,
      );
      canvas.drawLine(
        Offset(0, thirdH * i),
        Offset(size.width, thirdH * i),
        gridPaint,
      );
    }

    // Subtle border
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
