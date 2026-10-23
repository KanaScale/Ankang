import 'package:flutter/material.dart';

class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 18,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  Widget build(BuildContext context) {
    const base = Duration(milliseconds: 520);
    final total = base + delay;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: total,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final elapsed = value * total.inMilliseconds;
        final delayed = ((elapsed - delay.inMilliseconds) / base.inMilliseconds)
            .clamp(0.0, 1.0);

        return Opacity(
          opacity: delayed,
          child: Transform.translate(
            offset: Offset(0, offset * (1 - delayed)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
