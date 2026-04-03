import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../services/storage_service.dart';
import '../../services/sound_service.dart';

class PimplePopGame extends StatefulWidget {
  const PimplePopGame({super.key});

  @override
  State<PimplePopGame> createState() => _PimplePopGameState();
}

class _PimplePopGameState extends State<PimplePopGame>
    with TickerProviderStateMixin {
  final List<_Pimple> _pimples = [];
  final List<_PopEffect> _popEffects = [];
  final Random _random = Random();
  Timer? _spawnTimer;
  int _popped = 0;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    // Spawn a new pimple every 1.2 seconds
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (_active && _pimples.length < 12) _addPimple();
    });
    // Seed initial pimples with stagger
    for (int i = 0; i < 6; i++) {
      Future.delayed(Duration(milliseconds: i * 250), () {
        if (mounted && _active) _addPimple();
      });
    }
  }

  void _addPimple() {
    final size = 44.0 + _random.nextDouble() * 28; // 44–72
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    // Random position within safe area (margin from edges)
    final margin = size / 2 + 16;
    final x = margin + _random.nextDouble() * (screenW - 2 * margin);
    final y = 80 + margin + _random.nextDouble() * (screenH - 180 - 2 * margin);

    // Grow animation
    final growCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600 + _random.nextInt(400)),
    );

    // Idle wobble animation (looping)
    final wobbleCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1800 + _random.nextInt(800)),
    )..repeat(reverse: true);

    // Determine pimple type
    final typeRoll = _random.nextDouble();
    final type = typeRoll < 0.5
        ? _PimpleType.whitehead
        : typeRoll < 0.85
            ? _PimpleType.reddish
            : _PimpleType.blackhead;

    final pimple = _Pimple(
      id: DateTime.now().microsecondsSinceEpoch + _random.nextInt(9999),
      x: x,
      y: y,
      size: size,
      type: type,
      growController: growCtrl,
      wobbleController: wobbleCtrl,
      tapsNeeded: type == _PimpleType.blackhead ? 2 : 1,
    );

    setState(() => _pimples.add(pimple));
    growCtrl.forward();
  }

  void _tapPimple(_Pimple pimple) {
    if (!_pimples.any((p) => p.id == pimple.id)) return;

    pimple.tapCount++;

    if (pimple.tapCount < pimple.tapsNeeded) {
      // Not fully popped yet — give squeeze feedback
      HapticFeedback.lightImpact();
      SoundService().playClick();
      setState(() {});
      return;
    }

    // Fully popped!
    HapticFeedback.mediumImpact();
    SoundService().playPop();

    _spawnPopEffect(
      Offset(pimple.x, pimple.y),
      pimple.size,
      pimple.type,
    );

    setState(() {
      _pimples.removeWhere((p) => p.id == pimple.id);
      _popped++;
    });
    pimple.growController.dispose();
    pimple.wobbleController.dispose();
    StorageService().incrementCounter('totalPimples');
  }

  void _spawnPopEffect(Offset center, double size, _PimpleType type) {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    final splats = List.generate(6, (i) {
      final angle = i * pi / 3 + _random.nextDouble() * 0.4;
      final speed = 0.5 + _random.nextDouble() * 0.7;
      final splatSize = 4.0 + _random.nextDouble() * 5;
      return _Splat(angle: angle, speed: speed, size: splatSize);
    });

    final effect = _PopEffect(
      id: DateTime.now().microsecondsSinceEpoch + _random.nextInt(9999),
      center: center,
      size: size,
      type: type,
      controller: controller,
      splats: splats,
    );

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!mounted) return;
        setState(() => _popEffects.removeWhere((e) => e.id == effect.id));
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
    for (final p in _pimples) {
      p.growController.dispose();
      p.wobbleController.dispose();
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
      await StorageService().discoverGame('pimples');
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
            // Skin-tone background area
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.only(top: 60),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      const Color(0xFFFDE8D0).withValues(alpha: 0.3),
                      Theme.of(context).scaffoldBackgroundColor,
                    ],
                  ),
                ),
              ),
            ),

            // Pimples
            ..._pimples.map((pimple) => _buildPimple(pimple)),

            // Pop effects
            ..._popEffects.map((effect) => _buildPopEffect(effect)),

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
                      'Granitos',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '💥 $_popped',
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

            // Hint text
            if (_popped == 0)
              Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: Text(
                  'Toca los granitos para reventarlos',
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

  Widget _buildPimple(_Pimple pimple) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        pimple.growController,
        pimple.wobbleController,
      ]),
      builder: (context, _) {
        final grow = pimple.growController.value;
        final wobble = pimple.wobbleController.value;
        final scale = grow * (1.0 + wobble * 0.06); // subtle breathing
        final squeezed = pimple.tapCount > 0 && pimple.tapCount < pimple.tapsNeeded;
        final squeezeScale = squeezed ? 1.15 : 1.0;
        final currentSize = pimple.size * scale * squeezeScale;

        return Positioned(
          left: pimple.x - currentSize / 2,
          top: pimple.y - currentSize / 2,
          child: GestureDetector(
            onTap: () => _tapPimple(pimple),
            child: _PimpleWidget(
              size: currentSize,
              type: pimple.type,
              squeezed: squeezed,
              opacity: grow.clamp(0.0, 1.0),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPopEffect(_PopEffect effect) {
    return AnimatedBuilder(
      animation: effect.controller,
      builder: (context, _) {
        final t = effect.controller.value;
        final opacity = (1.0 - t).clamp(0.0, 1.0);
        final splatColor = _splatColor(effect.type);

        return Stack(
          children: [
            // Center burst
            Positioned(
              left: effect.center.dx - effect.size * (0.3 + t * 0.3),
              top: effect.center.dy - effect.size * (0.3 + t * 0.3),
              child: Opacity(
                opacity: opacity * 0.6,
                child: Container(
                  width: effect.size * (0.6 + t * 0.6),
                  height: effect.size * (0.6 + t * 0.6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: splatColor.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
            // Splat particles
            ...effect.splats.map((s) {
              final dist = effect.size * 0.7 * t * s.speed;
              final px = effect.center.dx + cos(s.angle) * dist - s.size / 2;
              final py = effect.center.dy + sin(s.angle) * dist - s.size / 2;
              final pSize = s.size * (1 - t * 0.5);
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
                      color: splatColor,
                    ),
                  ),
                ),
              );
            }),
            // Satisfying "clean" circle left behind (fades away)
            Positioned(
              left: effect.center.dx - effect.size * 0.2,
              top: effect.center.dy - effect.size * 0.2,
              child: Opacity(
                opacity: opacity * 0.4,
                child: Container(
                  width: effect.size * 0.4,
                  height: effect.size * 0.4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFE4D6),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _splatColor(_PimpleType type) {
    switch (type) {
      case _PimpleType.whitehead:
        return const Color(0xFFFFF8E1); // cream/white
      case _PimpleType.reddish:
        return const Color(0xFFFCA5A5); // pinkish
      case _PimpleType.blackhead:
        return const Color(0xFF8B7355); // brownish
    }
  }
}

// --- Models ---

enum _PimpleType { whitehead, reddish, blackhead }

class _Pimple {
  final int id;
  final double x;
  final double y;
  final double size;
  final _PimpleType type;
  final AnimationController growController;
  final AnimationController wobbleController;
  final int tapsNeeded;
  int tapCount = 0;

  _Pimple({
    required this.id,
    required this.x,
    required this.y,
    required this.size,
    required this.type,
    required this.growController,
    required this.wobbleController,
    required this.tapsNeeded,
  });
}

class _PopEffect {
  final int id;
  final Offset center;
  final double size;
  final _PimpleType type;
  final AnimationController controller;
  final List<_Splat> splats;

  _PopEffect({
    required this.id,
    required this.center,
    required this.size,
    required this.type,
    required this.controller,
    required this.splats,
  });
}

class _Splat {
  final double angle;
  final double speed;
  final double size;

  _Splat({required this.angle, required this.speed, required this.size});
}

// --- Pimple Widget ---

class _PimpleWidget extends StatelessWidget {
  final double size;
  final _PimpleType type;
  final bool squeezed;
  final double opacity;

  const _PimpleWidget({
    required this.size,
    required this.type,
    required this.squeezed,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _PimplePainter(type: type, squeezed: squeezed),
        ),
      ),
    );
  }
}

class _PimplePainter extends CustomPainter {
  final _PimpleType type;
  final bool squeezed;

  _PimplePainter({required this.type, required this.squeezed});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Base bump (skin-colored raised area)
    final basePaint = Paint()
      ..color = const Color(0xFFFFCDB2).withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, basePaint);

    // Reddish ring around
    final ringPaint = Paint()
      ..color = _ringColor.withValues(alpha: squeezed ? 0.7 : 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.18;
    canvas.drawCircle(center, radius * 0.75, ringPaint);

    // Inner bump / core
    final corePaint = Paint()
      ..color = _coreColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.35, corePaint);

    // Highlight (glossy reflection)
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(center.dx - radius * 0.15, center.dy - radius * 0.15),
      radius * 0.14,
      highlightPaint,
    );
  }

  Color get _ringColor {
    switch (type) {
      case _PimpleType.whitehead:
        return const Color(0xFFE8A090);
      case _PimpleType.reddish:
        return const Color(0xFFE57373);
      case _PimpleType.blackhead:
        return const Color(0xFFBCAA90);
    }
  }

  Color get _coreColor {
    switch (type) {
      case _PimpleType.whitehead:
        return const Color(0xFFFFF8E1);
      case _PimpleType.reddish:
        return const Color(0xFFFFCDD2);
      case _PimpleType.blackhead:
        return const Color(0xFF5D4E37);
    }
  }

  @override
  bool shouldRepaint(_PimplePainter old) =>
      type != old.type || squeezed != old.squeezed;
}
