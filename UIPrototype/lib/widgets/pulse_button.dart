import 'package:flutter/material.dart';

import '../app/design_tokens.dart';
import 'animated_pressable.dart';

class PulseButton extends StatefulWidget {
  const PulseButton({
    super.key,
    required this.child,
    this.onTap,
    this.size = 212,
    this.colors = AppGradients.emergency,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double size;
  final List<Color> colors;

  @override
  State<PulseButton> createState() => _PulseButtonState();
}

class _PulseButtonState extends State<PulseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final outerScale = 1 + _pulse.value * 0.08;
        final outerOpacity = 0.18 - _pulse.value * 0.08;

        return SizedBox(
          width: widget.size * 1.28,
          height: widget.size * 1.28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: outerScale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.emergency.withValues(alpha: outerOpacity),
                  ),
                ),
              ),
              AnimatedPressable(
                onTap: widget.onTap,
                scale: 0.95,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.colors,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emergency.withValues(alpha: 0.22),
                        blurRadius: 30,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Center(child: widget.child),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
