import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../services/storage_service.dart';
import '../../services/sound_service.dart';

// --- Mandala pattern definitions ---

class _MandalaPattern {
  final String name;
  final String emoji;
  final String hint;
  final int rings;
  final int sectors;
  final int symmetry;
  final bool hasAlternatingRings;
  final bool hasPetals;
  final bool hasDots;

  const _MandalaPattern({
    required this.name,
    required this.emoji,
    required this.hint,
    required this.rings,
    required this.sectors,
    required this.symmetry,
    this.hasAlternatingRings = false,
    this.hasPetals = false,
    this.hasDots = false,
  });

  int get sectorsPerUnit => sectors ~/ symmetry;
}

const _patterns = [
  _MandalaPattern(
    name: 'Loto',
    emoji: '🪷',
    hint: 'Sencillo y suave',
    rings: 3,
    sectors: 12,
    symmetry: 6,
    hasPetals: true,
  ),
  _MandalaPattern(
    name: 'Estrella',
    emoji: '⭐',
    hint: 'Simetría estelar',
    rings: 4,
    sectors: 16,
    symmetry: 8,
    hasDots: true,
  ),
  _MandalaPattern(
    name: 'Flor',
    emoji: '🌸',
    hint: 'Pétalos y armonía',
    rings: 5,
    sectors: 24,
    symmetry: 6,
    hasPetals: true,
    hasAlternatingRings: true,
  ),
  _MandalaPattern(
    name: 'Sol',
    emoji: '☀️',
    hint: 'Rayos de calma',
    rings: 5,
    sectors: 24,
    symmetry: 12,
    hasDots: true,
  ),
  _MandalaPattern(
    name: 'Cosmos',
    emoji: '🌙',
    hint: 'Espiral profunda',
    rings: 6,
    sectors: 32,
    symmetry: 8,
    hasPetals: true,
    hasAlternatingRings: true,
  ),
  _MandalaPattern(
    name: 'Infinito',
    emoji: '✨',
    hint: 'Meditación total',
    rings: 7,
    sectors: 36,
    symmetry: 6,
    hasPetals: true,
    hasDots: true,
    hasAlternatingRings: true,
  ),
];

// --- Game widget ---

class MandalaGame extends StatefulWidget {
  const MandalaGame({super.key});

  @override
  State<MandalaGame> createState() => _MandalaGameState();
}

