import 'package:hive/hive.dart';

part 'breathing_session.g.dart';

@HiveType(typeId: 1)
class BreathingSession extends HiveObject {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  final int durationSeconds;

  @HiveField(2)
  final int cyclesCompleted;

  @HiveField(3)
  final String patternName;

  BreathingSession({
    required this.date,
    required this.durationSeconds,
    required this.cyclesCompleted,
    required this.patternName,
  });

  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    if (minutes == 0) return '${seconds}s';
    return '${minutes}m ${seconds}s';
  }
}
