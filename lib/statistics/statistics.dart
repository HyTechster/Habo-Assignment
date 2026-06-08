import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:habo/constants.dart';
import 'package:habo/habits/habit.dart';
import 'package:intl/intl.dart';

class StatisticsData {
  String title = '';
  int topStreak = 0;
  int actualStreak = 0;
  int checks = 0;
  int skips = 0;
  int fails = 0;
  int progress = 0; // Add progress as separate category
  SplayTreeMap<int, Map<DayType, List<int>>> monthlyCheck = SplayTreeMap();
}

class OverallStatisticsData {
  int checks = 0;
  int skips = 0;
  int fails = 0;
  int progress = 0; // Add progress as separate category
}

class AllStatistics {
  OverallStatisticsData total = OverallStatisticsData();
  List<StatisticsData> habitsData = [];
  List<HeatmapData> heatmaps = [];
  WeeklyTrendData? overallWeeklyTrend;
  ComparisonData? comparison;
  BestDayTimeData bestDayTime = BestDayTimeData();

  /// Deduplicated, sorted category names across all non-archived habits.
  /// Shared between the leaderboard, heatmap, and weekly trend filter dropdowns.
  /// Computed once by calculateComparison() and/or calculateHeatmaps() so
  /// statistics_screen.dart can pass it to any widget without recalculating.
  List<String> allCategoryTitles = [];
}

/// Heatmap completion levels for a single day:
///   0 = no event / DayType.clear
///   1 = skip
///   2 = fail
///   3 = check OR completed progress (target reached)
///   4 = partial progress (target not reached)
///
/// Keys are normalised to midnight UTC: DateTime.utc(year, month, day).
/// Do not use the raw event datetime (stored at noon UTC) as a map key.
///
/// New multi-row heatmap fields (populated in Phase 5 of blueprint2):
/// [habitColor] — reserved for future per-habit colour; null falls back to checkColor.
/// [categoryTitle] — primary category title for grouping rows under section headers.
/// [categoryId] — primary category ID for stable sort ordering; null if no categories.
/// [streakRunLengths] — consecutive level-3 run length ending on each completed day,
///   capped at 10. Used to darken the cell colour as a streak grows. Keys are the same
///   midnight-UTC DateTimes as [dailyCounts]; missing key defaults to 0 in the widget.
class HeatmapData {
  String title;
  Map<DateTime, int> dailyCounts;
  int year;

  // Multi-row heatmap fields
  Color? habitColor;
  String categoryTitle;
  int? categoryId;
  Map<DateTime, int> streakRunLengths;

  HeatmapData({
    required this.title,
    Map<DateTime, int>? dailyCounts,
    int? year,
    this.habitColor,
    this.categoryTitle = '',
    this.categoryId,
    Map<DateTime, int>? streakRunLengths,
  })  : dailyCounts = dailyCounts ?? {},
        year = year ?? DateTime.now().year,
        streakRunLengths = streakRunLengths ?? {};
}

/// Completion-rate trend across the most recent 12 weeks.
///
/// [weeklyRates] — exactly 12 elements; index 0 = oldest, 11 = most recent.
/// Each value is in [0.0, 1.0]: check-equivalent days / total logged days.
/// 0.0 when no events were logged in a week.
///
/// [weekLabels] — exactly 12 elements; short label for the Monday of each
/// week formatted as "MMM d" (e.g. "May 5"). Index-aligned to weeklyRates.
///
/// New tooltip and filter fields (populated in Phase 6 of blueprint2):
/// [weekCompletedHabits] — exactly 12 elements. Each inner list holds the
///   titles of habits that had at least one level-3 (check-equivalent) day
///   during that week, in the order they appear in allHabits.
/// [allCategoryTitles] — deduplicated, sorted category names across all habits
///   in this trend; populates the category filter dropdown in WeeklyTrendCard.
/// [habitCategoryMap] — maps habit title → list of category titles; allows the
///   widget to compute filtered rates client-side without a server round-trip.
class WeeklyTrendData {
  String title;
  List<double> weeklyRates;
  List<String> weekLabels;

  // Tooltip payload fields
  List<List<String>> weekCompletedHabits;
  List<String> allCategoryTitles;

  // Category-filter support: habitTitle → [categoryTitle, ...]
  Map<String, List<String>> habitCategoryMap;

