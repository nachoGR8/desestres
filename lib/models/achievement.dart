import '../services/storage_service.dart';

class Achievement {
  final String id;
  final String emoji;
  final String title;
  final String description;
  final bool Function(StorageService) check;

  Achievement({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.check,
  });
}

final List<Achievement> allAchievements = [
  Achievement(
    id: 'first_mood',
    emoji: '🌱',
    title: 'Primer paso',
    description: 'Registra tu primer ánimo',
    check: (s) => s.getAllMoods().isNotEmpty,
  ),
  Achievement(
    id: 'streak_3',
    emoji: '🔥',
    title: 'Tres en racha',
    description: '3 días seguidos',
    check: (s) => s.bestStreak >= 3,
  ),
  Achievement(
    id: 'streak_7',
    emoji: '⭐',
    title: 'Semana completa',
    description: '7 días seguidos',
    check: (s) => s.bestStreak >= 7,
  ),
  Achievement(
    id: 'streak_30',
    emoji: '👑',
    title: 'Un mes entero',
    description: '30 días seguidos',
    check: (s) => s.bestStreak >= 30,
  ),
  Achievement(
    id: 'first_breath',
    emoji: '🌬️',
    title: 'Primera respiración',
    description: 'Completa una sesión',
    check: (s) => s.totalSessions >= 1,
  ),
  Achievement(
    id: 'breath_20',
    emoji: '🧘',
    title: 'Respirador experto',
    description: '20 sesiones de respiración',
    check: (s) => s.totalSessions >= 20,
  ),
  Achievement(
    id: 'bubbles_100',
    emoji: '🫧',
    title: 'Cazaburbujas',
    description: 'Explota 100 burbujas',
    check: (s) => s.getCounter('totalBubbles') >= 100,
  ),
  Achievement(
    id: 'worries_20',
    emoji: '✨',
    title: 'Sin preocupaciones',
    description: 'Disuelve 20 preocupaciones',
    check: (s) => s.getCounter('totalWorries') >= 20,
  ),
  Achievement(
    id: 'zen_10',
    emoji: '🎨',
    title: 'Artista zen',
    description: 'Dibuja 10 veces',
    check: (s) => s.getCounter('totalZenDraws') >= 10,
  ),
  Achievement(
    id: 'explorer',
    emoji: '🧩',
    title: 'Descubridor',
    description: 'Prueba los 5 juegos',
    check: (s) => s.discoveredGamesCount >= 5,
  ),
  Achievement(
    id: 'mood_14',
    emoji: '📅',
    title: 'Rutina',
    description: 'Registra 14 días de ánimo',
    check: (s) => s.getAllMoods().length >= 14,
  ),
  Achievement(
    id: 'breath_60min',
    emoji: '🎯',
    title: 'Dedicación',
    description: '60 minutos respirando',
    check: (s) => s.totalSecondsBreathing >= 3600,
  ),
];
