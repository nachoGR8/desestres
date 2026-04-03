import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/welcome_screen.dart';

class DesestresApp extends StatelessWidget {
  const DesestresApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Desestres',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const WelcomeScreen(),
    );
  }
}
