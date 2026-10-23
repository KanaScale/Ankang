import 'package:flutter/material.dart';

import '../pages/auth/login_page.dart';
import '../pages/auth/session_gate_page.dart';
import '../pages/auth/forgot_password_page.dart';
import '../pages/auth/register_page.dart';
import '../pages/emergency/emergency_page.dart';
import '../pages/emergency/contact_page.dart';
import '../pages/family/family_home_page.dart';
import '../pages/family/family_agent_entry_page.dart';
import '../pages/home/home_page.dart';
import '../pages/medical_summary/medical_summary_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/records/mode_aware_health_page.dart';
import '../pages/reminders/reminder_list_page.dart';
import '../pages/reports/report_page.dart';
import '../services/care_mode_service.dart';
import 'route_names.dart';

typedef AuthGuard = bool Function(RouteSettings settings);

class AppRouter {
  AppRouter._();

  static AuthGuard? authGuard;

  static Map<String, WidgetBuilder> get routes => {
        RouteNames.sessionGate: (_) => const SessionGatePage(),
        RouteNames.login: (_) => const LoginPage(),
        RouteNames.register: (_) => const RegisterPage(),
        RouteNames.forgotPassword: (_) => const ForgotPasswordPage(),
        RouteNames.home: (_) => const HomePage(),
        RouteNames.health: (_) => const ModeAwareHealthPage(),
        RouteNames.reminder: (_) => const ReminderListPage(),
        RouteNames.emergency: (_) => const EmergencyPage(),
        RouteNames.emergencyContacts: (_) => const ContactPage(),
        RouteNames.profile: (_) => const ProfilePage(),
        RouteNames.family: (_) => const FamilyHomePage(),
        RouteNames.familyAgent: (_) => const FamilyAgentEntryPage(),
        RouteNames.reports: (_) => const ReportPage(),
        RouteNames.medicalSummary: (_) => const MedicalSummaryPage(),
      };

  static Future<T?> push<T extends Object?>(
      BuildContext context, String routeName) {
    return Navigator.of(context).pushNamed<T>(routeName);
  }

  static Future<T?> replace<T extends Object?, TO extends Object?>(
    BuildContext context,
    String routeName, {
    TO? result,
  }) {
    return Navigator.of(context).pushReplacementNamed<T, TO>(
      routeName,
      result: result,
    );
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final guarded = _applyAuthGuard(settings);
    if (guarded != null) {
      return guarded;
    }

    if (CareModeService.isCaregiver &&
        (settings.name == RouteNames.emergency ||
            settings.name == RouteNames.emergencyContacts)) {
      return _buildRoute(
        settings: const RouteSettings(name: RouteNames.family),
        builder: (_) => const FamilyHomePage(),
      );
    }

    final builder = routes[settings.name];
    if (builder == null) {
      return onUnknownRoute(settings);
    }

    return _buildRoute(
      settings: settings,
      builder: builder,
    );
  }

  static List<Route<dynamic>> onGenerateInitialRoutes(String initialRoute) {
    final settings = RouteSettings(name: initialRoute);
    return <Route<dynamic>>[onGenerateRoute(settings)];
  }

  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('页面不存在')),
        body: Center(child: Text('未找到路由：${settings.name ?? ''}')),
      ),
    );
  }

  static Route<dynamic>? _applyAuthGuard(RouteSettings settings) {
    final canOpen = authGuard?.call(settings) ?? true;
    if (canOpen || settings.name == RouteNames.login) {
      return null;
    }

    return _buildRoute(
      settings: const RouteSettings(name: RouteNames.login),
      builder: (_) => const LoginPage(),
    );
  }

  static PageRouteBuilder<dynamic> _buildRoute({
    required RouteSettings settings,
    required WidgetBuilder builder,
  }) {
    return PageRouteBuilder<dynamic>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.025),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}
