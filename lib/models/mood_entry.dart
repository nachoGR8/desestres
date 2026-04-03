import 'package:hive/hive.dart';

part 'mood_entry.g.dart';

@HiveType(typeId: 0)
class MoodEntry extends HiveObject {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  final int level; // 1-5

  @HiveField(2)
  final String? note;

  MoodEntry({
    required this.date,
    required this.level,
    this.note,
  });

  String get dateKey {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String get emoji {
    switch (level) {
      case 1:
        return '😫';
      case 2:
        return '😕';
      case 3:
        return '😐';
      case 4:
        return '🙂';
      case 5:
        return '😄';
      default:
        return '😐';
    }
  }

  String get label {
    switch (level) {
      case 1:
        return 'Muy mal';
      case 2:
        return 'Mal';
      case 3:
        return 'Normal';
      case 4:
        return 'Bien';
      case 5:
        return 'Genial';
      default:
        return 'Normal';
    }
  }
}
