import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StreakCard extends StatelessWidget {
  final int currentStreak;
  final int bestStreak;

  const StreakCard({
    super.key,
    required this.currentStreak,
    required this.bestStreak,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary.withValues(alpha: 0.15),
            AppTheme.secondary.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            currentStreak > 0 ? '🔥' : '💤',
            style: const TextStyle(fontSize: 40),
          ),
          const SizedBox(height: 8),
          Text(
            '$currentStreak',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            currentStreak == 1 ? 'día de racha' : 'días de racha',
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          if (bestStreak > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Mejor racha: $bestStreak días',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textHint,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
