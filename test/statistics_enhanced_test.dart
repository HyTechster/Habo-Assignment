// Unit tests for the four new calculation methods in Statistics
// (calculateHeatmaps, calculateWeeklyTrend, calculateComparison, calculateBestDayTime).
//
// These tests exercise pure computation logic only — no widgets are rendered.
// The Flutter binding is initialised to satisfy the TimeOfDay dependency.

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habo/constants.dart';
import 'package:habo/habits/habit.dart';
import 'package:habo/model/habit_data.dart';
import 'package:habo/statistics/statistics.dart';

// Jan 1 2024 is a Monday (weekday == 1).
// Used as an anchor for day-of-week tests.
final _monday2024 = DateTime.utc(2024, 1, 1);

/// Builds a minimal [Habit] for testing.
/// All required fields default to safe values; pass specific arguments to
/// exercise particular calculation paths.
Habit _makeHabit({
  int id = 1,
  String title = 'Test Habit',
  SplayTreeMap<DateTime, List>? events,
  HabitType habitType = HabitType.boolean,
  double targetValue = 10.0,
  double partialValue = 1.0,
  bool archived = false,
  bool notification = false,
  TimeOfDay notTime = const TimeOfDay(hour: 12, minute: 0),
  bool twoDayRule = false,
}) {
  return Habit(
    habitData: HabitData(
      id: id,
      position: 0,
      title: title,
      twoDayRule: twoDayRule,
      cue: '',
      routine: '',
      reward: '',
      showReward: false,
      advanced: false,
      notification: notification,
      notTime: notTime,
      events: events ?? SplayTreeMap<DateTime, List>(),
      sanction: '',
      showSanction: false,
      accountant: '',
      habitType: habitType,
      targetValue: targetValue,
      partialValue: partialValue,
      archived: archived,
    ),
  );
}

