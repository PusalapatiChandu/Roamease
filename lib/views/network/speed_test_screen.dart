import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/speed_test_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/network_provider.dart';
import '../../widgets/custom_button.dart';

class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen> with SingleTickerProviderStateMixin {
  late AnimationController _needleController;
  late Animation<double> _needleAnimation;
  double _currentSpeedValue = 0.0;
  double _targetSpeedValue = 0.0;

  @override
  void initState() {
    super.initState();
    _needleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _needleAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _needleController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _needleController.dispose();
    super.dispose();
  }

  void _animateNeedleTo(double newSpeed) {
    if ((newSpeed - _targetSpeedValue).abs() > 0.05) {
      _needleAnimation = Tween<double>(
        begin: _currentSpeedValue,
        end: newSpeed,
      ).animate(
        CurvedAnimation(parent: _needleController, curve: Curves.easeOutCubic),
      );
      _targetSpeedValue = newSpeed;
      _needleController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final networkProvider = Provider.of<NetworkProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    final isRunning = networkProvider.isRunningSpeedTest;
    final progress = networkProvider.speedTestProgress;
    final latest = networkProvider.latestSpeedTest;
    final network = networkProvider.currentNetwork;
    final userId = authProvider.currentSubscriber?.uid ?? 'guest';

    double displayedSpeed = 0.0;
    String stageText = 'Ready to Test';
    SpeedTestStage stage = SpeedTestStage.idle;

    if (isRunning && progress != null) {
      stage = progress.stage;
      displayedSpeed = progress.currentSpeedMbps;
      switch (stage) {
        case SpeedTestStage.ping:
          stageText = 'Measuring Latency & Jitter...';
          break;
        case SpeedTestStage.download:
          stageText = 'Testing Download Throughput...';
          break;
        case SpeedTestStage.upload:
          stageText = 'Testing Upload Speed...';
          break;
        case SpeedTestStage.completed:
          stageText = 'Speed Test Completed';
          break;
        default:
          stageText = 'Connecting to Node...';
      }
    } else if (latest != null) {
      displayedSpeed = latest.downloadSpeedMbps;
      stageText = 'Latest Verified Test';
      stage = SpeedTestStage.completed;
    }

    // Animate needle smoothly to displayed speed
    _animateNeedleTo(displayedSpeed);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Interactive Speedometer'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              // 1. Operator & Network Technology Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.cell_tower_rounded, color: AppColors.primaryBlue, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              network.operatorName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              network.isRoaming ? 'Roaming Network' : 'Home Carrier Band',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: network.is5gActive ? AppColors.card5GGradient : null,
                        color: !network.is5gActive ? AppColors.primaryBlue.withOpacity(0.15) : null,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        network.networkType,
                        style: TextStyle(
                          color: network.is5gActive ? Colors.white : AppColors.primaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. Stage Stepper Bar (Ping -> Download -> Upload)
              Row(
                children: [
                  _buildStageChip(
                    icon: Icons.timer_outlined,
                    label: 'Ping',
                    value: progress != null && progress.currentPingMs > 0
                        ? '${progress.currentPingMs} ms'
                        : (latest != null ? '${latest.pingMs} ms' : '--'),
                    isActive: stage == SpeedTestStage.ping,
                    isDone: stage == SpeedTestStage.download ||
                        stage == SpeedTestStage.upload ||
                        stage == SpeedTestStage.completed,
                    color: AppColors.accentIndigo,
                  ),
                  const SizedBox(width: 8),
                  _buildStageChip(
                    icon: Icons.arrow_downward_rounded,
                    label: 'Download',
                    value: progress != null && progress.currentDownloadMbps > 0
                        ? '${progress.currentDownloadMbps.toStringAsFixed(1)} Mbps'
                        : (latest != null ? '${latest.downloadSpeedMbps.toStringAsFixed(1)} Mbps' : '--'),
                    isActive: stage == SpeedTestStage.download,
                    isDone: stage == SpeedTestStage.upload || stage == SpeedTestStage.completed,
                    color: AppColors.signalExcellent,
                  ),
                  const SizedBox(width: 8),
                  _buildStageChip(
                    icon: Icons.arrow_upward_rounded,
                    label: 'Upload',
                    value: progress != null && progress.currentUploadMbps > 0
                        ? '${progress.currentUploadMbps.toStringAsFixed(1)} Mbps'
                        : (latest != null ? '${latest.uploadSpeedMbps.toStringAsFixed(1)} Mbps' : '--'),
                    isActive: stage == SpeedTestStage.upload,
                    isDone: stage == SpeedTestStage.completed,
                    color: AppColors.cyan5G,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 3. Custom Interactive Speedometer Dial
              AnimatedBuilder(
                animation: _needleAnimation,
                builder: (context, child) {
                  _currentSpeedValue = _needleAnimation.value;
                  return CustomPaint(
                    size: const Size(300, 260),
                    painter: SpeedometerPainter(
                      speedMbps: _currentSpeedValue,
                      maxSpeedMbps: 500.0,
                      isDark: isDark,
                      is5G: network.is5gActive,
                      stageText: stageText,
                      isRunning: isRunning,
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // 4. Metric Tiles (Download, Upload, Ping, Jitter)
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      context,
                      label: 'Download',
                      value: latest != null ? '${latest.downloadSpeedMbps.toStringAsFixed(1)} Mbps' : '--',
                      icon: Icons.arrow_downward_rounded,
                      color: AppColors.signalExcellent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      context,
                      label: 'Upload',
                      value: latest != null ? '${latest.uploadSpeedMbps.toStringAsFixed(1)} Mbps' : '--',
                      icon: Icons.arrow_upward_rounded,
                      color: AppColors.cyan5G,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      context,
                      label: 'Ping (Latency)',
                      value: isRunning && progress != null
                          ? '${progress.currentPingMs} ms'
                          : (latest != null ? '${latest.pingMs} ms' : '--'),
                      icon: Icons.timer_outlined,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      context,
                      label: 'Jitter (Variance)',
                      value: isRunning && progress != null
                          ? '${progress.currentJitterMs} ms'
                          : (latest != null ? '${latest.jitterMs} ms' : '--'),
                      icon: Icons.graphic_eq_rounded,
                      color: AppColors.accentIndigo,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 5. Connection Quality Analysis Banner
              if (latest != null) _buildVerdictCard(latest.downloadSpeedMbps, latest.pingMs, isDark),

              const SizedBox(height: 20),

              // 6. Action Button
              CustomButton(
                text: isRunning ? 'Measuring Throughput...' : (latest != null ? 'Retest Network Speed' : 'Start Speed Test'),
                isLoading: isRunning,
                icon: Icons.speed_rounded,
                onPressed: isRunning
                    ? null
                    : () async {
                        final res = await networkProvider.runSpeedTest(userId: userId);
                        if (context.mounted && res != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Test complete: ${res.downloadSpeedMbps} Mbps Download • ${res.pingMs} ms Ping'),
                              backgroundColor: AppColors.signalExcellent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
              ),

              const SizedBox(height: 12),
              Text(
                'Uses dynamic sliding-window HTTP edge probes for carrier speed measurement.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStageChip({
    required IconData icon,
    required String label,
    required String value,
    required bool isActive,
    required bool isDone,
    required Color color,
  }) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isActive
              ? color.withOpacity(0.2)
              : (isDone ? color.withOpacity(0.08) : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? color : (isDone ? color.withOpacity(0.4) : Colors.white12),
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 12, color: isActive || isDone ? color : Colors.grey),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isActive || isDone ? color : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isActive || isDone ? Colors.white : Colors.grey.shade400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerdictCard(double downloadMbps, int pingMs, bool isDark) {
    String title;
    String subtitle;
    Color color;
    IconData icon;

    if (downloadMbps >= 100) {
      title = 'Ultra-High 5G Performance';
      subtitle = 'Seamless 8K VR streaming, instantaneous cloud backups, zero-lag online gaming.';
      color = AppColors.cyan5G;
      icon = Icons.rocket_launch_rounded;
    } else if (downloadMbps >= 40) {
      title = 'Fast High-Speed Connection';
      subtitle = 'Smooth 4K video playback, fast video conferences, and snappy browsing.';
      color = AppColors.signalExcellent;
      icon = Icons.verified_rounded;
    } else if (downloadMbps >= 10) {
      title = 'Good Standard Mobile Speed';
      subtitle = 'Suitable for HD streaming, voice calls, social apps, and web access.';
      color = AppColors.primaryBlue;
      icon = Icons.thumb_up_alt_rounded;
    } else {
      title = 'Degraded Connection Detected';
      subtitle = 'Low bandwidth may cause buffering. Step outside or move closer to window.';
      color = AppColors.roamingWarning;
      icon = Icons.warning_amber_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter that renders an authentic telecommunications speedometer dial
class SpeedometerPainter extends CustomPainter {
  final double speedMbps;
  final double maxSpeedMbps;
  final bool isDark;
  final bool is5G;
  final String stageText;
  final bool isRunning;

  SpeedometerPainter({
    required this.speedMbps,
    required this.maxSpeedMbps,
    required this.isDark,
    required this.is5G,
    required this.stageText,
    required this.isRunning,
  });

  // Total sweeping angle: 240 degrees (from 150 deg to 390 deg)
  static const double _startAngle = 150 * (math.pi / 180);
  static const double _sweepAngle = 240 * (math.pi / 180);

  // Speed tick markers: 0, 10, 25, 50, 100, 200, 500
  static const List<double> _scaleTicks = [0, 10, 25, 50, 100, 200, 500];

  /// Non-linear mapping from speed in Mbps to ratio 0.0 -> 1.0 for prominent display of all tiers
  double _speedToRatio(double speed) {
    final s = speed.clamp(0.0, 500.0);
    if (s <= 20.0) {
      // 0 to 20 Mbps maps to 0.0 -> 0.28
      return (s / 20.0) * 0.28;
    } else if (s <= 100.0) {
      // 20 to 100 Mbps maps to 0.28 -> 0.65
      return 0.28 + ((s - 20.0) / 80.0) * 0.37;
    } else {
      // 100 to 500 Mbps maps to 0.65 -> 1.0
      return 0.65 + ((s - 100.0) / 400.0) * 0.35;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.58);
    final radius = size.width * 0.44;

    // 1. Background Arc Track
    final trackPaint = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16.0
      ..strokeCap = StrokeCap.round;

    final arcRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(arcRect, _startAngle, _sweepAngle, false, trackPaint);

    // 2. Active Glowing Progress Arc
    final currentRatio = _speedToRatio(speedMbps);
    final activeSweep = _sweepAngle * currentRatio;

    if (activeSweep > 0.01) {
      final activeGradient = SweepGradient(
        startAngle: _startAngle,
        endAngle: _startAngle + _sweepAngle,
        colors: [
          AppColors.primaryBlue,
          AppColors.cyan5G,
          if (is5G) AppColors.signalExcellent else AppColors.accentIndigo,
        ],
        stops: const [0.0, 0.55, 1.0],
      );

      final activePaint = Paint()
        ..shader = activeGradient.createShader(arcRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16.0
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(arcRect, _startAngle, activeSweep, false, activePaint);
    }

    // 3. Tick Marks and Scale Labels
    for (final tickVal in _scaleTicks) {
      final tickRatio = _speedToRatio(tickVal);
      final tickAngle = _startAngle + (_sweepAngle * tickRatio);

      final outerX = center.dx + (radius + 8) * math.cos(tickAngle);
      final outerY = center.dy + (radius + 8) * math.sin(tickAngle);
      final innerX = center.dx + (radius - 12) * math.cos(tickAngle);
      final innerY = center.dy + (radius - 12) * math.sin(tickAngle);

      final isMajor = tickVal == 0 || tickVal == 50 || tickVal == 100 || tickVal == 500;
      final tickPaint = Paint()
        ..color = isDark ? Colors.white54 : Colors.black45
        ..strokeWidth = isMajor ? 2.5 : 1.5;

      canvas.drawLine(Offset(innerX, innerY), Offset(outerX, outerY), tickPaint);

      // Label text
      final textPainter = TextPainter(
        text: TextSpan(
          text: tickVal.toInt().toString(),
          style: TextStyle(
            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
            fontSize: isMajor ? 11 : 9,
            fontWeight: isMajor ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelRadius = radius - 26;
      final labelX = center.dx + labelRadius * math.cos(tickAngle) - (textPainter.width / 2);
      final labelY = center.dy + labelRadius * math.sin(tickAngle) - (textPainter.height / 2);
      textPainter.paint(canvas, Offset(labelX, labelY));
    }

    // 4. Center Digital Speed Display & Subtitle
    final speedTextPainter = TextPainter(
      text: TextSpan(
        text: speedMbps.toStringAsFixed(1),
        style: TextStyle(
          color: isDark ? Colors.white : AppColors.navyDark,
          fontSize: 48,
          fontWeight: FontWeight.bold,
          letterSpacing: -1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final speedTextOffset = Offset(
      center.dx - (speedTextPainter.width / 2),
      center.dy - 35,
    );
    speedTextPainter.paint(canvas, speedTextOffset);

    // "Mbps" label
    final unitPainter = TextPainter(
      text: const TextSpan(
        text: 'Mbps',
        style: TextStyle(
          color: AppColors.cyan5G,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final unitOffset = Offset(
      center.dx - (unitPainter.width / 2),
      center.dy + 16,
    );
    unitPainter.paint(canvas, unitOffset);

    // Stage pill status text below
    final stagePainter = TextPainter(
      text: TextSpan(
        text: stageText.toUpperCase(),
        style: TextStyle(
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final stageOffset = Offset(
      center.dx - (stagePainter.width / 2),
      center.dy + 38,
    );
    stagePainter.paint(canvas, stageOffset);

    // 5. Tapered Needle and Glowing Pointer
    final needleAngle = _startAngle + activeSweep;
    final needleLength = radius - 10;

    final needleTip = Offset(
      center.dx + needleLength * math.cos(needleAngle),
      center.dy + needleLength * math.sin(needleAngle),
    );

    // Needle path (tapered shape)
    final needleBaseWidth = 6.0;
    final perpAngle = needleAngle + (math.pi / 2);
    final p1 = Offset(
      center.dx + needleBaseWidth * math.cos(perpAngle),
      center.dy + needleBaseWidth * math.sin(perpAngle),
    );
    final p2 = Offset(
      center.dx - needleBaseWidth * math.cos(perpAngle),
      center.dy - needleBaseWidth * math.sin(perpAngle),
    );

    final needlePath = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(needleTip.dx, needleTip.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();

    final needlePaint = Paint()
      ..color = AppColors.cyan5G
      ..style = PaintingStyle.fill;

    canvas.drawPath(needlePath, needlePaint);

    // Glowing tip circle
    final tipGlowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(needleTip, 3.5, tipGlowPaint);

    // 6. Central Hub Pivot
    final hubOuterPaint = Paint()
      ..color = isDark ? const Color(0xFF0F172A) : Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 14, hubOuterPaint);

    final hubRingPaint = Paint()
      ..color = AppColors.cyan5G
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(center, 14, hubRingPaint);

    final hubCenterPaint = Paint()
      ..color = AppColors.primaryBlue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 7, hubCenterPaint);
  }

  @override
  bool shouldRepaint(covariant SpeedometerPainter oldDelegate) {
    return oldDelegate.speedMbps != speedMbps ||
        oldDelegate.stageText != stageText ||
        oldDelegate.isDark != isDark ||
        oldDelegate.isRunning != isRunning;
  }
}
