import 'package:flutter/material.dart';
import 'package:habo/generated/l10n.dart';
import 'package:habo/settings/settings_manager.dart';
import 'package:habo/statistics/statistics.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

enum _ViewMode { yearly, monthly }

/// Multi-row activity heatmap — one row per habit, grouped by category.
///
/// Two view modes:
///   Yearly  — 53 scrollable week-columns × 7 day-rows (default)
///   Monthly — 7-column calendar grid, day by day, no horizontal scroll
///
/// Level colour mapping:
///   0 = no event         → transparent (monthly: faint bg for in-month days)
///   1 = skip             → skipColor  at 35 % opacity
///   2 = fail             → failColor  at 25 % opacity
///   3 = check / complete → checkColor darkened by streak length (20 %→100 %)
///   4 = partial progress → progressColor at 35 % opacity
class YearlyHeatmapCard extends StatefulWidget {
  const YearlyHeatmapCard({
    super.key,
    required this.allHeatmaps,
    required this.allCategoryTitles,
  });

  final List<HeatmapData> allHeatmaps;
  final List<String> allCategoryTitles;

  @override
  State<YearlyHeatmapCard> createState() => _YearlyHeatmapCardState();
}

class _YearlyHeatmapCardState extends State<YearlyHeatmapCard> {
  late int _year;
  _ViewMode _viewMode = _ViewMode.yearly;
  int _month = DateTime.now().month;
  Set<String> _selectedCategories = {};

  // ── Grid geometry — yearly ─────────────────────────────────────────────────
  static const double _cellSize = 10.0;
  static const double _cellMargin = 1.5;
  static const double _columnWidth = _cellSize + _cellMargin * 2; // 13 px
  static const int _columns = 53;
  static const double _labelWidth = 80.0;

  // ── Grid geometry — monthly calendar (26 px cells, 7 fixed columns) ───────
  static const double _monthCellSize = 26.0;
  static const double _monthCellMargin = 2.0;
  static const double _monthCellWidth = _monthCellSize + _monthCellMargin * 2; // 30 px

  // Opacity table for level-3 cells: index = clamp(streakRunLength, 0, 10).
  static const List<double> _streakOpacity = [
    0.20, // 0  (fallback)
    0.20, // 1
    0.32, // 2
    0.44, // 3
    0.56, // 4
    0.68, // 5
    0.80, // 6
    0.86, // 7
    0.92, // 8
    0.96, // 9
    1.00, // 10+
  ];

  @override
  void initState() {
    super.initState();
    int latest = DateTime.now().year;
    for (final h in widget.allHeatmaps) {
      for (final d in h.dailyCounts.keys) {
        if (d.year > latest) latest = d.year;
      }
    }
    _year = latest;
  }

  // ── Data helpers ──────────────────────────────────────────────────────────

  List<int> _availableYears() {
    final years = <int>{DateTime.now().year};
    for (final h in widget.allHeatmaps) {
      for (final d in h.dailyCounts.keys) {
        years.add(d.year);
      }
    }
    return years.toList()..sort((a, b) => b.compareTo(a));
  }

  List<HeatmapData> _visibleHabits() {
    if (_selectedCategories.isEmpty) return widget.allHeatmaps;
    return widget.allHeatmaps
        .where((h) => _selectedCategories.contains(h.categoryTitle))
        .toList();
  }

  Color _cellColor(
      int level, DateTime date, HeatmapData heatmap, SettingsManager settings) {
    switch (level) {
      case 1:
        return settings.skipColor.withValues(alpha: 0.35);
      case 2:
        return settings.failColor.withValues(alpha: 0.25);
      case 3:
        final run = (heatmap.streakRunLengths[date] ?? 0).clamp(0, 10);
        return settings.checkColor.withValues(alpha: _streakOpacity[run]);
      case 4:
        return settings.progressColor.withValues(alpha: 0.35);
      default:
        return Colors.transparent;
    }
  }

  // ── Filter dialogs ────────────────────────────────────────────────────────

