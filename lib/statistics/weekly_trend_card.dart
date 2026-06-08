import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:habo/generated/l10n.dart';
import 'package:habo/settings/settings_manager.dart';
import 'package:habo/statistics/statistics.dart';
import 'package:provider/provider.dart';

/// 12-week completion-rate line chart with stat boxes, tap tooltip, and
/// optional category filter.
///
/// Null guard is the caller's responsibility — [WeeklyTrendData] is only null
/// when the 12-week window contains zero events.
class WeeklyTrendCard extends StatefulWidget {
  const WeeklyTrendCard({super.key, required this.data});

  final WeeklyTrendData data;

  @override
  State<WeeklyTrendCard> createState() => _WeeklyTrendCardState();
}

class _WeeklyTrendCardState extends State<WeeklyTrendCard> {
  String? _selectedCategory;
  int? _tappedSpotIndex;

  // ── Rate computation ──────────────────────────────────────────────────────

  /// When no category is selected returns the pre-computed overall rates.
  /// When a category is selected, recomputes client-side:
  ///   numerator   = habits in the category that completed that week
  ///   denominator = total habits in the category (fixed across all weeks)
  List<double> _filteredRates() {
    if (_selectedCategory == null) return widget.data.weeklyRates;

    final habitsInCategory = widget.data.habitCategoryMap.entries
        .where((e) => e.value.contains(_selectedCategory))
        .map((e) => e.key)
        .toSet();

    final denominator = habitsInCategory.length;
    if (denominator == 0) return List.filled(12, 0.0);

    return List.generate(12, (week) {
      final completed = widget.data.weekCompletedHabits[week]
          .where(habitsInCategory.contains)
          .length;
      return completed / denominator;
    });
  }

  /// Habit titles that completed in [weekIndex] passing the current filter.
  List<String> _completedHabitsForWeek(int weekIndex) {
    if (weekIndex < 0 || weekIndex >= 12) return const [];
    final all = widget.data.weekCompletedHabits[weekIndex];
    if (_selectedCategory == null) return all;
    return all
        .where((title) =>
            widget.data.habitCategoryMap[title]?.contains(_selectedCategory) ==
            true)
        .toList();
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  Widget _statBox(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final checkColor =
        Provider.of<SettingsManager>(context, listen: false).checkColor;
    final gridLineColor =
        Theme.of(context).colorScheme.surfaceContainerHighest;

    // Cache once — used by spots, stat boxes, and tooltip builder
    final rates = _filteredRates();

    final spots = List.generate(
      rates.length,
      (i) => FlSpot(i.toDouble(), rates[i]),
    );

    final thisWeekPct = '${(rates.last * 100).round()}%';
    final avgPct =
        '${(rates.reduce((a, b) => a + b) / rates.length * 100).round()}%';

    Widget bottomTitle(double value, TitleMeta meta) {
      final index = value.round();
      if (![0, 3, 6, 9, 11].contains(index) ||
          index >= widget.data.weekLabels.length) {
        return const SizedBox.shrink();
      }
      return SideTitleWidget(
        meta: meta,
        space: 4,
        child: Text(
          widget.data.weekLabels[index],
          style: const TextStyle(fontSize: 9),
        ),
      );
    }

    Widget leftTitle(double value, TitleMeta meta) {
      final String label;
      if ((value - 0.0).abs() < 0.01) {
        label = '0%';
      } else if ((value - 0.5).abs() < 0.01) {
        label = '50%';
      } else if ((value - 1.0).abs() < 0.01) {
        label = '100%';
      } else {
        return const SizedBox.shrink();
      }
      return SideTitleWidget(
        meta: meta,
        space: 4,
        child: Text(label, style: const TextStyle(fontSize: 9)),
      );
    }

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: title + optional category filter ──────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    S.of(context).weeklyTrendTitle,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                if (widget.data.allCategoryTitles.isNotEmpty)
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _selectedCategory,
                      isDense: true,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(S.of(context).weeklyTrendFilterAll),
                        ),
                        ...widget.data.allCategoryTitles.map(
                          (cat) => DropdownMenuItem<String?>(
                            value: cat,
                            child: Text(cat),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() {
                        _selectedCategory = value;
                        _tappedSpotIndex = null;
                      }),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Stat boxes ────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _statBox(S.of(context).weeklyTrendThisWeek, thisWeekPct, checkColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statBox(S.of(context).weeklyTrendAverage, avgPct, checkColor),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Line chart ────────────────────────────────────────────────
            SizedBox(
              height: 140,
              child: LineChart(
                LineChartData(
                  minY: 0.0,
                  maxY: 1.0,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: checkColor,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          final isTapped = index == _tappedSpotIndex;
                          return FlDotCirclePainter(
                            radius: isTapped ? 6 : 3,
                            color: checkColor,
                            strokeColor: isTapped ? Colors.white : checkColor,
                            strokeWidth: isTapped ? 2 : 1,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: checkColor.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    drawHorizontalLine: true,
                    horizontalInterval: 0.25,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: gridLineColor,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 20,
                        getTitlesWidget: bottomTitle,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: 0.5,
                        getTitlesWidget: leftTitle,
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  // Tap a dot to enlarge it and show a tooltip.
                  // Tapping the same dot again dismisses it.
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchCallback:
                        (FlTouchEvent event, LineTouchResponse? response) {
                      if (event is FlTapUpEvent) {
                        final barSpots = response?.lineBarSpots;
                        final idx =
                            (barSpots != null && barSpots.isNotEmpty)
                                ? barSpots.first.spotIndex
                                : null;
                        setState(() {
                          _tappedSpotIndex =
                              (idx != null && _tappedSpotIndex == idx)
                                  ? null
                                  : idx;
                        });
                      }
                    },
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (spot) => Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.95),
                      tooltipBorderRadius: BorderRadius.circular(8),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final idx = spot.spotIndex;
                          if (idx < 0 || idx >= 12) return null;

                          final rate = rates[idx];
                          final weekLabel = widget.data.weekLabels[idx];
                          final habitsThisWeek = _completedHabitsForWeek(idx);

                          final sb = StringBuffer();
                          sb.write(
                              'Week of $weekLabel: ${(rate * 100).round()}%');

                          if (habitsThisWeek.isEmpty) {
                            sb.write('\n${S.of(context).weeklyTrendNoCompletions}');
                          } else {
                            for (final t in habitsThisWeek.take(5)) {
                              sb.write('\n$t');
                            }
                            if (habitsThisWeek.length > 5) {
                              sb.write('\n${S.of(context).weeklyTrendMoreHabits(habitsThisWeek.length - 5)}');
                            }
                          }

                          return LineTooltipItem(
                            sb.toString(),
                            const TextStyle(fontSize: 11),
                          );
                        }).toList();
                      },
                    ),
                  ),
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
