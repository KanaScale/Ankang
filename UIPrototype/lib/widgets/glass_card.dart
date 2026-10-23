import 'dart:ui';

import 'package:flutter/material.dart';

import '../app/design_tokens.dart';
import 'animated_pressable.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.margin = EdgeInsets.zero,
    this.borderRadius = AppRadius.xxl,
    this.color = AppColors.surfaceGlass,
    this.borderColor = const Color(0xCCFFFFFF),
    this.onTap,
    this.blur = 18,
    this.opacity = 0.72,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final Color color;
  final Color borderColor;
  final VoidCallback? onTap;
  final double blur;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final effectiveColor = color.withValues(alpha: opacity);
    final content = Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: effectiveColor,
              borderRadius: radius,
              border: Border.all(color: borderColor),
              boxShadow: AppShadows.soft,
            ),
            child: child,
          ),
        ),
      ),
    );

    if (onTap == null) {
      return content;
    }

    return AnimatedPressable(
      onTap: onTap,
      child: content,
    );
  }
}
