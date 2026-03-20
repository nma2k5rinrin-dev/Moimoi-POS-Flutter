import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../utils/constants.dart';
import '../utils/avatar_picker.dart';

/// Shows a crop dialog where the user can drag & resize a square crop frame
/// over the image. Returns base64 data-URI or null if cancelled.
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
      return _SquareCropDialog(
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

class _SquareCropDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final double borderRadius;
  final String title;
  const _SquareCropDialog({
    required this.imageBytes,
    required this.borderRadius,
    required this.title,
  });

  @override
  State<_SquareCropDialog> createState() => _SquareCropDialogState();
}

class _SquareCropDialogState extends State<_SquareCropDialog> {
  bool _exporting = false;

  // Image natural size
  int _imgW = 0;
  int _imgH = 0;

  // Displayed image size (fitted in viewport)
  double _displayW = 0;
  double _displayH = 0;

  // Crop rect in display coordinates
  double _cropX = 0;
  double _cropY = 0;
  double _cropSize = 100;

  // Drag state
  _DragMode _dragMode = _DragMode.none;
  Offset _dragStart = Offset.zero;
  double _startCropX = 0;
  double _startCropY = 0;
  double _startCropSize = 0;

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

  void _initCropIfNeeded(double viewportW, double viewportH) {
    if (_initialized || _imgW == 0) return;
    _initialized = true;

    // Fit image in viewport
    final scaleX = viewportW / _imgW;
    final scaleY = viewportH / _imgH;
    final scale = math.min(scaleX, scaleY);
    _displayW = _imgW * scale;
    _displayH = _imgH * scale;

    // Init crop: centered square, 80% of smaller dimension
    _cropSize = math.min(_displayW, _displayH) * 0.8;
    _cropX = (_displayW - _cropSize) / 2;
    _cropY = (_displayH - _cropSize) / 2;
  }

  void _clampCrop() {
    _cropSize = _cropSize.clamp(40.0, math.min(_displayW, _displayH));
    _cropX = _cropX.clamp(0.0, _displayW - _cropSize);
    _cropY = _cropY.clamp(0.0, _displayH - _cropSize);
  }

  _DragMode _hitTest(Offset local) {
    const handleSize = 28.0;
    final r = Rect.fromLTWH(_cropX, _cropY, _cropSize, _cropSize);

    // Corner handles (resize)
    if ((local - r.topLeft).distance < handleSize) return _DragMode.resizeTL;
    if ((local - r.topRight).distance < handleSize) return _DragMode.resizeTR;
    if ((local - r.bottomLeft).distance < handleSize) return _DragMode.resizeBL;
    if ((local - r.bottomRight).distance < handleSize) return _DragMode.resizeBR;

    // Inside crop = move
    if (r.contains(local)) return _DragMode.move;

    return _DragMode.none;
  }

  void _onPanStart(DragStartDetails d) {
    final local = d.localPosition;
    _dragMode = _hitTest(local);
    _dragStart = local;
    _startCropX = _cropX;
    _startCropY = _cropY;
    _startCropSize = _cropSize;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_dragMode == _DragMode.none) return;
    final local = d.localPosition;
    final dx = local.dx - _dragStart.dx;
    final dy = local.dy - _dragStart.dy;

