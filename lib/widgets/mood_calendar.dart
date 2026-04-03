import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/mood_entry.dart';

class MoodCalendar extends StatefulWidget {
  final List<MoodEntry> allEntries;

  const MoodCalendar({super.key, required this.allEntries});

  @override
  State<MoodCalendar> createState() => _MoodCalendarState();
}

class _MoodCalendarState extends State<MoodCalendar> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_currentMonth.year, _currentMonth.month + 1);
    if (next.isBefore(DateTime(now.year, now.month + 1))) {
      setState(() => _currentMonth = next);
    }
  }

  static const _moodColors = {
    1: Color(0xFFFCA5A5),
    2: Color(0xFFFDBA74),
    3: Color(0xFFFDE68A),
    4: Color(0xFF6EE7B7),
    5: Color(0xFF5B9CF6),
  };

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday =
        DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;
    final moodMap = <String, MoodEntry>{};
    for (final e in widget.allEntries) {
      moodMap[e.dateKey] = e;
    }

    final now = DateTime.now();
    final isCurrentMonth =
        _currentMonth.year == now.year && _currentMonth.month == now.month;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _prevMonth,
                icon: const Icon(Icons.chevron_left_rounded, size: 28),
                color: AppTheme.textSecondary,
              ),
              Text(
                DateFormat('MMMM yyyy', 'es').format(_currentMonth),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              IconButton(
                onPressed: isCurrentMonth ? null : _nextMonth,
                icon: const Icon(Icons.chevron_right_rounded, size: 28),
                color: isCurrentMonth ? AppTheme.textHint : AppTheme.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['L', 'M', 'X', 'J', 'V', 'S', 'D']
                .map((d) => SizedBox(
                      width: 36,
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textHint,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 0,
            ),
            itemCount: 42,
            itemBuilder: (context, index) {
              final dayNumber = index - (firstWeekday - 1) + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }

              final isFuture = isCurrentMonth && dayNumber > now.day;
              final dateKey =
                  '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}-${dayNumber.toString().padLeft(2, '0')}';
              final entry = moodMap[dateKey];
              final isToday = isCurrentMonth && dayNumber == now.day;

              return Center(
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: entry != null
                        ? _moodColors[entry.level]
                        : isFuture
                            ? Colors.transparent
                            : Colors.grey.withValues(alpha: 0.1),
                    border: isToday
                        ? Border.all(color: AppTheme.primary, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: entry != null
                        ? Text(
                            entry.emoji,
                            style: const TextStyle(fontSize: 14),
                          )
                        : isFuture
                            ? null
                            : Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey.withValues(alpha: 0.3),
                                ),
                              ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
