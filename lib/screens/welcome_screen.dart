import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../data/love_phrases.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late final String _phrase;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _phrase = getRandomPhrase();
    _timer = Timer(const Duration(seconds: 4), _navigate);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _navigate() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) => const HomeScreen(),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _navigate,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF5F0FF),
                Color(0xFFEDE5FF),
                Color(0xFFF0F7FF),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  Icon(
                    Icons.favorite,
                    size: 48,
                    color: AppTheme.primary.withValues(alpha: 0.6),
                  )
                      .animate()
                      .scale(
                        begin: const Offset(0.5, 0.5),
                        end: const Offset(1.0, 1.0),
                        duration: 800.ms,
                        curve: Curves.elasticOut,
                      )
                      .fadeIn(duration: 600.ms),
                  const SizedBox(height: 32),
                  Text(
                    _phrase,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: AppTheme.textPrimary,
                        ),
                  )
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 800.ms)
                      .slideY(
                        begin: 0.15,
                        end: 0,
                        delay: 400.ms,
                        duration: 800.ms,
                        curve: Curves.easeOut,
                      ),
                  const SizedBox(height: 24),
                  Text(
                    '— Nacho',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textHint,
                          fontStyle: FontStyle.italic,
                        ),
                  )
                      .animate()
                      .fadeIn(delay: 1000.ms, duration: 600.ms),
                  const Spacer(flex: 3),
                  Text(
                    'Toca para continuar',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textHint.withValues(alpha: 0.6),
                        ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .fadeIn(delay: 2000.ms, duration: 800.ms)
                      .then()
                      .fadeOut(duration: 800.ms),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
