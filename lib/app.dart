import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/today/screens/today_screen.dart';
import 'features/settings/screens/settings_screen.dart';

class BuffAIApp extends StatelessWidget {
  const BuffAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buff AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const TodayScreen(),
      routes: {
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}
