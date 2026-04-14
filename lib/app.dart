import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/main_shell.dart';

class BuffAIApp extends StatelessWidget {
  const BuffAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buff AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const MainShell(),
    );
  }
}
