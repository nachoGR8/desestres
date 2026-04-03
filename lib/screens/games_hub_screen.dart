import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../widgets/page_transitions.dart';
import 'games/breathing_game.dart';
import 'games/bubble_pop_game.dart';
import 'games/zen_draw_game.dart';
import 'games/worry_jar_game.dart';
import 'games/mandala_game.dart';
import 'games/pimple_pop_game.dart';
import 'garden_screen.dart';
import 'sos_calm_screen.dart';
import 'gratitude_screen.dart';
import 'cartas_screen.dart';

class GamesHubScreen extends StatefulWidget {
  const GamesHubScreen({super.key});

  @override
  State<GamesHubScreen> createState() => _GamesHubScreenState();
}

class _GamesHubScreenState extends State<GamesHubScreen> {
  static final _startDate = DateTime(2025, 4, 5);

  @override
  Widget build(BuildContext context) {
    final daysTogether =
        DateTime.now().difference(_startDate).inDays;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Jugar',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Elige algo para relajarte 🤍',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 20),

            // Days together counter
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppTheme.primary.withValues(alpha: 0.10),
                  AppTheme.accentLilac.withValues(alpha: 0.10),
                ]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    '🤍 $daysTogether días juntos 🤍',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Amor, eres mi vida misma, te ame en locura pa tota la vida',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textHint,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 600.ms),
            const SizedBox(height: 16),

            // SOS Calm button
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SosCalmScreen()),
              ).then((_) => setState(() {})),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5B9CF6), Color(0xFF7C5BF6)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🫂', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 12),
                    Text(
                      'Necesito calma',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 400.ms).scale(
                  begin: const Offset(0.95, 0.95),
                  end: const Offset(1.0, 1.0),
                  duration: 400.ms,
                ),
            const SizedBox(height: 16),

            // Quick access: Garden + Gratitude + Cartas
            Row(
              children: [
                Expanded(
                  child: _QuickCard(
                    emoji: '🌱',
                    label: 'Mi Jardín',
                    color: const Color(0xFF5AAF4A),
                    onTap: () => Navigator.of(context).push(
                      WavePageRoute(builder: (_) => const GardenScreen()),
                    ).then((_) => setState(() {})),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickCard(
                    emoji: '📝',
                    label: 'Gratitud',
                    color: AppTheme.secondary,
                    onTap: () => Navigator.of(context).push(
                      WavePageRoute(builder: (_) => const GratitudeScreen()),
                    ).then((_) => setState(() {})),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickCard(
                    emoji: '💌',
                    label: 'Cartas',
                    color: AppTheme.accentPink,
                    onTap: () => Navigator.of(context).push(
                      WavePageRoute(builder: (_) => const CartasScreen()),
                    ).then((_) => setState(() {})),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
            const SizedBox(height: 20),

            // Games grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.9,
              children: [
                _GameCard(
                  title: 'Respiración',
                  subtitle: 'Sigue el ritmo',
                  emoji: '🌬️',
                  color: AppTheme.primary,
                  onTap: () => _openGame(context, const BreathingGame()),
                ),
                _GameCard(
                  title: 'Burbujas',
                  subtitle: 'Explótalas todas',
                  emoji: '🫧',
                  color: AppTheme.accentLilac,
                  onTap: () => _openGame(context, const BubblePopGame()),
                ),
                _GameCard(
                  title: 'Dibuja zen',
                  subtitle: 'Dibuja y relájate',
                  emoji: '🎨',
                  color: AppTheme.secondary,
                  onTap: () => _openGame(context, const ZenDrawGame()),
                ),
                _GameCard(
                  title: 'Jarro',
                  subtitle: 'Suelta tus\npreocupaciones',
                  emoji: '🏺',
                  color: AppTheme.accentPink,
                  onTap: () => _openGame(context, const WorryJarGame()),
                ),
                _GameCard(
                  title: 'Mandala',
                  subtitle: 'Colorea y relájate',
                  emoji: '🔮',
                  color: AppTheme.primaryLight,
                  onTap: () => _openGame(context, const MandalaGame()),
                ),
                _GameCard(
                  title: 'Granitos',
                  subtitle: 'Reviéntalos todos',
                  emoji: '😌',
                  color: AppTheme.accentPink,
                  onTap: () => _openGame(context, const PimplePopGame()),
                ),
              ]
                  .animate(interval: 100.ms)
                  .fadeIn(duration: 400.ms)
                  .scale(
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1.0, 1.0),
                    duration: 400.ms,
                  ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _openGame(BuildContext context, Widget game) {
    Navigator.of(context).push(
      WavePageRoute(builder: (_) => game),
    ).then((_) => setState(() {}));
  }
}

class _QuickCard extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickCard({
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emoji;
  final Color color;
  final VoidCallback onTap;

  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
