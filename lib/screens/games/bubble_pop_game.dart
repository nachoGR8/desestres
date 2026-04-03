import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../services/storage_service.dart';

class BubblePopGame extends StatefulWidget {
  const BubblePopGame({super.key});

  @override
  State<BubblePopGame> createState() => _BubblePopGameState();
}

class _BubblePopGameState extends State<BubblePopGame>
    with TickerProviderStateMixin {
  final List<_Bubble> _bubbles = [];
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
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (_active && _bubbles.length < 15) {
        _addBubble();
      }
    });
    // Add initial bubbles
    for (int i = 0; i < 5; i++) {
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
        setState(() {
          controller.dispose();
          _bubbles.removeWhere((b) => b.id == bubble.id);
        });
      }
    });

    setState(() => _bubbles.add(bubble));
    controller.forward();
  }

  void _popBubble(_Bubble bubble) {
    HapticFeedback.lightImpact();
    bubble.controller.dispose();
    setState(() {
      _bubbles.removeWhere((b) => b.id == bubble.id);
      _popped++;
    });
  }

  @override
  void dispose() {
    _active = false;
    _spawnTimer?.cancel();
    for (final b in _bubbles) {
      b.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _exit() async {
    _active = false;
    _spawnTimer?.cancel();
    if (_popped > 0) {
      await StorageService().recordActivity();
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Background tap area
            Positioned.fill(
              child: GestureDetector(
                onTap: () {},
                behavior: HitTestBehavior.translucent,
              ),
            ),
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
                    color: AppTheme.textPrimary,
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
                      color: Colors.white.withValues(alpha: 0.9),
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
