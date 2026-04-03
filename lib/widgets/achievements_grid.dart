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
            childAspectRatio: 0.62,
          ),
          itemCount: allAchievements.length,
          itemBuilder: (context, index) {
            final a = allAchievements[index];
            final isUnlocked = a.check(storage);
            final progressVal = a.progress(storage);
            return _AchievementTile(
              achievement: a,
              unlocked: isUnlocked,
              progress: progressVal,
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
  final double progress;

  const _AchievementTile({
    required this.achievement,
    required this.unlocked,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.textPrimary;

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
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: unlocked
                  ? Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.3))
                  : Border.all(
                      color: Colors.grey.withValues(alpha: 0.15)),
            ),
            child: Center(
              child: Text(
                unlocked ? achievement.emoji : '🔒',
                style: TextStyle(fontSize: unlocked ? 28 : 20),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Progress bar for locked achievements
          if (!unlocked)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: Colors.grey.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(
                    AppTheme.primary.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 3),
          Text(
            unlocked ? achievement.title : '???',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: unlocked ? textColor : AppTheme.textHint,
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
        backgroundColor: Theme.of(context).colorScheme.surface,
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
              style: TextStyle(color: AppTheme.textHint),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // Progress bar in dialog
            if (!unlocked) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey.withValues(alpha: 0.12),
                  valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  color: AppTheme.textHint,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
