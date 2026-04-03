import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/welcome_screen.dart';
import 'services/theme_service.dart';

class DesestresApp extends StatelessWidget {
  const DesestresApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService(),
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Desestres',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: const WelcomeScreen(),
        );
      },
    );
  }
}
