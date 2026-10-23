import 'dart:ui';

import 'package:flutter/material.dart';

import '../app/design_tokens.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const int sosIndex = 4;

  static const items = [
    _BottomNavItem('首页', Icons.home_rounded),
    _BottomNavItem('功能', Icons.grid_view_rounded),
    _BottomNavItem('个人数据', Icons.person_rounded),
    _BottomNavItem('健康数据', Icons.monitor_heart_rounded),
    _BottomNavItem('SOS', Icons.sos_rounded, emergency: true),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: const Color(0x99FFFFFF)),
                boxShadow: AppShadows.soft,
              ),
              child: Row(
                children: [
                  for (var index = 0; index < items.length; index++)
                    Expanded(
                      child: _NavButton(
                        key: ValueKey('bottom_nav_${items[index].label}'),
                        item: items[index],
                        selected:
                            !items[index].emergency && index == currentIndex,
                        onTap: () => onTap(index),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
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
    final color =
        selected || item.emergency ? activeColor : AppColors.textTertiary;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 58,
            height: 50,
            decoration: BoxDecoration(
              color: selected || item.emergency
                  ? activeColor.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, color: color, size: 22),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color,
                        fontSize: 10,
                        fontWeight: selected || item.emergency
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem {
  const _BottomNavItem(this.label, this.icon, {this.emergency = false});

  final String label;
  final IconData icon;
  final bool emergency;
}
