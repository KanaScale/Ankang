import 'package:flutter/material.dart';

import '../app/design_tokens.dart';

class AvatarView extends StatelessWidget {
  const AvatarView({
    super.key,
    this.size = 56,
    this.initials,
    this.icon,
  });

  final double size;
  final String? initials;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppColors.peachSurface,
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: AppShadows.subtle,
      ),
      child: Center(
        child: icon == null
            ? Text(
                _initials,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primaryDark,
                      fontSize: size * 0.36,
                      fontWeight: FontWeight.w800,
                    ),
              )
            : Icon(icon, color: AppColors.primaryDark, size: size * 0.48),
      ),
    );
  }

  String get _initials {
    final value = initials?.trim();
    if (value == null || value.isEmpty) {
      return '?';
    }
    return String.fromCharCode(value.runes.first).toUpperCase();
  }
}
