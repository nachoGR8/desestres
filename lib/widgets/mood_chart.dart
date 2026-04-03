import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/mood_entry.dart';

class MoodChart extends StatelessWidget {
  final List<MoodEntry> entries;

  const MoodChart({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📊', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 8),
              Text(
                'Registra tu ánimo para\nver tu gráfico aquí',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textHint, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final sorted = List<MoodEntry>.from(entries)
      ..sort((a, b) => a.date.compareTo(b.date));

    final spots = sorted.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.level.toDouble());
    }).toList();

    return Container(
      height: 200,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: LineChart(
        LineChartData(
          minY: 0.5,
          maxY: 5.5,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppTheme.textHint.withValues(alpha: 0.15),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, _) {
                  const emojis = ['', '😫', '😕', '😐', '🙂', '😄'];
                  final i = value.toInt();
                  if (i < 1 || i > 5) return const SizedBox.shrink();
                  return Text(emojis[i], style: const TextStyle(fontSize: 12));
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: (sorted.length / 5).ceilToDouble().clamp(1, 7),
                getTitlesWidget: (value, _) {
                  final i = value.toInt();
                  if (i < 0 || i >= sorted.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    DateFormat('d/M').format(sorted[i].date),
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textHint,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: AppTheme.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, xPercentage, bar, index) => FlDotCirclePainter(
                  radius: 4,
                  color: AppTheme.primary,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) {
                return spots.map((spot) {
                  final entry = sorted[spot.spotIndex];
                  return LineTooltipItem(
                    '${entry.emoji} ${entry.label}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}