  WeeklyTrendData({
    required this.title,
    required this.weeklyRates,
    required this.weekLabels,
    List<List<String>>? weekCompletedHabits,
    this.allCategoryTitles = const [],
    Map<String, List<String>>? habitCategoryMap,
  })  : weekCompletedHabits =
            weekCompletedHabits ?? List.generate(12, (_) => []),
        habitCategoryMap = habitCategoryMap ?? {};
}

/// Side-by-side comparison of check rates and streaks across non-archived habits.
///
/// Only non-archived habits are included (see calculateComparison in Statistics).
/// [colors] is reserved for future per-habit color assignment; currently all null.
///
/// New leaderboard fields (populated in Phase 4 of blueprint2):
/// [actualStreaks] — current running streak per habit (forward-scan, same index as habitTitles).
/// [habitCategories] — comma-joined category names per habit; empty string if none.
/// [habitCategoryList] — raw list of category title strings per habit; used for filter matching.
/// [allCategoryTitles] — deduplicated, sorted list of all category names across the filtered habits.
class ComparisonData {
  List<String> habitTitles;
  List<double> checkRates;
  List<int> topStreaks;
  List<Color?> colors;

  // Leaderboard fields — populated in calculateComparison()
  List<int> actualStreaks;
  List<String> habitCategories;
  List<List<String>> habitCategoryList;
  List<String> allCategoryTitles;

  // Per-habit raw event counts — populated in calculateComparison()
  List<int> totalChecks;
  List<int> totalSkips;
  List<int> totalProgress;
  List<int> totalFails;

  ComparisonData({
    required this.habitTitles,
    required this.checkRates,
    required this.topStreaks,
    required this.colors,
    this.actualStreaks = const [],
    this.habitCategories = const [],
    this.habitCategoryList = const [],
    this.allCategoryTitles = const [],
    this.totalChecks = const [],
    this.totalSkips = const [],
    this.totalProgress = const [],
    this.totalFails = const [],
  });
}

/// Best day-of-week and best time-of-day derived from the user's event history
/// and habit notification schedules.
///
/// [bestDayOfWeek] — full English weekday name (e.g. "Monday"), or null when
/// the total sample is fewer than 14 check-equivalent events.
///
/// [bestTimeOfDay] — one of "Morning" / "Afternoon" / "Evening" / "Night",
/// derived from habit notification times (not event timestamps). null if no
/// habits have notifications enabled.
///
/// [dayOfWeekRates] — always exactly 7 entries (Monday–Sunday); 0.0 when no
/// data exists for a weekday.
class BestDayTimeData {
  String? bestDayOfWeek;
  double bestDayRate;
  String? bestTimeOfDay;
  Map<String, double> dayOfWeekRates;

  BestDayTimeData({
    this.bestDayOfWeek,
    this.bestDayRate = 0.0,
    this.bestTimeOfDay,
    Map<String, double>? dayOfWeekRates,
  }) : dayOfWeekRates = dayOfWeekRates ??
            {
              'Monday': 0.0,
              'Tuesday': 0.0,
              'Wednesday': 0.0,
              'Thursday': 0.0,
              'Friday': 0.0,
              'Saturday': 0.0,
              'Sunday': 0.0,
            };
}

