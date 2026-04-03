import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
  final List<_PusEffect> _pusEffects = [];
  final List<_SplatMark> _splatMarks = [];
  final Random _random = Random();
  Timer? _spawnTimer;
  int _popped = 0;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (_active && _pimples.length < 10) _addPimple();
    });
    for (int i = 0; i < 5; i++) {
      Future.delayed(Duration(milliseconds: i * 300), () {
        if (mounted && _active) _addPimple();
      });
    }
  }

  void _addPimple() {
    final size = 52.0 + _random.nextDouble() * 32; // 52–84
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final margin = size / 2 + 20;
    final x = margin + _random.nextDouble() * (screenW - 2 * margin);
    final y = 90 + margin + _random.nextDouble() * (screenH - 200 - 2 * margin);

    final growCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500 + _random.nextInt(400)),
    );
    final wobbleCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000 + _random.nextInt(800)),
    )..repeat(reverse: true);

    final typeRoll = _random.nextDouble();
    final type = typeRoll < 0.45
        ? _PimpleType.whitehead
        : typeRoll < 0.80
            ? _PimpleType.reddish
            : _PimpleType.cyst;

    final pimple = _Pimple(
      id: DateTime.now().microsecondsSinceEpoch + _random.nextInt(9999),
      x: x,
      y: y,
      size: size,
      type: type,
      growController: growCtrl,
      wobbleController: wobbleCtrl,
      // How long you need to hold to pop
      holdDuration: type == _PimpleType.cyst
          ? 1.8
          : type == _PimpleType.reddish
              ? 1.2
              : 0.8,
    );

    setState(() => _pimples.add(pimple));
    growCtrl.forward();
  }

  void _startSqueezing(_Pimple pimple) {
    if (!_pimples.any((p) => p.id == pimple.id)) return;
    if (pimple.squeezing) return;
    pimple.squeezing = true;
    pimple.squeezeStart = DateTime.now();
    HapticFeedback.lightImpact();
    SoundService().playClick();
    setState(() {});
    // Start squeeze progress ticker (16ms for ~60 FPS)
    pimple.squeezeTicker?.cancel();
    pimple.squeezeTicker = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _updateSqueeze(pimple),
    );
  }

  void _updateSqueeze(_Pimple pimple) {
    if (!mounted || !_active) return;
    if (!pimple.squeezing) return;
    final elapsed = DateTime.now()
        .difference(pimple.squeezeStart!)
        .inMilliseconds / 1000.0;
    final progress = (elapsed / pimple.holdDuration).clamp(0.0, 1.0);
    pimple.squeezeProgress = progress;

    // Haptic pulses while squeezing (adaptive to frame rate)
    if (progress > 0.3 && progress < 0.95) {
      // Trigger haptic every ~125ms (8 pulses per second)
      final pulseCount = (elapsed * 8).floor();
      if (pimple.lastHapticPulse != pulseCount) {
        pimple.lastHapticPulse = pulseCount;
        HapticFeedback.selectionClick();
      }
    }

    setState(() {});

    if (progress >= 1.0) {
      _popPimple(pimple);
    }
  }

  void _stopSqueezing(_Pimple pimple) {
    if (!pimple.squeezing) return;
    pimple.squeezing = false;
    pimple.squeezeTicker?.cancel();
    // If almost done (>70%), still pop it
    if (pimple.squeezeProgress > 0.7) {
      _popPimple(pimple);
      return;
    }
    // Otherwise reset
    pimple.squeezeProgress = 0;
    setState(() {});
  }

  void _popPimple(_Pimple pimple) {
    if (!_pimples.any((p) => p.id == pimple.id)) return;
    pimple.squeezeTicker?.cancel();
    pimple.squeezing = false;

    // Big satisfying feedback
    HapticFeedback.heavyImpact();
    SoundService().playPop();
    // Delayed second feedback for the "splat"
    Future.delayed(const Duration(milliseconds: 80), () {
      HapticFeedback.mediumImpact();
    });

    _spawnPusEffect(
      Offset(pimple.x, pimple.y),
      pimple.size,
      pimple.type,
      pimple.squeezeProgress,
    );

    // Keep references before removing from list
    final growCtrl = pimple.growController;
    final wobbleCtrl = pimple.wobbleController;

    setState(() {
      _pimples.removeWhere((p) => p.id == pimple.id);
      _popped++;
    });

    // Dispose controllers AFTER the frame rebuilds so AnimatedBuilder
    // can remove its listeners before the controllers are disposed.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      growCtrl.dispose();
      wobbleCtrl.dispose();
    });
    StorageService().incrementCounter('totalPimples');
  }

  void _spawnPusEffect(
      Offset center, double size, _PimpleType type, double intensity) {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100), // Slightly longer for viscosity
    );

    // More pus streams for higher intensity / bigger pimples with realistic distribution
    final streamCount = 3 + (intensity * 5).round() + _random.nextInt(3);
    final streams = List.generate(streamCount, (i) {
      final baseAngle = i * 2 * pi / streamCount;
      // More random variation for realistic spray pattern
      final angle = baseAngle + (_random.nextDouble() - 0.5) * 1.2;
      // Variable speed with intensity affecting trajectory
      final speed = 0.7 + _random.nextDouble() * 0.9 + intensity * 0.5;
      final length = 0.5 + _random.nextDouble() * 0.7;
      // Variable thickness for pus viscosity
      final thickness = 2.5 + _random.nextDouble() * 5 + intensity * 2;
      return _PusStream(
        angle: angle,
        speed: speed,
        length: length,
        thickness: thickness,
      );
    });

    // Secondary splat drops - more for bigger pops
    final dropCount = 5 + _random.nextInt(6) + (intensity * 3).round();
    final drops = List.generate(dropCount, (i) {
      return _PusDrop(
        angle: _random.nextDouble() * 2 * pi,
        distance: 0.6 + _random.nextDouble() * 1.2,
        size: 2.5 + _random.nextDouble() * 5,
        delay: _random.nextDouble() * 0.25,
      );
    });

    final effect = _PusEffect(
      id: DateTime.now().microsecondsSinceEpoch + _random.nextInt(9999),
      center: center,
      size: size,
      type: type,
      controller: controller,
      streams: streams,
      drops: drops,
      intensity: intensity,
    );

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!mounted) return;
        // Leave a splat mark behind
        _splatMarks.add(_SplatMark(
          center: center,
          size: size * 0.3,
          color: _pusColor(type).withValues(alpha: 0.15),
          createdAt: DateTime.now(),
        ));
        // Clean old marks
        _splatMarks.removeWhere((m) =>
            DateTime.now().difference(m.createdAt).inSeconds > 8);
        setState(() => _pusEffects.removeWhere((e) => e.id == effect.id));
        controller.dispose();
      }
    });

    setState(() => _pusEffects.add(effect));
    controller.forward();
  }

  @override
  void dispose() {
    _active = false;
    _spawnTimer?.cancel();
    for (final p in _pimples) {
      p.squeezeTicker?.cancel();
      p.growController.dispose();
      p.wobbleController.dispose();
    }
    for (final e in _pusEffects) {
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
            // Skin-tone background
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.only(top: 60),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      const Color(0xFFFDE8D0).withValues(alpha: 0.35),
                      Theme.of(context).scaffoldBackgroundColor,
                    ],
                  ),
                ),
              ),
            ),

            // Skin texture dots
            ..._buildSkinTexture(),

            // Splat marks that linger
            ..._splatMarks.map((mark) => Positioned(
                  left: mark.center.dx - mark.size / 2,
                  top: mark.center.dy - mark.size / 2,
                  child: Container(
                    width: mark.size,
                    height: mark.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: mark.color,
                    ),
                  ),
                )),

            // Pimples
            ..._pimples.map((p) => _buildPimple(p)),

            // Pus effects
            ..._pusEffects.map((e) => _buildPusEffect(e)),

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

            // Hint
            if (_popped == 0)
              Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: Text(
                  'Mantén pulsado para reventar los granitos',
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

  List<Widget> _buildSkinTexture() {
    // Deterministic small pore dots for skin feel
    final rng = Random(42);
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    return List.generate(30, (i) {
      final x = rng.nextDouble() * screenW;
      final y = 80 + rng.nextDouble() * (screenH - 160);
      final s = 2.0 + rng.nextDouble() * 2;
      return Positioned(
        left: x,
        top: y,
        child: Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFD4A98A).withValues(alpha: 0.15),
          ),
        ),
      );
    });
  }

  Widget _buildPimple(_Pimple pimple) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([
          pimple.growController,
          pimple.wobbleController,
        ]),
        builder: (context, _) {
          final grow = pimple.growController.value;
          final wobble = pimple.wobbleController.value;
          final squeeze = pimple.squeezeProgress;

          // Enhanced breathing animation
          final breathe = 1.0 + wobble * 0.05;
          // More dramatic squeeze inflate with realistic bulging
          final squeezeInflate = 1.0 + squeeze * 0.35 + (squeeze > 0.7 ? (squeeze - 0.7) * 0.5 : 0);
          final scale = grow * breathe * squeezeInflate;
          final currentSize = pimple.size * scale;

          // Add skin deformation ring around pimple when squeezing
          final showDeformation = squeeze > 0.1;
          final deformationSize = currentSize * (1.4 + squeeze * 0.3);
          final deformationOpacity = (squeeze * 0.3).clamp(0.0, 1.0);

          return Stack(
            children: [
              // Skin deformation when squeezing
              if (showDeformation)
                Positioned(
                  left: pimple.x - deformationSize / 2,
                  top: pimple.y - deformationSize / 2,
                  child: Opacity(
                    opacity: deformationOpacity,
                    child: Container(
                      width: deformationSize,
                      height: deformationSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.transparent,
                            const Color(0xFFFFB4A2).withValues(alpha: 0.4 * squeeze),
                            const Color(0xFFE8A090).withValues(alpha: 0.6 * squeeze),
                          ],
                          stops: const [0.3, 0.7, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              // The pimple itself
              Positioned(
                left: pimple.x - currentSize / 2,
                top: pimple.y - currentSize / 2,
                child: GestureDetector(
                  onLongPressStart: (_) => _startSqueezing(pimple),
                  onLongPressEnd: (_) => _stopSqueezing(pimple),
                  onLongPressCancel: () => _stopSqueezing(pimple),
                  child: _PimpleWidget(
                    size: currentSize,
                    type: pimple.type,
                    squeezeProgress: squeeze,
                    opacity: grow.clamp(0.0, 1.0),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPusEffect(_PusEffect effect) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: effect.controller,
        builder: (context, _) {
          final t = effect.controller.value;

          return Stack(
            children: [
              // Central burst — the "hole" left behind
              _buildBurstCenter(effect, t),
              // Pus streams shooting out
              ...effect.streams.map((s) => _buildPusStream(effect, s, t)),
              // Secondary drops
              ...effect.drops
                  .where((d) => t > d.delay)
                  .map((d) => _buildPusDrop(effect, d, t)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBurstCenter(_PusEffect effect, double t) {
    final burstProgress = (t * 2.5).clamp(0.0, 1.0);
    final fadeOut = (1.0 - (t - 0.4).clamp(0.0, 1.0) * 1.67).clamp(0.0, 1.0);
    final burstSize = effect.size * (0.35 + burstProgress * 0.5);

    return Positioned(
      left: effect.center.dx - burstSize / 2,
      top: effect.center.dy - burstSize / 2,
      child: Opacity(
        opacity: fadeOut * 0.9,
        child: Container(
          width: burstSize,
          height: burstSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFFD32F2F).withValues(alpha: 0.5 * fadeOut),
                const Color(0xFFE8A090).withValues(alpha: 0.6 * fadeOut),
                _pusColor(effect.type).withValues(alpha: 0.4 * fadeOut),
                const Color(0xFFFFE4D6).withValues(alpha: 0.1 * fadeOut),
              ],
              stops: const [0.0, 0.3, 0.6, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD32F2F).withValues(alpha: 0.3 * fadeOut),
                blurRadius: burstSize * 0.4,
                spreadRadius: -burstSize * 0.1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPusStream(_PusEffect effect, _PusStream stream, double t) {
    // Pus shoots out fast then slows with viscosity (more realistic easing)
    final easedT = Curves.easeOutQuart.transform(t.clamp(0.0, 1.0));
    final opacity = (1.0 - t * 0.85).clamp(0.0, 1.0);

    // Draw as a trail of blobs along the path with varying sizes (viscosity effect)
    return Stack(
      children: List.generate(5, (i) {
        final blobT = (easedT - i * 0.075 * stream.length).clamp(0.0, 1.0);
        if (blobT <= 0) return const SizedBox.shrink();

        final blobDist = effect.size * stream.speed * blobT;
        final px = effect.center.dx + cos(stream.angle) * blobDist;
        final py = effect.center.dy + sin(stream.angle) * blobDist;

        // Viscosity: blobs get smaller and elongated as they travel
        final blobSize = stream.thickness * (1.0 - i * 0.15) * (1.0 - t * 0.35);
        final blobOpacity = opacity * (1.0 - i * 0.18);

        // Add slight gravity effect to downward trajectory
        final gravityOffset = sin(stream.angle + pi / 2).abs() * blobT * effect.size * 0.15;

        if (blobSize <= 0 || blobOpacity <= 0) return const SizedBox.shrink();

        // Create oval shape for viscosity (elongated in direction of travel)
        return Positioned(
          left: px - blobSize / 2,
          top: py - blobSize / 2 + gravityOffset,
          child: Opacity(
            opacity: blobOpacity.clamp(0.0, 1.0),
            child: Container(
              width: blobSize,
              height: blobSize * (1.0 + stream.speed * 0.3), // Elongate based on speed
              decoration: BoxDecoration(
                borderRadius: BorderRadius.elliptical(
                  blobSize,
                  blobSize * (1.0 + stream.speed * 0.3),
                ),
                gradient: RadialGradient(
                  colors: [
                    _pusColor(effect.type),
                    _pusColor(effect.type).withValues(alpha: 0.7),
                  ],
                  stops: const [0.4, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _pusColor(effect.type).withValues(alpha: 0.4),
                    blurRadius: blobSize * 0.6,
                    spreadRadius: blobSize * 0.1,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPusDrop(_PusEffect effect, _PusDrop drop, double t) {
    final dropT = ((t - drop.delay) / (1.0 - drop.delay)).clamp(0.0, 1.0);
    // More realistic gravity simulation
    final easedDrop = Curves.easeInCubic.transform(dropT);
    final dist = effect.size * drop.distance * easedDrop;
    // Enhanced gravity effect with acceleration
    final gravity = dist * 0.4 * easedDrop * easedDrop;
    final px = effect.center.dx + cos(drop.angle) * dist;
    final py = effect.center.dy + sin(drop.angle) * dist + gravity;
    final opacity = (1.0 - dropT * 0.9).clamp(0.0, 1.0);
    // Drops flatten as they fall and hit (realistic deformation)
    final size = drop.size * (1.0 - dropT * 0.25);
    final flattenRatio = 1.0 + dropT * 0.4;

    return Positioned(
      left: px - size / 2,
      top: py - size / (2 * flattenRatio),
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: size,
          height: size / flattenRatio,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.elliptical(size, size / flattenRatio),
            gradient: RadialGradient(
              colors: [
                _pusColor(effect.type),
                _pusColor(effect.type).withValues(alpha: 0.8),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: _pusColor(effect.type).withValues(alpha: 0.25),
                blurRadius: size * 0.4,
                offset: Offset(0, size * 0.2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _pusColor(_PimpleType type) {
    switch (type) {
      case _PimpleType.whitehead:
        return const Color(0xFFFFF3CD); // yellowish-white pus
      case _PimpleType.reddish:
        return const Color(0xFFFFE0B2); // creamy pus
      case _PimpleType.cyst:
        return const Color(0xFFE6D5A8); // thicker yellowish
    }
  }
}

// --- Models ---

enum _PimpleType { whitehead, reddish, cyst }

class _Pimple {
  final int id;
  final double x;
  final double y;
  final double size;
  final _PimpleType type;
  final AnimationController growController;
  final AnimationController wobbleController;
  final double holdDuration; // seconds to hold
  bool squeezing = false;
  double squeezeProgress = 0; // 0..1
  DateTime? squeezeStart;
  Timer? squeezeTicker;
  int lastHapticPulse = -1;

  _Pimple({
    required this.id,
    required this.x,
    required this.y,
    required this.size,
    required this.type,
    required this.growController,
    required this.wobbleController,
    required this.holdDuration,
  });
}

class _PusEffect {
  final int id;
  final Offset center;
  final double size;
  final _PimpleType type;
  final AnimationController controller;
  final List<_PusStream> streams;
  final List<_PusDrop> drops;
  final double intensity;

  _PusEffect({
    required this.id,
    required this.center,
    required this.size,
    required this.type,
    required this.controller,
    required this.streams,
    required this.drops,
    required this.intensity,
  });
}

class _PusStream {
  final double angle;
  final double speed;
  final double length;
  final double thickness;

  _PusStream({
    required this.angle,
    required this.speed,
    required this.length,
    required this.thickness,
  });
}

class _PusDrop {
  final double angle;
  final double distance;
  final double size;
  final double delay;

  _PusDrop({
    required this.angle,
    required this.distance,
    required this.size,
    required this.delay,
  });
}

class _SplatMark {
  final Offset center;
  final double size;
  final Color color;
  final DateTime createdAt;

  _SplatMark({
    required this.center,
    required this.size,
    required this.color,
    required this.createdAt,
  });
}

// --- Pimple Widget ---

class _PimpleWidget extends StatelessWidget {
  final double size;
  final _PimpleType type;
  final double squeezeProgress;
  final double opacity;

  const _PimpleWidget({
    required this.size,
    required this.type,
    required this.squeezeProgress,
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
          painter: _PimplePainter(
            type: type,
            squeezeProgress: squeezeProgress,
          ),
        ),
      ),
    );
  }
}

class _PimplePainter extends CustomPainter {
  final _PimpleType type;
  final double squeezeProgress;

  _PimplePainter({required this.type, required this.squeezeProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sp = squeezeProgress; // 0..1

    // Shadow beneath pimple for depth (darkens with squeeze)
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15 + sp * 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(
      Offset(center.dx + radius * 0.08, center.dy + radius * 0.12),
      radius * 0.9,
      shadowPaint,
    );

    // Outer inflamed area — gets redder as squeezed with realistic gradient
    final baseAlpha = 0.5 + sp * 0.3;
    final basePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(
            const Color(0xFFFFCDB2),
            const Color(0xFFE8A090),
            sp * 0.5,
          )!.withValues(alpha: baseAlpha * 0.7),
          Color.lerp(
            const Color(0xFFFFCDB2),
            const Color(0xFFD32F2F),
            sp,
          )!.withValues(alpha: baseAlpha),
        ],
        stops: const [0.3, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, basePaint);

    // Reddish inflammation ring — throbs when squeezing with gradient
    final ringAlpha = 0.35 + sp * 0.5;
    final ringWidth = radius * (0.16 + sp * 0.1);
    final ringPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(_ringColor, const Color(0xFFD32F2F), sp * 0.7)!
              .withValues(alpha: ringAlpha * 1.2),
          Color.lerp(_ringColor, const Color(0xFFD32F2F), sp * 0.5)!
              .withValues(alpha: ringAlpha * 0.8),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.72))
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth;
    canvas.drawCircle(center, radius * 0.72, ringPaint);

    // Secondary ring for depth with subtle glow
    if (sp > 0.2) {
      final innerRing = Paint()
        ..color = _ringColor.withValues(alpha: (sp - 0.2) * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.07
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.05);
      canvas.drawCircle(center, radius * 0.55, innerRing);
    }

    // The head / core — gets bigger and more visible when squeezed with 3D shading
    final coreRadius = radius * (0.30 + sp * 0.18);
    final corePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 0.8,
        colors: [
          _coreColor.withValues(alpha: 1.0),
          Color.lerp(_coreColor, _fillingColor, 0.3)!,
          Color.lerp(_coreColor, _ringColor, 0.2)!.withValues(alpha: 0.9),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: coreRadius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, coreRadius, corePaint);

    // Subtle rim shadow on core for depth
    final rimShadow = Paint()
      ..color = _ringColor.withValues(alpha: 0.3 + sp * 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.04
      ..maskFilter = MaskFilter.blur(BlurStyle.inner, radius * 0.08);
    canvas.drawCircle(center, coreRadius * 0.95, rimShadow);

    // Inner "filling" showing through — visible when pressing with realistic texture
    if (sp > 0.3) {
      final fillingRadius = coreRadius * 0.65 * ((sp - 0.3) / 0.7);
      final fillingPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            _fillingColor.withValues(alpha: 0.9 + sp * 0.1),
            _fillingColor.withValues(alpha: 0.7 + sp * 0.3),
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: fillingRadius))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, fillingRadius, fillingPaint);

      // Pus starting to emerge effect
      if (sp > 0.6) {
        final emergePaint = Paint()
          ..color = _fillingColor.withValues(alpha: (sp - 0.6) * 0.8)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, fillingRadius * 0.2);
        canvas.drawCircle(center, fillingRadius * 1.1, emergePaint);
      }
    }

    // Core highlight — glossy top-left reflection (more pronounced)
    final hlOffset = Offset(
      center.dx - radius * 0.20,
      center.dy - radius * 0.22,
    );
    final hlRadius = radius * (0.14 + sp * 0.05);
    final hlPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.7 + sp * 0.2),
          Colors.white.withValues(alpha: 0.3 + sp * 0.1),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: hlOffset, radius: hlRadius));
    canvas.drawCircle(hlOffset, hlRadius, hlPaint);

    // Secondary smaller highlight for realism
    final hl2Offset = Offset(
      center.dx + radius * 0.15,
      center.dy - radius * 0.08,
    );
    final hl2Paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25 + sp * 0.15);
    canvas.drawCircle(hl2Offset, radius * 0.08, hl2Paint);

    // Squeeze pressure ring (red pulsing outline when holding) with glow
    if (sp > 0) {
      final pressurePaint = Paint()
        ..color = const Color(0xFFEF5350).withValues(alpha: sp * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 + sp * 2.5
        ..maskFilter = MaskFilter.blur(BlurStyle.outer, 2 + sp * 3);
      canvas.drawCircle(center, radius + 3 + sp * 5, pressurePaint);
    }

    // "About to pop" glow (more dramatic)
    if (sp > 0.7) {
      final glowIntensity = (sp - 0.7) / 0.3;
      final glowPaint = Paint()
        ..color = _coreColor.withValues(alpha: glowIntensity * 0.8)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * (0.4 + glowIntensity * 0.3));
      canvas.drawCircle(center, coreRadius * (1.3 + glowIntensity * 0.2), glowPaint);

      // Add pulsing red glow indicating imminent pop
      final redGlowPaint = Paint()
        ..color = const Color(0xFFFF5252).withValues(alpha: glowIntensity * 0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.5);
      canvas.drawCircle(center, radius * 1.1, redGlowPaint);
    }
  }

  Color get _ringColor {
    switch (type) {
      case _PimpleType.whitehead:
        return const Color(0xFFE8A090);
      case _PimpleType.reddish:
        return const Color(0xFFE57373);
      case _PimpleType.cyst:
        return const Color(0xFFD32F2F);
    }
  }

  Color get _coreColor {
    switch (type) {
      case _PimpleType.whitehead:
        return const Color(0xFFFFF8E1);
      case _PimpleType.reddish:
        return const Color(0xFFFFECB3);
      case _PimpleType.cyst:
        return const Color(0xFFE6D5A8);
    }
  }

  Color get _fillingColor {
    switch (type) {
      case _PimpleType.whitehead:
        return const Color(0xFFFFF9C4); // yellowish white
      case _PimpleType.reddish:
        return const Color(0xFFFFE082); // creamy yellow
      case _PimpleType.cyst:
        return const Color(0xFFD4C98A); // thick yellow
    }
  }

  @override
  bool shouldRepaint(_PimplePainter old) =>
      type != old.type || squeezeProgress != old.squeezeProgress;
}
