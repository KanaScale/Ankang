import 'package:flutter/material.dart';

class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 1100),
    this.curve = Curves.easeOutCubic,
    this.suffix = '',
  });

  final int value;
  final TextStyle style;
  final Duration duration;
  final Curve curve;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: curve,
      builder: (context, animatedValue, child) {
        return Text(
          '${animatedValue.round()}$suffix',
          style: style,
        );
      },
    );
  }
}