    setState(() {
      if (_dragMode == _DragMode.move) {
        _cropX = _startCropX + dx;
        _cropY = _startCropY + dy;
      } else {
        // Resize from corner — keep square
        double delta;
        switch (_dragMode) {
          case _DragMode.resizeBR:
            delta = math.max(dx, dy);
            _cropSize = _startCropSize + delta;
            break;
          case _DragMode.resizeTL:
            delta = math.min(dx, dy);
            _cropSize = _startCropSize - delta;
            _cropX = _startCropX + (_startCropSize - _cropSize);
            _cropY = _startCropY + (_startCropSize - _cropSize);
            break;
          case _DragMode.resizeTR:
            delta = math.max(dx, -dy);
            _cropSize = _startCropSize + delta;
            _cropY = _startCropY + (_startCropSize - _cropSize);
            break;
          case _DragMode.resizeBL:
            delta = math.max(-dx, dy);
            _cropSize = _startCropSize + delta;
            _cropX = _startCropX + (_startCropSize - _cropSize);
            break;
          default:
            break;
        }
      }
      _clampCrop();
    });
  }

  void _onPanEnd(DragEndDetails d) {
    _dragMode = _DragMode.none;
  }

  Future<void> _handleConfirm() async {
    setState(() => _exporting = true);
    try {
      // Calculate crop in original image coordinates
      final scale = _imgW / _displayW;
      final srcX = (_cropX * scale).round();
      final srcY = (_cropY * scale).round();
      final srcSize = (_cropSize * scale).round();

      // Decode and crop using image package
      final decoded = img.decodeImage(widget.imageBytes);
      if (decoded == null) {
        setState(() => _exporting = false);
        return;
      }

      final cropped = img.copyCrop(decoded,
          x: srcX.clamp(0, decoded.width - 1),
          y: srcY.clamp(0, decoded.height - 1),
          width: srcSize.clamp(1, decoded.width - srcX.clamp(0, decoded.width - 1)),
          height: srcSize.clamp(1, decoded.height - srcY.clamp(0, decoded.height - 1)));

      // Resize to max dimension if needed
      img.Image processed = cropped;
      if (cropped.width > maxImageDimension || cropped.height > maxImageDimension) {
        processed = img.copyResize(cropped,
            width: maxImageDimension, interpolation: img.Interpolation.linear);
      }

      // Encode as JPEG (compressed), label as webp
      var quality = 85;
      var compressed = Uint8List.fromList(img.encodeJpg(processed, quality: quality));
      while (compressed.length > maxImageFileBytes && quality > 30) {
        quality -= 10;
        compressed = Uint8List.fromList(img.encodeJpg(processed, quality: quality));
      }

      final base64Str = 'data:image/webp;base64,${base64Encode(compressed)}';

      if (mounted) Navigator.pop(context, base64Str);
    } catch (e) {
      debugPrint('[SquareCrop] export error: $e');
      setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final viewportW = (screenSize.width - 80).clamp(200.0, 440.0);
    final viewportH = (screenSize.height * 0.5).clamp(200.0, 440.0);

    _initCropIfNeeded(viewportW, viewportH);

    return Center(
      child: Container(
        width: viewportW + 48,
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
                    Row(
                      children: [
                        const Icon(Icons.crop_rounded,
                            size: 20, color: AppColors.emerald600),
                        const SizedBox(width: 8),
                        Text(
                          widget.title,
                          style: const TextStyle(
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
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                child: Column(
                  children: [
                    const Text(
                      'Kéo để di chuyển • Kéo góc để thay đổi kích thước',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.slate400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Image + crop frame
                    Container(
                      width: viewportW,
                      height: viewportH,
                      decoration: BoxDecoration(
                        color: AppColors.slate800,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _imgW == 0
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.emerald500))
                          : Stack(
                              children: [
                                // Centered image
                                Positioned(
                                  left: (viewportW - _displayW) / 2,
                                  top: (viewportH - _displayH) / 2,
                                  child: GestureDetector(
                                    onPanStart: _onPanStart,
                                    onPanUpdate: _onPanUpdate,
                                    onPanEnd: _onPanEnd,
                                    child: SizedBox(
                                      width: _displayW,
                                      height: _displayH,
                                      child: Stack(
                                        children: [
                                          // Full image
                                          Image.memory(
                                            widget.imageBytes,
                                            width: _displayW,
                                            height: _displayH,
                                            fit: BoxFit.fill,
                                          ),
                                          // Dark overlay outside crop
                                          CustomPaint(
                                            size: Size(_displayW, _displayH),
                                            painter: _CropOverlayPainter(
                                              cropRect: Rect.fromLTWH(
                                                  _cropX, _cropY,
                                                  _cropSize, _cropSize),
                                              borderRadius:
                                                  widget.borderRadius,
                                            ),
                                          ),
                                          // Corner handles
                                          ..._buildCornerHandles(),
                                        ],
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

              // Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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

  List<Widget> _buildCornerHandles() {
    const size = 20.0;
    const half = size / 2;
    final positions = [
      Offset(_cropX - half, _cropY - half),          // TL
      Offset(_cropX + _cropSize - half, _cropY - half),  // TR
      Offset(_cropX - half, _cropY + _cropSize - half),  // BL
      Offset(_cropX + _cropSize - half, _cropY + _cropSize - half), // BR
    ];

    return positions.map((pos) {
      return Positioned(
        left: pos.dx,
        top: pos.dy,
        child: IgnorePointer(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.emerald500, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }
}

enum _DragMode { none, move, resizeTL, resizeTR, resizeBL, resizeBR }

/// Draws dark overlay outside the crop rect with a clear cutout.
class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;
  final double borderRadius;

  _CropOverlayPainter({required this.cropRect, required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final cropRRect =
        RRect.fromRectAndRadius(cropRect, Radius.circular(borderRadius.clamp(0, cropRect.width / 2)));

    // Dark overlay
    final overlayPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(fullRect)
      ..addRRect(cropRRect);
    canvas.drawPath(
      overlayPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill,
    );

    // White border on crop
    canvas.drawRRect(
      cropRRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Grid lines (rule of thirds)
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 0.5;

    final thirdW = cropRect.width / 3;
    final thirdH = cropRect.height / 3;
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(cropRect.left + thirdW * i, cropRect.top),
        Offset(cropRect.left + thirdW * i, cropRect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left, cropRect.top + thirdH * i),
        Offset(cropRect.right, cropRect.top + thirdH * i),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter old) =>
      old.cropRect != cropRect;
}
