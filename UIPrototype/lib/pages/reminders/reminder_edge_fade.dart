import 'package:flutter/material.dart';

/// 为提醒模块的滚动内容保留首尾渐隐，提示还可继续滑动。
class ReminderEdgeFade extends StatelessWidget {
  const ReminderEdgeFade({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
        stops: [0, 0.03, 0.97, 1],
      ).createShader(bounds),
      child: child,
    );
  }
}
