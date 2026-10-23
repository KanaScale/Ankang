import 'dart:ui';

import 'package:flutter/material.dart';

import '../app/design_tokens.dart';

class GlassBottomBar extends StatelessWidget {
  const GlassBottomBar({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                borderRadius: BorderRadius.circular(AppRadius.xxl),
                border: Border.all(color: const Color(0xCCFFF3EA)),
                boxShadow: AppShadows.soft,
              ),
              child: Row(children: children),
            ),
          ),
        ),
      ),
    );
  }
}
