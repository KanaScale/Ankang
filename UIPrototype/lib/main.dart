import 'package:flutter/material.dart';

import 'app/app.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiClient.instance.initialize();
  final authService = AuthService();
  ApiClient.instance.onUnauthorized = authService.handleUnauthorized;
  ApiClient.instance.onAuthenticated = authService.handleAuthenticated;
  runApp(const AnkangAssistantApp());
}
