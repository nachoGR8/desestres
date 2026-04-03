import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../services/sound_service.dart';

class GardenScreen extends StatefulWidget {
  const GardenScreen({super.key});

  @override
  State<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends State<GardenScreen>
    with TickerProviderStateMixin {
  late AnimationController _waterCtrl;
  late AnimationController _swayCtrl;
  late AnimationController _sparkleCtrl;
  bool _showWaterDrop = false;
  bool _justWatered = false;

  // Floating water droplets for watering animation
  final List<_WaterDrop> _waterDrops = [];

  @override
  void initState() {
    super.initState();
    _waterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _swayCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);
    _sparkleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _waterCtrl.dispose();
    _swayCtrl.dispose();
    _sparkleCtrl.dispose();
    super.dispose();
  }

  int get _waterCount => StorageService().getCounter('gardenWater');
  int get _daysWatered => StorageService().getCounter('gardenDaysWatered');

  _GrowthStage get _stage {
    final d = _daysWatered;
    if (d < 1) return _GrowthStage.seed;
    if (d < 3) return _GrowthStage.sprout;
    if (d < 7) return _GrowthStage.seedling;
    if (d < 14) return _GrowthStage.plant;
    if (d < 30) return _GrowthStage.flowering;
    return _GrowthStage.tree;
  }

  bool get _wateredToday {
    final lastWater = StorageService().getLastGardenWaterDate();
    if (lastWater == null) return false;
    final now = DateTime.now();
    return lastWater.year == now.year &&
        lastWater.month == now.month &&
        lastWater.day == now.day;
  }

