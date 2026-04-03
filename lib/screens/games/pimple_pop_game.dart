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
    // Start squeeze progress ticker
    pimple.squeezeTicker?.cancel();
    pimple.squeezeTicker = Timer.periodic(
      const Duration(milliseconds: 40),
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

    // Haptic pulses while squeezing
    if (progress > 0.3 && progress < 0.95) {
      if ((elapsed * 8).floor() % 2 == 0) {
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
      duration: const Duration(milliseconds: 900),
    );

    // More pus streams for higher intensity / bigger pimples
    final streamCount = 3 + (intensity * 5).round() + _random.nextInt(3);
    final streams = List.generate(streamCount, (i) {
      final baseAngle = i * 2 * pi / streamCount;
      final angle = baseAngle + (_random.nextDouble() - 0.5) * 0.8;
      final speed = 0.6 + _random.nextDouble() * 0.8 + intensity * 0.4;
      final length = 0.4 + _random.nextDouble() * 0.6;
      final thickness = 3.0 + _random.nextDouble() * 4;
      return _PusStream(
        angle: angle,
        speed: speed,
        length: length,
        thickness: thickness,
      );
    });

    // Secondary splat drops
    final dropCount = 4 + _random.nextInt(5);
    final drops = List.generate(dropCount, (i) {
      return _PusDrop(
        angle: _random.nextDouble() * 2 * pi,
        distance: 0.5 + _random.nextDouble() * 1.0,
        size: 2.0 + _random.nextDouble() * 4,
        delay: _random.nextDouble() * 0.3,
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
    return AnimatedBuilder(
      animation: Listenable.merge([
        pimple.growController,
        pimple.wobbleController,
      ]),
      builder: (context, _) {
        final grow = pimple.growController.value;
        final wobble = pimple.wobbleController.value;
        final squeeze = pimple.squeezeProgress;

        // When squeezing: grows, turns more red, then "bulges"
        final breathe = 1.0 + wobble * 0.04;
        final squeezeInflate = 1.0 + squeeze * 0.25;
        final scale = grow * breathe * squeezeInflate;
        final currentSize = pimple.size * scale;

        return Positioned(
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
        );
      },
    );
  }

  Widget _buildPusEffect(_PusEffect effect) {
    return AnimatedBuilder(
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
    );
  }

  Widget _buildBurstCenter(_PusEffect effect, double t) {
    final burstProgress = (t * 3).clamp(0.0, 1.0);
    final fadeOut = (1.0 - (t - 0.5).clamp(0.0, 1.0) * 2).clamp(0.0, 1.0);
    final burstSize = effect.size * (0.3 + burstProgress * 0.4);

    return Positioned(
      left: effect.center.dx - burstSize / 2,
      top: effect.center.dy - burstSize / 2,
      child: Opacity(
        opacity: fadeOut * 0.8,
        child: Container(
          width: burstSize,
          height: burstSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFFE8A090).withValues(alpha: 0.6),
                _pusColor(effect.type).withValues(alpha: 0.3),
                const Color(0xFFFFE4D6).withValues(alpha: 0.1),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPusStream(_PusEffect effect, _PusStream stream, double t) {
    // Pus shoots out fast then slows
    final easedT = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
    final opacity = (1.0 - t * 0.9).clamp(0.0, 1.0);

    // Draw as a trail of blobs along the path
    return Stack(
      children: List.generate(4, (i) {
        final blobT = (easedT - i * 0.08 * stream.length).clamp(0.0, 1.0);
        final blobDist = effect.size * stream.speed * blobT;
        final px = effect.center.dx + cos(stream.angle) * blobDist;
        final py = effect.center.dy + sin(stream.angle) * blobDist;
        final blobSize = stream.thickness * (1.0 - i * 0.18) * (1.0 - t * 0.4);
        final blobOpacity = opacity * (1.0 - i * 0.2);

        if (blobSize <= 0 || blobOpacity <= 0) return const SizedBox.shrink();

        return Positioned(
          left: px - blobSize / 2,
          top: py - blobSize / 2,
          child: Opacity(
            opacity: blobOpacity.clamp(0.0, 1.0),
            child: Container(
              width: blobSize,
              height: blobSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _pusColor(effect.type),
                boxShadow: [
                  BoxShadow(
                    color: _pusColor(effect.type).withValues(alpha: 0.3),
                    blurRadius: blobSize * 0.5,
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
    final easedDrop = Curves.easeOutQuad.transform(dropT);
    final dist = effect.size * drop.distance * easedDrop;
    // Gravity effect: drops fall a bit
    final gravity = dist * 0.3 * easedDrop;
    final px = effect.center.dx + cos(drop.angle) * dist;
    final py = effect.center.dy + sin(drop.angle) * dist + gravity;
    final opacity = (1.0 - dropT).clamp(0.0, 1.0);
    final size = drop.size * (1.0 - dropT * 0.3);

    return Positioned(
      left: px - size / 2,
      top: py - size / 2,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _pusColor(effect.type),
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

    // Outer inflamed area — gets redder as squeezed
    final baseAlpha = 0.5 + sp * 0.3;
    final basePaint = Paint()
      ..color = Color.lerp(
        const Color(0xFFFFCDB2),
        const Color(0xFFE8A090),
        sp,
      )!
          .withValues(alpha: baseAlpha)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, basePaint);

    // Reddish inflammation ring — throbs when squeezing
    final ringAlpha = 0.3 + sp * 0.5;
    final ringWidth = radius * (0.14 + sp * 0.08);
    final ringPaint = Paint()
      ..color = Color.lerp(_ringColor, const Color(0xFFD32F2F), sp * 0.6)!
          .withValues(alpha: ringAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth;
    canvas.drawCircle(center, radius * 0.72, ringPaint);

    // Secondary ring for depth
    if (sp > 0.2) {
      final innerRing = Paint()
        ..color = _ringColor.withValues(alpha: (sp - 0.2) * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.06;
      canvas.drawCircle(center, radius * 0.55, innerRing);
    }

    // The head / core — gets bigger and more visible when squeezed
    final coreRadius = radius * (0.28 + sp * 0.15);
    final corePaint = Paint()
      ..color = _coreColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, coreRadius, corePaint);

    // Inner "filling" showing through — visible when pressing
    if (sp > 0.3) {
      final fillingRadius = coreRadius * 0.6 * ((sp - 0.3) / 0.7);
      final fillingPaint = Paint()
        ..color = _fillingColor.withValues(alpha: 0.7 + sp * 0.3);
      canvas.drawCircle(center, fillingRadius, fillingPaint);
    }

    // Core highlight — glossy top-left reflection
    final hlOffset = Offset(
      center.dx - radius * 0.18,
      center.dy - radius * 0.18,
    );
    final hlRadius = radius * (0.12 + sp * 0.04);
    final hlPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45 + sp * 0.15);
    canvas.drawCircle(hlOffset, hlRadius, hlPaint);

    // Squeeze pressure ring (red pulsing outline when holding)
    if (sp > 0) {
      final pressurePaint = Paint()
        ..color = const Color(0xFFEF5350).withValues(alpha: sp * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + sp * 2;
      canvas.drawCircle(center, radius + 2 + sp * 4, pressurePaint);
    }

    // "About to pop" glow
    if (sp > 0.7) {
      final glowPaint = Paint()
        ..color = _coreColor.withValues(alpha: (sp - 0.7) * 2)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.3);
      canvas.drawCircle(center, coreRadius * 1.3, glowPaint);
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
