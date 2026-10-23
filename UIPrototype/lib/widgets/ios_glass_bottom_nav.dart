import 'package:flutter/material.dart';

import '../app/design_tokens.dart';
import '../routes/route_names.dart';
import '../services/care_mode_service.dart';
import 'animated_pressable.dart';
import 'glass_card.dart';

class IOSGlassBottomNav extends StatelessWidget {
  const IOSGlassBottomNav({
    super.key,
    required this.currentRoute,
  });

  final String currentRoute;

  static const _patientItems = [
    _BottomNavItem('首页', Icons.house_rounded, RouteNames.home),
    _BottomNavItem('数据', Icons.favorite_rounded, RouteNames.health),
    _BottomNavItem('提醒', Icons.alarm_rounded, RouteNames.reminder),
    _BottomNavItem('SOS', Icons.sos_rounded, RouteNames.emergency,
        emergency: true),
    _BottomNavItem('我的', Icons.person_rounded, RouteNames.profile),
  ];

  static const _caregiverItems = [
    _BottomNavItem('照护', Icons.family_restroom_rounded, RouteNames.family),
    _BottomNavItem('数据', Icons.favorite_rounded, RouteNames.health),
    _BottomNavItem('Agent', Icons.smart_toy_rounded, RouteNames.familyAgent),
    _BottomNavItem('我的', Icons.person_rounded, RouteNames.profile),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CareMode>(
      valueListenable: CareModeService.mode,
      builder: (context, mode, _) {
        final items =
            mode == CareMode.caregiver ? _caregiverItems : _patientItems;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              borderRadius: AppRadius.xxl,
              blur: 26,
              opacity: 0.78,
              child: Row(
                children: [
                  for (final item in items)
                    Expanded(
                      child: _BottomNavButton(
                        key: ValueKey('bottom_nav_${item.label}'),
                        item: item,
                        selected: item.routeName == currentRoute,
                        onTap: () {
                          if (item.routeName == currentRoute) {
                            return;
                          }
                          Navigator.of(context)
                              .pushReplacementNamed(item.routeName);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _BottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor =
        item.emergency ? AppColors.emergency : AppColors.primary;
    final foreground =
        selected || item.emergency ? activeColor : AppColors.textTertiary;

    return AnimatedPressable(
      onTap: onTap,
      scale: 0.92,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        height: 54,
        decoration: BoxDecoration(
          color: selected || item.emergency
              ? activeColor.withValues(alpha: item.emergency ? 0.12 : 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: foreground, size: selected ? 23 : 21),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: foreground,
                    fontSize: 10,
                    fontWeight:
                        selected || item.emergency ? FontWeight.w700 : null,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem {
  const _BottomNavItem(
    this.label,
    this.icon,
    this.routeName, {
    this.emergency = false,
  });

  final String label;
  final IconData icon;
  final String routeName;
  final bool emergency;
}
