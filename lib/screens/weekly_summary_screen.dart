import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../data/love_phrases.dart';

class WeeklySummaryScreen extends StatelessWidget {
  const WeeklySummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final summary = StorageService().getWeeklySummary();
    final moodCount = summary['moodCount'] as int;
    final avgMood = summary['avgMood'] as double;
    final sessionCount = summary['sessionCount'] as int;
    final breathingSec = summary['breathingSec'] as int;
    final activeDays = summary['activeDays'] as int;
    final gratitudeDays = summary['gratitudeDays'] as int;
    final currentStreak = summary['currentStreak'] as int;
    final bestStreak = summary['bestStreak'] as int;

    final moodEmoji = _moodEmoji(avgMood);
    final moodLabel = _moodLabel(avgMood);
    final phrase = getRandomPhrase();

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
                      'Tu semana',
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
                    const SizedBox(height: 24),

                    // Motivational phrase from Nacho
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          AppTheme.primary.withValues(alpha: 0.08),
                          AppTheme.accentLilac.withValues(alpha: 0.08),
                        ]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          const Text('💌',
                              style: TextStyle(fontSize: 28)),
                          const SizedBox(height: 10),
                          Text(
                            phrase,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.color,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 600.ms),
                    const SizedBox(height: 24),

                    // Average mood — big hero card
                    if (moodCount > 0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppTheme.primary.withValues(alpha: 0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Ánimo promedio',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textHint,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(moodEmoji,
                                style: const TextStyle(fontSize: 52)),
                            const SizedBox(height: 8),
                            Text(
                              moodLabel,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${avgMood.toStringAsFixed(1)} / 5 · $moodCount registros',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textHint,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 100.ms, duration: 500.ms).scale(
                            begin: const Offset(0.95, 0.95),
                            end: const Offset(1.0, 1.0),
                            duration: 500.ms,
                          ),

                    if (moodCount == 0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          children: [
                            const Text('😶',
                                style: TextStyle(fontSize: 40)),
                            const SizedBox(height: 8),
                            Text(
                              'Sin registros de ánimo esta semana',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textHint,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 100.ms, duration: 500.ms),

                    const SizedBox(height: 20),

                    // Stats grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.3,
                      children: [
                        _StatTile(
                          emoji: '📅',
                          value: '$activeDays/7',
                          label: 'Días activa',
                          color: AppTheme.primary,
                        ),
                        _StatTile(
                          emoji: '🔥',
                          value: '$currentStreak',
                          label: 'Racha actual',
                          color: AppTheme.accentPink,
                        ),
                        _StatTile(
                          emoji: '🌬️',
                          value: '$sessionCount',
                          label: 'Respiraciones',
                          color: AppTheme.accentLilac,
                        ),
                        _StatTile(
                          emoji: '⏱️',
                          value: _formatTime(breathingSec),
                          label: 'Tiempo respirando',
                          color: AppTheme.secondary,
                        ),
                        _StatTile(
                          emoji: '📝',
                          value: '$gratitudeDays',
                          label: 'Días de gratitud',
                          color: AppTheme.primaryLight,
                        ),
                        _StatTile(
                          emoji: '⭐',
                          value: '$bestStreak',
                          label: 'Mejor racha',
                          color: AppTheme.primary,
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(delay: 200.ms, duration: 400.ms)
                        .slideY(begin: 0.1, end: 0, duration: 400.ms),
                    const SizedBox(height: 24),

                    // Weekly message
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _weeklyMessage(activeDays, moodCount, sessionCount),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.color,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 400.ms, duration: 500.ms),
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

  String _moodEmoji(double avg) {
    if (avg <= 0) return '😶';
    if (avg < 1.5) return '😫';
    if (avg < 2.5) return '😕';
    if (avg < 3.5) return '😐';
    if (avg < 4.5) return '🙂';
    return '😄';
  }

  String _moodLabel(double avg) {
    if (avg <= 0) return 'Sin datos';
    if (avg < 1.5) return 'Semana dura';
    if (avg < 2.5) return 'Semana difícil';
    if (avg < 3.5) return 'Semana normal';
    if (avg < 4.5) return 'Buena semana';
    return '¡Semana genial!';
  }

  String _formatTime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final min = seconds ~/ 60;
    if (min < 60) return '${min}m';
    return '${min ~/ 60}h ${min % 60}m';
  }

  String _weeklyMessage(int activeDays, int moods, int sessions) {
    if (activeDays == 0) {
      return '¡Ey! Esta semana no te he visto por aquí. '
          'Acuérdate de dedicarte un ratito cada día, te lo mereces 🤍';
    }
    if (activeDays >= 6) {
      return '¡Increíble! Casi toda la semana aquí, cuidándote. '
          'Eso dice muchísimo de ti. Estoy muy orgulloso 🤍';
    }
    if (activeDays >= 4) {
      return '¡Muy bien! $activeDays días activa esta semana. '
          'Se nota que te estás tomando en serio tu bienestar 🤍';
    }
    if (moods > 0 && sessions > 0) {
      return 'Has registrado tu ánimo y respirado esta semana. '
          'Cada pequeño gesto suma. ¡Sigue así! 🤍';
    }
    return '$activeDays días de actividad esta semana. '
        'Cada día cuenta, y estoy aquí contigo 🤍';
  }
}

class _StatTile extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final Color color;

  const _StatTile({
    required this.emoji,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppTheme.textHint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
