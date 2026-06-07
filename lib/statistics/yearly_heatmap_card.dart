import 'package:flutter/material.dart';
import 'package:habo/generated/l10n.dart';
import 'package:habo/settings/settings_manager.dart';
import 'package:habo/statistics/statistics.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Displays a GitHub-style yearly activity heatmap for a single habit.
///
/// The grid is 53 columns × 7 rows (week × day-of-week). Column 0 starts on
/// the Monday on or before January 1 of the selected year; cells outside the
/// selected year are rendered at level 0 (grey padding).
///
/// Level colour mapping:
///   0 = no data  → surfaceContainerHighest
///   1 = skip     → skipColor  at 40 % opacity
///   2 = fail / partial progress → failColor at 60 % opacity
///   3 = check / completed progress → checkColor at full opacity
class YearlyHeatmapCard extends StatefulWidget {
  const YearlyHeatmapCard({super.key, required this.data});

  final HeatmapData data;

  @override
  State<YearlyHeatmapCard> createState() => _YearlyHeatmapCardState();
}

class _YearlyHeatmapCardState extends State<YearlyHeatmapCard> {
  late int year;

  // Grid geometry constants
  static const double _cellSize = 10.0;
  static const double _cellMargin = 1.5;
  static const double _columnWidth = _cellSize + _cellMargin * 2; // 13 px
  static const int _columns = 53;

  @override
  void initState() {
    super.initState();
    year = widget.data.year;
  }

  /// Sorted-descending list of years that have data, always including the
  /// current calendar year so the dropdown is never empty.
  List<int> _availableYears() {
    final years = widget.data.dailyCounts.keys.map((d) => d.year).toSet();
    years.add(DateTime.now().year);
    return years.toList()..sort((a, b) => b.compareTo(a));
  }

  @override
  Widget build(BuildContext context) {
    // Read colours once — consistent with SettingsManager listen: false convention
    final settings = Provider.of<SettingsManager>(context, listen: false);
    final level0Color = Theme.of(context).colorScheme.surfaceContainerHighest;
    final level1Color = settings.skipColor.withValues(alpha: 0.4);
    final level2Color = settings.failColor.withValues(alpha: 0.6);
    final level3Color = settings.checkColor;
    final muteColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    // Local helpers — defined here to capture pre-computed colours without
    // repeating Provider.of inside the 371-cell grid loop.
    Color levelColor(int level) {
      switch (level) {
        case 1:
          return level1Color;
        case 2:
          return level2Color;
        case 3:
          return level3Color;
        default:
          return level0Color;
      }
    }

    String levelLabel(int level) {
      switch (level) {
        case 1:
          return S.of(context).heatmapLevelSkipped;
        case 2:
          return S.of(context).heatmapLevelFailed;
        case 3:
          return S.of(context).heatmapLevelCompleted;
        default:
          return S.of(context).heatmapLevelNoData;
      }
    }

    // Grid anchor: Monday on or before January 1 of the selected year.
    // DateTime.weekday: 1 = Monday … 7 = Sunday.
    final startOfYear = DateTime.utc(year, 1, 1);
    final gridStart =
        startOfYear.subtract(Duration(days: startOfYear.weekday - 1));

    // Month label positions: grid-column index → abbreviated month name.
    // Create formatter once, not inside the loop.
    final monthFormatter = DateFormat('MMM');
    final tooltipFormatter = DateFormat('d MMM yyyy');
    final Map<int, String> monthColumns = {};
    for (int m = 1; m <= 12; m++) {
      final firstOfMonth = DateTime.utc(year, m, 1);
      final dayOffset = firstOfMonth.difference(gridStart).inDays;
      if (dayOffset >= 0) {
        monthColumns[dayOffset ~/ 7] = monthFormatter.format(firstOfMonth);
      }
    }

    return Material(
      borderRadius: BorderRadius.circular(15.0),
      color: Theme.of(context).colorScheme.primaryContainer,
      shadowColor: Theme.of(context).shadowColor,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: habit title + year dropdown ──────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.data.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: year,
                    items: _availableYears()
                        .map((y) => DropdownMenuItem<int>(
                              value: y,
                              child: Text(y.toString()),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => year = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Month labels + heatmap grid ───────────────────────────────
            // Wrapped in SingleChildScrollView so the 689 px-wide grid scrolls
            // horizontally without overflowing the card on narrow screens.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month labels use a Stack with Positioned children so label
                  // text can overflow into the next column's space naturally,
                  // matching the GitHub contribution-graph style.
                  SizedBox(
                    width: _columns * _columnWidth,
                    height: 14,
                    child: Stack(
                      children: [
                        for (int col = 0; col < _columns; col++)
                          if (monthColumns.containsKey(col))
                            Positioned(
                              left: col * _columnWidth,
                              child: Text(
                                monthColumns[col]!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontSize: 9),
                              ),
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),

                  // 53 columns × 7 rows of coloured squares.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(_columns, (col) {
                      return Column(
                        children: List.generate(7, (row) {
                          final cellDate =
                              gridStart.add(Duration(days: col * 7 + row));

                          // Cells outside the selected year are padding (grey).
                          final int level;
                          if (cellDate.year != year) {
                            level = 0;
                          } else {
                            level =
                                widget.data.dailyCounts[cellDate] ?? 0;
                          }

                          return GestureDetector(
                            onTap: () {
                              // Tapping a padding cell outside the year does nothing.
                              if (cellDate.year != year) return;
                              ScaffoldMessenger.of(context)
                                  .hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  duration: const Duration(seconds: 2),
                                  content: Text(
                                    '${tooltipFormatter.format(cellDate)} — ${levelLabel(level)}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: _cellSize,
                              height: _cellSize,
                              margin: const EdgeInsets.all(_cellMargin),
                              decoration: BoxDecoration(
                                color: levelColor(level),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        }),
                      );
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Legend: Less [0] [1] [2] [3] More ────────────────────────
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(S.of(context).heatmapLegendLess, style: TextStyle(fontSize: 10, color: muteColor)),
                const SizedBox(width: 4),
                for (int lvl = 0; lvl <= 3; lvl++)
                  Container(
                    width: _cellSize,
                    height: _cellSize,
                    margin:
                        const EdgeInsets.symmetric(horizontal: _cellMargin),
                    decoration: BoxDecoration(
                      color: levelColor(lvl),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                const SizedBox(width: 4),
                Text(S.of(context).heatmapLegendMore, style: TextStyle(fontSize: 10, color: muteColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
