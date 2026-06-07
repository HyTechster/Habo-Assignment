import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:habo/generated/l10n.dart';
import 'package:habo/settings/settings_manager.dart';
import 'package:habo/statistics/statistics.dart';
import 'package:provider/provider.dart';

/// Displays the best day-of-week and best time-of-day for habit completion,
/// plus a 7-bar mini chart showing per-weekday check rates.
///
/// [BestDayTimeData] is never null — it carries zeroed defaults when there is
/// insufficient data. The null guards on [bestDayOfWeek] and [bestTimeOfDay]
/// control which sections render in a muted "no data" state.
class BestDayTimeCard extends StatelessWidget {
  const BestDayTimeCard({super.key, required this.data});

  final BestDayTimeData data;

  // Full English names must match the keys used in BestDayTimeData.dayOfWeekRates
  // (set by calculateBestDayTime in statistics.dart).
  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const _weekdayAbbr = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  Widget build(BuildContext context) {
    // Read colours once — listen: false convention used throughout statistics widgets
    final settings = Provider.of<SettingsManager>(context, listen: false);
    final checkColor = settings.checkColor;
    final progressColor = settings.progressColor;
    final muteColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    final bool hasBestDay = data.bestDayOfWeek != null;
    final bool hasBestTime = data.bestTimeOfDay != null;

    // ── Mini bar chart helpers ───────────────────────────────────────────

    Widget bottomTitle(double value, TitleMeta meta) {
      final index = value.round();
      if (index < 0 || index >= _weekdayAbbr.length) {
        return const SizedBox.shrink();
      }
      return SideTitleWidget(
        meta: meta,
        space: 4,
        child: Text(
          _weekdayAbbr[index],
          style: const TextStyle(fontSize: 9),
        ),
      );
    }

    List<BarChartGroupData> buildBarGroups() {
      return List.generate(7, (i) {
        final dayName = _weekdays[i];
        final rate = data.dayOfWeekRates[dayName] ?? 0.0;
        final isBest = data.bestDayOfWeek == dayName;
        return BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: rate * 100,
              // Best day: full checkColor opacity; all others: 50 % opacity
              color: isBest
                  ? checkColor
                  : checkColor.withValues(alpha: 0.5),
              width: 12,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ],
        );
      });
    }

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section title ─────────────────────────────────────────────
            Text(
              S.of(context).bestDayTimeTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // ── Best day highlight ────────────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: hasBestDay ? checkColor : muteColor,
                ),
                const SizedBox(width: 8),
                Text(
                  '${S.of(context).bestDayLabel}'
                  '${data.bestDayOfWeek ?? S.of(context).notEnoughData}',
                  style: TextStyle(
                    color: hasBestDay ? null : muteColor,
                  ),
                ),
                if (hasBestDay) ...[
                  const Spacer(),
                  Text(
                    '${(data.bestDayRate * 100).round()}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: checkColor,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // ── Best time highlight ───────────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 18,
                  color: hasBestTime ? progressColor : muteColor,
                ),
                const SizedBox(width: 8),
                Text(
                  '${S.of(context).bestTimeLabel}'
                  '${data.bestTimeOfDay ?? S.of(context).noNotificationsSet}',
                  style: TextStyle(
                    color: hasBestTime ? null : muteColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Day-of-week mini bar chart ────────────────────────────────
            // Height 80; maxY 100 (percentage scale). No grid, no border, no touch.
            // The best-day rod is rendered at full checkColor opacity; all others
            // at 50 % so the best day stands out clearly.
            SizedBox(
              height: 80,
              child: BarChart(
                BarChartData(
                  maxY: 100,
                  alignment: BarChartAlignment.spaceAround,
                  barTouchData: BarTouchData(enabled: false),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 20,
                        getTitlesWidget: bottomTitle,
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  barGroups: buildBarGroups(),
                ),
                duration: const Duration(milliseconds: 150),
                curve: Curves.linear,
              ),
            ),

            // ── Disclaimer — only when best-time data is available ────────
            if (hasBestTime) ...[
              const SizedBox(height: 8),
              Text(
                S.of(context).bestTimeDisclaimer,
                style: TextStyle(fontSize: 10, color: muteColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
