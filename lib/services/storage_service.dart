import 'package:hive_flutter/hive_flutter.dart';
import '../models/mood_entry.dart';
import '../models/breathing_session.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _moodBoxName = 'moods';
  static const String _sessionBoxName = 'sessions';
  static const String _streakBoxName = 'streak';

  late Box<MoodEntry> _moodBox;
  late Box<BreathingSession> _sessionBox;
  late Box _streakBox;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(MoodEntryAdapter());
    Hive.registerAdapter(BreathingSessionAdapter());
    _moodBox = await Hive.openBox<MoodEntry>(_moodBoxName);
    _sessionBox = await Hive.openBox<BreathingSession>(_sessionBoxName);
    _streakBox = await Hive.openBox(_streakBoxName);
  }

  // --- Mood ---

  Future<void> saveMood(MoodEntry entry) async {
    await _moodBox.put(entry.dateKey, entry);
  }

  MoodEntry? getTodayMood() {
    final now = DateTime.now();
    final key =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return _moodBox.get(key);
  }

  List<MoodEntry> getMoods({int lastDays = 30}) {
    final entries = _moodBox.values.toList();
    entries.sort((a, b) => b.date.compareTo(a.date));
    final cutoff = DateTime.now().subtract(Duration(days: lastDays));
    return entries.where((e) => e.date.isAfter(cutoff)).toList();
  }

  List<MoodEntry> getAllMoods() {
    final entries = _moodBox.values.toList();
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  // --- Breathing Sessions ---

  Future<void> saveSession(BreathingSession session) async {
    await _sessionBox.add(session);
  }

  List<BreathingSession> getSessions({int lastDays = 30}) {
    final entries = _sessionBox.values.toList();
    entries.sort((a, b) => b.date.compareTo(a.date));
    final cutoff = DateTime.now().subtract(Duration(days: lastDays));
    return entries.where((e) => e.date.isAfter(cutoff)).toList();
  }

  int get totalSessions => _sessionBox.values.length;

  int get totalSecondsBreathing {
    return _sessionBox.values.fold(0, (sum, s) => sum + s.durationSeconds);
  }

  // --- Streak ---

  Future<void> recordActivity() async {
    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final lastDateStr = _streakBox.get('lastActivityDate') as String?;
    final currentStreak = _streakBox.get('currentStreak', defaultValue: 0) as int;
    final bestStreak = _streakBox.get('bestStreak', defaultValue: 0) as int;

    if (lastDateStr == todayKey) return; // Already recorded today

    int newStreak;
    if (lastDateStr != null) {
      final lastDate = DateTime.parse(lastDateStr);
      final diff = DateTime(now.year, now.month, now.day)
          .difference(DateTime(lastDate.year, lastDate.month, lastDate.day))
          .inDays;
      newStreak = diff == 1 ? currentStreak + 1 : 1;
    } else {
      newStreak = 1;
    }

    await _streakBox.put('lastActivityDate', todayKey);
    await _streakBox.put('currentStreak', newStreak);
    if (newStreak > bestStreak) {
      await _streakBox.put('bestStreak', newStreak);
    }
  }

  int get currentStreak => _streakBox.get('currentStreak', defaultValue: 0) as int;
  int get bestStreak => _streakBox.get('bestStreak', defaultValue: 0) as int;

  // --- Counters (for achievements) ---

  int getCounter(String key) => _streakBox.get(key, defaultValue: 0) as int;

  Future<void> incrementCounter(String key, [int amount = 1]) async {
    final current = getCounter(key);
    await _streakBox.put(key, current + amount);
  }

  Future<void> discoverGame(String gameName) async {
    final raw = _streakBox.get('gamesDiscovered', defaultValue: '') as String;
    final games = raw.isEmpty ? <String>{} : raw.split(',').toSet();
    if (games.add(gameName)) {
      await _streakBox.put('gamesDiscovered', games.join(','));
    }
  }

  int get discoveredGamesCount {
    final raw = _streakBox.get('gamesDiscovered', defaultValue: '') as String;
    return raw.isEmpty ? 0 : raw.split(',').length;
  }

  Set<String> get activityDates {
    final moods = _moodBox.keys.cast<String>().toSet();
    final sessionDates = _sessionBox.values.map((s) {
      final d = s.date;
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }).toSet();
    return moods.union(sessionDates);
  }
}