  Future<void> _water() async {
    if (_wateredToday) return;
    await StorageService().waterGarden();
    SoundService().playBell();
    HapticFeedback.mediumImpact();

    // Spawn multiple water drops
    final rng = Random();
    _waterDrops.clear();
    for (int i = 0; i < 8; i++) {
      _waterDrops.add(_WaterDrop(
        x: 0.3 + rng.nextDouble() * 0.4,
        delay: i * 0.08,
        speed: 0.7 + rng.nextDouble() * 0.5,
        size: 14 + rng.nextDouble() * 10,
      ));
    }

    setState(() {
      _showWaterDrop = true;
      _justWatered = true;
    });
    _waterCtrl.forward(from: 0).then((_) {
      if (mounted) {
        setState(() => _showWaterDrop = false);
        // Delayed sparkle after watering
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) SoundService().playChime();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final stage = _stage;
    final nextStage = _nextThreshold(stage);
    final screenW = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: Theme.of(context).iconTheme.color,
                  ),
                  Expanded(
                    child: Text(
                      'Mi Jardín',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Stage label with emoji
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(stage.emoji, style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 10),
                        Text(
                          stage.label,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.secondary,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: 6),
                    Text(
                      stage.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textHint,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Plant visualization with sky/background
                    Container(
                      height: 340,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _skyTopColor(stage),
                            _skyBottomColor(stage),
                          ],
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_swayCtrl, _sparkleCtrl]),
                          builder: (context, _) {
                            final sway = _swayCtrl.value;
                            return Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                // Background particles (fireflies/sparkles)
                                if (stage.index >= _GrowthStage.plant.index)
                                  ..._buildSparkles(stage),

                                // Sun/moon
                                Positioned(
                                  top: 20,
                                  right: 30,
                                  child: _buildSun(stage),
                                ),

                                // Clouds
                                if (stage.index >= _GrowthStage.seedling.index)
                                  ..._buildClouds(sway),

                                // Ground layers
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: CustomPaint(
                                    size: Size(screenW, 80),
                                    painter: _GroundPainter(stage: stage),
                                  ),
                                ),

                                // Plant with sway
                                Positioned(
                                  bottom: 40,
                                  child: Transform(
                                    alignment: Alignment.bottomCenter,
                                    transform: Matrix4.identity()
                                      ..rotateZ(sin(sway * 2 * pi) * 0.015),
                                    child: CustomPaint(
                                      size: const Size(220, 260),
                                      painter: _PlantPainter(
                                        stage: stage,
                                        sway: sway,
                                        justWatered: _justWatered,
                                      ),
                                    ),
                                  ),
                                ),

                                // Water drops falling
                                if (_showWaterDrop)
                                  ..._buildWaterDrops(),

                                // Watered sparkle burst
                                if (_justWatered && !_showWaterDrop)
                                  ..._buildWateredSparkles(),
                              ],
                            );
                          },
                        ),
                      ),
                    ).animate().fadeIn(duration: 600.ms).scale(
                          begin: const Offset(0.95, 0.95),
                          end: const Offset(1.0, 1.0),
                          duration: 600.ms,
                          curve: Curves.easeOut,
                        ),
                    const SizedBox(height: 20),

                    // Progress to next stage
                    if (nextStage != null) ...[
                      Row(
                        children: [
                          Text(
                            'Próxima etapa: ',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textHint,
                            ),
                          ),
                          Text(
                            nextStage.$1,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.secondary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$_daysWatered/${nextStage.$2} días',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (_daysWatered / nextStage.$2).clamp(0, 1),
                          minHeight: 8,
                          backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                          color: AppTheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Stats row
                    Row(
                      children: [
                        Expanded(
                          child: _infoTile(
                            '🌧️',
                            '$_waterCount',
                            'Riegos',
                            const Color(0xFF5B9CF6),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _infoTile(
                            '📅',
                            '$_daysWatered',
                            'Días',
                            const Color(0xFF6EE7B7),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _infoTile(
                            stage.emoji,
                            stage.shortName,
                            'Etapa',
                            AppTheme.secondary,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                    const SizedBox(height: 20),

                    // Water button
                    GestureDetector(
                      onTap: _wateredToday ? null : _water,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          gradient: _wateredToday
                              ? LinearGradient(colors: [
                                  AppTheme.secondary.withValues(alpha: 0.2),
                                  AppTheme.secondary.withValues(alpha: 0.15),
                                ])
                              : const LinearGradient(colors: [
                                  Color(0xFF5B9CF6),
                                  Color(0xFF6EE7B7),
                                ]),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: _wateredToday
                              ? []
                              : [
                                  BoxShadow(
                                    color: const Color(0xFF5B9CF6)
                                        .withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _wateredToday ? '✅' : '💧',
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _wateredToday
                                  ? 'Regado hoy — ¡vuelve mañana!'
                                  : 'Regar mi planta',
                              style: TextStyle(
                                color: _wateredToday
                                    ? AppTheme.textHint
                                    : Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
                    const SizedBox(height: 10),

                    Text(
                      'Cada actividad en la app riega automáticamente.\nTambién puedes regar manualmente una vez al día.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textHint,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Sky colors based on growth ---
  Color _skyTopColor(_GrowthStage stage) {
    switch (stage) {
      case _GrowthStage.seed:
        return const Color(0xFF2D3748).withValues(alpha: 0.6);
      case _GrowthStage.sprout:
        return const Color(0xFF4A6FA5).withValues(alpha: 0.5);
      case _GrowthStage.seedling:
        return const Color(0xFF87CEEB).withValues(alpha: 0.4);
      case _GrowthStage.plant:
        return const Color(0xFF87CEEB).withValues(alpha: 0.45);
      case _GrowthStage.flowering:
        return const Color(0xFFFDB99B).withValues(alpha: 0.4);
      case _GrowthStage.tree:
        return const Color(0xFF87CEEB).withValues(alpha: 0.5);
    }
  }

  Color _skyBottomColor(_GrowthStage stage) {
    switch (stage) {
      case _GrowthStage.seed:
      case _GrowthStage.sprout:
        return const Color(0xFF3A2D1F).withValues(alpha: 0.3);
      case _GrowthStage.seedling:
      case _GrowthStage.plant:
        return const Color(0xFFD4E4C8).withValues(alpha: 0.3);
      case _GrowthStage.flowering:
        return const Color(0xFFFFE4D6).withValues(alpha: 0.3);
      case _GrowthStage.tree:
        return const Color(0xFFD4E4C8).withValues(alpha: 0.35);
    }
  }

  Widget _buildSun(_GrowthStage stage) {
    final color = stage == _GrowthStage.flowering
        ? const Color(0xFFFFB347)
        : const Color(0xFFFFE082);
    final size = stage.index >= _GrowthStage.plant.index ? 36.0 : 28.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.7),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildClouds(double sway) {
    return [
      Positioned(
        top: 25,
        left: 20 + sway * 15,
        child: Opacity(
          opacity: 0.25,
          child: Container(
            width: 60,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      Positioned(
        top: 45,
        left: 100 + sway * 10,
        child: Opacity(
          opacity: 0.18,
          child: Container(
            width: 40,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildSparkles(_GrowthStage stage) {
    final t = _sparkleCtrl.value;
    final rng = Random(7);
    final count = stage == _GrowthStage.tree ? 8 : 4;
    return List.generate(count, (i) {
      final phase = rng.nextDouble();
      final x = 20 + rng.nextDouble() * 180;
      final y = 30 + rng.nextDouble() * 200;
      final alpha = (sin((t + phase) * 2 * pi) * 0.5 + 0.5) * 0.4;
      final s = 3.0 + rng.nextDouble() * 2;
      return Positioned(
        left: x,
        top: y,
        child: Opacity(
          opacity: alpha.clamp(0.0, 1.0),
          child: Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: stage == _GrowthStage.flowering
                  ? const Color(0xFFFFD700)
                  : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: (stage == _GrowthStage.flowering
                          ? const Color(0xFFFFD700)
                          : Colors.white)
                      .withValues(alpha: 0.5),
                  blurRadius: s * 2,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  List<Widget> _buildWaterDrops() {
    return _waterDrops.map((drop) {
      return AnimatedBuilder(
        animation: _waterCtrl,
        builder: (context, _) {
          final t = _waterCtrl.value;
          final dropT = ((t - drop.delay) / drop.speed).clamp(0.0, 1.0);
          if (dropT <= 0) return const SizedBox.shrink();
          final y = dropT * 300;
          final opacity = (1.0 - dropT * 1.2).clamp(0.0, 1.0);
          final screenW = MediaQuery.of(context).size.width - 48;
          return Positioned(
            left: drop.x * screenW,
            top: y,
            child: Opacity(
              opacity: opacity,
              child: Text(
                '💧',
                style: TextStyle(fontSize: drop.size),
              ),
            ),
          );
        },
      );
    }).toList();
  }

  List<Widget> _buildWateredSparkles() {
    final rng = Random(42);
    return List.generate(6, (i) {
      final angle = i * (2 * pi / 6);
      final dist = 30 + rng.nextDouble() * 30;
      final screenW = MediaQuery.of(context).size.width - 48;
      return Positioned(
        left: screenW / 2 + cos(angle) * dist - 6,
        bottom: 80 + sin(angle) * dist * 0.5,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 800 + i * 100),
          builder: (context, t, _) {
            return Opacity(
              opacity: (1.0 - t).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, -t * 20),
                child: const Text('✨', style: TextStyle(fontSize: 14)),
              ),
            );
          },
        ),
      );
    });
  }

  (String, int)? _nextThreshold(_GrowthStage stage) {
    switch (stage) {
      case _GrowthStage.seed:
        return ('Brote', 1);
      case _GrowthStage.sprout:
        return ('Plantita', 3);
      case _GrowthStage.seedling:
        return ('Planta', 7);
      case _GrowthStage.plant:
        return ('Floreciendo', 14);
      case _GrowthStage.flowering:
        return ('Árbol', 30);
      case _GrowthStage.tree:
        return null;
    }
  }

  Widget _infoTile(String emoji, String value, String label, Color accent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Growth Stages ---

enum _GrowthStage {
  seed('Semilla', '🌰', 'Una semilla llena de potencial', 'Semilla'),
  sprout('Brote', '🌱', 'Algo bonito está empezando a crecer', 'Brote'),
  seedling('Plantita', '🌿', 'Creciendo con cariño cada día', 'Plantita'),
  plant('Planta', '🪴', 'Fuerte y hermosa, como tú', 'Planta'),
  flowering('Floreciendo', '🌸', '¡Han salido flores preciosas!', 'Flores'),
  tree('Árbol', '🌳', 'Un árbol que representa tu esfuerzo', 'Árbol');

  final String label;
  final String emoji;
  final String description;
  final String shortName;
  const _GrowthStage(this.label, this.emoji, this.description, this.shortName);
}

class _WaterDrop {
  final double x;
  final double delay;
  final double speed;
  final double size;
  _WaterDrop({
    required this.x,
    required this.delay,
    required this.speed,
    required this.size,
  });
}

// --- Ground Painter ---

class _GroundPainter extends CustomPainter {
  final _GrowthStage stage;
  _GroundPainter({required this.stage});

  @override
  void paint(Canvas canvas, Size size) {
    // Main soil mound
    final soilPath = Path();
    soilPath.moveTo(0, size.height);
    soilPath.lineTo(0, size.height * 0.5);
    soilPath.quadraticBezierTo(
      size.width * 0.25, size.height * 0.15,
      size.width * 0.5, size.height * 0.1,
    );
    soilPath.quadraticBezierTo(
      size.width * 0.75, size.height * 0.15,
      size.width, size.height * 0.5,
    );
    soilPath.lineTo(size.width, size.height);
    soilPath.close();

    // Rich soil gradient
    final soilPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF8B6914).withValues(alpha: 0.5),
          const Color(0xFF6B4E0A).withValues(alpha: 0.4),
          const Color(0xFF4A3508).withValues(alpha: 0.3),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(soilPath, soilPaint);

    // Grass blades for plant+ stages
    if (stage.index >= _GrowthStage.seedling.index) {
      final grassPaint = Paint()
        ..color = const Color(0xFF6EBF5E).withValues(alpha: 0.5)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final rng = Random(33);
      for (int i = 0; i < 12; i++) {
        final x = rng.nextDouble() * size.width;
        final h = 6 + rng.nextDouble() * 10;
        final bend = (rng.nextDouble() - 0.5) * 6;
        final path = Path();
        path.moveTo(x, size.height * 0.35);
        path.quadraticBezierTo(
          x + bend, size.height * 0.35 - h / 2,
          x + bend * 1.5, size.height * 0.35 - h,
        );
        canvas.drawPath(path, grassPaint);
      }
    }

    // Small soil texture dots
    final dotPaint = Paint()
      ..color = const Color(0xFF5A3D0A).withValues(alpha: 0.2);
    final rng = Random(99);
    for (int i = 0; i < 20; i++) {
      final x = rng.nextDouble() * size.width;
      final y = size.height * 0.4 + rng.nextDouble() * size.height * 0.5;
      canvas.drawCircle(Offset(x, y), 1.5 + rng.nextDouble(), dotPaint);
    }
  }

  @override
  bool shouldRepaint(_GroundPainter old) => stage != old.stage;
}

// --- Plant Painter ---

class _PlantPainter extends CustomPainter {
  final _GrowthStage stage;
  final double sway;
  final bool justWatered;
  _PlantPainter({
    required this.stage,
    required this.sway,
    this.justWatered = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final bottom = size.height;

    switch (stage) {
      case _GrowthStage.seed:
        _drawSeed(canvas, cx, bottom);
      case _GrowthStage.sprout:
        _drawSprout(canvas, cx, bottom, sway);
      case _GrowthStage.seedling:
        _drawSeedling(canvas, cx, bottom, sway);
      case _GrowthStage.plant:
        _drawPlant(canvas, cx, bottom, sway);
      case _GrowthStage.flowering:
        _drawFlowering(canvas, cx, bottom, sway);
      case _GrowthStage.tree:
        _drawTree(canvas, cx, bottom, sway);
    }
  }

  void _drawSeed(Canvas canvas, double cx, double bottom) {
    // Seed shadow
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, bottom - 4), width: 30, height: 8),
      shadow,
    );

    // Seed body
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: [
          const Color(0xFFBB9B40),
          const Color(0xFF8B6914),
          const Color(0xFF6B4E0A),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(
        Rect.fromCenter(center: Offset(cx, bottom - 12), width: 28, height: 22),
      );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, bottom - 12), width: 28, height: 22),
      paint,
    );

    // Highlight
    final hl = Paint()
      ..color = const Color(0xFFE0CA70).withValues(alpha: 0.6);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 4, bottom - 15), width: 8, height: 6),
      hl,
    );

    // Tiny crack indicating life
    final crack = Paint()
      ..color = const Color(0xFF6EBF5E).withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx, bottom - 20),
      Offset(cx + 1, bottom - 25),
      crack,
    );
  }

  void _drawSprout(Canvas canvas, double cx, double bottom, double sway) {
    // Stem with sway
    final bendX = sin(sway * 2 * pi) * 3;
    final stem = Paint()
      ..color = const Color(0xFF6EBF5E)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final stemPath = Path();
    stemPath.moveTo(cx, bottom);
    stemPath.quadraticBezierTo(cx + bendX, bottom - 30, cx + bendX * 0.5, bottom - 50);
    canvas.drawPath(stemPath, stem);

    // Two tiny leaves with sway
    _drawLeaf(canvas, cx + bendX * 0.5, bottom - 45, 14, -0.5 + sway * 0.2,
        const Color(0xFF7FD66E));
    _drawLeaf(canvas, cx + bendX * 0.5, bottom - 38, 11, 0.5 - sway * 0.15,
        const Color(0xFF6EBF5E));

    // Dewdrop on leaf
    if (justWatered) {
      final dew = Paint()
        ..color = const Color(0xFF87CEEB).withValues(alpha: 0.6);
      canvas.drawCircle(Offset(cx + bendX * 0.5 - 10, bottom - 47), 2.5, dew);
    }
  }

  void _drawSeedling(Canvas canvas, double cx, double bottom, double sway) {
    final bendX = sin(sway * 2 * pi) * 5;
    // Main stem
    final stem = Paint()
      ..color = const Color(0xFF5AAF4A)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final stemPath = Path();
    stemPath.moveTo(cx, bottom);
    stemPath.quadraticBezierTo(
        cx - 5 + bendX, bottom - 50, cx + bendX * 0.5, bottom - 85);
    canvas.drawPath(stemPath, stem);

    // Leaves at intervals, each swaying slightly differently
    _drawLeaf(canvas, cx + bendX * 0.5, bottom - 75, 22,
        -0.6 + sway * 0.3, const Color(0xFF7FD66E));
    _drawLeaf(canvas, cx + bendX * 0.5, bottom - 63, 18,
        0.5 - sway * 0.25, const Color(0xFF6EBF5E));
    _drawLeaf(canvas, cx + bendX * 0.3, bottom - 48, 16,
        -0.4 + sway * 0.2, const Color(0xFF8FE67E));
    _drawLeaf(canvas, cx + bendX * 0.2, bottom - 36, 14,
        0.6 - sway * 0.2, const Color(0xFF6EBF5E));

    // Leaf veins on the biggest leaf
    final vein = Paint()
      ..color = const Color(0xFF4A9A3A).withValues(alpha: 0.3)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(cx + bendX * 0.5 - 3, bottom - 75),
      Offset(cx + bendX * 0.5 - 18, bottom - 72),
      vein,
    );
  }

  void _drawPlant(Canvas canvas, double cx, double bottom, double sway) {
    final bendX = sin(sway * 2 * pi) * 6;

    // Main stem with slight curve
    final stem = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFF4A9A3A),
          const Color(0xFF5AAF4A),
        ],
      ).createShader(Rect.fromLTWH(cx - 3, bottom - 140, 6, 140))
      ..strokeWidth = 5.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final stemPath = Path();
    stemPath.moveTo(cx, bottom);
    stemPath.cubicTo(cx - 8 + bendX, bottom - 60,
        cx + 8 + bendX * 0.5, bottom - 100, cx + bendX * 0.3, bottom - 135);
    canvas.drawPath(stemPath, stem);

    // Multiple leaves with gradient feel
    final leafPositions = [
      (bottom - 125.0, 28.0, -0.7, const Color(0xFF6EBF5E)),
      (bottom - 112.0, 24.0, 0.6, const Color(0xFF7FD66E)),
      (bottom - 95.0, 22.0, -0.5, const Color(0xFF8FE67E)),
      (bottom - 82.0, 26.0, 0.7, const Color(0xFF6EBF5E)),
      (bottom - 62.0, 20.0, -0.4, const Color(0xFF7FD66E)),
      (bottom - 50.0, 22.0, 0.5, const Color(0xFF5AAF4A)),
    ];
    for (final (y, size, dir, color) in leafPositions) {
      _drawLeaf(canvas, cx + bendX * 0.3, y, size,
          dir + sway * 0.2 * dir.sign, color);
    }
  }

  void _drawFlowering(Canvas canvas, double cx, double bottom, double sway) {
    _drawPlant(canvas, cx, bottom, sway);

    final bendX = sin(sway * 2 * pi) * 6;
    // Flowers with petal detail
    _drawFlower(canvas, cx - 15 + bendX * 0.3, bottom - 142, 12,
        const Color(0xFFFCA5A5), sway);
    _drawFlower(canvas, cx + 18 + bendX * 0.2, bottom - 130, 10,
        const Color(0xFFA78BFA), sway);
    _drawFlower(canvas, cx + bendX * 0.3, bottom - 148, 14,
        const Color(0xFFFFD700), sway);
    _drawFlower(canvas, cx - 20 + bendX * 0.2, bottom - 105, 8,
        const Color(0xFFB3D4FF), sway);
    _drawFlower(canvas, cx + 22 + bendX * 0.1, bottom - 100, 9,
        const Color(0xFFFCA5A5), sway);

    // Butterfly near the flowers
    _drawButterfly(canvas, cx + 35 + sin(sway * 2 * pi) * 15,
        bottom - 155 + cos(sway * 2 * pi) * 8, sway);
  }

  void _drawTree(Canvas canvas, double cx, double bottom, double sway) {
    final bendX = sin(sway * 2 * pi) * 3;

    // Trunk with bark texture
    final trunk = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0xFF6B4E0A),
          const Color(0xFF8B6914),
          const Color(0xFF7B5E12),
        ],
      ).createShader(Rect.fromCenter(
          center: Offset(cx, bottom - 55), width: 22, height: 120));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, bottom - 55), width: 20, height: 115),
        const Radius.circular(5),
      ),
      trunk,
    );

    // Bark lines
    final barkPaint = Paint()
      ..color = const Color(0xFF4A3508).withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 5; i++) {
      final y = bottom - 20 - i * 20.0;
      canvas.drawLine(
        Offset(cx - 8 + i % 2 * 3, y),
        Offset(cx + 5 - i % 2 * 3, y + 8),
        barkPaint,
      );
    }

    // Branches
    final branchPaint = Paint()
      ..color = const Color(0xFF6B4E0A)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx, bottom - 85),
      Offset(cx - 35 + bendX, bottom - 118),
      branchPaint,
    );
    canvas.drawLine(
      Offset(cx, bottom - 75),
      Offset(cx + 40 + bendX, bottom - 108),
      branchPaint,
    );

    // Foliage with layered depth
    final foliageColors = [
      const Color(0xFF4A9A3A),
      const Color(0xFF5AAF4A),
      const Color(0xFF6EBF5E),
      const Color(0xFF7FD66E),
    ];
    final foliagePositions = [
      (cx - 30.0 + bendX, bottom - 135.0, 34.0, 0),
      (cx + 30.0 + bendX, bottom - 135.0, 34.0, 1),
      (cx + bendX * 0.5, bottom - 155.0, 42.0, 2),
      (cx - 18.0 + bendX, bottom - 170.0, 30.0, 3),
      (cx + 18.0 + bendX, bottom - 170.0, 30.0, 2),
      (cx + bendX * 0.3, bottom - 182.0, 26.0, 1),
    ];
    for (final (x, y, r, ci) in foliagePositions) {
      final paint = Paint()..color = foliageColors[ci];
      canvas.drawCircle(Offset(x, y), r, paint);
    }

    // Foliage highlight
    final hlPaint = Paint()
      ..color = const Color(0xFF8FE67E).withValues(alpha: 0.3);
    canvas.drawCircle(Offset(cx - 10 + bendX, bottom - 170), 15, hlPaint);

    // Flowers/fruits
    _drawFlower(canvas, cx - 22 + bendX, bottom - 165, 7,
        const Color(0xFFFCA5A5), sway);
    _drawFlower(canvas, cx + 15 + bendX, bottom - 175, 6,
        const Color(0xFFFFD700), sway);
    _drawFlower(canvas, cx + 28 + bendX, bottom - 145, 7,
        const Color(0xFFA78BFA), sway);
    _drawFlower(canvas, cx - 32 + bendX, bottom - 140, 6,
        const Color(0xFFB3D4FF), sway);
    _drawFlower(canvas, cx + bendX, bottom - 185, 8,
        const Color(0xFFFCA5A5), sway);
    _drawFlower(canvas, cx - 10 + bendX, bottom - 150, 5,
        const Color(0xFFFFD700), sway);

    // Falling petals / leaves
    final rng = Random(12);
    for (int i = 0; i < 3; i++) {
      final px = cx - 40 + rng.nextDouble() * 80 + bendX;
      final py = bottom - 100 + rng.nextDouble() * 40;
      final petalPaint = Paint()
        ..color = const Color(0xFFFCA5A5).withValues(alpha: 0.3);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(px, py), width: 4, height: 3),
        petalPaint,
      );
    }

    // Butterfly
    _drawButterfly(canvas, cx + 50 + sin(sway * 2 * pi) * 20,
        bottom - 190 + cos(sway * 2 * pi) * 10, sway);
  }

  void _drawLeaf(Canvas canvas, double cx, double y, double size,
      double direction, Color color) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(cx, y);
    path.quadraticBezierTo(
      cx + size * direction * 1.5,
      y - size * 0.5,
      cx + size * direction * 2,
      y + size * 0.2,
    );
    path.quadraticBezierTo(
      cx + size * direction * 1.5,
      y + size * 0.7,
      cx,
      y,
    );
    canvas.drawPath(path, paint);

    // Leaf vein
    final vein = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(cx, y),
      Offset(cx + size * direction * 1.3, y + size * 0.1),
      vein,
    );
  }

  void _drawFlower(Canvas canvas, double x, double y, double size,
      Color color, double sway) {
    // Gentle sway per flower
    final fx = x + sin(sway * 2 * pi + x) * 2;

    final petalPaint = Paint()..color = color;
    final petalHighlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.2);
    final centerPaint = Paint()..color = const Color(0xFFFFE082);

    for (int i = 0; i < 5; i++) {
      final angle = i * 2 * pi / 5 + sway * 0.3;
      final petalX = fx + cos(angle) * size * 0.55;
      final petalY = y + sin(angle) * size * 0.55;
      canvas.drawCircle(Offset(petalX, petalY), size * 0.42, petalPaint);
      // Petal highlight
      canvas.drawCircle(
        Offset(petalX - size * 0.1, petalY - size * 0.1),
        size * 0.15,
        petalHighlight,
      );
    }
    canvas.drawCircle(Offset(fx, y), size * 0.28, centerPaint);

    // Center detail
    final centerDot = Paint()
      ..color = const Color(0xFFFFB300).withValues(alpha: 0.5);
    canvas.drawCircle(Offset(fx - 1, y - 1), size * 0.12, centerDot);
  }

  void _drawButterfly(Canvas canvas, double x, double y, double sway) {
    final wingFlap = sin(sway * 4 * pi) * 0.3;
    final wingPaint = Paint()
      ..color = const Color(0xFFA78BFA).withValues(alpha: 0.7);
    final wingPaint2 = Paint()
      ..color = const Color(0xFFFCA5A5).withValues(alpha: 0.6);

    // Left wing
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(wingFlap);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-6, 0), width: 10, height: 6),
      wingPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-5, 3), width: 7, height: 4),
      wingPaint2,
    );
    canvas.restore();

    // Right wing
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(-wingFlap);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(6, 0), width: 10, height: 6),
      wingPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(5, 3), width: 7, height: 4),
      wingPaint2,
    );
    canvas.restore();

    // Body
    final body = Paint()
      ..color = const Color(0xFF4A3508).withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(x, y - 3), Offset(x, y + 4), body);
  }

  @override
  bool shouldRepaint(_PlantPainter old) =>
      stage != old.stage || sway != old.sway || justWatered != old.justWatered;
}
