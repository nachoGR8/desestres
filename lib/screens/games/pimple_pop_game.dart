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
  final List<_ComboText> _comboTexts = [];
  final List<_ComboStar> _comboStars = [];
  final Random _random = Random();
  Timer? _spawnTimer;
  int _popped = 0;
  bool _active = true;

  // Combo system
  int _combo = 0;
  DateTime? _lastPopTime;
  static const _comboDuration = Duration(milliseconds: 2500);
  Timer? _comboResetTimer;

  // Screen shake
  double _shakeX = 0;
  double _shakeY = 0;
  Timer? _shakeTicker;

  // Score counter animation
  late AnimationController _scoreAnimCtrl;
  int _displayedScore = 0;

  // Screen flash on pop
  double _flashOpacity = 0;
  Timer? _flashTimer;

  // Best combo tracking
  int _bestCombo = 0;

  // Start time for session summary
  late DateTime _sessionStart;

  @override
  void initState() {
    super.initState();
    _sessionStart = DateTime.now();
    _scoreAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (_active && _pimples.where((p) => !p.popping).length < 10) _addPimple();
    });
    for (int i = 0; i < 5; i++) {
      Future.delayed(Duration(milliseconds: i * 300), () {
        if (mounted && _active) _addPimple();
      });
    }
  }

  void _addPimple() {
    final size = 52.0 + _random.nextDouble() * 32;
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final margin = size / 2 + 20;

    // Try to find a non-overlapping position (up to 12 attempts)
    double x = 0, y = 0;
    bool placed = false;
    for (int attempt = 0; attempt < 12; attempt++) {
      x = margin + _random.nextDouble() * (screenW - 2 * margin);
      y = 90 + margin + _random.nextDouble() * (screenH - 200 - 2 * margin);
      bool overlaps = false;
      for (final p in _pimples) {
        final dist = sqrt(pow(p.x - x, 2) + pow(p.y - y, 2));
        if (dist < (p.size + size) * 0.55) {
          overlaps = true;
          break;
        }
      }
      if (!overlaps) { placed = true; break; }
    }
    if (!placed && _pimples.length >= 6) return; // Skip if too crowded

    final growCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500 + _random.nextInt(400)),
    );
    final wobbleCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000 + _random.nextInt(800)),
    )..repeat(reverse: true);

    final typeRoll = _random.nextDouble();
    final type = typeRoll < 0.35
        ? _PimpleType.whitehead
        : typeRoll < 0.60
            ? _PimpleType.reddish
            : typeRoll < 0.80
                ? _PimpleType.blackhead
                : _PimpleType.cyst;

    final pimple = _Pimple(
      id: DateTime.now().microsecondsSinceEpoch + _random.nextInt(9999),
      x: x,
      y: y,
      size: size,
      type: type,
      growController: growCtrl,
      wobbleController: wobbleCtrl,
      holdDuration: type == _PimpleType.cyst
          ? 1.8
          : type == _PimpleType.reddish
              ? 1.2
              : type == _PimpleType.blackhead
                  ? 0.0 // blackheads use tap, not hold
                  : 0.8,
      tapsNeeded: type == _PimpleType.blackhead ? 3 : 0,
    );

    setState(() => _pimples.add(pimple));
    growCtrl.forward();
  }

  // --- Blackhead tap mechanic ---
  void _tapPimple(_Pimple pimple) {
    if (!_pimples.any((p) => p.id == pimple.id)) return;
    if (pimple.type != _PimpleType.blackhead) return;

    pimple.tapCount++;
    HapticFeedback.lightImpact();
    SoundService().playSquish();

    // Visual squeeze bump per tap
    pimple.squeezeProgress = (pimple.tapCount / pimple.tapsNeeded).clamp(0.0, 1.0);
    setState(() {});

    if (pimple.tapCount >= pimple.tapsNeeded) {
      _popPimple(pimple);
    }
  }

  // --- Hold-to-squeeze for whitehead/reddish/cyst ---
  void _startSqueezing(_Pimple pimple) {
    if (!_pimples.any((p) => p.id == pimple.id)) return;
    if (pimple.type == _PimpleType.blackhead) return; // blackheads use tap
    if (pimple.squeezing) return;
    pimple.squeezing = true;
    pimple.squeezeStart = DateTime.now();
    HapticFeedback.lightImpact();
    SoundService().playSquelch();
    setState(() {});
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

    if (progress > 0.3 && progress < 0.95) {
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
    if (pimple.squeezeProgress > 0.7) {
      _popPimple(pimple);
      return;
    }
    pimple.squeezeProgress = 0;
    setState(() {});
  }

  Future<void> _popPimple(_Pimple pimple) async {
    if (!_pimples.any((p) => p.id == pimple.id)) return;
    pimple.squeezeTicker?.cancel();
    pimple.squeezing = false;

    HapticFeedback.heavyImpact();
    SoundService().playSplat();
    Future.delayed(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
    });
    // Secondary wet sound for extra juice on big pops
    if (pimple.type == _PimpleType.cyst || pimple.squeezeProgress > 0.9) {
      Future.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        SoundService().playSquish();
      });
    }

    // Update combo
    _comboResetTimer?.cancel();
    final now = DateTime.now();
    if (_lastPopTime != null && now.difference(_lastPopTime!) < _comboDuration) {
      _combo++;
    } else {
      _combo = 1;
    }
    _lastPopTime = now;
    // Auto-reset combo after window expires
    _comboResetTimer = Timer(_comboDuration, () {
      if (mounted) setState(() => _combo = 0);
    });

    // Track best combo
    if (_combo > _bestCombo) _bestCombo = _combo;

    // Show combo text if ≥ 2
    if (_combo >= 2) {
      _spawnComboText(Offset(pimple.x, pimple.y - pimple.size), _combo);
    }

    // Spawn celebration stars + reward sound on combos ≥ 3
    if (_combo >= 3) {
      _spawnComboStars(Offset(pimple.x, pimple.y), _combo);
      if (_combo == 3 || _combo == 5 || _combo >= 8) {
        SoundService().playRewardDing();
      }
    }

    // Screen shake — stronger for cysts and combos
    final shakeIntensity = pimple.type == _PimpleType.cyst
        ? 8.0
        : pimple.type == _PimpleType.blackhead
            ? 3.0
            : 5.0;
    _triggerShake(shakeIntensity + _combo * 1.5);

    // Screen flash — brief white flash for satisfying feedback
    _triggerFlash(pimple.type == _PimpleType.cyst ? 0.18 : 0.10);

    _spawnPusEffect(
      Offset(pimple.x, pimple.y),
      pimple.size,
      pimple.type,
      pimple.squeezeProgress,
    );

    // Animate the pimple shrinking away instead of instant removal
    pimple.popping = true;
    setState(() {
      _popped++;
      _displayedScore = _popped;
    });

    // Bounce the score
    _scoreAnimCtrl.forward(from: 0);

    // Pop shrink animation
    final popCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    pimple.popController = popCtrl;
    popCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!mounted) return;
        final growCtrl = pimple.growController;
        final wobbleCtrl = pimple.wobbleController;
        setState(() => _pimples.removeWhere((p) => p.id == pimple.id));
        SchedulerBinding.instance.addPostFrameCallback((_) {
          growCtrl.dispose();
          wobbleCtrl.dispose();
          popCtrl.dispose();
        });
      }
    });
    popCtrl.forward();

    await StorageService().incrementCounter('totalPimples');
  }

  void _triggerFlash(double intensity) {
    _flashTimer?.cancel();
    setState(() => _flashOpacity = intensity);
    _flashTimer = Timer(const Duration(milliseconds: 80), () {
      if (mounted) setState(() => _flashOpacity = 0);
    });
  }

  void _spawnComboStars(Offset center, int combo) {
    final count = 4 + min(combo, 8);
    for (int i = 0; i < count; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + _random.nextInt(400)),
      );
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 40.0 + _random.nextDouble() * 80;
      final star = _ComboStar(
        id: DateTime.now().microsecondsSinceEpoch + i,
        center: center,
        angle: angle,
        speed: speed,
        size: 4.0 + _random.nextDouble() * 6,
        color: combo >= 8
            ? const Color(0xFFFF1744)
            : combo >= 5
                ? const Color(0xFFFF9100)
                : const Color(0xFFFFC107),
        controller: ctrl,
      );
      ctrl.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (!mounted) return;
          setState(() => _comboStars.removeWhere((s) => s.id == star.id));
          ctrl.dispose();
        }
      });
      setState(() => _comboStars.add(star));
      ctrl.forward();
    }
  }

  void _triggerShake(double intensity) {
    _shakeTicker?.cancel();
    int ticks = 0;
    _shakeTicker = Timer.periodic(const Duration(milliseconds: 25), (timer) {
      if (!mounted || ticks > 8) {
        timer.cancel();
        if (mounted) setState(() { _shakeX = 0; _shakeY = 0; });
        return;
      }
      final decay = 1.0 - ticks / 9;
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _shakeX = (_random.nextDouble() - 0.5) * 2 * intensity * decay;
        _shakeY = (_random.nextDouble() - 0.5) * 2 * intensity * decay;
      });
      ticks++;
    });
  }

  void _spawnComboText(Offset pos, int combo) {
    final ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    final ct = _ComboText(
      id: DateTime.now().microsecondsSinceEpoch + _random.nextInt(9999),
      position: pos,
      combo: combo,
      controller: ctrl,
    );
    ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!mounted) return;
        setState(() => _comboTexts.removeWhere((c) => c.id == ct.id));
        ctrl.dispose();
      }
    });
    setState(() => _comboTexts.add(ct));
    ctrl.forward();
  }

  void _spawnPusEffect(
      Offset center, double size, _PimpleType type, double intensity) {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // More pus streams for bigger, juicier pops
    final streamCount = 6 + (intensity * 8).round() + _random.nextInt(5);
    final streams = List.generate(streamCount, (i) {
      final baseAngle = i * 2 * pi / streamCount;
      final angle = baseAngle + (_random.nextDouble() - 0.5) * 1.4;
      final speed = 0.9 + _random.nextDouble() * 1.3 + intensity * 0.7;
      final length = 0.6 + _random.nextDouble() * 0.9;
      final thickness = 3.5 + _random.nextDouble() * 7 + intensity * 3;
      return _PusStream(
        angle: angle,
        speed: speed,
        length: length,
        thickness: thickness,
      );
    });

    // Many more splatter drops
    final dropCount = 10 + _random.nextInt(10) + (intensity * 6).round();
    final drops = List.generate(dropCount, (i) {
      return _PusDrop(
        angle: _random.nextDouble() * 2 * pi,
        distance: 0.5 + _random.nextDouble() * 1.8,
        size: 2.0 + _random.nextDouble() * 7,
        delay: _random.nextDouble() * 0.35,
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
        final markCount = 2 + _random.nextInt(4);
        for (int i = 0; i < markCount; i++) {
          final markOffset = Offset(
            center.dx + (_random.nextDouble() - 0.5) * size * 0.8,
            center.dy + (_random.nextDouble() - 0.5) * size * 0.8,
          );
          _splatMarks.add(_SplatMark(
            center: markOffset,
            size: size * (0.25 + _random.nextDouble() * 0.35),
            color: _pusColor(type).withValues(alpha: 0.12 + _random.nextDouble() * 0.08),
            createdAt: DateTime.now(),
            rotation: _random.nextDouble() * 2 * pi,
            irregularity: 0.7 + _random.nextDouble() * 0.3,
          ));
        }
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
    _shakeTicker?.cancel();
    _comboResetTimer?.cancel();
    _flashTimer?.cancel();
    _scoreAnimCtrl.dispose();
    for (final p in _pimples) {
      p.squeezeTicker?.cancel();
      p.growController.dispose();
      p.wobbleController.dispose();
      p.popController?.dispose();
    }
    for (final e in _pusEffects) {
      e.controller.dispose();
    }
    for (final c in _comboTexts) {
      c.controller.dispose();
    }
    for (final s in _comboStars) {
      s.controller.dispose();
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
    if (!mounted) return;

    // Show session summary if player popped any pimples
    if (_popped > 0) {
      final duration = DateTime.now().difference(_sessionStart);
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds % 60;
      final timeStr = minutes > 0
          ? '$minutes min $seconds s'
          : '$seconds s';

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Theme.of(ctx).colorScheme.surface,
          title: Text(
            _popped >= 20
                ? '🎉 Increíble!'
                : _popped >= 10
                    ? '💪 Bien hecho!'
                    : '😌 Relax',
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '💥 $_popped granitos reventados',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (_bestCombo >= 2)
                Text(
                  '🔥 Mejor combo: x$_bestCombo',
                  style: TextStyle(
                    fontSize: 14,
                    color: _bestCombo >= 8
                        ? const Color(0xFFFF1744)
                        : _bestCombo >= 5
                            ? const Color(0xFFFF9100)
                            : const Color(0xFFFFC107),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                '⏱ $timeStr',
                style: TextStyle(fontSize: 13, color: AppTheme.textHint),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cerrar',
                style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Transform.translate(
          offset: Offset(_shakeX, _shakeY),
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

              // Splat marks
              ..._splatMarks.map((mark) => Positioned(
                    left: mark.center.dx - mark.size / 2,
                    top: mark.center.dy - mark.size / 2,
                    child: Transform.rotate(
                      angle: mark.rotation,
                      child: CustomPaint(
                        size: Size(mark.size, mark.size),
                        painter: _SplatPainter(
                          color: mark.color,
                          irregularity: mark.irregularity,
                        ),
                      ),
                    ),
                  )),

              // Pimples
              ..._pimples.map((p) => _buildPimple(p)),

              // Pus effects (IgnorePointer so they don't block taps)
              ...(_pusEffects.map((e) => IgnorePointer(child: _buildPusEffect(e)))),

              // Combo texts floating up
              ..._comboTexts.map((ct) => _buildComboText(ct)),

              // Combo star particles
              ..._comboStars.map((s) => _buildComboStar(s)),

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
                    // Animated score counter
                    AnimatedBuilder(
                      animation: _scoreAnimCtrl,
                      builder: (context, _) {
                        final bounce = 1.0 + sin(_scoreAnimCtrl.value * pi) * 0.2;
                        return Transform.scale(
                          scale: bounce,
                          child: Container(
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
                              '💥 $_displayedScore',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Combo indicator
              if (_combo >= 2)
                Positioned(
                  top: 56,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _comboColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _comboColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '🔥 x$_combo',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _comboColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

              // Screen flash overlay
              if (_flashOpacity > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: Colors.white.withValues(alpha: _flashOpacity),
                    ),
                  ),
                ),

              // Hint
              if (_popped == 0)
                Positioned(
                  bottom: 60,
                  left: 20,
                  right: 20,
                  child: Text(
                    'Mantén pulsado para reventar\nLos negros necesitan varios toques',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textHint,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color get _comboColor {
    if (_combo >= 8) return const Color(0xFFFF1744);
    if (_combo >= 5) return const Color(0xFFFF9100);
    return const Color(0xFFFFC107);
  }

  List<Widget> _buildSkinTexture() {
    final rng = Random(42);
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    return List.generate(30, (i) {
      final x = rng.nextDouble() * screenW;
      final y = 80 + rng.nextDouble() * (screenH - 160);
      final s = 2.0 + rng.nextDouble() * 2;

      double proximityEffect = 0.0;
      for (final pimple in _pimples) {
        if (pimple.squeezeProgress > 0) {
          final distance = ((x - pimple.x).abs() + (y - pimple.y).abs()) / 100;
          if (distance < 3) {
            proximityEffect = ((3 - distance) / 3) * pimple.squeezeProgress;
          }
        }
      }

      final enhancedAlpha = (0.15 + proximityEffect * 0.25).clamp(0.0, 1.0);
      final enhancedSize = s * (1.0 + proximityEffect * 0.3);

      return Positioned(
        left: x,
        top: y,
        child: Container(
          width: enhancedSize,
          height: enhancedSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFD4A98A).withValues(alpha: enhancedAlpha),
          ),
        ),
      );
    });
  }

  Widget _buildPimple(_Pimple pimple) {
    final listenables = <Listenable>[
      pimple.growController,
      pimple.wobbleController,
    ];
    if (pimple.popController != null) listenables.add(pimple.popController!);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge(listenables),
        builder: (context, _) {
          final grow = pimple.growController.value;
          final wobble = pimple.wobbleController.value;
          final squeeze = pimple.squeezeProgress;

          // Pop animation: shrink and fade out
          final popT = pimple.popController?.value ?? 0.0;
          final popScale = pimple.popping ? 1.0 + popT * 0.4 : 1.0;
          final popOpacity = pimple.popping ? (1.0 - popT).clamp(0.0, 1.0) : 1.0;

          final breathe = 1.0 + wobble * 0.05;
          final squeezeInflate = 1.0 + squeeze * 0.35 +
              (squeeze > 0.7 ? (squeeze - 0.7) * 0.5 : 0);
          final scale = grow * breathe * squeezeInflate * popScale;
          final currentSize = pimple.size * scale;

          final showDeformation = squeeze > 0.1;
          final deformationSize = currentSize * (1.4 + squeeze * 0.3);
          final deformationOpacity = (squeeze * 0.3).clamp(0.0, 1.0);

          // Progress ring radius
          final ringRadius = currentSize / 2 + 8 + squeeze * 4;

          return Opacity(
            opacity: popOpacity,
            child: Stack(
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

              // Progress ring (arc showing squeeze progress)
              if (squeeze > 0 && pimple.type != _PimpleType.blackhead)
                Positioned(
                  left: pimple.x - ringRadius,
                  top: pimple.y - ringRadius,
                  child: CustomPaint(
                    size: Size(ringRadius * 2, ringRadius * 2),
                    painter: _ProgressRingPainter(
                      progress: squeeze,
                      color: squeeze > 0.7
                          ? const Color(0xFFFF5252)
                          : const Color(0xFFEF9A9A),
                    ),
                  ),
                ),

              // Tap counter for blackheads
              if (pimple.type == _PimpleType.blackhead && pimple.tapCount > 0)
                Positioned(
                  left: pimple.x - ringRadius,
                  top: pimple.y - ringRadius,
                  child: CustomPaint(
                    size: Size(ringRadius * 2, ringRadius * 2),
                    painter: _ProgressRingPainter(
                      progress: pimple.tapCount / pimple.tapsNeeded,
                      color: const Color(0xFF8D6E63),
                    ),
                  ),
                ),

              // The pimple itself
              Positioned(
                left: pimple.x - currentSize / 2,
                top: pimple.y - currentSize / 2,
                child: GestureDetector(
                  onTap: pimple.type == _PimpleType.blackhead && !pimple.popping
                      ? () => _tapPimple(pimple)
                      : null,
                  onLongPressStart: pimple.type != _PimpleType.blackhead && !pimple.popping
                      ? (_) => _startSqueezing(pimple)
                      : null,
                  onLongPressEnd: pimple.type != _PimpleType.blackhead && !pimple.popping
                      ? (_) => _stopSqueezing(pimple)
                      : null,
                  onLongPressCancel: pimple.type != _PimpleType.blackhead && !pimple.popping
                      ? () => _stopSqueezing(pimple)
                      : null,
                  behavior: HitTestBehavior.opaque,
                  child: _PimpleWidget(
                    size: currentSize,
                    type: pimple.type,
                    squeezeProgress: squeeze,
                    opacity: grow.clamp(0.0, 1.0),
                  ),
                ),
              ),
            ],
          ),
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
              _buildBurstCenter(effect, t),
              // Secondary burst ring expanding outward
              if (t < 0.6) _buildBurstRing(effect, t),
              ...effect.streams.map((s) => _buildPusStream(effect, s, t)),
              ...effect.drops
                  .where((d) => t > d.delay)
                  .map((d) => _buildPusDrop(effect, d, t)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildComboText(_ComboText ct) {
    return AnimatedBuilder(
      animation: ct.controller,
      builder: (context, _) {
        final t = ct.controller.value;
        final y = ct.position.dy - 40 * t;
        final opacity = (1.0 - t * 1.2).clamp(0.0, 1.0);
        final scale = 1.0 + sin(t * pi) * 0.3;

        return Positioned(
          left: ct.position.dx - 30,
          top: y,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Text(
                  ct.combo >= 8
                      ? '🔥 x${ct.combo}!'
                      : ct.combo >= 5
                          ? '⚡ x${ct.combo}'
                          : 'x${ct.combo}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18 + ct.combo.clamp(0, 8).toDouble(),
                    color: ct.combo >= 8
                        ? const Color(0xFFFF1744)
                        : ct.combo >= 5
                            ? const Color(0xFFFF9100)
                            : const Color(0xFFFFC107),
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildComboStar(_ComboStar star) {
    return AnimatedBuilder(
      animation: star.controller,
      builder: (context, _) {
        final t = star.controller.value;
        final easedT = Curves.easeOutCubic.transform(t);
        final dist = star.speed * easedT;
        final x = star.center.dx + cos(star.angle) * dist;
        final y = star.center.dy + sin(star.angle) * dist - easedT * 20;
        final opacity = (1.0 - t).clamp(0.0, 1.0);
        final size = star.size * (1.0 - t * 0.5);
        final rotation = t * pi * 2;

        return Positioned(
          left: x - size / 2,
          top: y - size / 2,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: Transform.rotate(
                angle: rotation,
                child: Icon(
                  Icons.star_rounded,
                  size: size,
                  color: star.color,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBurstRing(_PusEffect effect, double t) {
    final ringT = (t * 3).clamp(0.0, 1.0);
    final ringSize = effect.size * (0.5 + ringT * 1.8);
    final ringOpacity = (1.0 - ringT * 1.8).clamp(0.0, 0.5);
    final ringWidth = (4.0 - ringT * 3).clamp(0.5, 4.0);

    return Positioned(
      left: effect.center.dx - ringSize / 2,
      top: effect.center.dy - ringSize / 2,
      child: Opacity(
        opacity: ringOpacity,
        child: Container(
          width: ringSize,
          height: ringSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _pusColor(effect.type).withValues(alpha: 0.6),
              width: ringWidth,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBurstCenter(_PusEffect effect, double t) {
    final burstProgress = (t * 2.5).clamp(0.0, 1.0);
    final fadeOut = (1.0 - (t - 0.5).clamp(0.0, 1.0) * 1.4).clamp(0.0, 1.0);
    final burstSize = effect.size * (0.45 + burstProgress * 0.65);

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
    final easedT = Curves.easeOutQuart.transform(t.clamp(0.0, 1.0));
    final opacity = (1.0 - t * 0.85).clamp(0.0, 1.0);

    return Stack(
      children: List.generate(8, (i) {
        final blobT = (easedT - i * 0.055 * stream.length).clamp(0.0, 1.0);
        if (blobT <= 0) return const SizedBox.shrink();

        final blobDist = effect.size * stream.speed * blobT;
        final px = effect.center.dx + cos(stream.angle) * blobDist;
        final py = effect.center.dy + sin(stream.angle) * blobDist;

        final blobSize = stream.thickness * (1.0 - i * 0.10) * (1.0 - t * 0.30);
        final blobOpacity = opacity * (1.0 - i * 0.11);

        final gravityOffset = sin(stream.angle + pi / 2).abs() * blobT * effect.size * 0.15;

        if (blobSize <= 0 || blobOpacity <= 0) return const SizedBox.shrink();

        return Positioned(
          left: px - blobSize / 2,
          top: py - blobSize / 2 + gravityOffset,
          child: Opacity(
            opacity: blobOpacity.clamp(0.0, 1.0),
            child: Container(
              width: blobSize,
              height: blobSize * (1.0 + stream.speed * 0.3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(
                  Radius.elliptical(
                    blobSize,
                    blobSize * (1.0 + stream.speed * 0.3),
                  ),
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
    final easedDrop = Curves.easeInCubic.transform(dropT);
    final dist = effect.size * drop.distance * easedDrop;
    final gravity = dist * 0.4 * easedDrop * easedDrop;
    final px = effect.center.dx + cos(drop.angle) * dist;
    final py = effect.center.dy + sin(drop.angle) * dist + gravity;
    final opacity = (1.0 - dropT * 0.9).clamp(0.0, 1.0);
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
            borderRadius: BorderRadius.all(
              Radius.elliptical(size, size / flattenRatio),
            ),
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
        return const Color(0xFFFFF3CD);
      case _PimpleType.reddish:
        return const Color(0xFFFFE0B2);
      case _PimpleType.blackhead:
        return const Color(0xFF8B7355);
      case _PimpleType.cyst:
        return const Color(0xFFE6D5A8);
    }
  }
}

// --- Models ---

enum _PimpleType { whitehead, reddish, blackhead, cyst }

class _Pimple {
  final int id;
  final double x;
  final double y;
  final double size;
  final _PimpleType type;
  final AnimationController growController;
  final AnimationController wobbleController;
  final double holdDuration;
  final int tapsNeeded; // for blackheads
  int tapCount = 0;
  bool squeezing = false;
  bool popping = false;
  double squeezeProgress = 0;
  DateTime? squeezeStart;
  Timer? squeezeTicker;
  AnimationController? popController;
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
    this.tapsNeeded = 0,
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
  final double rotation;
  final double irregularity;

  _SplatMark({
    required this.center,
    required this.size,
    required this.color,
    required this.createdAt,
    required this.rotation,
    required this.irregularity,
  });
}

class _ComboText {
  final int id;
  final Offset position;
  final int combo;
  final AnimationController controller;

  _ComboText({
    required this.id,
    required this.position,
    required this.combo,
    required this.controller,
  });
}

class _ComboStar {
  final int id;
  final Offset center;
  final double angle;
  final double speed;
  final double size;
  final Color color;
  final AnimationController controller;

  _ComboStar({
    required this.id,
    required this.center,
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.controller,
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

// --- Progress Ring Painter ---

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ProgressRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // Background track
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      arcPaint,
    );

    // Glow on the leading edge
    if (progress > 0.1) {
      final angle = -pi / 2 + 2 * pi * progress;
      final glowPos = Offset(
        center.dx + cos(angle) * radius,
        center.dy + sin(angle) * radius,
      );
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(glowPos, 4, glowPaint);
    }
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) =>
      progress != old.progress || color != old.color;
}

// --- Pimple Painter ---

class _PimplePainter extends CustomPainter {
  final _PimpleType type;
  final double squeezeProgress;

  _PimplePainter({required this.type, required this.squeezeProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sp = squeezeProgress;

    // Shadow beneath pimple for depth
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15 + sp * 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(
      Offset(center.dx + radius * 0.08, center.dy + radius * 0.12),
      radius * 0.9,
      shadowPaint,
    );

    // Outer inflamed area
    final baseAlpha = 0.5 + sp * 0.3;
    final basePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(
            _baseColor,
            const Color(0xFFE8A090),
            sp * 0.5,
          )!.withValues(alpha: baseAlpha * 0.7),
          Color.lerp(
            _baseColor,
            const Color(0xFFD32F2F),
            sp,
          )!.withValues(alpha: baseAlpha),
        ],
        stops: const [0.3, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, basePaint);

    // Reddish inflammation ring
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

    // Secondary ring for depth
    if (sp > 0.2) {
      final innerRing = Paint()
        ..color = _ringColor.withValues(alpha: (sp - 0.2) * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.07
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.05);
      canvas.drawCircle(center, radius * 0.55, innerRing);
    }

    // The head / core
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

    // Rim shadow on core
    final rimShadow = Paint()
      ..color = _ringColor.withValues(alpha: 0.3 + sp * 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.04
      ..maskFilter = MaskFilter.blur(BlurStyle.inner, radius * 0.08);
    canvas.drawCircle(center, coreRadius * 0.95, rimShadow);

    // Inner filling showing through when pressing
    if (sp > 0.3) {
      final fillingRadius = coreRadius * 0.65 * ((sp - 0.3) / 0.7);
      final fillingPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            _fillingColor.withValues(alpha: 0.9 + sp * 0.1),
            _fillingColor.withValues(alpha: 0.7 + sp * 0.3),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: fillingRadius))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, fillingRadius, fillingPaint);

      if (sp > 0.6) {
        final emergePaint = Paint()
          ..color = _fillingColor.withValues(alpha: (sp - 0.6) * 0.8)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, fillingRadius * 0.2);
        canvas.drawCircle(center, fillingRadius * 1.1, emergePaint);
      }
    }

    // Core highlight
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

    // Secondary highlight
    final hl2Offset = Offset(
      center.dx + radius * 0.15,
      center.dy - radius * 0.08,
    );
    final hl2Paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25 + sp * 0.15);
    canvas.drawCircle(hl2Offset, radius * 0.08, hl2Paint);

    // Squeeze pressure ring with glow
    if (sp > 0) {
      final pressurePaint = Paint()
        ..color = const Color(0xFFEF5350).withValues(alpha: sp * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 + sp * 2.5
        ..maskFilter = MaskFilter.blur(BlurStyle.outer, 2 + sp * 3);
      canvas.drawCircle(center, radius + 3 + sp * 5, pressurePaint);
    }

    // About to pop glow
    if (sp > 0.7) {
      final glowIntensity = (sp - 0.7) / 0.3;
      final glowPaint = Paint()
        ..color = _coreColor.withValues(alpha: glowIntensity * 0.8)
        ..maskFilter = MaskFilter.blur(
            BlurStyle.normal, radius * (0.4 + glowIntensity * 0.3));
      canvas.drawCircle(
          center, coreRadius * (1.3 + glowIntensity * 0.2), glowPaint);

      final redGlowPaint = Paint()
        ..color = const Color(0xFFFF5252).withValues(alpha: glowIntensity * 0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.5);
      canvas.drawCircle(center, radius * 1.1, redGlowPaint);
    }
  }

  Color get _baseColor {
    switch (type) {
      case _PimpleType.blackhead:
        return const Color(0xFFE8D5C4);
      default:
        return const Color(0xFFFFCDB2);
    }
  }

  Color get _ringColor {
    switch (type) {
      case _PimpleType.whitehead:
        return const Color(0xFFE8A090);
      case _PimpleType.reddish:
        return const Color(0xFFE57373);
      case _PimpleType.blackhead:
        return const Color(0xFFBCAA90);
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
      case _PimpleType.blackhead:
        return const Color(0xFF5D4E37);
      case _PimpleType.cyst:
        return const Color(0xFFE6D5A8);
    }
  }

  Color get _fillingColor {
    switch (type) {
      case _PimpleType.whitehead:
        return const Color(0xFFFFF9C4);
      case _PimpleType.reddish:
        return const Color(0xFFFFE082);
      case _PimpleType.blackhead:
        return const Color(0xFF8B7355);
      case _PimpleType.cyst:
        return const Color(0xFFD4C98A);
    }
  }

  @override
  bool shouldRepaint(_PimplePainter old) =>
      type != old.type || squeezeProgress != old.squeezeProgress;
}

// --- Splat Painter for irregular marks ---

class _SplatPainter extends CustomPainter {
  final Color color;
  final double irregularity;

  _SplatPainter({required this.color, required this.irregularity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final points = 8 + (irregularity * 6).round();
    for (int i = 0; i < points; i++) {
      final angle = (i / points) * 2 * pi;
      final pointRadius = radius * (0.6 + irregularity * 0.4 + (i % 3) * 0.15);
      final x = center.dx + cos(angle) * pointRadius;
      final y = center.dy + sin(angle) * pointRadius;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevAngle = ((i - 1) / points) * 2 * pi;
        final prevRadius = radius * (0.6 + irregularity * 0.4 + ((i - 1) % 3) * 0.15);
        final prevX = center.dx + cos(prevAngle) * prevRadius;
        final prevY = center.dy + sin(prevAngle) * prevRadius;
        final controlX = (prevX + x) / 2 + (irregularity - 0.5) * radius * 0.2;
        final controlY = (prevY + y) / 2 + (irregularity - 0.5) * radius * 0.2;
        path.quadraticBezierTo(controlX, controlY, x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SplatPainter old) =>
      color != old.color || irregularity != old.irregularity;
}