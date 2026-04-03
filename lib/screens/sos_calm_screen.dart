import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../data/love_phrases.dart';

class SosCalmScreen extends StatefulWidget {
  const SosCalmScreen({super.key});

  @override
  State<SosCalmScreen> createState() => _SosCalmScreenState();
}

class _SosCalmScreenState extends State<SosCalmScreen>
    with TickerProviderStateMixin {
  late AnimationController _breathController;
  late AnimationController _fadeController;
  late String _phrase;
  String _phaseLabel = 'Inhala';
  int _cycleCount = 0;

  // 4s inhale, 4s hold, 6s exhale = 14s cycle
  static const _inhaleDuration = 4;
  static const _holdDuration = 4;
  static const _exhaleDuration = 6;
  static const _totalDuration = _inhaleDuration + _holdDuration + _exhaleDuration;

  @override
  void initState() {
    super.initState();
    _phrase = getRandomPhrase();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _totalDuration),
    )..addListener(_updatePhase);

    _breathController.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        _cycleCount++;
        if (_cycleCount >= 5) {
          // After 5 cycles, show a new phrase
          setState(() => _phrase = getRandomPhrase());
          _cycleCount = 0;
        }
        _breathController.forward(from: 0);
      }
    });

    _breathController.forward();
  }

  void _updatePhase() {
    if (!mounted) return;
    final progress = _breathController.value;
    final inhaleEnd = _inhaleDuration / _totalDuration;
    final holdEnd = (_inhaleDuration + _holdDuration) / _totalDuration;

    String newPhase;
    if (progress < inhaleEnd) {
      newPhase = 'Inhala';
    } else if (progress < holdEnd) {
      newPhase = 'Sostén';
    } else {
      newPhase = 'Exhala';
    }

    if (newPhase != _phaseLabel) {
      setState(() => _phaseLabel = newPhase);
      HapticFeedback.selectionClick();
    }
  }

  double get _circleScale {
    final progress = _breathController.value;
    final inhaleEnd = _inhaleDuration / _totalDuration;
    final holdEnd = (_inhaleDuration + _holdDuration) / _totalDuration;

    if (progress < inhaleEnd) {
      // Expanding: 0.5 -> 1.0
      return 0.5 + 0.5 * (progress / inhaleEnd);
    } else if (progress < holdEnd) {
      return 1.0;
    } else {
      // Contracting: 1.0 -> 0.5
      final exhaleProgress = (progress - holdEnd) / (1.0 - holdEnd);
      return 1.0 - 0.5 * exhaleProgress;
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: AnimatedBuilder(
          animation: _breathController,
          builder: (context, _) {
            final scale = _circleScale;
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1E3A5F).withValues(alpha: 0.95),
                    const Color(0xFF2D1B69).withValues(alpha: 0.95),
                    const Color(0xFF0F172A),
                  ],
                ),
              ),
              child: SafeArea(
                child: FadeTransition(
                  opacity: _fadeController,
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      Text(
                        _phaseLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 22,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 4,
                        ),
                      ),
                      const Spacer(),
                      // Breathing circle
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer glow
                          Container(
                            width: 220 * scale,
                            height: 220 * scale,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withValues(alpha: 0.15),
                                  blurRadius: 60,
                                  spreadRadius: 20,
                                ),
                              ],
                            ),
                          ),
                          // Main circle
                          Container(
                            width: 180 * scale,
                            height: 180 * scale,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppTheme.primary.withValues(alpha: 0.5),
                                  AppTheme.primary.withValues(alpha: 0.15),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '🤍',
                                style: TextStyle(fontSize: 36 * scale),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Love phrase
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          _phrase,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        'Toca la pantalla para salir',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.25),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