class Statistics {
  static Future<AllStatistics> calculateStatistics(List<Habit>? habits) async {
    AllStatistics stats = AllStatistics();

    if (habits == null) return stats;

    for (var habit in habits) {
      var stat = StatisticsData();
      stat.title = habit.habitData.title;

      bool usingTwoDayRule = false;

      var lastDay = habit.habitData.events.firstKey();

      habit.habitData.events.forEach(
        (key, value) {
          if (value[0] != null && value[0] != DayType.clear) {
            if (key.difference(lastDay!).inDays > 1) {
              stat.actualStreak = 0;
            }

            switch (value[0]) {
              case DayType.check:
                stat.checks++;
                stat.actualStreak++;
                if (stat.actualStreak > stat.topStreak) {
                  stat.topStreak = stat.actualStreak;
                }
                usingTwoDayRule = false;
                break;
              case DayType.progress:
                // Handle numeric habit progress events as separate category
                stat.progress++;
                if (habit.habitData.isNumeric && value.length > 2) {
                  final progressValue = (value[2] as num?)?.toDouble() ?? 0.0;
                  // Use stored target value for completion check
                  final targetAtTime = (value.length > 3)
                      ? (value[3] as num?)?.toDouble() ??
                          habit.habitData.targetValue
                      : habit.habitData.targetValue;
                  if (progressValue >= targetAtTime) {
                    // 100% or more = maintain streak
                    stat.actualStreak++;
                    if (stat.actualStreak > stat.topStreak) {
                      stat.topStreak = stat.actualStreak;
                    }
                    usingTwoDayRule = false;
                  }
                } else {
                  // Fallback for non-numeric progress events
                  if (usingTwoDayRule) {
                    stat.actualStreak = 0;
                  }
                }
                usingTwoDayRule = false;
                break;
              case DayType.skip:
                stat.skips++;
                if (usingTwoDayRule) {
                  stat.actualStreak = 0;
                }
                break;
              case DayType.fail:
                stat.fails++;
                if (habit.habitData.twoDayRule) {
                  if (usingTwoDayRule) {
                    stat.actualStreak = 0;
                  } else {
                    usingTwoDayRule = true;
                  }
                } else {
                  stat.actualStreak = 0;
                }
                break;
            }

            generateYearIfNull(stat, key.year);

            if (value[0] != DayType.clear) {
              // Track all event types including progress in monthly stats
              stat.monthlyCheck[key.year]![value[0]]![key.month - 1]++;
            }

            lastDay = key;
          }
        },
      );

      generateYearIfNull(stat, DateTime.now().year);
      stats.habitsData.add(stat);
      stats.total.checks += stat.checks;
      stats.total.fails += stat.fails;
      stats.total.skips += stat.skips;
      stats.total.progress += stat.progress; // Add progress to totals
    }

    // Populate the four enhanced statistics fields.
    // Note: allHabits is passed unfiltered here; comparison filters internally.
    stats.heatmaps = calculateHeatmaps(habits, DateTime.now().year);

    // Phase 5 §5.3 — derive allCategoryTitles from heatmaps (covers all habits,
    // including archived, because calculateHeatmaps receives unfiltered allHabits).
    stats.allCategoryTitles = stats.heatmaps
        .map((h) => h.categoryTitle)
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    stats.overallWeeklyTrend = calculateWeeklyTrend(habits);
    stats.comparison = calculateComparison(habits, stats.habitsData);
    stats.bestDayTime = calculateBestDayTime(habits);

    // Phase 4 §4.2 — overwrite allCategoryTitles with the non-archived-only
    // version when a comparison result is available. This is the preferred source
    // because it excludes archived habits from the filter dropdowns.
    if (stats.comparison != null) {
      stats.allCategoryTitles = stats.comparison!.allCategoryTitles;
    }

    return stats;
  }

  /// Returns a [HeatmapData] per habit for the given [year].
  ///
  /// Keys in [HeatmapData.dailyCounts] are midnight-UTC [DateTime] values so
  /// that same-day events from any timezone compare equal under ==.
  /// [DayType.clear] events are skipped — same guard as [calculateStatistics].
  static List<HeatmapData> calculateHeatmaps(List<Habit> habits, int year) {
    final List<HeatmapData> result = [];

    for (var habit in habits) {
      final heatmap = HeatmapData(title: habit.habitData.title, year: year);

      // Populate category fields from the first category (if any) — Phase 5 §5.1
      if (habit.habitData.categories.isNotEmpty) {
        heatmap.categoryTitle = habit.habitData.categories.first.title;
        heatmap.categoryId = habit.habitData.categories.first.id;
      }

      habit.habitData.events.forEach((key, value) {
        if (value[0] != null &&
            value[0] != DayType.clear &&
            key.year == year) {
          final normalised = DateTime.utc(key.year, key.month, key.day);
          final dayType = value[0] as DayType;
          int level;

          switch (dayType) {
            case DayType.check:
              level = 3;
              break;
            case DayType.skip:
              level = 1;
              break;
            case DayType.fail:
              level = 2;
              break;
            case DayType.progress:
              if (value.length > 2) {
                final progressValue = (value[2] as num?)?.toDouble() ?? 0.0;
                final targetAtTime = (value.length > 3)
                    ? (value[3] as num?)?.toDouble() ??
                        habit.habitData.targetValue
                    : habit.habitData.targetValue;
                level = progressValue >= targetAtTime ? 3 : 2;
              } else {
                level = 2;
              }
              break;
            default:
              level = 0;
          }

          heatmap.dailyCounts[normalised] = level;
        }
      });

      // Phase 5 §5.2 — compute streakRunLengths in a second pass over dailyCounts.
      // Sort explicitly even though SplayTreeMap would already be ordered — the
      // dailyCounts map is a plain HashMap whose keys have no guaranteed order.
      final sortedDates = heatmap.dailyCounts.keys.toList()..sort();
      int currentRun = 0;
      DateTime? prevDate;

      for (final date in sortedDates) {
        final level = heatmap.dailyCounts[date]!;

        if (level == 3) {
          // Gap since the last processed date breaks the consecutive run.
          if (prevDate != null && date.difference(prevDate).inDays > 1) {
            currentRun = 0;
          }
          currentRun++;
          heatmap.streakRunLengths[date] = currentRun.clamp(1, 10);
        } else {
          // Any non-level-3 event (skip/fail/partial) breaks the run.
          currentRun = 0;
        }

        // Always advance prevDate so a subsequent level-3 day can detect
        // any gap through intermediate non-event days.
        prevDate = date;
      }

      result.add(heatmap);
    }

    return result;
  }

