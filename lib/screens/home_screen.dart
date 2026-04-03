import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/theme_service.dart';
import '../services/storage_service.dart';
import '../services/sound_service.dart';
import '../services/notification_service.dart';
import 'games_hub_screen.dart';
import 'mood_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const GamesHubScreen(),
    const MoodScreen(),
    const StatsScreen(),
  ];

  bool get _moodLoggedToday => StorageService().getTodayMood() != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Reminder banner
          if (!_moodLoggedToday && _currentIndex != 1)
            SafeArea(
              bottom: false,
              child: GestureDetector(
                onTap: () => setState(() => _currentIndex = 1),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      AppTheme.primary.withValues(alpha: 0.08),
                      AppTheme.secondary.withValues(alpha: 0.08),
                    ]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Text('🤍', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '¿Cómo te sientes hoy?',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.color,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 20, color: AppTheme.textHint),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.sports_esports_rounded, 'Jugar'),
                _buildNavItem(1, Icons.emoji_emotions_rounded, 'Ánimo'),
                _buildNavItem(2, Icons.bar_chart_rounded, 'Progreso'),
                GestureDetector(
                  onTap: () => setState(() => SoundService().toggle()),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      SoundService().enabled
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      color: AppTheme.textHint,
                      size: 22,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => NotificationService().toggle()),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      NotificationService().enabled
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_off_rounded,
                      color: AppTheme.textHint,
                      size: 22,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => ThemeService().toggle(),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      ThemeService().isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: AppTheme.textHint,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primary : AppTheme.textHint,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
