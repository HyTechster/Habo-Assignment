import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:habo/generated/l10n.dart';
import 'package:habo/settings/settings_manager.dart';
import 'package:habo/statistics/statistics.dart';
import 'package:provider/provider.dart';

/// Renders a line chart of the overall completion rate across the past 12 weeks.
///
/// Each of the 12 data points (index 0 = oldest, 11 = most recent) represents
/// the fraction of logged days in that week on which at least one habit was
/// check-equivalent. A flat zero line is a valid state (no data in the window).
///
/// The caller is responsible for the null guard — [WeeklyTrendData] is only
/// null when the 12-week window contains zero events.
class WeeklyTrendCard extends StatelessWidget {
  const WeeklyTrendCard({super.key, required this.data});

  final WeeklyTrendData data;

  @override
  Widget build(BuildContext context) {
    // Read colours once — consistent with listen: false convention used across
    // all statistics widgets (colour changes are not live-reactive here).
    final checkColor =
        Provider.of<SettingsManager>(context, listen: false).checkColor;
    final gridLineColor =
        Theme.of(context).colorScheme.surfaceContainerHighest;

    // Convert weekly rates to chart spots (index = x, rate = y).
    final spots = List.generate(
      data.weeklyRates.length,
      (i) => FlSpot(i.toDouble(), data.weeklyRates[i]),
    );

    // Bottom-axis label widget — only rendered for indices 0, 3, 6, 9, 11.
    Widget bottomTitle(double value, TitleMeta meta) {
      final index = value.round();
      if (![0, 3, 6, 9, 11].contains(index) ||
          index >= data.weekLabels.length) {
        return const SizedBox.shrink();
      }
      return SideTitleWidget(
        meta: meta,
        space: 4,
        child: Text(
          data.weekLabels[index],
          style: const TextStyle(fontSize: 9),
        ),
      );
    }

    // Left-axis label widget — 0 %, 50 %, 100 % only.
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Text(
              S.of(context).weeklyTrendTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // ── Line chart ────────────────────────────────────────────────
            SizedBox(
              height: 140,
              child: LineChart(
                LineChartData(
                  minY: 0.0,
                  maxY: 1.0,

                  // Single line: completion rate over 12 weeks
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: checkColor,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                          radius: 3,
                          color: checkColor,
                          strokeColor: checkColor,
                          strokeWidth: 1,
                        ),
                      ),
                      // Filled area below the line at 20 % opacity
                      belowBarData: BarAreaData(
                        show: true,
                        color: checkColor.withValues(alpha: 0.2),
                      ),
                    ),
                  ],

                  // Horizontal grid lines at 25 % intervals; no vertical lines
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

                  // No border box — matches MonthlyGraph convention
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

                  // Touch disabled — consistent with MonthlyGraph
                  lineTouchData: LineTouchData(enabled: false),
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
