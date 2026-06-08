import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:habo/generated/l10n.dart';
import 'package:habo/settings/settings_manager.dart';
import 'package:habo/statistics/statistics.dart';
import 'package:provider/provider.dart';

/// Displays the best day-of-week for habit completion plus a 7-bar chart.
/// Tapping a bar shows the completion percentage for that day as a tooltip.
class BestDayTimeCard extends StatefulWidget {
  const BestDayTimeCard({super.key, required this.data});

  final BestDayTimeData data;

  @override
  State<BestDayTimeCard> createState() => _BestDayTimeCardState();
}

class _BestDayTimeCardState extends State<BestDayTimeCard> {
  int? _touchedIndex;

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
    final settings = Provider.of<SettingsManager>(context, listen: false);
    final checkColor = settings.checkColor;
    final muteColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    final bool hasBestDay = widget.data.bestDayOfWeek != null;

    // ── Bar chart helpers ────────────────────────────────────────────────

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
        final rate = widget.data.dayOfWeekRates[dayName] ?? 0.0;
        final isBest = widget.data.bestDayOfWeek == dayName;
        final isTouched = _touchedIndex == i;
        return BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: rate * 100,
              color: (isBest || isTouched)
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
              S.of(context).bestDayLabel.trimRight(),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                  widget.data.bestDayOfWeek ?? S.of(context).notEnoughData,
                  style: TextStyle(
                    color: hasBestDay ? null : muteColor,
                  ),
                ),
                if (hasBestDay) ...[
                  const Spacer(),
                  Text(
                    '${(widget.data.bestDayRate * 100).round()}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: checkColor,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // ── Day-of-week bar chart ─────────────────────────────────────
            // Tapping a bar shows its completion % as a tooltip.
            // Best-day rod and touched rod render at full opacity; others at 50 %.
            SizedBox(
              height: 80,
              child: BarChart(
                BarChartData(
                  maxY: 100,
                  alignment: BarChartAlignment.spaceAround,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchCallback: (FlTouchEvent event,
                        BarTouchResponse? response) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            response == null ||
                            response.spot == null) {
                          _touchedIndex = null;
                          return;
                        }
                        _touchedIndex =
                            response.spot!.touchedBarGroupIndex;
                      });
                    },
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) =>
                          checkColor.withValues(alpha: 0.9),
                      tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      getTooltipItem:
                          (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${rod.toY.round()}%',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
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
          ],
        ),
      ),
    );
  }
}
