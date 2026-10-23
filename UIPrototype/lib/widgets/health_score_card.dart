import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/design_tokens.dart';
import 'animated_number.dart';
import 'glass_card.dart';

class HealthScoreCard extends StatelessWidget {
  const HealthScoreCard({
    super.key,
    required this.score,
    this.label = '健康指数',
    this.status = '状态良好',
    this.subtitle = '睡眠、心率和活动量保持稳定',
  });

  final int score;
  final String label;
  final String status;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      child: Column(
        children: [
          SizedBox(
            height: 218,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: score / 100),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, progress, child) {
                return CustomPaint(
                  painter: _HealthRingPainter(progress: progress),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedNumber(
                          value: score,
                          style: Theme.of(context)
                              .textTheme
                              .displayLarge!
                              .copyWith(
                                fontSize: 58,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          label,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                status,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  subtitle,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthRingPainter extends CustomPainter {
  const _HealthRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 12;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2;
    final sweepAngle = math.pi * 2 * progress.clamp(0, 1);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..color = AppColors.warmSurface.withValues(alpha: 0.75);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: startAngle,
        endAngle: math.pi * 1.5,
        colors: [
          AppColors.primary,
          Color(0xFF9DDC83),
          AppColors.warning,
          AppColors.primary,
        ],
        stops: [0, 0.5, 0.78, 1],
      ).createShader(rect);

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(rect, startAngle, sweepAngle, false, ring);
  }

  @override
  bool shouldRepaint(covariant _HealthRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
