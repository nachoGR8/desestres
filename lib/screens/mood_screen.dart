import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/mood_entry.dart';
import '../services/storage_service.dart';
import '../widgets/mood_selector.dart';
import '../widgets/mood_calendar.dart';

class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  int? _selectedLevel;
  final _noteController = TextEditingController();
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _loadToday();
  }

  void _loadToday() {
    final today = StorageService().getTodayMood();
    if (today != null) {
      setState(() {
        _selectedLevel = today.level;
        _noteController.text = today.note ?? '';
        _saved = true;
      });
    }
  }

  Future<void> _save() async {
    if (_selectedLevel == null) return;
    final entry = MoodEntry(
      date: DateTime.now(),
      level: _selectedLevel!,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );
    await StorageService().saveMood(entry);
    await StorageService().recordActivity();
    setState(() => _saved = true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('¡Guardado! 🤍'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recentMoods = StorageService().getMoods(lastDays: 7);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Ánimo',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                '¿Cómo te sientes hoy?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 24),
            MoodSelector(
              selectedLevel: _selectedLevel,
              onSelected: (level) {
                setState(() {
                  _selectedLevel = level;
                  _saved = false;
                });
              },
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _noteController,
              maxLength: 140,
              maxLines: 2,
              onChanged: (_) {
                if (_saved) setState(() => _saved = false);
              },
              decoration: InputDecoration(
                hintText: '¿Quieres agregar una nota? (opcional)',
                hintStyle: TextStyle(color: AppTheme.textHint),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                counterStyle: TextStyle(color: AppTheme.textHint),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedLevel != null && !_saved ? _save : null,
                child: Text(_saved ? 'Guardado ✓' : 'Guardar'),
              ),
            ),
            const SizedBox(height: 32),
            if (recentMoods.isNotEmpty) ...[
              Text(
                'Últimos días',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ...recentMoods.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Text(entry.emoji, style: const TextStyle(fontSize: 28)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('EEEE d', 'es').format(entry.date),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).textTheme.bodyLarge?.color,
                                  ),
                                ),
                                if (entry.note != null)
                                  Text(
                                    entry.note!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textHint,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            entry.label,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textHint,
                            ),
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 300.ms)
                        .slideX(begin: 0.05, end: 0, duration: 300.ms),
                  )),
            ] else ...[
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    Text('📝', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 8),
                    Text(
                      'Aún no hay registros.\n¡Empieza hoy!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textHint),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Calendar view
            Text(
              'Calendario',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            MoodCalendar(allEntries: StorageService().getAllMoods()),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