  /// Returns the overall 12-week completion-rate trend across all habits,
  /// or `null` if no events were logged in the 84-day window.
  ///
  /// weeklyRate = (days where ≥1 habit reached level 3) /
  ///              (days where ≥1 habit had any non-zero level).
  /// Returns `null` when every weekly rate is 0.0.
  ///
  /// Phase 6 additions: also populates [WeeklyTrendData.weekCompletedHabits],
  /// [WeeklyTrendData.allCategoryTitles], and [WeeklyTrendData.habitCategoryMap]
  /// for the tap-tooltip and category-filter features in WeeklyTrendCard.
  static WeeklyTrendData? calculateWeeklyTrend(List<Habit> habits) {
    final today = DateTime.now();
    final todayNorm = DateTime.utc(today.year, today.month, today.day);
    // 84-day window (12 × 7), ending today inclusive
    final windowStart = todayNorm.subtract(const Duration(days: 83));

    // key = midnight-UTC date, value = list of levels from each habit entry
    final Map<DateTime, List<int>> dayLevels = {};

    // Phase 6 §6.1 — per-week set of habit titles that had ≥1 level-3 day
    final Map<int, Set<String>> weekCompletedHabitSets = {
      for (int i = 0; i < 12; i++) i: <String>{},
    };

    // Phase 6 §6.2 — habit title → list of its category titles (for filter)
    final Map<String, List<String>> habitCategoryMap = {};

    for (var habit in habits) {
      // Build category map entry before the events loop
      habitCategoryMap[habit.habitData.title] =
          habit.habitData.categories.map((c) => c.title).toList();

      habit.habitData.events.forEach((key, value) {
        if (value[0] != null && value[0] != DayType.clear) {
          final norm = DateTime.utc(key.year, key.month, key.day);
          if (!norm.isBefore(windowStart) && !norm.isAfter(todayNorm)) {
            final dayType = value[0] as DayType;
            int level;

            switch (dayType) {
              case DayType.check:
                level = 3;
                break;
              case DayType.skip:
                level = 1;
                break;
              case DayType.fail:
                level = 2;
                break;
              case DayType.progress:
                if (value.length > 2) {
                  final progressValue =
                      (value[2] as num?)?.toDouble() ?? 0.0;
                  final targetAtTime = (value.length > 3)
                      ? (value[3] as num?)?.toDouble() ??
                          habit.habitData.targetValue
                      : habit.habitData.targetValue;
                  level = progressValue >= targetAtTime ? 3 : 2;
                } else {
                  level = 2;
                }
                break;
              default:
                level = 0;
            }

            dayLevels.putIfAbsent(norm, () => []).add(level);

            // Track level-3 completions per week for the tooltip payload
            if (level == 3) {
              final weekIndex = norm.difference(windowStart).inDays ~/ 7;
              if (weekIndex >= 0 && weekIndex < 12) {
                weekCompletedHabitSets[weekIndex]!
                    .add(habit.habitData.title);
              }
            }
          }
        }
      });
    }

    // Create formatter once — do not instantiate inside the loop
    final formatter = DateFormat('MMM d');
    final List<double> weeklyRates = [];
    final List<String> weekLabels = [];

    for (int week = 0; week < 12; week++) {
      final weekStart = windowStart.add(Duration(days: week * 7));

      // Label = Monday of the week that contains weekStart
      final monday =
          weekStart.subtract(Duration(days: weekStart.weekday - 1));
      weekLabels.add(formatter.format(monday));

      // Count per habit-day so the rate stays meaningful regardless of
      // how many habits the user tracks.  A day with 5 habits logged and
      // 2 completed contributes 2 successes out of 5 attempts instead of
      // "1 successful day out of 1 active day" (which inflates to 100%).
      int completedEntries = 0;
      int trackedEntries = 0;

      for (int d = 0; d < 7; d++) {
        final day = weekStart.add(Duration(days: d));
        final levels = dayLevels[day];
        if (levels != null) {
          for (final level in levels) {
            trackedEntries++;
            if (level == 3) completedEntries++;
          }
        }
      }

      weeklyRates.add(
          trackedEntries == 0 ? 0.0 : completedEntries / trackedEntries);
    }

    if (weeklyRates.every((r) => r == 0.0)) return null;

    // Convert per-week sets to sorted lists (deterministic order in tooltip)
    final weekCompletedHabits = List.generate(
      12,
      (i) => weekCompletedHabitSets[i]!.toList()..sort(),
    );

    // allCategoryTitles for the WeeklyTrendCard filter dropdown
    final allCategoryTitles = habitCategoryMap.values
        .expand((list) => list)
        .toSet()
        .toList()
      ..sort();

    return WeeklyTrendData(
      title: 'Overall',
      weeklyRates: weeklyRates,
      weekLabels: weekLabels,
      weekCompletedHabits: weekCompletedHabits,
      allCategoryTitles: allCategoryTitles,
      habitCategoryMap: habitCategoryMap,
    );
  }

