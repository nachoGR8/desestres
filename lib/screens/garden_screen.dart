import 'dart:math';
import 'package:flutter/material.dart';
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
    with SingleTickerProviderStateMixin {
  late AnimationController _waterCtrl;
  bool _showWaterDrop = false;

  @override
  void initState() {
    super.initState();
    _waterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _waterCtrl.dispose();
    super.dispose();
  }

  int get _waterCount => StorageService().getCounter('gardenWater');
  int get _daysWatered => StorageService().getCounter('gardenDaysWatered');

  // Growth stages based on total days watered
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
    SoundService().playSoftTone();
    setState(() => _showWaterDrop = true);
    _waterCtrl.forward(from: 0).then((_) {
      if (mounted) setState(() => _showWaterDrop = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final stage = _stage;
    final nextStage = _nextThreshold(stage);

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
                    // Stage label
                    Text(
                      stage.label,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.secondary,
                      ),
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: 8),
                    Text(
                      stage.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textHint,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Plant visualization
                    SizedBox(
                      height: 300,
                      width: double.infinity,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          // Ground
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    const Color(0xFF8B6914).withValues(alpha: 0.3),
                                    const Color(0xFF6B4E0A).withValues(alpha: 0.2),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Plant
                          Positioned(
                            bottom: 30,
                            child: CustomPaint(
                              size: const Size(200, 250),
                              painter: _PlantPainter(stage: stage),
                            ),
                          ),
                          // Water drop animation
                          if (_showWaterDrop)
                            AnimatedBuilder(
                              animation: _waterCtrl,
                              builder: (context, child) {
                                final t = _waterCtrl.value;
                                return Positioned(
                                  bottom: 30 + 200 * (1 - t),
                                  child: Opacity(
                                    opacity: (1 - t).clamp(0, 1),
                                    child: Text(
                                      '💧',
                                      style: TextStyle(fontSize: 24 + t * 10),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 600.ms).scale(
                          begin: const Offset(0.9, 0.9),
                          end: const Offset(1.0, 1.0),
                          duration: 600.ms,
                        ),
                    const SizedBox(height: 24),

                    // Progress to next stage
                    if (nextStage != null) ...[
                      Text(
                        'Siguiente etapa: ${nextStage.$1} ($_daysWatered/${nextStage.$2} días)',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
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
                      const SizedBox(height: 20),
                    ],

                    // Stats row
                    Row(
                      children: [
                        Expanded(
                          child: _infoTile('🌧️', '$_waterCount', 'Riegos'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _infoTile('📅', '$_daysWatered', 'Días'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _infoTile(
                              stage.emoji, stage.shortName, 'Etapa'),
                        ),
                      ],
                    ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                    const SizedBox(height: 24),

                    // Water button
                    GestureDetector(
                      onTap: _wateredToday ? null : _water,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          gradient: _wateredToday
                              ? LinearGradient(colors: [
                                  AppTheme.secondary.withValues(alpha: 0.3),
                                  AppTheme.secondary.withValues(alpha: 0.2),
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
                                    color: AppTheme.primary.withValues(alpha: 0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
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
                    const SizedBox(height: 12),

                    Text(
                      'Cada actividad en la app cuenta como riego automático.\nTambién puedes regar manualmente una vez al día.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textHint,
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

  Widget _infoTile(String emoji, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
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
  sprout('Brote', '🌱', 'Algo bonito está empezando', 'Brote'),
  seedling('Plantita', '🌿', 'Creciendo con cariño', 'Plantita'),
  plant('Planta', '🪴', 'Fuerte y hermosa', 'Planta'),
  flowering('Floreciendo', '🌸', '¡Han salido flores!', 'Flores'),
  tree('Árbol', '🌳', 'Un árbol que representa tu esfuerzo', 'Árbol');

  final String label;
  final String emoji;
  final String description;
  final String shortName;
  const _GrowthStage(this.label, this.emoji, this.description, this.shortName);
}

// --- Plant Painter ---

class _PlantPainter extends CustomPainter {
  final _GrowthStage stage;
  _PlantPainter({required this.stage});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final bottom = size.height;

    switch (stage) {
      case _GrowthStage.seed:
        _drawSeed(canvas, cx, bottom);
      case _GrowthStage.sprout:
        _drawSprout(canvas, cx, bottom);
      case _GrowthStage.seedling:
        _drawSeedling(canvas, cx, bottom);
      case _GrowthStage.plant:
        _drawPlant(canvas, cx, bottom);
      case _GrowthStage.flowering:
        _drawFlowering(canvas, cx, bottom);
      case _GrowthStage.tree:
        _drawTree(canvas, cx, bottom);
    }
  }

  void _drawSeed(Canvas canvas, double cx, double bottom) {
    final paint = Paint()..color = const Color(0xFF8B6914);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, bottom - 10), width: 24, height: 18),
      paint,
    );
    // Highlight
    final hl = Paint()
      ..color = const Color(0xFFBB9B40)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx - 3, bottom - 12), width: 8, height: 6),
      hl,
    );
  }

  void _drawSprout(Canvas canvas, double cx, double bottom) {
    // Stem
    final stem = Paint()
      ..color = const Color(0xFF6EBF5E)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final stemPath = Path();
    stemPath.moveTo(cx, bottom);
    stemPath.quadraticBezierTo(cx, bottom - 30, cx, bottom - 45);
    canvas.drawPath(stemPath, stem);

    // Two tiny leaves
    _drawLeaf(canvas, cx, bottom - 40, 12, -0.5, const Color(0xFF7FD66E));
    _drawLeaf(canvas, cx, bottom - 35, 10, 0.5, const Color(0xFF6EBF5E));
  }

  void _drawSeedling(Canvas canvas, double cx, double bottom) {
    // Stem
    final stem = Paint()
      ..color = const Color(0xFF5AAF4A)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final stemPath = Path();
    stemPath.moveTo(cx, bottom);
    stemPath.quadraticBezierTo(cx - 5, bottom - 50, cx, bottom - 80);
    canvas.drawPath(stemPath, stem);

    // Four leaves at intervals
    _drawLeaf(canvas, cx, bottom - 70, 20, -0.6, const Color(0xFF7FD66E));
    _drawLeaf(canvas, cx, bottom - 60, 18, 0.5, const Color(0xFF6EBF5E));
    _drawLeaf(canvas, cx, bottom - 45, 16, -0.4, const Color(0xFF8FE67E));
    _drawLeaf(canvas, cx, bottom - 35, 14, 0.6, const Color(0xFF6EBF5E));
  }

  void _drawPlant(Canvas canvas, double cx, double bottom) {
    // Main stem
    final stem = Paint()
      ..color = const Color(0xFF4A9A3A)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final stemPath = Path();
    stemPath.moveTo(cx, bottom);
    stemPath.cubicTo(cx - 8, bottom - 60, cx + 8, bottom - 100, cx, bottom - 130);
    canvas.drawPath(stemPath, stem);

    // Multiple leaves
    _drawLeaf(canvas, cx, bottom - 120, 28, -0.7, const Color(0xFF6EBF5E));
    _drawLeaf(canvas, cx, bottom - 110, 24, 0.6, const Color(0xFF7FD66E));
    _drawLeaf(canvas, cx, bottom - 90, 22, -0.5, const Color(0xFF8FE67E));
    _drawLeaf(canvas, cx, bottom - 80, 26, 0.7, const Color(0xFF6EBF5E));
    _drawLeaf(canvas, cx, bottom - 60, 20, -0.4, const Color(0xFF7FD66E));
    _drawLeaf(canvas, cx, bottom - 50, 22, 0.5, const Color(0xFF5AAF4A));
  }

  void _drawFlowering(Canvas canvas, double cx, double bottom) {
    _drawPlant(canvas, cx, bottom);

    // Flowers on top
    _drawFlower(canvas, cx - 15, bottom - 135, 10, const Color(0xFFFCA5A5));
    _drawFlower(canvas, cx + 18, bottom - 125, 8, const Color(0xFFA78BFA));
    _drawFlower(canvas, cx, bottom - 140, 12, const Color(0xFFFFD700));
    _drawFlower(canvas, cx - 20, bottom - 100, 7, const Color(0xFFB3D4FF));
    _drawFlower(canvas, cx + 22, bottom - 95, 9, const Color(0xFFFCA5A5));
  }

  void _drawTree(Canvas canvas, double cx, double bottom) {
    // Trunk
    final trunk = Paint()..color = const Color(0xFF8B6914);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, bottom - 55), width: 18, height: 110),
        const Radius.circular(4),
      ),
      trunk,
    );

    // Branches as subtle lines
    final branchPaint = Paint()
      ..color = const Color(0xFF6B4E0A)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(cx, bottom - 80), Offset(cx - 30, bottom - 110), branchPaint);
    canvas.drawLine(
        Offset(cx, bottom - 70), Offset(cx + 35, bottom - 100), branchPaint);

    // Foliage (overlapping circles)
    final foliage = Paint()..color = const Color(0xFF5AAF4A);
    final foliage2 = Paint()..color = const Color(0xFF6EBF5E);
    final foliage3 = Paint()..color = const Color(0xFF7FD66E);
    canvas.drawCircle(Offset(cx, bottom - 150), 40, foliage);
    canvas.drawCircle(Offset(cx - 30, bottom - 130), 32, foliage2);
    canvas.drawCircle(Offset(cx + 30, bottom - 130), 32, foliage2);
    canvas.drawCircle(Offset(cx - 15, bottom - 165), 28, foliage3);
    canvas.drawCircle(Offset(cx + 15, bottom - 165), 28, foliage3);
    canvas.drawCircle(Offset(cx, bottom - 175), 24, foliage);

    // Flowers scattered
    _drawFlower(canvas, cx - 20, bottom - 160, 7, const Color(0xFFFCA5A5));
    _drawFlower(canvas, cx + 15, bottom - 170, 6, const Color(0xFFFFD700));
    _drawFlower(canvas, cx + 25, bottom - 140, 7, const Color(0xFFA78BFA));
    _drawFlower(canvas, cx - 30, bottom - 135, 6, const Color(0xFFB3D4FF));
    _drawFlower(canvas, cx, bottom - 180, 8, const Color(0xFFFCA5A5));
    _drawFlower(canvas, cx - 10, bottom - 145, 5, const Color(0xFFFFD700));
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
  }

  void _drawFlower(
      Canvas canvas, double x, double y, double size, Color color) {
    final petalPaint = Paint()..color = color;
    final centerPaint = Paint()..color = const Color(0xFFFFE082);

    for (int i = 0; i < 5; i++) {
      final angle = i * 2 * pi / 5;
      canvas.drawCircle(
        Offset(x + cos(angle) * size * 0.5, y + sin(angle) * size * 0.5),
        size * 0.45,
        petalPaint,
      );
    }
    canvas.drawCircle(Offset(x, y), size * 0.3, centerPaint);
  }

  @override
  bool shouldRepaint(_PlantPainter old) => stage != old.stage;
}
