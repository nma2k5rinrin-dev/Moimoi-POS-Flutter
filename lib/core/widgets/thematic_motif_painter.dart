import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/constants.dart';

class ThematicMotifWidget extends StatelessWidget {
  final AppTheme theme;
  final Color overrideColor;

  const ThematicMotifWidget({Key? key, required this.theme, required this.overrideColor}) : super(key: key);

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
    var rng = math.Random(theme.index + 9000); 
    
    final paint = Paint()
      ..color = overrideColor.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
      
    final paintSolid = Paint()
      ..color = overrideColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    // Make motifs much sparser based on user request (8 instead of 16)
    int maxCount = size.height < 100 ? 5 : 8;
    for (int i = 0; i < maxCount; i++) {
        double startX = rng.nextDouble() * size.width;
        double startY = rng.nextDouble() * size.height;
        double scale = 0.8 + rng.nextDouble() * 1.5;
        double rot = rng.nextDouble() * math.pi * 2;
        
        canvas.save();
        canvas.translate(startX, startY);
        canvas.rotate(rot);
        canvas.scale(scale);

        switch (theme) {
          case AppTheme.rose: _drawCherryBlossom(canvas, paint); break;
          case AppTheme.amber: _drawDaisy(canvas, paint, paintSolid); break;
          case AppTheme.emerald: _drawLeaf(canvas, paint); break;
          case AppTheme.blue: _drawHydrangea(canvas, paint); break;
          case AppTheme.violet: _drawLotus(canvas, paint); break;
        }

        canvas.restore();
    }
  }

  void _drawCherryBlossom(Canvas canvas, Paint paint) {
    canvas.save();
    for(int i = 0; i < 5; i++) {
      Path p = Path();
      p.moveTo(0, 0);
      p.quadraticBezierTo(-8, -4, -5, -12);
      p.lineTo(-2, -10);
      p.lineTo(2, -10);
      p.lineTo(5, -12);
      p.quadraticBezierTo(8, -4, 0, 0);
      canvas.drawPath(p, paint);
      canvas.rotate(math.pi * 2 / 5);
    }
    canvas.restore();
    canvas.drawCircle(Offset.zero, 2.5, Paint()..color = paint.color.withValues(alpha: 0.3));
  }

  void _drawDaisy(Canvas canvas, Paint paint, Paint solidPaint) {
    canvas.save();
    for(int i = 0; i < 8; i++) {
      Path p = Path();
      p.moveTo(0, 0);
      p.quadraticBezierTo(-5, -8, 0, -15);
      p.quadraticBezierTo(5, -8, 0, 0);
      canvas.drawPath(p, paint);
      canvas.rotate(math.pi * 2 / 8);
    }
    canvas.restore();
    canvas.drawCircle(Offset.zero, 3.5, solidPaint);
  }

  void _drawLeaf(Canvas canvas, Paint paint) {
    Path p = Path();
    p.moveTo(0, -14);
    p.quadraticBezierTo(-12, -4, 0, 14);
    p.quadraticBezierTo(12, -4, 0, -14);
    canvas.drawPath(p, paint);
  }

  void _drawHydrangeaFlorets(Canvas canvas, Paint paint) {
    Path p = Path();
    p.addOval(Rect.fromCenter(center: const Offset(-4, -4), width: 10, height: 10));
    p.addOval(Rect.fromCenter(center: const Offset(4, -4), width: 10, height: 10));
    p.addOval(Rect.fromCenter(center: const Offset(-4, 4), width: 10, height: 10));
    p.addOval(Rect.fromCenter(center: const Offset(4, 4), width: 10, height: 10));
    canvas.drawPath(p, paint);
    canvas.drawCircle(Offset.zero, 2, Paint()..color = paint.color.withValues(alpha: 0.4));
  }

  void _drawHydrangea(Canvas canvas, Paint paint) {
    canvas.save();
    canvas.translate(-4, -4);
    _drawHydrangeaFlorets(canvas, paint);
    canvas.restore();
    
    canvas.save();
    canvas.translate(4, -4);
    _drawHydrangeaFlorets(canvas, paint);
    canvas.restore();
    
    canvas.save();
    canvas.translate(0, 5);
    _drawHydrangeaFlorets(canvas, paint);
    canvas.restore();
  }

  void _drawLotus(Canvas canvas, Paint paint) {
    Path p = Path();
    p.moveTo(0, 2);
    p.quadraticBezierTo(-6, -10, 0, -18);
    p.quadraticBezierTo(6, -10, 0, 2);
    
    p.moveTo(0, 2);
    p.quadraticBezierTo(-12, -4, -12, -12);
    p.quadraticBezierTo(-6, -2, 0, 2);
    
    p.moveTo(0, 2);
    p.quadraticBezierTo(12, -4, 12, -12);
    p.quadraticBezierTo(6, -2, 0, 2);
    
    p.moveTo(0, 2);
    p.quadraticBezierTo(-16, 4, -18, -4);
    p.quadraticBezierTo(-10, 4, 0, 2);
    
    p.moveTo(0, 2);
    p.quadraticBezierTo(16, 4, 18, -4);
    p.quadraticBezierTo(10, 4, 0, 2);
    
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(covariant _ThematicMotifPainter oldDelegate) {
    return oldDelegate.theme != theme || oldDelegate.overrideColor != overrideColor;
  }
}
