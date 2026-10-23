import 'package:flutter/material.dart';

import '../app/design_tokens.dart';

class GradientContainer extends StatelessWidget {
  const GradientContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.borderRadius = AppRadius.xxl,
    this.colors = AppGradients.card,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: AppShadows.soft,
      ),
      child: child,
    );
  }
}
