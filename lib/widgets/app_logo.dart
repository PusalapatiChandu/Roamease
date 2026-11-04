import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showShadow;
  final bool showText;
  final bool showTagline;
  final double? borderRadius;

  const AppLogo({
    super.key,
    this.size = 64,
    this.showShadow = true,
    this.showText = false,
    this.showTagline = false,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = borderRadius ?? (size * 0.24);

    Widget iconWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        gradient: const LinearGradient(
          colors: [Color(0xFF0A1128), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppColors.cyan5G.withOpacity(0.6),
          width: size > 40 ? 1.5 : 1.0,
        ),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: AppColors.cyan5G.withOpacity(0.35),
                  blurRadius: size * 0.35,
                  spreadRadius: 1,
                  offset: Offset(0, size * 0.08),
                ),
                BoxShadow(
                  color: AppColors.primaryBlue.withOpacity(0.25),
                  blurRadius: size * 0.5,
                  offset: Offset(0, size * 0.15),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Embedded Logo Asset (if exists) or Custom Brand Vector
            Image.asset(
              'assets/images/logo.png',
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => CustomPaint(
                size: Size(size, size),
                painter: _LogoPainter(size: size),
              ),
            ),
          ],
        ),
      ),
    );

    if (!showText) {
      return iconWidget;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconWidget,
        const SizedBox(height: 12),
        Text(
          AppConstants.appName,
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.navyDark,
            letterSpacing: 0.8,
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 4),
          Text(
            'Smart Mobile Roaming & 5G Location',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: size * 0.18,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _LogoPainter extends CustomPainter {
  final double size;

  _LogoPainter({required this.size});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final center = Offset(size / 2, size / 2);

    // 1. Diagonal Roaming Orbit Ring
    final orbitPaint = Paint()
      ..shader = const SweepGradient(
        colors: [
          Colors.transparent,
          AppColors.primaryBlue,
          AppColors.cyan5G,
          Colors.transparent,
        ],
        stops: [0.0, 0.4, 0.8, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: size * 0.42))
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.045
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 4);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: size * 0.78,
        height: size * 0.34,
      ),
      orbitPaint,
    );
    canvas.restore();

    // 2. Concentric 5G Signal Arcs (Left and Right)
    final arcPaint = Paint()
      ..color = AppColors.cyan5G
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Outer arc
    arcPaint.strokeWidth = size * 0.04;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size * 0.28),
      -math.pi * 0.75,
      math.pi * 0.5,
      false,
      arcPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size * 0.28),
      math.pi * 0.25,
      math.pi * 0.5,
      false,
      arcPaint,
    );

    // Inner arc
    arcPaint.strokeWidth = size * 0.035;
    arcPaint.color = Colors.white;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size * 0.18),
      -math.pi * 0.75,
      math.pi * 0.5,
      false,
      arcPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size * 0.18),
      math.pi * 0.25,
      math.pi * 0.5,
      false,
      arcPaint,
    );

    // 3. Central Antenna Tower Mast
    final towerPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.white, AppColors.cyan5G],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size, size))
      ..style = PaintingStyle.fill;

    // Glowing core beacon bulb
    final beaconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx, center.dy - size * 0.08), size * 0.08, beaconPaint);

    final glowPaint = Paint()
      ..color = AppColors.cyan5G.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.03;
    canvas.drawCircle(Offset(center.dx, center.dy - size * 0.08), size * 0.08, glowPaint);

    // Tower A-frame legs
    final towerPath = Path()
      ..moveTo(center.dx - size * 0.04, center.dy - size * 0.06)
      ..lineTo(center.dx + size * 0.04, center.dy - size * 0.06)
      ..lineTo(center.dx + size * 0.16, center.dy + size * 0.32)
      ..lineTo(center.dx + size * 0.08, center.dy + size * 0.32)
      ..lineTo(center.dx, center.dy + size * 0.06)
      ..lineTo(center.dx - size * 0.08, center.dy + size * 0.32)
      ..lineTo(center.dx - size * 0.16, center.dy + size * 0.32)
      ..close();

    canvas.drawPath(towerPath, towerPaint);

    // Cross brace on tower
    final bracePaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.025;
    canvas.drawLine(
      Offset(center.dx - size * 0.09, center.dy + size * 0.18),
      Offset(center.dx + size * 0.09, center.dy + size * 0.18),
      bracePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
