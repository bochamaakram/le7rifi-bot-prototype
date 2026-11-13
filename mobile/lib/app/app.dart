import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../features/onboarding/login_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/conversations/history_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/business_context/business_screen.dart';

final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/chat', builder: (_, _) => const ChatScreen()),
    GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    GoRoute(path: '/business', builder: (_, _) => const BusinessScreen()),
  ],
);

class Le7rayfiApp extends StatelessWidget {
  const Le7rayfiApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'الحريفي AI',
    debugShowCheckedModeBanner: false,
    routerConfig: router,
    theme: appTheme(Brightness.light),
    darkTheme: appTheme(Brightness.dark),
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('fr'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
  );
}
