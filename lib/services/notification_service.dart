import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _enabled = true;
  bool get enabled => _enabled;

  Future<void> init() async {
    _initTimezone();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);

    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool('notificationsEnabled') ?? true;

    if (_enabled) {
      await _requestPermission();
      await scheduleDailyReminder();
    }
  }

  void _initTimezone() {
    tz_data.initializeTimeZones();
    final deviceOffset = DateTime.now().timeZoneOffset.inMilliseconds;
    for (final loc in tz.timeZoneDatabase.locations.values) {
      if (loc.currentTimeZone.offset == deviceOffset) {
        tz.setLocalLocation(loc);
        return;
      }
    }
  }

  Future<bool> _requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    return true;
  }

  Future<void> toggle() async {
    _enabled = !_enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', _enabled);

    if (_enabled) {
      final granted = await _requestPermission();
      if (granted) {
        await scheduleDailyReminder();
      } else {
        _enabled = false;
        await prefs.setBool('notificationsEnabled', false);
      }
    } else {
      await _plugin.cancelAll();
    }
  }

  Future<void> scheduleDailyReminder() async {
    await _plugin.cancelAll();

    const androidDetails = AndroidNotificationDetails(
      'daily_reminder',
      'Recordatorio diario',
      channelDescription: 'Recordatorio para registrar tu estado de ánimo',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      0,
      '🤍 Desestres',
      '¿Cómo te sientes hoy? Tómate un momento para ti',
      _nextInstanceOf(20, 0),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
