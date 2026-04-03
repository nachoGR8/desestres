import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../widgets/page_transitions.dart';
import 'games/breathing_game.dart';
import 'games/bubble_pop_game.dart';
import 'games/zen_draw_game.dart';
import 'games/worry_jar_game.dart';
import 'games/mandala_game.dart';

class GamesHubScreen extends StatelessWidget {
  const GamesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
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
            const SizedBox(height: 28),
            Expanded(
              child: GridView.count(
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
                ]
                    .animate(interval: 100.ms)
                    .fadeIn(duration: 400.ms)
                    .scale(
                      begin: const Offset(0.9, 0.9),
                      end: const Offset(1.0, 1.0),
                      duration: 400.ms,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openGame(BuildContext context, Widget game) {
    Navigator.of(context).push(
      WavePageRoute(builder: (_) => game),
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
          color: Colors.white,
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
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
