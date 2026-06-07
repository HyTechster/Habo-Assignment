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
}

/// Heatmap completion levels for a single day:
///   0 = no event / DayType.clear
///   1 = skip
///   2 = fail OR partial progress (target not reached)
///   3 = check OR completed progress (target reached)
///
/// Keys are normalised to midnight UTC: DateTime.utc(year, month, day).
/// Do not use the raw event datetime (stored at noon UTC) as a map key.
class HeatmapData {
  String title;
  Map<DateTime, int> dailyCounts;
  int year;

  HeatmapData({
    required this.title,
    Map<DateTime, int>? dailyCounts,
    int? year,
  })  : dailyCounts = dailyCounts ?? {},
        year = year ?? DateTime.now().year;
}

/// Completion-rate trend across the most recent 12 weeks.
///
/// [weeklyRates] — exactly 12 elements; index 0 = oldest, 11 = most recent.
/// Each value is in [0.0, 1.0]: check-equivalent days / total logged days.
/// 0.0 when no events were logged in a week.
///
/// [weekLabels] — exactly 12 elements; short label for the Monday of each
/// week formatted as "MMM d" (e.g. "May 5"). Index-aligned to weeklyRates.
class WeeklyTrendData {
  String title;
  List<double> weeklyRates;
  List<String> weekLabels;

  WeeklyTrendData({
    required this.title,
    required this.weeklyRates,
    required this.weekLabels,
  });
}

/// Side-by-side comparison of check rates and top streaks across habits.
///
/// Only non-archived habits are included (see calculateComparison in Statistics).
/// [colors] is reserved for future per-habit color assignment; currently all null.
class ComparisonData {
  List<String> habitTitles;
  List<double> checkRates;
  List<int> topStreaks;
  List<Color?> colors;

  ComparisonData({
    required this.habitTitles,
    required this.checkRates,
    required this.topStreaks,
    required this.colors,
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
    stats.overallWeeklyTrend = calculateWeeklyTrend(habits);
    stats.comparison = calculateComparison(habits, stats.habitsData);
    stats.bestDayTime = calculateBestDayTime(habits);

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
  static WeeklyTrendData? calculateWeeklyTrend(List<Habit> habits) {
    final today = DateTime.now();
    final todayNorm = DateTime.utc(today.year, today.month, today.day);
    // 84-day window (12 × 7), ending today inclusive
    final windowStart = todayNorm.subtract(const Duration(days: 83));

    // key = midnight-UTC date, value = list of levels from each habit entry
    final Map<DateTime, List<int>> dayLevels = {};

    for (var habit in habits) {
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

      int level3Days = 0;
      int nonZeroDays = 0;

      for (int d = 0; d < 7; d++) {
        final day = weekStart.add(Duration(days: d));
        final levels = dayLevels[day];
        if (levels != null && levels.isNotEmpty) {
          nonZeroDays++;
          if (levels.any((l) => l == 3)) level3Days++;
        }
      }

      weeklyRates.add(
          nonZeroDays == 0 ? 0.0 : level3Days / nonZeroDays);
    }

    if (weeklyRates.every((r) => r == 0.0)) return null;

    return WeeklyTrendData(
      title: 'Overall',
      weeklyRates: weeklyRates,
      weekLabels: weekLabels,
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
    }

    if (habitTitles.length < 2) return null;

    return ComparisonData(
      habitTitles: habitTitles,
      checkRates: checkRates,
      topStreaks: topStreaks,
      colors: colors,
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
