import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MoodSelector extends StatelessWidget {
  final int? selectedLevel;
  final ValueChanged<int> onSelected;

  const MoodSelector({
    super.key,
    this.selectedLevel,
    required this.onSelected,
  });

  static const _moods = [
    (emoji: '😫', label: 'Muy mal'),
    (emoji: '😕', label: 'Mal'),
    (emoji: '😐', label: 'Normal'),
    (emoji: '🙂', label: 'Bien'),
    (emoji: '😄', label: 'Genial'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(_moods.length, (index) {
        final level = index + 1;
        final mood = _moods[index];
        final isSelected = selectedLevel == level;

        return GestureDetector(
          onTap: () => onSelected(level),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppTheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  mood.emoji,
                  style: TextStyle(fontSize: isSelected ? 36 : 28),
                ),
                const SizedBox(height: 4),
                Text(
                  mood.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w400,
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
