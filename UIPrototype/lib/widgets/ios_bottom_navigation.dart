import 'package:flutter/material.dart';

import 'ios_glass_bottom_nav.dart';

class IosBottomNavigation extends StatelessWidget {
  const IosBottomNavigation({
    super.key,
    required this.currentRoute,
  });

  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    return IOSGlassBottomNav(currentRoute: currentRoute);
  }
}
