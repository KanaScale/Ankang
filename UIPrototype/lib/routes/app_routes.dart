import 'package:flutter/material.dart';

import 'app_router.dart';
import 'route_names.dart';

class AppRoutes {
  AppRoutes._();

  static const String login = RouteNames.login;
  static const String sessionGate = RouteNames.sessionGate;
  static const String register = RouteNames.register;
  static const String forgotPassword = RouteNames.forgotPassword;
  static const String home = RouteNames.home;
  static const String profile = RouteNames.profile;
  static const String records = RouteNames.health;
  static const String reminders = RouteNames.reminder;
  static const String emergency = RouteNames.emergency;
  static const String emergencyContacts = RouteNames.emergencyContacts;
  static const String family = RouteNames.family;
  static const String familyAgent = RouteNames.familyAgent;
  static const String reports = RouteNames.reports;
  static const String medicalSummary = RouteNames.medicalSummary;

  static Map<String, WidgetBuilder> get routes => AppRouter.routes;

  static Route<dynamic> onGenerateRoute(RouteSettings settings) =>
      AppRouter.onGenerateRoute(settings);

  static List<Route<dynamic>> onGenerateInitialRoutes(String initialRoute) =>
      AppRouter.onGenerateInitialRoutes(initialRoute);

  static Route<dynamic> onUnknownRoute(RouteSettings settings) =>
      AppRouter.onUnknownRoute(settings);
}