  Future<void> _showCategoryFilter() async {
    final hasUncategorised =
        widget.allHeatmaps.any((h) => h.categoryTitle.isEmpty);
    Set<String> pending = Set.from(_selectedCategories);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: Text(S.of(context).heatmapFilterCategoryTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasUncategorised)
                  CheckboxListTile(
                    title: Text(S.of(context).heatmapNoCategory),
                    value: pending.contains(''),
                    onChanged: (v) => setInner(() =>
                        v == true ? pending.add('') : pending.remove('')),
                  ),
                ...widget.allCategoryTitles.map((cat) => CheckboxListTile(
                      title: Text(cat),
                      value: pending.contains(cat),
                      onChanged: (v) => setInner(() =>
                          v == true ? pending.add(cat) : pending.remove(cat)),
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.of(context).cancel),
            ),
            TextButton(
              onPressed: () {
                setState(() => _selectedCategories = pending);
                Navigator.pop(ctx);
              },
              child: Text(S.of(context).heatmapFilterApply),
            ),
          ],
        ),
      ),
    );
  }

  // ── View mode toggle ──────────────────────────────────────────────────────

  Widget _buildViewToggleButton(
      String label, _ViewMode mode, Color checkColor) {
    final active = _viewMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _viewMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active
              ? checkColor.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            color: active ? checkColor : checkColor.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsManager>(context, listen: false);
    final checkColor = settings.checkColor;
    final muteColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    final visible = _visibleHabits();
    final bool isMonthly = _viewMode == _ViewMode.monthly;

    // Yearly grid anchor: Monday on or before January 1 of the selected year.
    final startOfYear = DateTime.utc(_year, 1, 1);
    final yearlyGridStart =
        startOfYear.subtract(Duration(days: startOfYear.weekday - 1));

    // Monthly calendar anchor: Monday on or before the 1st of the selected month.
    // monthlyRowCount = number of week-rows in the calendar (4–6).
    final firstOfMonth = DateTime.utc(_year, _month, 1);
    final int daysInMonth = DateTime.utc(_year, _month + 1, 0).day;
    final monthlyGridStart =
        firstOfMonth.subtract(Duration(days: firstOfMonth.weekday - 1));
    final int monthlyRowCount =
        ((firstOfMonth.weekday - 1 + daysInMonth) / 7).ceil();

    // Yearly header labels: grid-column index → abbreviated month name.
    final monthFormatter = DateFormat('MMM');
    final Map<int, String> headerLabels = {};
    for (int m = 1; m <= 12; m++) {
      final fom = DateTime.utc(_year, m, 1);
      final dayOffset = fom.difference(yearlyGridStart).inDays;
      if (dayOffset >= 0) {
        headerLabels[dayOffset ~/ 7] = monthFormatter.format(fom);
      }
    }

    // Group visible habits by categoryTitle (preserve first-occurrence order).
    final List<String> categoryOrder = [];
    final Map<String, List<HeatmapData>> groups = {};
    for (final h in visible) {
      if (!groups.containsKey(h.categoryTitle)) {
        categoryOrder.add(h.categoryTitle);
        groups[h.categoryTitle] = [];
      }
      groups[h.categoryTitle]!.add(h);
    }

    final bool showSectionHeaders = categoryOrder.length > 1;

    // Active filter summary text.
    final activeFilters = <String>[];
    if (_selectedCategories.isNotEmpty) {
      activeFilters.add(
          '${_selectedCategories.length} categor${_selectedCategories.length == 1 ? 'y' : 'ies'}');
    }

    // ── Shared section-header widget (used by both yearly and monthly) ────────
    Widget sectionHeader(String cat) => Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Row(
            children: [
              SizedBox(width: _labelWidth),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: checkColor.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                cat.isEmpty ? S.of(context).heatmapCategoryOther : cat,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: muteColor,
                ),
              ),
            ],
          ),
        );

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
            // ── Header: year/month dropdowns + view toggle + filter buttons ─
            Row(
              children: [
                // Year dropdown
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _year,
                    isDense: true,
                    items: _availableYears()
                        .map((y) => DropdownMenuItem<int>(
                              value: y,
                              child: Text(y.toString()),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _year = v);
                    },
                  ),
                ),
                // Month dropdown — only visible in monthly mode
                if (isMonthly) ...[
                  const SizedBox(width: 6),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _month,
                      isDense: true,
                      items: List.generate(
                        12,
                        (i) => DropdownMenuItem<int>(
                          value: i + 1,
                          child: Text(
                            DateFormat('MMM').format(DateTime(_year, i + 1)),
                          ),
                        ),
                      ),
                      onChanged: (v) {
                        if (v != null) setState(() => _month = v);
                      },
                    ),
                  ),
                ],
                const Spacer(),
                // Yearly / Monthly view toggle pill
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: checkColor.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildViewToggleButton(
                          'Year', _ViewMode.yearly, checkColor),
                      _buildViewToggleButton(
                          'Month', _ViewMode.monthly, checkColor),
                    ],
                  ),
                ),
                if (widget.allCategoryTitles.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: _showCategoryFilter,
                    icon: const Icon(Icons.label_outline, size: 16),
                    label: Text(
                      _selectedCategories.isEmpty
                          ? S.of(context).heatmapFilterCategories
                          : S.of(context).heatmapFilterSelected(
                              _selectedCategories.length),
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),

            // Active filter summary + clear link.
            if (activeFilters.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Text(
                      '${S.of(context).heatmapFilterShowing} ${activeFilters.join(', ')}',
                      style: TextStyle(fontSize: 11, color: muteColor),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() {
                        _selectedCategories = {};
                      }),
                      child: Text(
                        S.of(context).heatmapFilterClear,
                        style: TextStyle(
                          fontSize: 11,
                          color: checkColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // ── Heatmap body ──────────────────────────────────────────────
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    S.of(context).heatmapFilterEmpty,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else if (!isMonthly)
              // ── Yearly: 53-column horizontal scrollable heatmap ───────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month labels row.
                    SizedBox(
                      width: _labelWidth + _columns * _columnWidth,
                      height: 14,
                      child: Stack(
                        children: [
                          for (int col = 0; col < _columns; col++)
                            if (headerLabels.containsKey(col))
                              Positioned(
                                left: _labelWidth + col * _columnWidth,
                                child: Text(
                                  headerLabels[col]!,
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
                    // Habit rows.
                    for (final cat in categoryOrder) ...[
                      if (showSectionHeaders) ...[
                        if (cat != categoryOrder.first)
                          const Divider(height: 8, thickness: 1),
                        sectionHeader(cat),
                      ],
                      for (final h in groups[cat]!) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: _labelWidth,
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(right: 4, top: 1),
                                child: Text(
                                  h.title,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: List.generate(_columns, (col) {
                                return Column(
                                  children: List.generate(7, (row) {
                                    final cellDate = yearlyGridStart
                                        .add(Duration(days: col * 7 + row));
                                    final int level = cellDate.year != _year
                                        ? 0
                                        : h.dailyCounts[cellDate] ?? 0;
                                    return Container(
                                      width: _cellSize,
                                      height: _cellSize,
                                      margin:
                                          const EdgeInsets.all(_cellMargin),
                                      decoration: BoxDecoration(
                                        color: _cellColor(
                                            level, cellDate, h, settings),
                                        borderRadius:
                                            BorderRadius.circular(2),
                                      ),
                                    );
                                  }),
                                );
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                      ],
                    ],
                  ],
                ),
              )
            else
              // ── Monthly: day-by-day calendar grid (no horizontal scroll) ─
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day-of-week header: Mon Tue Wed Thu Fri Sat Sun
                  Row(
                    children: [
                      SizedBox(width: _labelWidth),
                      for (final label in const [
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                        'Sun',
                      ])
                        SizedBox(
                          width: _monthCellWidth,
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 8, color: muteColor),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Habit rows.
                  for (final cat in categoryOrder) ...[
                    if (showSectionHeaders) ...[
                      if (cat != categoryOrder.first)
                        const Divider(height: 8, thickness: 1),
                      sectionHeader(cat),
                    ],
                    for (final h in groups[cat]!) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Habit name label
                          SizedBox(
                            width: _labelWidth,
                            child: Padding(
                              padding:
                                  const EdgeInsets.only(right: 4, top: 2),
                              child: Text(
                                h.title,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                          // Calendar grid: rows = weeks, columns = day-of-week
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children:
                                List.generate(monthlyRowCount, (weekRow) {
                              return Row(
                                children: List.generate(7, (dayCol) {
                                  final cellDate = monthlyGridStart.add(
                                      Duration(
                                          days: weekRow * 7 + dayCol));
                                  final bool inMonth =
                                      cellDate.month == _month &&
                                      cellDate.year == _year;
                                  final int level = inMonth
                                      ? (h.dailyCounts[cellDate] ?? 0)
                                      : 0;
                                  final Color cellColor = !inMonth
                                      ? Colors.transparent
                                      : level == 0
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.06)
                                          : _cellColor(
                                              level, cellDate, h, settings);
                                  return Container(
                                    width: _monthCellSize,
                                    height: _monthCellSize,
                                    margin: const EdgeInsets.all(
                                        _monthCellMargin),
                                    decoration: BoxDecoration(
                                      color: cellColor,
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                  );
                                }),
                              );
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                  ],
                ],
              ),

            const SizedBox(height: 10),

            // ── Legend ────────────────────────────────────────────────────────
            Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Skipped
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: _cellSize,
                      height: _cellSize,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: settings.skipColor.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text('Skipped',
                        style: TextStyle(fontSize: 10, color: muteColor)),
                  ],
                ),
                // Failed
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: _cellSize,
                      height: _cellSize,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: settings.failColor.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text('Failed',
                        style: TextStyle(fontSize: 10, color: muteColor)),
                  ],
                ),
                // Partial — incomplete progressive habit (target not reached)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: _cellSize,
                      height: _cellSize,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color:
                            settings.progressColor.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text('Partial',
                        style: TextStyle(fontSize: 10, color: muteColor)),
                  ],
                ),
                // Complete: three cells show streak darkening (light → dark)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: _cellSize,
                      height: _cellSize,
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                        color: checkColor.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Container(
                      width: _cellSize,
                      height: _cellSize,
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                        color: checkColor.withValues(alpha: 0.60),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Container(
                      width: _cellSize,
                      height: _cellSize,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: checkColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text('Complete (streak ↑)',
                        style: TextStyle(fontSize: 10, color: muteColor)),
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
