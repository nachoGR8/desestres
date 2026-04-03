import 'dart:math';
import '../services/storage_service.dart';

class Achievement {
  final String id;
  final String emoji;
  final String title;
  final String description;
  final bool Function(StorageService) check;
  final double Function(StorageService) progress;

  Achievement({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.check,
    required this.progress,
  });
}

double _clamp01(double v) => min(1.0, max(0.0, v));

final List<Achievement> allAchievements = [
  // --- Estado de ánimo ---
  Achievement(
    id: 'first_mood',
    emoji: '🌱',
    title: 'Primer paso',
    description: 'Registra tu primer ánimo',
    check: (s) => s.getAllMoods().isNotEmpty,
    progress: (s) => s.getAllMoods().isEmpty ? 0.0 : 1.0,
  ),
  Achievement(
    id: 'mood_14',
    emoji: '📅',
    title: 'Rutina',
    description: 'Registra 14 días de ánimo',
    check: (s) => s.getAllMoods().length >= 14,
    progress: (s) => _clamp01(s.getAllMoods().length / 14),
  ),
  Achievement(
    id: 'mood_30',
    emoji: '📖',
    title: 'Diario personal',
    description: 'Registra 30 días de ánimo',
    check: (s) => s.getAllMoods().length >= 30,
    progress: (s) => _clamp01(s.getAllMoods().length / 30),
  ),

  // --- Rachas ---
  Achievement(
    id: 'streak_3',
    emoji: '🔥',
    title: 'Tres en racha',
    description: '3 días seguidos',
    check: (s) => s.bestStreak >= 3,
    progress: (s) => _clamp01(s.bestStreak / 3),
  ),
  Achievement(
    id: 'streak_7',
    emoji: '⭐',
    title: 'Semana completa',
    description: '7 días seguidos',
    check: (s) => s.bestStreak >= 7,
    progress: (s) => _clamp01(s.bestStreak / 7),
  ),
  Achievement(
    id: 'streak_30',
    emoji: '👑',
    title: 'Un mes entero',
    description: '30 días seguidos',
    check: (s) => s.bestStreak >= 30,
    progress: (s) => _clamp01(s.bestStreak / 30),
  ),

  // --- Respiración ---
  Achievement(
    id: 'first_breath',
    emoji: '🌬️',
    title: 'Primera respiración',
    description: 'Completa una sesión',
    check: (s) => s.totalSessions >= 1,
    progress: (s) => s.totalSessions >= 1 ? 1.0 : 0.0,
  ),
  Achievement(
    id: 'breath_20',
    emoji: '🧘',
    title: 'Respirador zen',
    description: '20 sesiones de respiración',
    check: (s) => s.totalSessions >= 20,
    progress: (s) => _clamp01(s.totalSessions / 20),
  ),
  Achievement(
    id: 'breath_50',
    emoji: '💨',
    title: 'Maestro del aire',
    description: '50 sesiones de respiración',
    check: (s) => s.totalSessions >= 50,
    progress: (s) => _clamp01(s.totalSessions / 50),
  ),
  Achievement(
    id: 'breath_60min',
    emoji: '🎯',
    title: 'Dedicación',
    description: '60 minutos respirando',
    check: (s) => s.totalSecondsBreathing >= 3600,
    progress: (s) => _clamp01(s.totalSecondsBreathing / 3600),
  ),
  Achievement(
    id: 'breath_120min',
    emoji: '🏔️',
    title: 'Hora zen',
    description: '2 horas respirando',
    check: (s) => s.totalSecondsBreathing >= 7200,
    progress: (s) => _clamp01(s.totalSecondsBreathing / 7200),
  ),

  // --- Burbujas ---
  Achievement(
    id: 'bubbles_100',
    emoji: '🫧',
    title: 'Cazaburbujas',
    description: 'Explota 100 burbujas',
    check: (s) => s.getCounter('totalBubbles') >= 100,
    progress: (s) => _clamp01(s.getCounter('totalBubbles') / 100),
  ),
  Achievement(
    id: 'bubbles_500',
    emoji: '🌊',
    title: 'Mar de burbujas',
    description: 'Explota 500 burbujas',
    check: (s) => s.getCounter('totalBubbles') >= 500,
    progress: (s) => _clamp01(s.getCounter('totalBubbles') / 500),
  ),

  // --- Preocupaciones ---
  Achievement(
    id: 'worries_20',
    emoji: '✨',
    title: 'Sin preocupaciones',
    description: 'Disuelve 20 preocupaciones',
    check: (s) => s.getCounter('totalWorries') >= 20,
    progress: (s) => _clamp01(s.getCounter('totalWorries') / 20),
  ),
  Achievement(
    id: 'worries_50',
    emoji: '🕊️',
    title: 'Mente en paz',
    description: 'Disuelve 50 preocupaciones',
    check: (s) => s.getCounter('totalWorries') >= 50,
    progress: (s) => _clamp01(s.getCounter('totalWorries') / 50),
  ),

  // --- Zen Draw ---
  Achievement(
    id: 'zen_10',
    emoji: '🎨',
    title: 'Artista zen',
    description: 'Dibuja 10 veces',
    check: (s) => s.getCounter('totalZenDraws') >= 10,
    progress: (s) => _clamp01(s.getCounter('totalZenDraws') / 10),
  ),

  // --- Mandala ---
  Achievement(
    id: 'mandala_1',
    emoji: '🪷',
    title: 'Primer mandala',
    description: 'Completa un mandala',
    check: (s) => s.getCounter('totalMandalas') >= 1,
    progress: (s) => s.getCounter('totalMandalas') >= 1 ? 1.0 : 0.0,
  ),
  Achievement(
    id: 'mandala_5',
    emoji: '🎨',
    title: 'Colorista',
    description: 'Completa 5 mandalas',
    check: (s) => s.getCounter('totalMandalas') >= 5,
    progress: (s) => _clamp01(s.getCounter('totalMandalas') / 5),
  ),
  Achievement(
    id: 'mandala_10',
    emoji: '🌈',
    title: 'Arcoíris interior',
    description: 'Completa 10 mandalas',
    check: (s) => s.getCounter('totalMandalas') >= 10,
    progress: (s) => _clamp01(s.getCounter('totalMandalas') / 10),
  ),

  // --- General ---
  Achievement(
    id: 'explorer',
    emoji: '🧩',
    title: 'Descubridor',
    description: 'Prueba los 5 juegos',
    check: (s) => s.discoveredGamesCount >= 5,
    progress: (s) => _clamp01(s.discoveredGamesCount / 5),
  ),
];
