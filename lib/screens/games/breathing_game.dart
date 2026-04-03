import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../widgets/breathing_circle.dart';
import '../../services/storage_service.dart';
import '../../models/breathing_session.dart';

class BreathingGame extends StatefulWidget {
  const BreathingGame({super.key});

  @override
  State<BreathingGame> createState() => _BreathingGameState();
}

class _BreathingGameState extends State<BreathingGame> {
  int _selectedPatternIndex = 0;
  bool _isRunning = false;
  bool _hasStarted = false;
  int _cyclesCompleted = 0;
  int _elapsedSeconds = 0;
  int _sessionKey = 0;
  Timer? _timer;

  BreathingPattern get _pattern => breathingPatterns[_selectedPatternIndex];

  void _start() {
    setState(() {
      _isRunning = true;
      _hasStarted = true;
      _cyclesCompleted = 0;
      _elapsedSeconds = 0;
      _sessionKey++;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isRunning && mounted) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  void _togglePause() {
    setState(() => _isRunning = !_isRunning);
  }

  void _onCycleComplete() {
    setState(() => _cyclesCompleted++);
  }

  Future<void> _finish() async {
    _timer?.cancel();
    setState(() => _isRunning = false);

    if (_elapsedSeconds > 0) {
      final session = BreathingSession(
        date: DateTime.now(),
        durationSeconds: _elapsedSeconds,
        cyclesCompleted: _cyclesCompleted,
        patternName: _pattern.name,
      );
      await StorageService().saveSession(session);
      await StorageService().discoverGame('breathing');
      await StorageService().recordActivity();
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¡Bien hecho! 🤍'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _summaryRow('Ciclos completados', '$_cyclesCompleted'),
            const SizedBox(height: 8),
            _summaryRow('Tiempo', _formatDuration(_elapsedSeconds)),
            const SizedBox(height: 8),
            _summaryRow('Patrón', _pattern.name),
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

    setState(() {
      _hasStarted = false;
      _cyclesCompleted = 0;
      _elapsedSeconds = 0;
    });
  }

  String _formatDuration(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s}s';
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: () async {
                      if (_hasStarted) {
                        await _finish();
                      }
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: Theme.of(context).iconTheme.color,
                  ),
                  Expanded(
                    child: Text(
                      'Respiración',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _hasStarted ? _pattern.name : 'Elige un patrón y comienza',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              if (!_hasStarted) ...[
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: breathingPatterns.length,
                    separatorBuilder: (context, i) =>
                        const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final p = breathingPatterns[index];
                      final selected = index == _selectedPatternIndex;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedPatternIndex = index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 130,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.primary.withValues(alpha: 0.15)
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected
                                  ? AppTheme.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                p.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? AppTheme.primary
                                      : Theme.of(context).textTheme.bodyLarge?.color,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                p.description,
                                style: TextStyle(
                                  color: AppTheme.textHint,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
              const Spacer(),
              BreathingCircle(
                key: ValueKey(_sessionKey),
                pattern: _pattern,
                isRunning: _isRunning,
                onCycleComplete: _onCycleComplete,
              ),
              const Spacer(),
              if (_hasStarted) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _infoChip('Ciclos', '$_cyclesCompleted'),
                    _infoChip('Tiempo', _formatDuration(_elapsedSeconds)),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              if (!_hasStarted)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _start,
                    child: const Text('Comenzar'),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.2, end: 0, duration: 400.ms)
              else
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _togglePause,
                        icon: Icon(_isRunning
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded),
                        label: Text(_isRunning ? 'Pausar' : 'Reanudar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _finish,
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('Terminar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentPink,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
