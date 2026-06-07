import 'dart:math' show max;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:habo/generated/l10n.dart';
import 'package:habo/settings/settings_manager.dart';
import 'package:habo/statistics/statistics.dart';
import 'package:provider/provider.dart';

/// Renders a horizontally scrollable grouped bar chart comparing all
/// non-archived habits side by side.
///
/// Each habit group shows up to two rods:
///   • Check rate (green): [checkRates[i] × maxY] — scaled to the same axis
///     as the streak so both rods share one y-axis.
///   • Top streak (orange): [topStreaks[i]] days.
///
/// The caller is responsible for the null guard — [ComparisonData] is only
/// null when fewer than 2 non-archived habits exist.
class HabitComparisonCard extends StatefulWidget {
  const HabitComparisonCard({super.key, required this.data});

  final ComparisonData data;

  @override
  State<HabitComparisonCard> createState() => _HabitComparisonCardState();
}

class _HabitComparisonCardState extends State<HabitComparisonCard> {
  bool showCheckRate = true;
  bool showTopStreak = true;

  /// Truncates [title] to 6 characters and appends "…" when longer.
  String _abbreviate(String title) {
    const maxChars = 6;
    if (title.length <= maxChars) return title;
    return '${title.substring(0, maxChars)}…';
  }

  @override
  Widget build(BuildContext context) {
    // Read colours once — listen: false convention used throughout statistics widgets
    final settings = Provider.of<SettingsManager>(context, listen: false);
    final checkColor = settings.checkColor;
    final gridLineColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    final primaryContainer = Theme.of(context).colorScheme.primaryContainer;
    final muteColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    // maxY: max top-streak value rounded up to the nearest 5, minimum 10.
    final maxTopStreak = widget.data.topStreaks.isNotEmpty
        ? widget.data.topStreaks.reduce(max)
        : 0;
    final double maxY =
        max(10.0, ((maxTopStreak / 5.0).ceil() * 5.0).toDouble());

    final double rodWidth = (showCheckRate && showTopStreak) ? 8.0 : 12.0;
    final int habitCount = widget.data.habitTitles.length;
    final double chartWidth =
        max(MediaQuery.of(context).size.width, habitCount * 60.0);

    // ── Local title builders ─────────────────────────────────────────────

    Widget bottomTitle(double value, TitleMeta meta) {
      final index = value.round();
      if (index < 0 || index >= widget.data.habitTitles.length) {
        return const SizedBox.shrink();
      }
      return SideTitleWidget(
        meta: meta,
        space: 4,
        child: Text(
          _abbreviate(widget.data.habitTitles[index]),
          style: const TextStyle(fontSize: 9),
        ),
      );
    }

    Widget leftTitle(double value, TitleMeta meta) {
      final double half = maxY / 2;
      final String label;
      if (value.abs() < 0.5) {
        label = '0';
      } else if ((value - half).abs() < 0.5) {
        label = half.round().toString();
      } else if ((value - maxY).abs() < 0.5) {
        label = maxY.round().toString();
      } else {
        return const SizedBox.shrink();
      }
      return SideTitleWidget(
        meta: meta,
        space: 4,
        child: Text(label, style: const TextStyle(fontSize: 9)),
      );
    }

    // ── Bar groups: one per habit, up to 2 rods ──────────────────────────

    List<BarChartGroupData> buildBarGroups() {
      return List.generate(habitCount, (i) {
        return BarChartGroupData(
          x: i,
          barRods: [
            if (showCheckRate)
              BarChartRodData(
                toY: widget.data.checkRates[i] * maxY,
                color: checkColor,
                width: rodWidth,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            if (showTopStreak)
              BarChartRodData(
                toY: widget.data.topStreaks[i].toDouble(),
                color: Colors.orange,
                width: rodWidth,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            // Transparent placeholder keeps the chart alive when both are off
            if (!showCheckRate && !showTopStreak)
              BarChartRodData(
                toY: 0,
                color: Colors.transparent,
                width: 4,
              ),
          ],
        );
      });
    }

    // ── Toggle button: matches MonthlyGraph's 32×32 Material pattern ─────

    Widget toggleButton({
      required bool active,
      required Color activeColor,
      required IconData icon,
      required VoidCallback onPressed,
    }) {
      return Padding(
        padding: const EdgeInsets.all(4.0),
        child: Material(
          color: active ? activeColor : primaryContainer,
          borderRadius: BorderRadius.circular(10.0),
          elevation: 2,
          child: SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              splashColor: Colors.transparent,
              padding: EdgeInsets.zero,
              icon: Icon(icon, size: 16),
              color: active ? Colors.white : activeColor,
              onPressed: onPressed,
            ),
          ),
        ),
      );
    }

    return Card(
      color: primaryContainer,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header + toggle buttons ───────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    S.of(context).habitComparisonTitle,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                toggleButton(
                  active: showCheckRate,
                  activeColor: checkColor,
                  icon: Icons.check_circle_outline,
                  onPressed: () =>
                      setState(() => showCheckRate = !showCheckRate),
                ),
                toggleButton(
                  active: showTopStreak,
                  activeColor: Colors.orange,
                  icon: Icons.local_fire_department,
                  onPressed: () =>
                      setState(() => showTopStreak = !showTopStreak),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Horizontally scrollable bar chart ─────────────────────────
            // Width = max(screen width, habitCount × 60 px) so that many habits
            // trigger horizontal scroll while a small number fills the card.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: chartWidth,
                height: 180,
                child: BarChart(
                  BarChartData(
                    maxY: maxY,
                    alignment: BarChartAlignment.spaceAround,
                    barTouchData: BarTouchData(enabled: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      drawHorizontalLine: true,
                      horizontalInterval: maxY / 2,
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
                          reservedSize: 22,
                          getTitlesWidget: bottomTitle,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          interval: maxY / 2,
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
                    barGroups: buildBarGroups(),
                  ),
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.linear,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Legend ────────────────────────────────────────────────────
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: checkColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      S.of(context).comparisonCheckRateLabel,
                      style: TextStyle(fontSize: 10, color: muteColor),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      S.of(context).comparisonTopStreakLabel,
                      style: TextStyle(fontSize: 10, color: muteColor),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
