import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../routes/route_names.dart';
import '../../services/auth_service.dart';
import '../../services/reminder_notification_service.dart';

class SessionGatePage extends StatefulWidget {
  const SessionGatePage({super.key});

  @override
  State<SessionGatePage> createState() => _SessionGatePageState();
}

class _SessionGatePageState extends State<SessionGatePage> {
  final AuthService _authService = AuthService();
  final ReminderNotificationService _notificationService =
      const ReminderNotificationService();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await _notificationService.getInitialNotificationTarget();
      final restored = await _authService.restoreSession();
      if (!mounted) return;
      if (!restored) {
        Navigator.of(context).pushReplacementNamed(RouteNames.login);
        return;
      }
      final ownerUserId = AuthService.currentUser?.id;
      final target = ownerUserId == null
          ? null
          : ReminderNotificationService.takePendingNavigation(ownerUserId);
      Navigator.of(context).pushReplacementNamed(
        target == null ? RouteNames.home : RouteNames.reminder,
      );
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(RouteNames.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF5EA),
              AppColors.background,
              AppColors.backgroundWarm,
            ],
          ),
        ),
        child: Center(
          child: Semantics(
            label: '正在恢复登录状态',
            child: const CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}
