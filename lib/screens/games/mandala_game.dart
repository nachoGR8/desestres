import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../services/storage_service.dart';

class MandalaGame extends StatefulWidget {
  const MandalaGame({super.key});

  @override
  State<MandalaGame> createState() => _MandalaGameState();
}

class _MandalaGameState extends State<MandalaGame> {
  static const _rings = 5;
  static const _sectors = 24;
  static const _symmetry = 6;
  static const _sectorsPerUnit = _sectors ~/ _symmetry;

  late List<List<int>> _colors;
  int _centerColor = -1;
  int _selectedColorIndex = 0;
  bool _hasColored = false;

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

  @override
  void initState() {
    super.initState();
    _colors = List.generate(_rings, (_) => List.filled(_sectors, -1));
  }

  void _tapCell(int ring, int sector) {
    HapticFeedback.lightImpact();
    setState(() {
      _hasColored = true;
      if (ring == -1) {
        _centerColor = _selectedColorIndex;
        return;
      }
      final unitSector = sector % _sectorsPerUnit;
      for (int k = 0; k < _symmetry; k++) {
        _colors[ring][(unitSector + k * _sectorsPerUnit) % _sectors] =
            _selectedColorIndex;
      }
    });
  }

  void _clear() {
    setState(() {
      _colors = List.generate(_rings, (_) => List.filled(_sectors, -1));
      _centerColor = -1;
    });
  }

  void _handleTap(Offset pos, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;
    final ringW = maxR / (_rings + 1);

    final dx = pos.dx - center.dx;
    final dy = pos.dy - center.dy;
    final dist = sqrt(dx * dx + dy * dy);

    if (dist > maxR) return;

    if (dist < ringW) {
      _tapCell(-1, 0);
      return;
    }

    final ring = ((dist - ringW) / ringW).floor();
    if (ring >= _rings) return;

    var angle = atan2(dy, dx);
    if (angle < 0) angle += 2 * pi;
    final sector = (angle / (2 * pi) * _sectors).floor() % _sectors;

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
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
                              rings: _rings,
                              sectors: _sectors,
                              surfaceColor: Theme.of(context).colorScheme.surface,
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
                          color:
                              selected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: _palette[i]
                                      .withValues(alpha: 0.5),
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
        ),
      ),
    );
  }
}

class _MandalaPainter extends CustomPainter {
  final List<List<int>> colors;
  final int centerColor;
  final List<Color> palette;
  final int rings;
  final int sectors;
  final Color surfaceColor;

  _MandalaPainter({
    required this.colors,
    required this.centerColor,
    required this.palette,
    required this.rings,
    required this.sectors,
    required this.surfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;
    final ringW = maxR / (rings + 1);

    final linePaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int r = rings - 1; r >= 0; r--) {
      final innerR = (r + 1) * ringW;
      final outerR = (r + 2) * ringW;

      for (int s = 0; s < sectors; s++) {
        final startAngle = s * 2 * pi / sectors;
        final sweepAngle = 2 * pi / sectors;

        final outerRect = Rect.fromCircle(center: center, radius: outerR);
        final innerRect = Rect.fromCircle(center: center, radius: innerR);

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

    final centerR = ringW;
    canvas.drawCircle(
      center,
      centerR,
      Paint()
        ..color = centerColor >= 0 ? palette[centerColor] : surfaceColor,
    );
    canvas.drawCircle(center, centerR, linePaint);

    canvas.drawCircle(
      center,
      maxR,
      Paint()
        ..color = Colors.grey.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_MandalaPainter old) => true;
}
