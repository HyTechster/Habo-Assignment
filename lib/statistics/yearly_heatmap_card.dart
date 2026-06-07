import 'package:flutter/material.dart';
import 'package:habo/generated/l10n.dart';
import 'package:habo/settings/settings_manager.dart';
import 'package:habo/statistics/statistics.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Multi-row yearly activity heatmap — one row per habit, grouped by category.
///
/// Constructor change (Phase 9): previously accepted a single [HeatmapData];
/// now accepts [allHeatmaps] (all habits) and [allCategoryTitles] (for the
/// category filter dropdown). The call site in statistics_screen.dart is
/// updated in Phase 10.
///
/// Level colour mapping:
///   0 = no event         → transparent
///   1 = skip             → skipColor  at 35 % opacity (fixed)
///   2 = fail / partial   → failColor  at 25 % opacity (fixed)
///   3 = check / complete → checkColor darkened by consecutive-streak length
///       day 1 → 20 %, day 2 → 32 %, … day 10+ → 100 %
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
  Set<String> _selectedCategories = {};
  Set<String> _selectedHabitTitles = {};

  // Grid geometry
  static const double _cellSize = 10.0;
  static const double _cellMargin = 1.5;
  static const double _columnWidth = _cellSize + _cellMargin * 2; // 13 px
  static const int _columns = 53;
  static const double _labelWidth = 80.0;

  // Opacity for level-3 cells indexed by clamp(streakRunLength, 0, 10).
  // Index 0 is a defensive fallback for a level-3 cell with no run entry.
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
    // Start on the most recent year that has any data; fall back to current year.
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
    var list = widget.allHeatmaps;
    if (_selectedCategories.isNotEmpty) {
      list = list
          .where((h) => _selectedCategories.contains(h.categoryTitle))
          .toList();
    }
    if (_selectedHabitTitles.isNotEmpty) {
      list =
          list.where((h) => _selectedHabitTitles.contains(h.title)).toList();
    }
    return list;
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

  Future<void> _showHabitFilter() async {
    // Show only habits that pass the current category filter.
    final habitsToShow = _selectedCategories.isEmpty
        ? widget.allHeatmaps
        : widget.allHeatmaps
            .where((h) => _selectedCategories.contains(h.categoryTitle))
            .toList();

    Set<String> pending = Set.from(_selectedHabitTitles);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: Text(S.of(context).heatmapFilterHabitTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: habitsToShow
                  .map((h) => CheckboxListTile(
                        title: Text(h.title),
                        value: pending.contains(h.title),
                        onChanged: (v) => setInner(() => v == true
                            ? pending.add(h.title)
                            : pending.remove(h.title)),
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.of(context).cancel),
            ),
            TextButton(
              onPressed: () {
                setState(() => _selectedHabitTitles = pending);
                Navigator.pop(ctx);
              },
              child: Text(S.of(context).heatmapFilterApply),
            ),
          ],
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

    // Grid anchor: Monday on or before January 1 of the selected year.
    final startOfYear = DateTime.utc(_year, 1, 1);
    final gridStart =
        startOfYear.subtract(Duration(days: startOfYear.weekday - 1));

    // Month label column positions (grid-column index → abbreviated name).
    final monthFormatter = DateFormat('MMM');
    final Map<int, String> monthColumns = {};
    for (int m = 1; m <= 12; m++) {
      final firstOfMonth = DateTime.utc(_year, m, 1);
      final dayOffset = firstOfMonth.difference(gridStart).inDays;
      if (dayOffset >= 0) {
        monthColumns[dayOffset ~/ 7] = monthFormatter.format(firstOfMonth);
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
    if (_selectedHabitTitles.isNotEmpty) {
      activeFilters.add(
          '${_selectedHabitTitles.length} habit${_selectedHabitTitles.length == 1 ? '' : 's'}');
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
            // ── Header: year dropdown + filter buttons ────────────────────
            Row(
              children: [
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
                const Spacer(),
                if (widget.allCategoryTitles.isNotEmpty)
                  TextButton.icon(
                    onPressed: _showCategoryFilter,
                    icon: const Icon(Icons.label_outline, size: 16),
                    label: Text(
                      _selectedCategories.isEmpty
                          ? S.of(context).heatmapFilterCategories
                          : S.of(context).heatmapFilterSelected(_selectedCategories.length),
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                TextButton.icon(
                  onPressed: _showHabitFilter,
                  icon: const Icon(Icons.filter_list, size: 16),
                  label: Text(
                    _selectedHabitTitles.isEmpty
                        ? S.of(context).heatmapFilterHabits
                        : S.of(context).heatmapFilterSelected(_selectedHabitTitles.length),
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
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
                        _selectedHabitTitles = {};
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
            else
              // Month labels and all habit rows live inside one
              // SingleChildScrollView so they always scroll in sync.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month labels — offset by _labelWidth to align with grids.
                    SizedBox(
                      width: _labelWidth + _columns * _columnWidth,
                      height: 14,
                      child: Stack(
                        children: [
                          for (int col = 0; col < _columns; col++)
                            if (monthColumns.containsKey(col))
                              Positioned(
                                left: _labelWidth + col * _columnWidth,
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

                    // Habit rows grouped by category.
                    for (final cat in categoryOrder) ...[
                      if (showSectionHeaders) ...[
                        // Section divider (not before the very first group).
                        if (cat != categoryOrder.first)
                          const Divider(height: 8, thickness: 1),
                        // Section header: coloured dot + category name.
                        Padding(
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
                        ),
                      ],
                      for (final h in groups[cat]!) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Fixed-width habit name label.
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
                            // 53 × 7 cell grid.
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: List.generate(_columns, (col) {
                                return Column(
                                  children: List.generate(7, (row) {
                                    final cellDate = gridStart
                                        .add(Duration(days: col * 7 + row));
                                    final int level = cellDate.year != _year
                                        ? 0
                                        : h.dailyCounts[cellDate] ?? 0;

                                    return Container(
                                      width: _cellSize,
                                      height: _cellSize,
                                      margin: const EdgeInsets.all(_cellMargin),
                                      decoration: BoxDecoration(
                                        color: _cellColor(
                                            level, cellDate, h, settings),
                                        borderRadius: BorderRadius.circular(2),
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
              ),

            const SizedBox(height: 10),

            // ── Legend: Less [skip] [fail] [check day1] [check day10+] More
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  S.of(context).heatmapLegendLess,
                  style: TextStyle(fontSize: 10, color: muteColor),
                ),
                const SizedBox(width: 4),
                // Level 0 — transparent placeholder shown as faint outline
                Container(
                  width: _cellSize,
                  height: _cellSize,
                  margin: const EdgeInsets.symmetric(horizontal: _cellMargin),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Level 1 — skip
                Container(
                  width: _cellSize,
                  height: _cellSize,
                  margin: const EdgeInsets.symmetric(horizontal: _cellMargin),
                  decoration: BoxDecoration(
                    color: settings.skipColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Level 2 — fail / partial
                Container(
                  width: _cellSize,
                  height: _cellSize,
                  margin: const EdgeInsets.symmetric(horizontal: _cellMargin),
                  decoration: BoxDecoration(
                    color: settings.failColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Level 3 — check (full opacity = long streak)
                Container(
                  width: _cellSize,
                  height: _cellSize,
                  margin: const EdgeInsets.symmetric(horizontal: _cellMargin),
                  decoration: BoxDecoration(
                    color: checkColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  S.of(context).heatmapLegendMore,
                  style: TextStyle(fontSize: 10, color: muteColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
