import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/sound_service.dart';

enum BreathingPhase { inhale, holdIn, exhale, holdOut }

class BreathingPattern {
  final String name;
  final String description;
  final int inhaleSeconds;
  final int holdInSeconds;
  final int exhaleSeconds;
  final int holdOutSeconds;

  const BreathingPattern({
    required this.name,
    required this.description,
    required this.inhaleSeconds,
    required this.holdInSeconds,
    required this.exhaleSeconds,
    this.holdOutSeconds = 0,
  });

  int get totalSeconds =>
      inhaleSeconds + holdInSeconds + exhaleSeconds + holdOutSeconds;
}

const breathingPatterns = [
  BreathingPattern(
    name: 'Relajación',
    description: '4-4-6',
    inhaleSeconds: 4,
    holdInSeconds: 4,
    exhaleSeconds: 6,
  ),
  BreathingPattern(
    name: 'Calma rápida',
    description: '4-7-8',
    inhaleSeconds: 4,
    holdInSeconds: 7,
    exhaleSeconds: 8,
  ),
  BreathingPattern(
    name: 'Box Breathing',
    description: '4-4-4-4',
    inhaleSeconds: 4,
    holdInSeconds: 4,
    exhaleSeconds: 4,
    holdOutSeconds: 4,
  ),
];

class BreathingCircle extends StatefulWidget {
  final BreathingPattern pattern;
  final bool isRunning;
  final VoidCallback onCycleComplete;

  const BreathingCircle({
    super.key,
    required this.pattern,
    required this.isRunning,
    required this.onCycleComplete,
  });

  @override
  State<BreathingCircle> createState() => BreathingCircleState();
}

class BreathingCircleState extends State<BreathingCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  BreathingPhase _currentPhase = BreathingPhase.inhale;
  int _phaseSecondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _buildAnimation();
    _phaseSecondsRemaining = widget.pattern.inhaleSeconds;
    if (widget.isRunning) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isRunning) {
          _controller.forward(from: 0);
        }
      });
    }
  }

  void _buildAnimation() {
    final p = widget.pattern;
    final total = p.totalSeconds;

    final items = <TweenSequenceItem<double>>[
      TweenSequenceItem(
        tween: Tween(begin: 0.5, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: p.inhaleSeconds.toDouble(),
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: p.holdInSeconds.toDouble(),
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.5)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: p.exhaleSeconds.toDouble(),
      ),
    ];

    if (p.holdOutSeconds > 0) {
      items.add(TweenSequenceItem(
        tween: ConstantTween(0.5),
        weight: p.holdOutSeconds.toDouble(),
      ));
    }

    _scaleAnimation = TweenSequence(items).animate(_controller);

    _controller.duration = Duration(seconds: total);
    _controller.removeStatusListener(_onStatus);
    _controller.addStatusListener(_onStatus);

    _controller.removeListener(_onTick);
    _controller.addListener(_onTick);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onCycleComplete();
      if (widget.isRunning) {
        _controller.forward(from: 0);
      }
    }
  }

  BreathingPhase _phaseFromProgress(double progress) {
    final p = widget.pattern;
    final total = p.totalSeconds;
    final elapsed = progress * total;

    if (elapsed < p.inhaleSeconds) return BreathingPhase.inhale;
    if (elapsed < p.inhaleSeconds + p.holdInSeconds) return BreathingPhase.holdIn;
    if (elapsed < p.inhaleSeconds + p.holdInSeconds + p.exhaleSeconds) {
      return BreathingPhase.exhale;
    }
    return BreathingPhase.holdOut;
  }

  int _secondsRemainingInPhase(double progress) {
    final p = widget.pattern;
    final total = p.totalSeconds;
    final elapsed = progress * total;

    if (elapsed < p.inhaleSeconds) {
      return (p.inhaleSeconds - elapsed).ceil();
    }
    if (elapsed < p.inhaleSeconds + p.holdInSeconds) {
      return (p.inhaleSeconds + p.holdInSeconds - elapsed).ceil();
    }
    if (elapsed < p.inhaleSeconds + p.holdInSeconds + p.exhaleSeconds) {
      return (p.inhaleSeconds + p.holdInSeconds + p.exhaleSeconds - elapsed)
          .ceil();
    }
    return (total - elapsed).ceil();
  }

  void _onTick() {
    final newPhase = _phaseFromProgress(_controller.value);
    final newSeconds = _secondsRemainingInPhase(_controller.value);

    if (newPhase != _currentPhase) {
      HapticFeedback.lightImpact();
      SoundService().playBell();
      setState(() {
        _currentPhase = newPhase;
        _phaseSecondsRemaining = newSeconds;
      });
    } else if (newSeconds != _phaseSecondsRemaining) {
      setState(() => _phaseSecondsRemaining = newSeconds);
    }
  }

  @override
  void didUpdateWidget(BreathingCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pattern != oldWidget.pattern) {
      _buildAnimation();
    }
    if (widget.isRunning && !oldWidget.isRunning) {
      _controller.forward(from: 0);
    } else if (!widget.isRunning && oldWidget.isRunning) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _phaseLabel {
    switch (_currentPhase) {
      case BreathingPhase.inhale:
        return 'Inhala';
      case BreathingPhase.holdIn:
      case BreathingPhase.holdOut:
        return 'Mantén';
      case BreathingPhase.exhale:
        return 'Exhala';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.6;

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          final scale = _scaleAnimation.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer waves
              for (int i = 3; i > 0; i--)
                Transform.scale(
                  scale: scale + (i * 0.08),
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primary
                            .withValues(alpha: 0.08 * (4 - i)),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              // Main circle
              Transform.scale(
                scale: scale,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primary.withValues(alpha: 0.7),
                        AppTheme.secondary.withValues(alpha: 0.5),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.25),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),
              // Text
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _phaseLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_phaseSecondsRemaining',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
