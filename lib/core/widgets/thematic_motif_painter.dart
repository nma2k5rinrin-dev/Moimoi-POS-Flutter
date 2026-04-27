import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/constants.dart';

class ThematicMotifWidget extends StatelessWidget {
  final AppTheme theme;
  final Color overrideColor;

  const ThematicMotifWidget({super.key, required this.theme, required this.overrideColor});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ThematicMotifPainter(
        theme: theme,
        overrideColor: overrideColor,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _ThematicMotifPainter extends CustomPainter {
  final AppTheme theme;
  final Color overrideColor;

  _ThematicMotifPainter({required this.theme, required this.overrideColor});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(theme.index * 7 + 4321);

    final paint = Paint()
      ..color = overrideColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final paintLight = Paint()
      ..color = overrideColor.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    final paintAccent = Paint()
      ..color = overrideColor.withValues(alpha: 0.20)
      ..style = PaintingStyle.fill;

    // Denser motifs: 18–24 elements scattered across the screen
    int motifCount = size.height < 200 ? 10 : (size.height < 600 ? 18 : 24);

    for (int i = 0; i < motifCount; i++) {
      double startX = rng.nextDouble() * size.width;
      double startY = rng.nextDouble() * size.height;
      double scale = 0.6 + rng.nextDouble() * 1.8;
      double rot = rng.nextDouble() * math.pi * 2;

      // Alternate between lighter and normal opacity for depth
      final usePaint = (i % 3 == 0) ? paintAccent : (i % 2 == 0) ? paint : paintLight;

      canvas.save();
      canvas.translate(startX, startY);
      canvas.rotate(rot);
      canvas.scale(scale);

      switch (theme) {
        case AppTheme.rose:
          _drawCherryPetal(canvas, usePaint);
          break;
        case AppTheme.amber:
          _drawGinkgoLeaf(canvas, usePaint);
          break;
        case AppTheme.emerald:
          _drawLeaf(canvas, usePaint);
          break;
        case AppTheme.blue:
          _drawHydrangea(canvas, usePaint);
          break;
        case AppTheme.violet:
          _drawLavenderLeaf(canvas, usePaint);
          break;
      }

      canvas.restore();
    }
  }

  /// 🌸 Cánh hoa anh đào — 1 cánh rơi đơn lẻ
  void _drawCherryPetal(Canvas canvas, Paint paint) {
    Path p = Path();
    p.moveTo(0, -14);
    p.quadraticBezierTo(-10, -8, -8, 0);
    p.quadraticBezierTo(-4, 6, 0, 10);
    p.quadraticBezierTo(4, 6, 8, 0);
    p.quadraticBezierTo(10, -8, 0, -14);
    canvas.drawPath(p, paint);
  }

  /// 🍁 Lá phong mùa thu — classic 5-lobe maple leaf
  void _drawMapleLeaf(Canvas canvas, Paint paint) {
    Path p = Path();
    // Classic maple leaf silhouette (like Canadian flag)
    p.moveTo(0, -20);  // Đỉnh thùy giữa

    // Thùy giữa → khe phải trên
    p.lineTo(-4, -14);
    p.lineTo(-2, -13);

    // Thùy trái trên
    p.lineTo(-10, -16);
    p.lineTo(-8, -11);

    // Khe giữa trái
    p.lineTo(-5, -10);

    // Thùy trái ngang
    p.lineTo(-16, -8);
    p.lineTo(-14, -5);
    p.lineTo(-10, -6);

    // Thùy trái dưới
    p.lineTo(-8, -2);
    p.lineTo(-10, 2);

    // Gốc trái
    p.lineTo(-5, 0);
    p.lineTo(-3, 4);

    // Cuống
    p.lineTo(-1, 4);
    p.lineTo(-1, 12);
    p.lineTo(1, 12);
    p.lineTo(1, 4);

    // Gốc phải (mirror)
    p.lineTo(3, 4);
    p.lineTo(5, 0);

    // Thùy phải dưới
    p.lineTo(10, 2);
    p.lineTo(8, -2);

    // Thùy phải ngang
    p.lineTo(10, -6);
    p.lineTo(14, -5);
    p.lineTo(16, -8);

    // Khe giữa phải
    p.lineTo(5, -10);

    // Thùy phải trên
    p.lineTo(8, -11);
    p.lineTo(10, -16);

    // Khe phải trên → đỉnh
    p.lineTo(2, -13);
    p.lineTo(4, -14);

    p.close();
    canvas.drawPath(p, paint);
  }

  /// 🍃 Lá cây thường — hình lá đơn giản không gân
  void _drawLeaf(Canvas canvas, Paint paint) {
    Path p = Path();
    p.moveTo(0, -16);
    p.quadraticBezierTo(-14, -5, 0, 16);
    p.quadraticBezierTo(14, -5, 0, -16);
    canvas.drawPath(p, paint);
  }

  /// 💐 Hoa cẩm tú cầu — cụm hoa nhỏ tròn xếp chặt
  void _drawHydrangea(Canvas canvas, Paint paint) {
    final positions = [
      const Offset(-5, -5), const Offset(5, -5),
      const Offset(-5, 5), const Offset(5, 5),
      const Offset(0, -8), const Offset(0, 8),
      const Offset(-8, 0), const Offset(8, 0),
      const Offset(0, 0),
    ];
    for (final pos in positions) {
      _drawSmallFloret(canvas, pos, paint);
    }
  }

  void _drawSmallFloret(Canvas canvas, Offset center, Paint paint) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    for (int i = 0; i < 4; i++) {
      Path p = Path();
      p.moveTo(0, 0);
      p.quadraticBezierTo(-2.5, -4, 0, -5.5);
      p.quadraticBezierTo(2.5, -4, 0, 0);
      canvas.drawPath(p, paint);
      canvas.rotate(math.pi / 2);
    }
    canvas.drawCircle(Offset.zero, 1.2, Paint()..color = paint.color.withValues(alpha: 0.3));
    canvas.restore();
  }

  /// 💜 Lá oải hương (lavender) — hình lá dài thon nhọn
  void _drawLavenderLeaf(Canvas canvas, Paint paint) {
    Path p = Path();
    p.moveTo(0, -20);
    p.quadraticBezierTo(-7, -10, -5, 0);
    p.quadraticBezierTo(-3, 8, 0, 16);
    p.quadraticBezierTo(3, 8, 5, 0);
    p.quadraticBezierTo(7, -10, 0, -20);
    canvas.drawPath(p, paint);
  }

  /// 🍂 Lá bạch quả (ginkgo biloba) — hình quạt có khe giữa
  void _drawGinkgoLeaf(Canvas canvas, Paint paint) {
    // Fan-shaped ginkgo leaf with central notch
    Path p = Path();
    // Cuống lá
    p.moveTo(0, 16);
    p.lineTo(-1, 6);
    // Cánh trái — cong ra ngoài tạo hình quạt
    p.quadraticBezierTo(-16, -2, -14, -14);
    p.quadraticBezierTo(-10, -20, -3, -16);
    // Khe giữa đặc trưng của lá bạch quả
    p.quadraticBezierTo(-1, -10, 0, -12);
    p.quadraticBezierTo(1, -10, 3, -16);
    // Cánh phải — mirror
    p.quadraticBezierTo(10, -20, 14, -14);
    p.quadraticBezierTo(16, -2, 1, 6);
    p.close();
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(covariant _ThematicMotifPainter oldDelegate) {
    return oldDelegate.theme != theme || oldDelegate.overrideColor != overrideColor;
  }
}
