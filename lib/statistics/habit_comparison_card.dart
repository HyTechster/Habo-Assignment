import 'package:flutter/material.dart';
import 'package:habo/generated/l10n.dart';
import 'package:habo/settings/settings_manager.dart';
import 'package:habo/statistics/statistics.dart';
import 'package:provider/provider.dart';

enum LeaderboardMetric { currentStreak, topStreak, completionRate }

enum LeaderboardSort { highestFirst, lowestFirst, byCategory }

/// Internal record for one habit's leaderboard entry after filtering/sorting.
class _LeaderboardEntry {
  final int index;
  final String title;
  final int currentStreak;
  final int topStreak;
  final double checkRate;
  final List<String> categories;

  const _LeaderboardEntry({
    required this.index,
    required this.title,
    required this.currentStreak,
    required this.topStreak,
    required this.checkRate,
    required this.categories,
  });
}

/// Leaderboard card ranking all non-archived habits by the active metric.
///
/// Replaces the previous bar chart (blueprint2 Phase 7). Three metric modes
/// (current streak, top streak, completion rate), three sort modes, and an
/// optional category filter.
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
  LeaderboardMetric _metric = LeaderboardMetric.currentStreak;
  LeaderboardSort _sort = LeaderboardSort.highestFirst;
  String? _selectedCategory; // null = all categories

  // ── Data helpers ──────────────────────────────────────────────────────────

  double _metricValue(_LeaderboardEntry e) {
    switch (_metric) {
      case LeaderboardMetric.currentStreak:
        return e.currentStreak.toDouble();
      case LeaderboardMetric.topStreak:
        return e.topStreak.toDouble();
      case LeaderboardMetric.completionRate:
        return e.checkRate;
    }
  }

  String _metricLabel(_LeaderboardEntry e) {
    switch (_metric) {
      case LeaderboardMetric.currentStreak:
        return '${e.currentStreak}d';
      case LeaderboardMetric.topStreak:
        return '${e.topStreak}d';
      case LeaderboardMetric.completionRate:
        return '${(e.checkRate * 100).round()}%';
    }
  }

  List<_LeaderboardEntry> _filteredSortedList() {
    final d = widget.data;

    // Build one entry per habit
    final entries = <_LeaderboardEntry>[
      for (int i = 0; i < d.habitTitles.length; i++)
        _LeaderboardEntry(
          index: i,
          title: d.habitTitles[i],
          currentStreak:
              i < d.actualStreaks.length ? d.actualStreaks[i] : 0,
          topStreak: d.topStreaks[i],
          checkRate: d.checkRates[i],
          categories: i < d.habitCategoryList.length
              ? d.habitCategoryList[i]
              : const [],
        ),
    ];

    // Category filter
    if (_selectedCategory != null) {
      entries
          .retainWhere((e) => e.categories.contains(_selectedCategory));
    }

    // Sort
    switch (_sort) {
      case LeaderboardSort.highestFirst:
        entries
            .sort((a, b) => _metricValue(b).compareTo(_metricValue(a)));
        break;
      case LeaderboardSort.lowestFirst:
        entries
            .sort((a, b) => _metricValue(a).compareTo(_metricValue(b)));
        break;
      case LeaderboardSort.byCategory:
        entries.sort((a, b) {
          // Uncategorised habits sort to the end (￿ > any letter)
          final catA = a.categories.isNotEmpty
              ? a.categories.first
              : '￿';
          final catB = b.categories.isNotEmpty
              ? b.categories.first
              : '￿';
          final cmp = catA.compareTo(catB);
          if (cmp != 0) return cmp;
          // Within the same category: highest metric first
          return _metricValue(b).compareTo(_metricValue(a));
        });
        break;
    }

    return entries;
  }

  // ── Widget builders ───────────────────────────────────────────────────────

  /// 32×32 toggle button — matches MonthlyGraph's Material button pattern.
  Widget _toggleButton({
    required bool active,
    required Color activeColor,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final primaryContainer =
        Theme.of(context).colorScheme.primaryContainer;
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

  Widget _rankWidget(int rank) {
    switch (rank) {
      case 1:
        return const Center(
            child: Text('🥇', style: TextStyle(fontSize: 18)));
      case 2:
        return const Center(
            child: Text('🥈', style: TextStyle(fontSize: 18)));
      case 3:
        return const Center(
            child: Text('🥉', style: TextStyle(fontSize: 18)));
      default:
        return Text(
          '$rank',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.5),
          ),
        );
    }
  }

  Widget _buildRow(
    _LeaderboardEntry entry,
    int rank,
    double maxValue,
  ) {
    final checkColor =
        Provider.of<SettingsManager>(context, listen: false).checkColor;
    final fraction = maxValue > 0
        ? (_metricValue(entry) / maxValue).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Fixed-width rank slot
          SizedBox(width: 32, child: _rankWidget(rank)),
          const SizedBox(width: 8),
          // Habit name — ellipsized
          Expanded(
            child: Text(
              entry.title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          // Proportional bar
          Expanded(
            flex: 2,
            child: ClipRect(
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    // Background track
                    Container(
                      decoration: BoxDecoration(
                        color: checkColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    // Filled portion
                    FractionallySizedBox(
                      widthFactor: fraction,
                      child: Container(
                        decoration: BoxDecoration(
                          color: checkColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Exact value — right-aligned in fixed slot
          SizedBox(
            width: 48,
            child: Text(
              _metricLabel(entry),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryHeader(String categoryTitle) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Text(
        // Empty title means uncategorised habits — label as "Other"
        categoryTitle.isEmpty
            ? S.of(context).heatmapCategoryOther
            : categoryTitle,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkColor =
        Provider.of<SettingsManager>(context, listen: false).checkColor;
    final primaryContainer =
        Theme.of(context).colorScheme.primaryContainer;

    final entries = _filteredSortedList();
    final maxValue = entries.isEmpty
        ? 0.0
        : entries
            .map(_metricValue)
            .reduce((a, b) => a > b ? a : b);

    // ── Build the ordered list of row/header/divider widgets ─────────────
    final List<Widget> rowWidgets = [];

    if (entries.isEmpty) {
      rowWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              S.of(context).leaderboardEmpty,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      );
    } else {
      bool needsThinDivider = false;
      String? lastCategory;
      int rank = 1;

      for (final entry in entries) {
        if (_sort == LeaderboardSort.byCategory) {
          final primaryCat =
              entry.categories.isNotEmpty ? entry.categories.first : '';

          if (primaryCat != lastCategory) {
            // New category group — thick divider (except before the very first)
            if (lastCategory != null) {
              rowWidgets.add(const Divider(height: 8, thickness: 1.5));
              needsThinDivider = false;
            }
            rowWidgets.add(_categoryHeader(primaryCat));
            lastCategory = primaryCat;
            needsThinDivider = false;
          }
        }

        // Thin divider between rows (not before the first row of each section)
        if (needsThinDivider) {
          rowWidgets.add(const Divider(height: 1));
        }

        rowWidgets.add(_buildRow(entry, rank, maxValue));
        needsThinDivider = true;
        rank++;
      }
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
            // ── Row 1: card title + metric toggle buttons ─────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    S.of(context).habitComparisonTitle,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                // Current streak
                _toggleButton(
                  active: _metric == LeaderboardMetric.currentStreak,
                  activeColor: checkColor,
                  icon: Icons.local_fire_department,
                  onPressed: () => setState(
                      () => _metric = LeaderboardMetric.currentStreak),
                ),
                // Top streak
                _toggleButton(
                  active: _metric == LeaderboardMetric.topStreak,
                  activeColor: Colors.amber,
                  icon: Icons.emoji_events,
                  onPressed: () => setState(
                      () => _metric = LeaderboardMetric.topStreak),
                ),
                // Completion rate
                _toggleButton(
                  active: _metric == LeaderboardMetric.completionRate,
                  activeColor: checkColor,
                  icon: Icons.check_circle_outline,
                  onPressed: () => setState(
                      () => _metric = LeaderboardMetric.completionRate),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // ── Row 2: sort dropdown + optional category filter ────────────
            Row(
              children: [
                DropdownButtonHideUnderline(
                  child: DropdownButton<LeaderboardSort>(
                    value: _sort,
                    isDense: true,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: LeaderboardSort.highestFirst,
                        child: Text(S.of(context).leaderboardSortHighest),
                      ),
                      DropdownMenuItem(
                        value: LeaderboardSort.lowestFirst,
                        child: Text(S.of(context).leaderboardSortLowest),
                      ),
                      DropdownMenuItem(
                        value: LeaderboardSort.byCategory,
                        child: Text(S.of(context).leaderboardSortByCategory),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _sort = value);
                    },
                  ),
                ),
                if (widget.data.allCategoryTitles.isNotEmpty) ...[
                  const SizedBox(width: 12),
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
                          child: Text(S.of(context).leaderboardFilterAll),
                        ),
                        ...widget.data.allCategoryTitles.map(
                          (cat) => DropdownMenuItem<String?>(
                            value: cat,
                            child: Text(cat),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedCategory = value),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // ── Habit rows (with dividers and optional category headers) ───
            ...rowWidgets,
          ],
        ),
      ),
    );
  }
}