/// Builds a [StatisticsData] with the given field values, used in
/// [calculateComparison] tests to avoid re-running the full calculation.
StatisticsData _makeStat({
  String title = 'Test',
  int checks = 0,
  int fails = 0,
  int skips = 0,
  int progress = 0,
  int topStreak = 0,
}) {
  return StatisticsData()
    ..title = title
    ..checks = checks
    ..fails = fails
    ..skips = skips
    ..progress = progress
    ..topStreak = topStreak;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 10.1 — calculateHeatmaps
  // ──────────────────────────────────────────────────────────────────────────
  group('calculateHeatmaps', () {
    const year = 2024;

    test('habit with no events → empty dailyCounts', () {
      final result = Statistics.calculateHeatmaps([_makeHabit()], year);
      expect(result, hasLength(1));
      expect(result.first.dailyCounts, isEmpty);
    });

    test('check event on Jan 15 → dailyCounts[Jan 15] == 3', () {
      final date = DateTime.utc(year, 1, 15);
      final events = SplayTreeMap<DateTime, List>()..[date] = [DayType.check, ''];
      final result = Statistics.calculateHeatmaps([_makeHabit(events: events)], year);
      expect(result.first.dailyCounts[DateTime.utc(year, 1, 15)], equals(3));
    });

    test('fail event → level 2', () {
      final date = DateTime.utc(year, 3, 10);
      final events = SplayTreeMap<DateTime, List>()..[date] = [DayType.fail, ''];
      final result = Statistics.calculateHeatmaps([_makeHabit(events: events)], year);
      expect(result.first.dailyCounts[DateTime.utc(year, 3, 10)], equals(2));
    });

    test('skip event → level 1', () {
      final date = DateTime.utc(year, 6, 1);
      final events = SplayTreeMap<DateTime, List>()..[date] = [DayType.skip, ''];
      final result = Statistics.calculateHeatmaps([_makeHabit(events: events)], year);
      expect(result.first.dailyCounts[DateTime.utc(year, 6, 1)], equals(1));
    });

    test('partial progress (progressValue < targetValue) → level 2', () {
      final date = DateTime.utc(year, 5, 5);
      // progressValue=3 < targetValue=10 → partial → level 2
      final events = SplayTreeMap<DateTime, List>()
        ..[date] = [DayType.progress, '', 3.0, 10.0];
      final result = Statistics.calculateHeatmaps(
        [_makeHabit(events: events, habitType: HabitType.numeric, targetValue: 10.0)],
        year,
      );
      expect(result.first.dailyCounts[DateTime.utc(year, 5, 5)], equals(2));
    });

    test('completed progress (progressValue >= targetValue) → level 3', () {
      final date = DateTime.utc(year, 5, 6);
      // progressValue=10 >= targetValue=10 → complete → level 3
      final events = SplayTreeMap<DateTime, List>()
        ..[date] = [DayType.progress, '', 10.0, 10.0];
      final result = Statistics.calculateHeatmaps(
        [_makeHabit(events: events, habitType: HabitType.numeric, targetValue: 10.0)],
        year,
      );
      expect(result.first.dailyCounts[DateTime.utc(year, 5, 6)], equals(3));
    });

    test('event outside target year → not included in dailyCounts', () {
      // Event is in 2023; heatmap requested for 2024
      final date = DateTime.utc(2023, 12, 31);
      final events = SplayTreeMap<DateTime, List>()..[date] = [DayType.check, ''];
      final result = Statistics.calculateHeatmaps([_makeHabit(events: events)], year);
      expect(result.first.dailyCounts, isEmpty);
    });

    test('DayType.clear event → not included in dailyCounts', () {
      final date = DateTime.utc(year, 7, 4);
      final events = SplayTreeMap<DateTime, List>()..[date] = [DayType.clear, ''];
      final result = Statistics.calculateHeatmaps([_makeHabit(events: events)], year);
      expect(result.first.dailyCounts, isEmpty);
    });

    test('returns one HeatmapData per habit in the same order', () {
      final habits = [
        _makeHabit(id: 1, title: 'Alpha'),
        _makeHabit(id: 2, title: 'Beta'),
      ];
      final result = Statistics.calculateHeatmaps(habits, year);
      expect(result, hasLength(2));
      expect(result[0].title, equals('Alpha'));
      expect(result[1].title, equals('Beta'));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 10.2 — calculateWeeklyTrend
  // ──────────────────────────────────────────────────────────────────────────
  group('calculateWeeklyTrend', () {
    test('all habits with no events → returns null', () {
      expect(Statistics.calculateWeeklyTrend([_makeHabit()]), isNull);
    });

    test('check events only in last 3 weeks → indices 0–8 are 0.0', () {
      final today = DateTime.now();
      final todayUtc = DateTime.utc(today.year, today.month, today.day);
      final events = SplayTreeMap<DateTime, List>()
        ..[todayUtc.subtract(const Duration(days: 6))] = [DayType.check, '']   // week 11
        ..[todayUtc.subtract(const Duration(days: 13))] = [DayType.check, '']  // week 10
        ..[todayUtc.subtract(const Duration(days: 20))] = [DayType.check, ''];  // week 9

      final result = Statistics.calculateWeeklyTrend([_makeHabit(events: events)]);
      if (result == null) fail('expected non-null WeeklyTrendData');
      for (int i = 0; i < 9; i++) {
        expect(
          result.weeklyRates[i],
          equals(0.0),
          reason: 'week $i should have 0.0 rate (no events)',
        );
      }
      expect(result.weeklyRates[9], greaterThan(0.0));
      expect(result.weeklyRates[10], greaterThan(0.0));
      expect(result.weeklyRates[11], greaterThan(0.0));
    });

    test('week with mixed check and fail events → rate between 0 and 1', () {
      final today = DateTime.now();
      final todayUtc = DateTime.utc(today.year, today.month, today.day);
      // Two events in week 11 on different days: one check (level 3), one fail (level 2)
      final events = SplayTreeMap<DateTime, List>()
        ..[todayUtc.subtract(const Duration(days: 2))] = [DayType.check, '']
        ..[todayUtc.subtract(const Duration(days: 3))] = [DayType.fail, ''];

      final result = Statistics.calculateWeeklyTrend([_makeHabit(events: events)]);
      if (result == null) fail('expected non-null WeeklyTrendData');
      // 1 day with level-3 / 2 days with non-zero level = 0.5
      expect(result.weeklyRates[11], closeTo(0.5, 0.001));
    });

    test('week with only skip events → rate is 0.0', () {
      final today = DateTime.now();
      final todayUtc = DateTime.utc(today.year, today.month, today.day);
      final events = SplayTreeMap<DateTime, List>()
        // Check in week 10 (prevents null return)
        ..[todayUtc.subtract(const Duration(days: 10))] = [DayType.check, '']
        // Skip in week 11 — level 1, not level 3
        ..[todayUtc.subtract(const Duration(days: 1))] = [DayType.skip, ''];

      final result = Statistics.calculateWeeklyTrend([_makeHabit(events: events)]);
      if (result == null) fail('expected non-null WeeklyTrendData');
      expect(result.weeklyRates[11], equals(0.0));
      expect(result.weeklyRates[10], greaterThan(0.0));
    });

    test('always returns exactly 12 rates and 12 labels', () {
      final today = DateTime.now();
      final todayUtc = DateTime.utc(today.year, today.month, today.day);
      final events = SplayTreeMap<DateTime, List>()
        ..[todayUtc] = [DayType.check, ''];
      final result = Statistics.calculateWeeklyTrend([_makeHabit(events: events)]);
      if (result == null) fail('expected non-null WeeklyTrendData');
      expect(result.weeklyRates, hasLength(12));
      expect(result.weekLabels, hasLength(12));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 10.3 — calculateComparison
  // ──────────────────────────────────────────────────────────────────────────
  group('calculateComparison', () {
    test('zero habits → returns null', () {
      expect(Statistics.calculateComparison([], []), isNull);
    });

    test('one non-archived habit → returns null', () {
      final habits = [_makeHabit(archived: false)];
      final stats = [_makeStat()];
      expect(Statistics.calculateComparison(habits, stats), isNull);
    });

    test('two non-archived habits → ComparisonData with 2 entries', () {
      final habits = [
        _makeHabit(id: 1, title: 'A', archived: false),
        _makeHabit(id: 2, title: 'B', archived: false),
      ];
      final stats = [_makeStat(title: 'A', checks: 5), _makeStat(title: 'B', checks: 3)];
      final result = Statistics.calculateComparison(habits, stats);
      if (result == null) fail('expected non-null ComparisonData');
      expect(result.habitTitles, hasLength(2));
      expect(result.checkRates, hasLength(2));
      expect(result.topStreaks, hasLength(2));
    });

    test('one non-archived + one archived → returns null (archived excluded)', () {
      final habits = [
        _makeHabit(id: 1, archived: false),
        _makeHabit(id: 2, archived: true),
      ];
      final stats = [_makeStat(), _makeStat()];
      expect(Statistics.calculateComparison(habits, stats), isNull);
    });

    test('habit with zero logged events → checkRate == 0.0, no crash', () {
      final habits = [
        _makeHabit(id: 1, archived: false),
        _makeHabit(id: 2, archived: false),
      ];
      final stats = [
        _makeStat(checks: 0, fails: 0, skips: 0, progress: 0),
        _makeStat(checks: 0, fails: 0, skips: 0, progress: 0),
      ];
      final result = Statistics.calculateComparison(habits, stats);
      if (result == null) fail('expected non-null ComparisonData');
      expect(result.checkRates[0], equals(0.0));
      expect(result.checkRates[1], equals(0.0));
    });

    test('checkRate = checks / totalLoggedDays', () {
      final habits = [
        _makeHabit(id: 1, archived: false),
        _makeHabit(id: 2, archived: false),
      ];
      // totalLoggedDays = 5 + 3 + 2 + 0 = 10; checkEquivalentDays = 5 (no progress)
      final stats = [
        _makeStat(checks: 5, fails: 3, skips: 2, progress: 0),
        _makeStat(checks: 1),
      ];
      final result = Statistics.calculateComparison(habits, stats);
      expect(result!.checkRates[0], closeTo(0.5, 0.001));
    });

    test('all colors entries are null (reserved for future use)', () {
      final habits = [
        _makeHabit(id: 1, archived: false),
        _makeHabit(id: 2, archived: false),
      ];
      final stats = [_makeStat(), _makeStat()];
      final result = Statistics.calculateComparison(habits, stats);
      expect(result!.colors.every((c) => c == null), isTrue);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 10.4 — calculateBestDayTime
  // ──────────────────────────────────────────────────────────────────────────
  group('calculateBestDayTime', () {
    test('all habits with no events → bestDayOfWeek is null', () {
      final result = Statistics.calculateBestDayTime([_makeHabit()]);
      expect(result.bestDayOfWeek, isNull);
      expect(result.dayOfWeekRates.values.every((r) => r == 0.0), isTrue);
    });

    test('fewer than 14 total events → bestDayOfWeek is null', () {
      final events = SplayTreeMap<DateTime, List>();
      // 13 Monday check events — one below the threshold
      for (int i = 0; i < 13; i++) {
        events[_monday2024.add(Duration(days: i * 7))] = [DayType.check, ''];
      }
      final result = Statistics.calculateBestDayTime([_makeHabit(events: events)]);
      expect(result.bestDayOfWeek, isNull);
    });

    test('14+ check events all on Mondays → bestDayOfWeek == Monday, rate == 1.0', () {
      final events = SplayTreeMap<DateTime, List>();
      for (int i = 0; i < 14; i++) {
        events[_monday2024.add(Duration(days: i * 7))] = [DayType.check, ''];
      }
      final result = Statistics.calculateBestDayTime([_makeHabit(events: events)]);
      expect(result.bestDayOfWeek, equals('Monday'));
      expect(result.bestDayRate, closeTo(1.0, 0.001));
    });

    test('no habits with notifications enabled → bestTimeOfDay is null', () {
      final result = Statistics.calculateBestDayTime([_makeHabit(notification: false)]);
      expect(result.bestTimeOfDay, isNull);
    });

    test('all habits have morning notification times → bestTimeOfDay == Morning', () {
      final habits = [
        _makeHabit(id: 1, notification: true, notTime: const TimeOfDay(hour: 7, minute: 0)),
        _makeHabit(id: 2, notification: true, notTime: const TimeOfDay(hour: 9, minute: 30)),
      ];
      expect(Statistics.calculateBestDayTime(habits).bestTimeOfDay, equals('Morning'));
    });

    test('tie between Morning and Night → Morning wins (earliest-in-day tiebreaker)', () {
      final habits = [
        _makeHabit(id: 1, notification: true, notTime: const TimeOfDay(hour: 8, minute: 0)),
        _makeHabit(id: 2, notification: true, notTime: const TimeOfDay(hour: 22, minute: 0)),
      ];
      expect(Statistics.calculateBestDayTime(habits).bestTimeOfDay, equals('Morning'));
    });

    test('dayOfWeekRates always has exactly 7 entries with correct keys', () {
      final result = Statistics.calculateBestDayTime([_makeHabit()]);
      expect(result.dayOfWeekRates, hasLength(7));
      expect(
        result.dayOfWeekRates.keys.toSet(),
        equals({
          'Monday', 'Tuesday', 'Wednesday', 'Thursday',
          'Friday', 'Saturday', 'Sunday',
        }),
      );
    });

    test('notification hour bucket boundaries are correct', () {
      void check(int hour, String expectedBucket) {
        final result = Statistics.calculateBestDayTime([
          _makeHabit(
            notification: true,
            notTime: TimeOfDay(hour: hour, minute: 0),
          ),
        ]);
        expect(
          result.bestTimeOfDay,
          equals(expectedBucket),
          reason: 'hour $hour should map to $expectedBucket',
        );
      }

      // Morning: 05:00–11:59
      check(5, 'Morning');
      check(11, 'Morning');
      // Afternoon: 12:00–16:59
      check(12, 'Afternoon');
      check(16, 'Afternoon');
      // Evening: 17:00–20:59
      check(17, 'Evening');
      check(20, 'Evening');
      // Night: 21:00–04:59
      check(21, 'Night');
      check(4, 'Night');
    });

    test('completed progress events count as check-equivalent for best-day', () {
      final events = SplayTreeMap<DateTime, List>();
      // 14 completed progress events on Mondays
      for (int i = 0; i < 14; i++) {
        // progressValue == targetValue → complete
        events[_monday2024.add(Duration(days: i * 7))] = [
          DayType.progress, '', 10.0, 10.0,
        ];
      }
      final result = Statistics.calculateBestDayTime([
        _makeHabit(
          events: events,
          habitType: HabitType.numeric,
          targetValue: 10.0,
        ),
      ]);
      expect(result.bestDayOfWeek, equals('Monday'));
    });
  });
}
