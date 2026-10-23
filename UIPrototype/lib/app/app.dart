import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/reminder_notification_model.dart';
import '../routes/app_router.dart';
import '../routes/route_names.dart';
import '../services/auth_service.dart';
import '../services/offline_session_coordinator.dart';
import '../services/reminder_notification_service.dart';
import 'design_tokens.dart';
import 'app_runtime_settings.dart';
import 'theme.dart';

class AnkangAssistantApp extends StatefulWidget {
  const AnkangAssistantApp({super.key});

  @override
  State<AnkangAssistantApp> createState() => _AnkangAssistantAppState();
}

class _AnkangAssistantAppState extends State<AnkangAssistantApp>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<ReminderNotificationEvent>? _reminderSubscription;
  StreamSubscription<ReminderNotificationTarget>? _notificationTapSubscription;
  bool _showingReminder = false;
  bool _revalidatingOfflineSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ReminderNotificationService.initializeForegroundEvents();
    _reminderSubscription =
        ReminderNotificationService.foregroundEvents.listen(_showReminder);
    _notificationTapSubscription =
        ReminderNotificationService.notificationTaps.listen(_openReminder);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reminderSubscription?.cancel();
    _notificationTapSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        OfflineSessionCoordinator.isOfflineRestored) {
      unawaited(_revalidateOfflineSession());
    }
  }

  Future<void> _revalidateOfflineSession() async {
    if (_revalidatingOfflineSession) return;
    _revalidatingOfflineSession = true;
    try {
      final restored = await AuthService().restoreSession();
      if (!mounted || restored) return;
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(
        RouteNames.login,
        (route) => false,
      );
    } finally {
      _revalidatingOfflineSession = false;
    }
  }

  void _openReminder(ReminderNotificationTarget target) {
    ReminderNotificationService.rememberPendingNavigation(target);
    final ownerUserId = OfflineSessionCoordinator.session.value.ownerUserId;
    if (ownerUserId != target.ownerUserId) return;
    ReminderNotificationService.takePendingNavigation(ownerUserId!);
    _navigatorKey.currentState?.pushNamed(RouteNames.reminder);
  }

  Future<void> _showReminder(ReminderNotificationEvent event) async {
    if (_showingReminder ||
        OfflineSessionCoordinator.session.value.ownerUserId !=
            event.ownerUserId) {
      return;
    }
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    _showingReminder = true;
    final time = '${event.triggeredAt.hour.toString().padLeft(2, '0')}:'
        '${event.triggeredAt.minute.toString().padLeft(2, '0')}';
    try {
      final openReminder = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.greenSurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          title: const Text(
            '提醒时间到了',
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                event.title,
                textAlign: TextAlign.center,
                style: Theme.of(dialogContext).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '$time · 系统通知会继续保留，您也可以稍后处理。',
                textAlign: TextAlign.center,
                style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                        ),
                      ),
                      child: const _SingleLineButtonLabel('稍后处理'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 6,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                      ),
                      icon: const Icon(Icons.checklist_rounded),
                      label: const _SingleLineButtonLabel('查看提醒'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
      if (openReminder == true &&
          mounted &&
          OfflineSessionCoordinator.session.value.ownerUserId ==
              event.ownerUserId) {
        await _navigatorKey.currentState?.pushNamed(RouteNames.reminder);
      }
    } finally {
      _showingReminder = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppRuntimeSettings.instance,
      builder: (context, _) {
        final settings = AppRuntimeSettings.instance;
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: AppConfig.appName,
          debugShowCheckedModeBanner: AppConfig.showDebugBanner,
          theme: _themeFor(settings),
          initialRoute: RouteNames.sessionGate,
          onGenerateRoute: AppRouter.onGenerateRoute,
          onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
          onUnknownRoute: AppRouter.onUnknownRoute,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(settings.fontScale),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }

  ThemeData _themeFor(AppRuntimeSettings settings) {
    final base = AppTheme.lightTheme;
    if (!settings.largeTouchTarget) {
      return base;
    }

    final largeButtonStyle = ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size.fromHeight(64)),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      ),
      tapTargetSize: MaterialTapTargetSize.padded,
    );
    final largeIconButtonStyle = ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size.square(52)),
      padding: WidgetStateProperty.all(const EdgeInsets.all(14)),
      tapTargetSize: MaterialTapTargetSize.padded,
    );

    return base.copyWith(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: base.elevatedButtonTheme.style?.merge(largeButtonStyle) ??
            largeButtonStyle,
      ),
      filledButtonTheme: FilledButtonThemeData(style: largeButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: largeButtonStyle),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStateProperty.all(const Size(56, 48)),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(style: largeIconButtonStyle),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      ),
    );
  }
}

class _SingleLineButtonLabel extends StatelessWidget {
  const _SingleLineButtonLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}
