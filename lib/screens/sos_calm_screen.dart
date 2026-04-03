import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../data/love_phrases.dart';
import '../services/sound_service.dart';

class SosCalmScreen extends StatefulWidget {
  const SosCalmScreen({super.key});

  @override
  State<SosCalmScreen> createState() => _SosCalmScreenState();
}

class _SosCalmScreenState extends State<SosCalmScreen>
    with TickerProviderStateMixin {
  late AnimationController _breathController;
  late AnimationController _fadeController;
  late AnimationController _phraseController;
  late AnimationController _particleController;
  late AnimationController _phaseLabelController;

  String _phrase = '';
  String _nextPhrase = '';
  String _phaseLabel = 'Inhala';
  String _prevPhaseLabel = '';
  int _cycleCount = 0;
  bool _soundPlayed = false; // prevent duplicate sounds per phase

  // Floating particles
  late List<_Particle> _particles;
  final Random _rng = Random();

  // 4s inhale, 4s hold, 6s exhale = 14s cycle
  static const _inhaleDuration = 4;
  static const _holdDuration = 4;
  static const _exhaleDuration = 6;
  static const _totalDuration =
      _inhaleDuration + _holdDuration + _exhaleDuration;

  @override
  void initState() {
    super.initState();
    _phrase = getRandomPhrase();
    _nextPhrase = _phrase;

    // Generate floating particles
    _particles = List.generate(20, (_) => _Particle.random(_rng));

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();

    _phraseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _phaseLabelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _totalDuration),
    )..addListener(_updatePhase);

    _breathController.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        _cycleCount++;
        if (_cycleCount % 3 == 0) {
          _changePhrase();
        }
        _breathController.forward(from: 0);
        _soundPlayed = false;
      }
    });

    _breathController.forward();

    // Play initial breath sound
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) SoundService().playBreathIn();
    });
  }

  void _changePhrase() {
    _nextPhrase = getRandomPhrase();
    // Make sure we don't repeat the same phrase
    while (_nextPhrase == _phrase && lovePhrases.length > 1) {
      _nextPhrase = getRandomPhrase();
    }
    _phraseController.forward(from: 0);
    _phraseController.addStatusListener(_onPhraseAnimDone);
  }

  void _onPhraseAnimDone(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _phraseController.removeStatusListener(_onPhraseAnimDone);
      setState(() => _phrase = _nextPhrase);
    }
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
      _prevPhaseLabel = _phaseLabel;
      _phaseLabel = newPhase;
      _soundPlayed = false;

      // Animate phase label transition
      _phaseLabelController.forward(from: 0);

      HapticFeedback.selectionClick();
      setState(() {});
    }

    // Play breath sounds at phase transitions
    if (!_soundPlayed) {
      if (newPhase == 'Inhala' && progress < inhaleEnd * 0.1) {
        SoundService().playBreathIn();
        _soundPlayed = true;
      } else if (newPhase == 'Sostén' &&
          progress < holdEnd * 1.02 &&
          progress > inhaleEnd) {
        SoundService().playSoftTone();
        _soundPlayed = true;
      } else if (newPhase == 'Exhala' && progress > holdEnd &&
          progress < holdEnd + 0.03) {
        SoundService().playBreathOut();
        _soundPlayed = true;
      }
    }
  }

  double get _circleScale {
    final progress = _breathController.value;
    final inhaleEnd = _inhaleDuration / _totalDuration;
    final holdEnd = (_inhaleDuration + _holdDuration) / _totalDuration;

    if (progress < inhaleEnd) {
      final t = progress / inhaleEnd;
      // Smooth ease-in-out
      return 0.5 + 0.5 * _smoothStep(t);
    } else if (progress < holdEnd) {
      // Gentle pulse during hold
      final holdT = (progress - inhaleEnd) / (holdEnd - inhaleEnd);
      return 1.0 + 0.02 * sin(holdT * 2 * pi);
    } else {
      final exhaleProgress = (progress - holdEnd) / (1.0 - holdEnd);
      return 1.0 - 0.5 * _smoothStep(exhaleProgress);
    }
  }

  double _smoothStep(double t) {
    return t * t * (3 - 2 * t);
  }

  @override
  void dispose() {
    _breathController.dispose();
    _fadeController.dispose();
    _phraseController.dispose();
    _particleController.dispose();
    _phaseLabelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _breathController,
            _particleController,
            _phraseController,
            _phaseLabelController,
          ]),
          builder: (context, _) {
            final scale = _circleScale;
            final breathProgress = _breathController.value;
            final inhaleEnd = _inhaleDuration / _totalDuration;
            final holdEnd =
                (_inhaleDuration + _holdDuration) / _totalDuration;

            // Dynamic background color shift with breathing
            final bgBlend = (scale - 0.5) * 2; // 0..1

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(
                      const Color(0xFF0D1B2A),
                      const Color(0xFF1E3A5F),
                      bgBlend * 0.6,
                    )!,
                    Color.lerp(
                      const Color(0xFF1A0F2E),
                      const Color(0xFF2D1B69),
                      bgBlend * 0.5,
                    )!,
                    const Color(0xFF0F172A),
                  ],
                ),
              ),
              child: SafeArea(
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _fadeController,
                    curve: Curves.easeOut,
                  ),
                  child: Stack(
                    children: [
                      // Floating particles
                      ..._buildParticles(scale),

                      // Main content
                      Column(
                        children: [
                          const SizedBox(height: 40),
                          // Phase label with crossfade
                          SizedBox(
                            height: 32,
                            child: _buildPhaseLabel(),
                          ),
                          // Phase progress dots
                          const SizedBox(height: 16),
                          _buildPhaseDots(breathProgress, inhaleEnd, holdEnd),
                          const Spacer(),
                          // Breathing circle with rings
                          _buildBreathingCircle(scale),
                          const Spacer(),
                          // Love phrase with crossfade
                          _buildPhrase(),
                          const SizedBox(height: 40),
                          // Cycle counter
                          if (_cycleCount > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '$_cycleCount ${_cycleCount == 1 ? 'ciclo' : 'ciclos'}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          Text(
                            'Toca la pantalla para salir',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.2),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
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

  Widget _buildPhaseLabel() {
    final t = _phaseLabelController.value;
    // Crossfade: old slides up and fades, new slides up from below
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outgoing label
        if (_prevPhaseLabel.isNotEmpty && t < 1.0)
          Opacity(
            opacity: (1.0 - t * 2).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -12 * t),
              child: Text(
                _prevPhaseLabel,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 22,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 4,
                ),
              ),
            ),
          ),
        // Incoming label
        Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 12 * (1.0 - t)),
            child: Text(
              _phaseLabel,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 22,
                fontWeight: FontWeight.w300,
                letterSpacing: 4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseDots(
      double progress, double inhaleEnd, double holdEnd) {
    final phase = progress < inhaleEnd
        ? 0
        : progress < holdEnd
            ? 1
            : 2;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final isActive = i == phase;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: isActive
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.15),
          ),
        );
      }),
    );
  }

  Widget _buildBreathingCircle(double scale) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outermost pulsing ring
        Container(
          width: 260 * scale,
          height: 260 * scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
        ),
        // Second ring
        Container(
          width: 230 * scale,
          height: 230 * scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
        ),
        // Outer glow
        Container(
          width: 220 * scale,
          height: 220 * scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.12 + scale * 0.08),
                blurRadius: 60 + scale * 20,
                spreadRadius: 10 + scale * 15,
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
                AppTheme.primary.withValues(alpha: 0.45 + scale * 0.1),
                AppTheme.primary.withValues(alpha: 0.1),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15 + scale * 0.1),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              '🤍',
              style: TextStyle(fontSize: 32 + 8 * scale),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhrase() {
    final phraseT = _phraseController.value;
    // First half: fade out old, second half: fade in new
    final showNew = phraseT > 0.5;
    final displayPhrase = showNew ? _nextPhrase : _phrase;
    final opacity = showNew
        ? ((phraseT - 0.5) * 2).clamp(0.0, 1.0)
        : phraseT == 0
            ? 1.0
            : (1.0 - phraseT * 2).clamp(0.0, 1.0);
    final slideY = showNew ? 10.0 * (1.0 - (phraseT - 0.5) * 2) : -10.0 * phraseT * 2;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(0, slideY),
          child: Text(
            displayPhrase,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 1.6,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildParticles(double breathScale) {
    final t = _particleController.value;
    return _particles.map((p) {
      // Each particle drifts upward slowly, wrapping around
      final rawY = (p.startY - t * p.speed * 0.3) % 1.0;
      final x = p.startX + sin((t + p.phase) * 2 * pi * p.wobbleFreq) * 0.03;
      final screenW = MediaQuery.of(context).size.width;
      final screenH = MediaQuery.of(context).size.height;

      // Particles react slightly to breathing
      final breathOffset = (breathScale - 0.75) * 20 * p.breathReact;

      final alpha = p.alpha * (0.6 + 0.4 * sin((t + p.phase) * 2 * pi));

      return Positioned(
        left: x * screenW,
        top: rawY * screenH + breathOffset,
        child: Opacity(
          opacity: alpha.clamp(0.0, 1.0),
          child: Container(
            width: p.size,
            height: p.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.6),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                  blurRadius: p.size * 2,
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }
}

class _Particle {
  final double startX;
  final double startY;
  final double size;
  final double speed;
  final double alpha;
  final double phase;
  final double wobbleFreq;
  final double breathReact;

  _Particle({
    required this.startX,
    required this.startY,
    required this.size,
    required this.speed,
    required this.alpha,
    required this.phase,
    required this.wobbleFreq,
    required this.breathReact,
  });

  factory _Particle.random(Random rng) {
    return _Particle(
      startX: rng.nextDouble(),
      startY: rng.nextDouble(),
      size: 2 + rng.nextDouble() * 3,
      speed: 0.3 + rng.nextDouble() * 0.7,
      alpha: 0.08 + rng.nextDouble() * 0.15,
      phase: rng.nextDouble(),
      wobbleFreq: 0.3 + rng.nextDouble() * 0.5,
      breathReact: 0.3 + rng.nextDouble() * 0.7,
    );
  }
}
