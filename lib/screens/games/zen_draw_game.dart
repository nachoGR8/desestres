import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/storage_service.dart';

class ZenDrawGame extends StatefulWidget {
  const ZenDrawGame({super.key});

  @override
  State<ZenDrawGame> createState() => _ZenDrawGameState();
}

class _ZenDrawGameState extends State<ZenDrawGame>
    with TickerProviderStateMixin {
  final List<_ZenStroke> _strokes = [];
  _ZenStroke? _currentStroke;
  int _colorIndex = 0;
  bool _hasDrawn = false;

  static const _palette = [
    Color(0xFF93C5FD), // azul claro
    Color(0xFF5B9CF6), // azul
    Color(0xFFA78BFA), // lila
    Color(0xFF6EE7B7), // menta
    Color(0xFFFCA5A5), // rosa
    Color(0xFF7DD3FC), // cielo
    Color(0xFFC4B5FD), // lavanda
    Color(0xFFFDE68A), // almendra
  ];

  Color get _currentColor => _palette[_colorIndex % _palette.length];

  void _onPanStart(DragStartDetails details) {
    _hasDrawn = true;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _currentStroke = _ZenStroke(
      points: [details.localPosition],
      color: _currentColor,
      fadeController: controller,
    );
    controller.addListener(() => setState(() {}));
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          controller.dispose();
          _strokes.remove(_currentStroke);
        });
      }
    });
    setState(() {
      _strokes.add(_currentStroke!);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_currentStroke == null) return;
    setState(() {
      _currentStroke!.points.add(details.localPosition);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentStroke == null) return;
    _currentStroke!.fadeController.forward();
    _currentStroke = null;
    _colorIndex++;
  }

  void _clear() {
    for (final s in _strokes) {
      s.fadeController.dispose();
    }
    setState(() {
      _strokes.clear();
      _currentStroke = null;
    });
  }

  Future<void> _exit() async {
    if (_hasDrawn) {
      await StorageService().recordActivity();
    }
    _clear();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    for (final s in _strokes) {
      s.fadeController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _exit,
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppTheme.textPrimary,
                  ),
                  Expanded(
                    child: Text(
                      'Dibuja zen',
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
            // Canvas
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: GestureDetector(
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    child: CustomPaint(
                      painter: _ZenPainter(_strokes),
                      child: Container(
                        color: Colors.transparent,
                        child: !_hasDrawn
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '🎨',
                                      style: TextStyle(fontSize: 40),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Dibuja con el dedo\nlo que quieras',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppTheme.textHint,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'El trazo se desvanecerá suavemente',
                                      style: TextStyle(
                                        color: AppTheme.textHint
                                            .withValues(alpha: 0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Color preview
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Siguiente color:  ',
                    style: TextStyle(
                      color: AppTheme.textHint,
                      fontSize: 13,
                    ),
                  ),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _currentColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _currentColor.withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZenStroke {
  final List<Offset> points;
  final Color color;
  final AnimationController fadeController;

  _ZenStroke({
    required this.points,
    required this.color,
    required this.fadeController,
  });

  double get opacity => (1.0 - fadeController.value).clamp(0.0, 1.0);
}

class _ZenPainter extends CustomPainter {
  final List<_ZenStroke> strokes;

  _ZenPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;

      final paint = Paint()
        ..color = stroke.color.withValues(alpha: stroke.opacity * 0.8)
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      // Glow effect
      final glowPaint = Paint()
        ..color = stroke.color.withValues(alpha: stroke.opacity * 0.2)
        ..strokeWidth = 12.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      final path = Path();
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);

      for (int i = 1; i < stroke.points.length; i++) {
        final p0 = stroke.points[i - 1];
        final p1 = stroke.points[i];
        final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
        path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
      }

      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ZenPainter oldDelegate) => true;
}
