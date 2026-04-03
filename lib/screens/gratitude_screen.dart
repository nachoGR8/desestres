import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';

class GratitudeScreen extends StatefulWidget {
  const GratitudeScreen({super.key});

  @override
  State<GratitudeScreen> createState() => _GratitudeScreenState();
}

class _GratitudeScreenState extends State<GratitudeScreen> {
  final _controllers = List.generate(3, (_) => TextEditingController());
  bool _savedToday = false;

  @override
  void initState() {
    super.initState();
    _loadToday();
  }

  void _loadToday() {
    final entries = StorageService().getGratitude();
    if (entries != null) {
      for (int i = 0; i < 3; i++) {
        if (i < entries.length) _controllers[i].text = entries[i];
      }
      _savedToday = entries.any((e) => e.isNotEmpty);
    }
  }

  Future<void> _save() async {
    final entries = _controllers.map((c) => c.text.trim()).toList();
    if (entries.every((e) => e.isEmpty)) return;
    await StorageService().saveGratitude(entries);
    await StorageService().recordActivity();
    setState(() => _savedToday = true);
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
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pastEntries = StorageService().getPastGratitude(days: 7);
    final surfaceColor = Theme.of(context).colorScheme.surface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: Theme.of(context).iconTheme.color,
                  ),
                  Expanded(
                    child: Text(
                      'Diario de Gratitud',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '¿Por qué estás agradecida hoy? 🤍',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 24),
              // 3 gratitude fields
              ...List.generate(3, (i) {
                final labels = [
                  '🌸 Algo que te hizo sonreír',
                  '💫 Algo que te hizo sentir bien',
                  '🤍 Algo que agradeces',
                ];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TextField(
                    controller: _controllers[i],
                    maxLength: 120,
                    maxLines: 2,
                    onChanged: (_) {
                      if (_savedToday) setState(() => _savedToday = false);
                    },
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    decoration: InputDecoration(
                      hintText: labels[i],
                      hintStyle: TextStyle(color: AppTheme.textHint),
                      filled: true,
                      fillColor: surfaceColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      counterStyle: TextStyle(color: AppTheme.textHint),
                    ),
                  ),
                ).animate().fadeIn(
                      delay: Duration(milliseconds: i * 100),
                      duration: 400.ms,
                    );
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: !_savedToday ? _save : null,
                  child: Text(_savedToday ? 'Guardado ✓' : 'Guardar'),
                ),
              ),
              const SizedBox(height: 32),
              // Past entries
              if (pastEntries.isNotEmpty) ...[
                Text(
                  'Días anteriores',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ...pastEntries.entries.map((entry) {
                  final date = DateTime.tryParse(entry.key);
                  final items = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            date != null
                                ? DateFormat('EEEE d MMM', 'es').format(date)
                                : entry.key,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...items.where((s) => s.isNotEmpty).map(
                                (s) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '• ',
                                        style: TextStyle(
                                          color: AppTheme.textHint,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          s,
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.color,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms);
                }),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