  /// Returns a side-by-side comparison of non-archived habits, or `null` when
  /// fewer than 2 non-archived habits exist.
  ///
  /// Note: [calculateStatistics] passes allHabits unfiltered (archived included).
  /// This method intentionally excludes archived habits — an asymmetry that is
  /// deliberate and must be preserved.
  static ComparisonData? calculateComparison(
      List<Habit> habits, List<StatisticsData> habitsStats) {
    final List<String> habitTitles = [];
    final List<double> checkRates = [];
    final List<int> topStreaks = [];
    final List<Color?> colors = [];

    // New leaderboard fields (Phase 4 of blueprint2)
    final List<int> actualStreaks = [];
    final List<String> habitCategories = [];
    final List<List<String>> habitCategoryList = [];

    // Raw event count fields
    final List<int> totalChecks = [];
    final List<int> totalSkips = [];
    final List<int> totalProgress = [];
    final List<int> totalFails = [];

    for (int i = 0; i < habits.length; i++) {
      final habit = habits[i];
      // Explicitly skip archived habits — different from calculateStatistics
      if (habit.habitData.archived) continue;

      final stat = habitsStats[i];
      final totalLoggedDays =
          stat.checks + stat.fails + stat.skips + stat.progress;

      // checkEquivalentDays = boolean checks + completed progress events
      int checkEquivalentDays = stat.checks;
      habit.habitData.events.forEach((key, value) {
        if (value[0] != null &&
            value[0] == DayType.progress &&
            value.length > 2) {
          final progressValue = (value[2] as num?)?.toDouble() ?? 0.0;
          final targetAtTime = (value.length > 3)
              ? (value[3] as num?)?.toDouble() ?? habit.habitData.targetValue
              : habit.habitData.targetValue;
          if (progressValue >= targetAtTime) checkEquivalentDays++;
        }
      });

      habitTitles.add(habit.habitData.title);
      checkRates.add(totalLoggedDays == 0
          ? 0.0
          : checkEquivalentDays / totalLoggedDays);
      topStreaks.add(stat.topStreak);
      colors.add(null); // Reserved for future per-habit color assignment

      // Current streak and category fields
      actualStreaks.add(stat.actualStreak);
      final categoryTitles =
          habit.habitData.categories.map((c) => c.title).toList();
      habitCategoryList.add(categoryTitles);
      habitCategories.add(categoryTitles.join(', '));

      totalChecks.add(stat.checks);
      totalSkips.add(stat.skips);
      totalProgress.add(stat.progress);
      totalFails.add(stat.fails);
    }

    // Build deduplicated, sorted list of all category names across non-archived habits
    final allCategoryTitles = habitCategoryList
        .expand((list) => list)
        .toSet()
        .toList()
      ..sort();

    if (habitTitles.length < 2) return null;

    return ComparisonData(
      habitTitles: habitTitles,
      checkRates: checkRates,
      topStreaks: topStreaks,
      colors: colors,
      actualStreaks: actualStreaks,
      habitCategories: habitCategories,
      habitCategoryList: habitCategoryList,
      allCategoryTitles: allCategoryTitles,
      totalChecks: totalChecks,
      totalSkips: totalSkips,
      totalProgress: totalProgress,
      totalFails: totalFails,
    );
  }