class _MandalaGameState extends State<MandalaGame>
    with SingleTickerProviderStateMixin {
  int _currentLevel = 0;
  bool _choosingLevel = true;
  bool _completed = false;

  late List<List<int>> _colors;
  int _centerColor = -1;
  int _selectedColorIndex = 0;
  bool _hasColored = false;

  AnimationController? _completionController;

  static const _palette = [
    Color(0xFF5B9CF6),
    Color(0xFFA78BFA),
    Color(0xFF6EE7B7),
    Color(0xFFFCA5A5),
    Color(0xFFFDE68A),
    Color(0xFF7DD3FC),
    Color(0xFFC4B5FD),
    Color(0xFFFFB4A2),
  ];

  _MandalaPattern get _pattern => _patterns[_currentLevel];

  @override
  void initState() {
    super.initState();
    _initGrid();
  }

  void _initGrid() {
    _colors = List.generate(_pattern.rings, (_) => List.filled(_pattern.sectors, -1));
    _centerColor = -1;
    _hasColored = false;
    _completed = false;
    _completionController?.dispose();
    _completionController = null;
  }

  void _selectLevel(int index) {
    setState(() {
      _currentLevel = index;
      _choosingLevel = false;
      _initGrid();
    });
  }

  void _checkCompletion() {
    final allFilled = _centerColor >= 0 &&
        _colors.every((ring) => ring.every((c) => c >= 0));
    if (allFilled && !_completed) {
      _completed = true;
      _completionController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      )..forward();
      HapticFeedback.mediumImpact();
      SoundService().playChime();
    }
  }

  void _tapCell(int ring, int sector) {
    if (_completed) return;
    HapticFeedback.lightImpact();
    SoundService().playClick();
    setState(() {
      _hasColored = true;
      if (ring == -1) {
        _centerColor = _selectedColorIndex;
        _checkCompletion();
        return;
      }
      final unitSector = sector % _pattern.sectorsPerUnit;
      for (int k = 0; k < _pattern.symmetry; k++) {
        _colors[ring][(unitSector + k * _pattern.sectorsPerUnit) % _pattern.sectors] =
            _selectedColorIndex;
      }
      _checkCompletion();
    });
  }

  void _clear() {
    setState(_initGrid);
  }

  void _nextLevel() {
    if (_currentLevel < _patterns.length - 1) {
      setState(() {
        _currentLevel++;
        _initGrid();
      });
    } else {
      setState(() {
        _choosingLevel = true;
        _initGrid();
      });
    }
  }

  void _handleTap(Offset pos, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;
    final ringW = maxR / (_pattern.rings + 1);

    final dx = pos.dx - center.dx;
    final dy = pos.dy - center.dy;
    final dist = sqrt(dx * dx + dy * dy);

    if (dist > maxR) return;

    if (dist < ringW) {
      _tapCell(-1, 0);
      return;
    }

    final ring = ((dist - ringW) / ringW).floor();
    if (ring >= _pattern.rings) return;

    var angle = atan2(dy, dx);
    if (angle < 0) angle += 2 * pi;
    final sector = (angle / (2 * pi) * _pattern.sectors).floor() % _pattern.sectors;

    _tapCell(ring, sector);
  }

  Future<void> _exit() async {
    if (_hasColored) {
      await StorageService().incrementCounter('totalMandalas');
      await StorageService().discoverGame('mandala');
      await StorageService().recordActivity();
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _completionController?.dispose();
    super.dispose();
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: _choosingLevel ? _buildLevelSelector() : _buildCanvas(),
      ),
    );
  }

  Widget _buildLevelSelector() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: _exit,
                icon: const Icon(Icons.arrow_back_rounded),
                color: Theme.of(context).iconTheme.color,
              ),
              Expanded(
                child: Text(
                  'Mandala',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Elige un mandala y relájate pintando 🤍',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GridView.builder(
              itemCount: _patterns.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemBuilder: (context, index) {
                final p = _patterns[index];
                return GestureDetector(
                  onTap: () => _selectLevel(index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Mini preview
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CustomPaint(
                            painter: _MandalaPainter(
                              colors: List.generate(
                                p.rings,
                                (_) => List.filled(p.sectors, -1),
                              ),
                              centerColor: -1,
                              palette: _palette,
                              rings: p.rings,
                              sectors: p.sectors,
                              surfaceColor: Theme.of(context).colorScheme.surface,
                              pattern: p,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${p.emoji} ${p.name}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.hint,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCanvas() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _choosingLevel = true;
                    _initGrid();
                  });
                },
                icon: const Icon(Icons.arrow_back_rounded),
                color: Theme.of(context).iconTheme.color,
              ),
              Expanded(
                child: Text(
                  '${_pattern.emoji} ${_pattern.name}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: _clear,
                icon: const Icon(Icons.refresh_rounded),
                color: AppTheme.textHint,
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final canvasSize = constraints.biggest;
                    return GestureDetector(
                      onTapDown: (d) =>
                          _handleTap(d.localPosition, canvasSize),
                      child: CustomPaint(
                        painter: _MandalaPainter(
                          colors: _colors,
                          centerColor: _centerColor,
                          palette: _palette,
                          rings: _pattern.rings,
                          sectors: _pattern.sectors,
                          surfaceColor: Theme.of(context).colorScheme.surface,
                          pattern: _pattern,
                        ),
                        size: canvasSize,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        // Completion message
        if (_completed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(
                  '¡Hermoso! 🤍',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 8),
                if (_currentLevel < _patterns.length - 1)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextLevel,
                      child: Text('Siguiente: ${_patterns[_currentLevel + 1].emoji} ${_patterns[_currentLevel + 1].name}'),
                    ),
                  )
                else
                  Text(
                    'Has completado todos los mandalas ✨',
                    style: TextStyle(
                      color: AppTheme.textHint,
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        // Palette
        if (!_completed)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_palette.length, (i) {
                final selected = i == _selectedColorIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColorIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: selected ? 40 : 30,
                    height: selected ? 40 : 30,
                    decoration: BoxDecoration(
                      color: _palette[i],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: _palette[i].withValues(alpha: 0.5),
                                blurRadius: 8,
                              )
                            ]
                          : null,
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

// --- Painter ---

class _MandalaPainter extends CustomPainter {
  final List<List<int>> colors;
  final int centerColor;
  final List<Color> palette;
  final int rings;
  final int sectors;
  final Color surfaceColor;
  final _MandalaPattern pattern;

  _MandalaPainter({
    required this.colors,
    required this.centerColor,
    required this.palette,
    required this.rings,
    required this.sectors,
    required this.surfaceColor,
    required this.pattern,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;
    final ringW = maxR / (rings + 1);

    final linePaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Draw cells ring by ring
    for (int r = rings - 1; r >= 0; r--) {
      final innerR = (r + 1) * ringW;
      final outerR = (r + 2) * ringW;

      // Alternating ring widths for visual variety
      final adjustedInner = pattern.hasAlternatingRings && r.isOdd
          ? innerR + ringW * 0.08
          : innerR;
      final adjustedOuter = pattern.hasAlternatingRings && r.isOdd
          ? outerR - ringW * 0.08
          : outerR;

      for (int s = 0; s < sectors; s++) {
        final startAngle = s * 2 * pi / sectors;
        final sweepAngle = 2 * pi / sectors;

        final outerRect = Rect.fromCircle(center: center, radius: adjustedOuter);
        final innerRect = Rect.fromCircle(center: center, radius: adjustedInner);

        final path = Path()
          ..arcTo(outerRect, startAngle, sweepAngle, true)
          ..arcTo(innerRect, startAngle + sweepAngle, -sweepAngle, false)
          ..close();

        final idx = colors[r][s];
        final fill = idx >= 0 ? palette[idx] : surfaceColor;
        canvas.drawPath(path, Paint()..color = fill);
        canvas.drawPath(path, linePaint);
      }
    }

    // Center circle
    final centerR = ringW;
    canvas.drawCircle(
      center,
      centerR,
      Paint()..color = centerColor >= 0 ? palette[centerColor] : surfaceColor,
    );
    canvas.drawCircle(center, centerR, linePaint);

    // Decorative petals
    if (pattern.hasPetals) {
      _drawPetals(canvas, center, maxR, ringW);
    }

    // Decorative dots
    if (pattern.hasDots) {
      _drawDots(canvas, center, maxR, ringW);
    }

    // Outer circle
    canvas.drawCircle(
      center,
      maxR,
      Paint()
        ..color = Colors.grey.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawPetals(Canvas canvas, Offset center, double maxR, double ringW) {
    final petalPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int k = 0; k < pattern.symmetry; k++) {
      final angle = k * 2 * pi / pattern.symmetry;
      final petalLen = maxR * 0.7;
      final petalWidth = ringW * 0.8;

      final path = Path();
      // Simple leaf-like petal along the angle
      final tip = Offset(
        center.dx + cos(angle) * petalLen,
        center.dy + sin(angle) * petalLen,
      );
      final left = Offset(
        center.dx + cos(angle - 0.2) * petalLen * 0.5,
        center.dy + sin(angle - 0.2) * petalLen * 0.5,
      );
      final right = Offset(
        center.dx + cos(angle + 0.2) * petalLen * 0.5,
        center.dy + sin(angle + 0.2) * petalLen * 0.5,
      );

      final startPt = Offset(
        center.dx + cos(angle) * ringW,
        center.dy + sin(angle) * ringW,
      );

      path.moveTo(startPt.dx, startPt.dy);
      path.quadraticBezierTo(
        left.dx - cos(angle) * petalWidth * 0.3,
        left.dy - sin(angle) * petalWidth * 0.3,
        tip.dx,
        tip.dy,
      );
      path.quadraticBezierTo(
        right.dx + cos(angle) * petalWidth * 0.3,
        right.dy + sin(angle) * petalWidth * 0.3,
        startPt.dx,
        startPt.dy,
      );

      canvas.drawPath(path, petalPaint);
    }
  }

  void _drawDots(Canvas canvas, Offset center, double maxR, double ringW) {
    final dotPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    // Dots at ring boundaries along symmetry axes
    for (int k = 0; k < pattern.symmetry; k++) {
      final angle = k * 2 * pi / pattern.symmetry;
      for (int r = 1; r <= rings; r++) {
        final radius = (r + 0.5) * ringW;
        if (radius > maxR) continue;
        final x = center.dx + cos(angle) * radius;
        final y = center.dy + sin(angle) * radius;
        canvas.drawCircle(Offset(x, y), 2.5, dotPaint);
      }
    }

    // Dots between symmetry axes at mid-ring
    for (int k = 0; k < pattern.symmetry; k++) {
      final angle = (k + 0.5) * 2 * pi / pattern.symmetry;
      for (int r = 0; r < rings; r += 2) {
        final radius = (r + 1.5) * ringW;
        if (radius > maxR) continue;
        final x = center.dx + cos(angle) * radius;
        final y = center.dy + sin(angle) * radius;
        canvas.drawCircle(Offset(x, y), 1.8, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_MandalaPainter old) => true;
}
