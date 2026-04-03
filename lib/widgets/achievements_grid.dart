import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/achievement.dart';
import '../services/storage_service.dart';

class AchievementsGrid extends StatelessWidget {
  const AchievementsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();
    final unlocked = allAchievements.where((a) => a.check(storage)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Logros', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text(
              '$unlocked / ${allAchievements.length}',
              style: TextStyle(
                color: AppTheme.textHint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: allAchievements.length,
          itemBuilder: (context, index) {
            final a = allAchievements[index];
            final isUnlocked = a.check(storage);
            return _AchievementTile(
              achievement: a,
              unlocked: isUnlocked,
            ).animate().fadeIn(
                  delay: Duration(milliseconds: index * 50),
                  duration: 300.ms,
                );
          },
        ),
      ],
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final Achievement achievement;
  final bool unlocked;

  const _AchievementTile({required this.achievement, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: unlocked
                  ? AppTheme.primary.withValues(alpha: 0.12)
                  : Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: unlocked
                  ? Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.3))
                  : null,
            ),
            child: Center(
              child: Text(
                unlocked ? achievement.emoji : '🔒',
                style: TextStyle(fontSize: unlocked ? 28 : 20),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            unlocked ? achievement.title : '???',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: unlocked ? AppTheme.textPrimary : AppTheme.textHint,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(achievement.emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              achievement.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              achievement.description,
              style: TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              unlocked ? '✅ Desbloqueado' : '🔒 Bloqueado',
              style: TextStyle(
                color: unlocked ? AppTheme.secondary : AppTheme.textHint,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
