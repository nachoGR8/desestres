import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../services/storage_service.dart';
import '../../services/sound_service.dart';

class BubblePopGame extends StatefulWidget {
  const BubblePopGame({super.key});

  @override
  State<BubblePopGame> createState() => _BubblePopGameState();
}

class _BubblePopGameState extends State<BubblePopGame>
    with TickerProviderStateMixin {
  final List<_Bubble> _bubbles = [];
  final List<_PopEffect> _popEffects = [];
  final Random _random = Random();
  Timer? _spawnTimer;
  int _popped = 0;
  bool _active = true;

  static const _bubbleColors = [
    Color(0xFF93C5FD), // azul claro
    Color(0xFF5B9CF6), // azul
    Color(0xFFB3D4FF), // azul pastel
    Color(0xFFA78BFA), // lila
    Color(0xFF6EE7B7), // menta
    Color(0xFFFCA5A5), // rosa
    Color(0xFFC4B5FD), // lavanda
    Color(0xFF7DD3FC), // cielo
  ];

  @override
  void initState() {
    super.initState();
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_active && _bubbles.length < 25) {
        _addBubble();
      }
    });
    // Add initial bubbles
    for (int i = 0; i < 8; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted && _active) _addBubble();
      });
    }
  }

  void _addBubble() {
    final size = 50.0 + _random.nextDouble() * 40;
    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 4000 + _random.nextInt(4000)),
    );

    final startX = _random.nextDouble();

    final bubble = _Bubble(
      id: DateTime.now().microsecondsSinceEpoch + _random.nextInt(9999),
      x: startX,
      size: size,
      color: _bubbleColors[_random.nextInt(_bubbleColors.length)],
      controller: controller,
      wobbleOffset: _random.nextDouble() * 2 * pi,
      wobbleSpeed: 1.5 + _random.nextDouble() * 2,
    );

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!mounted) return;
        setState(() {
          _bubbles.removeWhere((b) => b.id == bubble.id);
        });
        SchedulerBinding.instance.addPostFrameCallback((_) {
          controller.dispose();
        });
      }
    });

    setState(() => _bubbles.add(bubble));
    controller.forward();
  }

  Future<void> _popBubble(_Bubble bubble) async {
    if (!_bubbles.any((b) => b.id == bubble.id)) return;
    HapticFeedback.lightImpact();
    SoundService().playPop();

    // Capture position before removing
    final progress = bubble.controller.value;
    final screenSize = MediaQuery.of(context).size;
    final safeLeft = bubble.x * (screenSize.width - bubble.size);
    final wobble = sin(progress * bubble.wobbleSpeed * 2 * pi +
            bubble.wobbleOffset) *
        20;
    final y = screenSize.height -
        (progress * (screenSize.height + bubble.size + 100));
    final center = Offset(
      safeLeft + wobble + bubble.size / 2,
      y + bubble.size / 2,
    );

    // Spawn pop effect
    _spawnPopEffect(center, bubble.size, bubble.color);

    final ctrl = bubble.controller;
    setState(() {
      _bubbles.removeWhere((b) => b.id == bubble.id);
      _popped++;
    });
    // Dispose after frame so AnimatedBuilder can remove its listener first
    SchedulerBinding.instance.addPostFrameCallback((_) {
      ctrl.dispose();
    });
    await StorageService().incrementCounter('totalBubbles');
  }

  void _spawnPopEffect(Offset center, double bubbleSize, Color color) {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    final particles = List.generate(8, (i) {
      final angle = i * pi / 4 + _random.nextDouble() * 0.3;
      final speed = 0.6 + _random.nextDouble() * 0.8;
      return _Particle(angle: angle, speed: speed);
    });

    final effect = _PopEffect(
      id: DateTime.now().microsecondsSinceEpoch + _random.nextInt(9999),
      center: center,
      size: bubbleSize,
      color: color,
      controller: controller,
      particles: particles,
    );

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!mounted) return;
        setState(() {
          _popEffects.removeWhere((e) => e.id == effect.id);
        });
        controller.dispose();
      }
    });

    setState(() => _popEffects.add(effect));
    controller.forward();
  }

  @override
  void dispose() {
    _active = false;
    _spawnTimer?.cancel();
    for (final b in _bubbles) {
      b.controller.dispose();
    }
    for (final e in _popEffects) {
      e.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _exit() async {
    _active = false;
    _spawnTimer?.cancel();
    if (_popped > 0) {
      await StorageService().discoverGame('bubbles');
      await StorageService().recordActivity();
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Bubbles
            ..._bubbles.map((bubble) {
              return AnimatedBuilder(
                animation: bubble.controller,
                builder: (context, child) {
                  final progress = bubble.controller.value;
                  final screenSize = MediaQuery.of(context).size;
                  final safeLeft =
                      bubble.x * (screenSize.width - bubble.size);
                  final wobble = sin(progress * bubble.wobbleSpeed * 2 * pi +
                          bubble.wobbleOffset) *
                      20;
                  final y = screenSize.height -
                      (progress * (screenSize.height + bubble.size + 100));

                  return Positioned(
                    left: safeLeft + wobble,
                    top: y,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _popBubble(bubble),
                      child: _BubbleWidget(
                        size: bubble.size,
                        color: bubble.color,
                        opacity: (1.0 - progress * 0.3).clamp(0.3, 1.0),
                      ),
                    ),
                  );
                },
              );
            }),
            // Pop effects (IgnorePointer so they don't block bubble taps)
            ..._popEffects.map((effect) {
              return IgnorePointer(
                child: AnimatedBuilder(
                animation: effect.controller,
                builder: (context, child) {
                  final t = effect.controller.value;
                  final opacity = (1.0 - t).clamp(0.0, 1.0);
                  return Stack(
                    children: [
                      // Expanding ring
                      Positioned(
                        left: effect.center.dx - effect.size * (0.5 + t * 0.4),
                        top: effect.center.dy - effect.size * (0.5 + t * 0.4),
                        child: Opacity(
                          opacity: opacity * 0.5,
                          child: Container(
                            width: effect.size * (1.0 + t * 0.8),
                            height: effect.size * (1.0 + t * 0.8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: effect.color,
                                width: 2 * (1 - t),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Particles
                      ...effect.particles.map((p) {
                        final dist = effect.size * 0.8 * t * p.speed;
                        final px = effect.center.dx + cos(p.angle) * dist - 4;
                        final py = effect.center.dy + sin(p.angle) * dist - 4;
                        final pSize = 8.0 * (1 - t * 0.6);
                        return Positioned(
                          left: px,
                          top: py,
                          child: Opacity(
                            opacity: opacity,
                            child: Container(
                              width: pSize,
                              height: pSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: effect.color,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
              );
            }),
            // Header
            Positioned(
              top: 8,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  IconButton(
                    onPressed: _exit,
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: Theme.of(context).iconTheme.color,
                  ),
                  Expanded(
                    child: Text(
                      'Burbujas',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '🫧 $_popped',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Hint text at bottom
            if (_popped == 0)
              Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: Text(
                  'Toca las burbujas para explotarlas',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textHint,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bubble {
  final int id;
  final double x;
  final double size;
  final Color color;
  final AnimationController controller;
  final double wobbleOffset;
  final double wobbleSpeed;

  _Bubble({
    required this.id,
    required this.x,
    required this.size,
    required this.color,
    required this.controller,
    required this.wobbleOffset,
    required this.wobbleSpeed,
  });
}

class _PopEffect {
  final int id;
  final Offset center;
  final double size;
  final Color color;
  final AnimationController controller;
  final List<_Particle> particles;

  _PopEffect({
    required this.id,
    required this.center,
    required this.size,
    required this.color,
    required this.controller,
    required this.particles,
  });
}

class _Particle {
  final double angle;
  final double speed;

  _Particle({required this.angle, required this.speed});
}

class _BubbleWidget extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _BubbleWidget({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.3),
            colors: [
              color.withValues(alpha: 0.3),
              color.withValues(alpha: 0.6),
              color.withValues(alpha: 0.2),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          border: Border.all(
            color: color.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: size * 0.25,
            height: size * 0.15,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size),
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