  /// Returns the best day-of-week and best time-of-day for habit completion.
  ///
  /// Best day: weekday with the highest average check-equivalent rate across
  /// the full event history. Requires ≥14 total non-clear events to be non-null.
  ///
  /// Best time: the notification-hour bucket shared by the most habits that
  /// have notifications enabled. Tiebreaker = earliest bucket in the day
  /// (Morning > Afternoon > Evening > Night).
  ///
  /// Time buckets: Morning 05–11, Afternoon 12–16, Evening 17–20, Night 21–04.
  /// Derived from [HabitData.notTime] (not event timestamps, which are stored
  /// at noon UTC regardless of when the user actually logs).
  static BestDayTimeData calculateBestDayTime(List<Habit> habits) {
    // weekday: 1=Monday … 7=Sunday (Dart DateTime.weekday convention)
    final Map<int, List<double>> weekdayData = {
      1: [], 2: [], 3: [], 4: [], 5: [], 6: [], 7: [],
    };
    int totalEvents = 0;

    for (var habit in habits) {
      habit.habitData.events.forEach((key, value) {
        if (value[0] != null && value[0] != DayType.clear) {
          totalEvents++;
          final weekday = key.weekday;
          final dayType = value[0] as DayType;

          bool isCheckEquivalent = dayType == DayType.check;
          if (!isCheckEquivalent &&
              dayType == DayType.progress &&
              value.length > 2) {
            final progressValue = (value[2] as num?)?.toDouble() ?? 0.0;
            final targetAtTime = (value.length > 3)
                ? (value[3] as num?)?.toDouble() ?? habit.habitData.targetValue
                : habit.habitData.targetValue;
            isCheckEquivalent = progressValue >= targetAtTime;
          }

          weekdayData[weekday]!.add(isCheckEquivalent ? 1.0 : 0.0);
        }
      });
    }

    const weekdayNames = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    final Map<String, double> dayOfWeekRates = {};
    for (int wd = 1; wd <= 7; wd++) {
      final list = weekdayData[wd]!;
      dayOfWeekRates[weekdayNames[wd]] =
          list.isEmpty ? 0.0 : list.reduce((a, b) => a + b) / list.length;
    }

    String? bestDayOfWeek;
    double bestDayRate = 0.0;

    if (totalEvents >= 14) {
      int bestWd = 1;
      double bestMean = dayOfWeekRates[weekdayNames[1]]!;
      for (int wd = 2; wd <= 7; wd++) {
        final mean = dayOfWeekRates[weekdayNames[wd]]!;
        if (mean > bestMean) {
          bestMean = mean;
          bestWd = wd;
        }
      }
      bestDayOfWeek = weekdayNames[bestWd];
      bestDayRate = bestMean;
    }

    // Tiebreaker: iterate bucketOrder so the first (earliest) bucket with the
    // max count is selected.
    const bucketOrder = ['Morning', 'Afternoon', 'Evening', 'Night'];
    final Map<String, int> bucketCounts = {
      'Morning': 0,
      'Afternoon': 0,
      'Evening': 0,
      'Night': 0,
    };

    bool hasNotifications = false;
    for (var habit in habits) {
      if (habit.habitData.notification) {
        hasNotifications = true;
        final hour = habit.habitData.notTime.hour;
        final String bucket;
        if (hour >= 5 && hour < 12) {
          bucket = 'Morning';
        } else if (hour >= 12 && hour < 17) {
          bucket = 'Afternoon';
        } else if (hour >= 17 && hour < 21) {
          bucket = 'Evening';
        } else {
          bucket = 'Night';
        }
        bucketCounts[bucket] = bucketCounts[bucket]! + 1;
      }
    }

    String? bestTimeOfDay;
    if (hasNotifications) {
      int maxCount = -1;
      for (final bucket in bucketOrder) {
        if (bucketCounts[bucket]! > maxCount) {
          maxCount = bucketCounts[bucket]!;
          bestTimeOfDay = bucket;
        }
      }
    }

    return BestDayTimeData(
      bestDayOfWeek: bestDayOfWeek,
      bestDayRate: bestDayRate,
      bestTimeOfDay: bestTimeOfDay,
      dayOfWeekRates: dayOfWeekRates,
    );
  }

  static void generateYearIfNull(StatisticsData stat, int year) {
    if (stat.monthlyCheck[year] == null) {
      stat.monthlyCheck[year] = {
        DayType.check: List.filled(12, 0),
        DayType.skip: List.filled(12, 0),
        DayType.fail: List.filled(12, 0),
        DayType.progress: List.filled(12, 0), // Add progress tracking
      };
    }
  }
}
