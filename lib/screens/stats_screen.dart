import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../widgets/streak_card.dart';
import '../widgets/mood_chart.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  @override
  Widget build(BuildContext context) {
    final storage = StorageService();
    final moodEntries = storage.getMoods(lastDays: 30);
    final totalSessions = storage.totalSessions;
    final totalSeconds = storage.totalSecondsBreathing;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Progreso',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 24),

            // Streak
            StreakCard(
              currentStreak: storage.currentStreak,
              bestStreak: storage.bestStreak,
            ).animate().fadeIn(duration: 400.ms).scale(
                  begin: const Offset(0.95, 0.95),
                  end: const Offset(1.0, 1.0),
                  duration: 400.ms,
                ),
            const SizedBox(height: 24),

            // Breathing stats
            Text(
              'Respiración',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    icon: Icons.air_rounded,
                    value: '$totalSessions',
                    label: 'Sesiones',
                    color: AppTheme.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    icon: Icons.timer_rounded,
                    value: _formatMinutes(totalSeconds),
                    label: 'Tiempo total',
                    color: AppTheme.primaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Mood chart
            Text(
              'Estado de ánimo (30 días)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            MoodChart(entries: moodEntries),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatMinutes(int totalSeconds) {
    if (totalSeconds < 60) return '${totalSeconds}s';
    final minutes = totalSeconds ~/ 60;
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final remainingMin = minutes % 60;
    return '${hours}h ${remainingMin}m';
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1, end: 0, duration: 400.ms);
  }
}
