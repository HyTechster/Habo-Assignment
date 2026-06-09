import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:habo/constants.dart';
import 'package:habo/habits/habit.dart';
import 'package:habo/habits/habits_manager.dart';
import 'package:habo/model/category.dart';
import 'package:habo/model/habit_data.dart';
import 'package:habo/services/service_locator.dart';

/// Seeds 10 dummy habits (boolean + progressive) across three categories.
///
/// Each habit has its own tracking rate and completion rate to produce
/// realistic, varied statistics:
///   trackRate    — probability that any event is logged for a given day
///   successRate  — probability of completion on logged days
///   skipRate     — probability of skip on logged days (rest = fail/partial)
///
/// Today is always forced to "completed" so the home screen shows activity.
/// Compile-time guarded by [kDebugMode] — no-op in release builds.
class DummyDataSeeder {
  DummyDataSeeder._();

  // ── Category definitions ──────────────────────────────────────────────────

  static const _categoryDefs = [
    {'title': 'Health',    'icon': 0xf44b}, // fa-dumbbell
    {'title': 'Mind',      'icon': 0xf02d}, // fa-book
    {'title': 'Lifestyle', 'icon': 0xf015}, // fa-home
  ];

  // ── Habit definitions ─────────────────────────────────────────────────────
  //
  // type        : 'boolean' | 'numeric'
  // category    : category title string, or null for uncategorised
  // target      : (numeric only) goal value per day
  // partial     : (numeric only) value for partial progress
  // unit        : (numeric only) display unit label
  // trackRate   : fraction of days where any event is logged (0–1)
  // successRate : fraction of logged days that end in completion (0–1)
  // skipRate    : fraction of logged days that end in skip (0–1)
  //               remaining fraction = fail / partial progress

  static const _habitDefs = [
    // ── Boolean (checkable) ──────────────────────────────────────────────
    {
      'title': 'Morning Run', 'category': 'Health', 'type': 'boolean',
      'trackRate': 0.75, 'successRate': 0.40, 'skipRate': 0.15,
    },
    {
      'title': 'Cold Shower', 'category': 'Health', 'type': 'boolean',
      'trackRate': 0.70, 'successRate': 0.30, 'skipRate': 0.20,
    },
    {
      'title': 'Meditate', 'category': 'Mind', 'type': 'boolean',
      'trackRate': 0.85, 'successRate': 0.60, 'skipRate': 0.10,
    },
    {
      'title': 'Journal', 'category': 'Mind', 'type': 'boolean',
      'trackRate': 0.80, 'successRate': 0.55, 'skipRate': 0.15,
    },
    {
      'title': 'No Social Media', 'category': 'Lifestyle', 'type': 'boolean',
      'trackRate': 0.60, 'successRate': 0.20, 'skipRate': 0.25,
    },
    {
      'title': 'Gratitude Practice', 'category': null, 'type': 'boolean',
      'trackRate': 0.65, 'successRate': 0.35, 'skipRate': 0.20,
    },
    // ── Numeric (progressive) ────────────────────────────────────────────
    {
      'title': 'Drink Water', 'category': 'Health', 'type': 'numeric',
      'target': 8.0, 'partial': 4.0, 'unit': 'glasses',
      'trackRate': 0.90, 'successRate': 0.65, 'skipRate': 0.08,
    },
    {
      'title': 'Read', 'category': 'Mind', 'type': 'numeric',
      'target': 30.0, 'partial': 15.0, 'unit': 'min',
      'trackRate': 0.75, 'successRate': 0.50, 'skipRate': 0.15,
    },
    {
      'title': 'Workout', 'category': 'Health', 'type': 'numeric',
      'target': 60.0, 'partial': 30.0, 'unit': 'min',
      'trackRate': 0.70, 'successRate': 0.35, 'skipRate': 0.15,
    },
    {
      'title': 'Daily Steps', 'category': 'Lifestyle', 'type': 'numeric',
      'target': 10000.0, 'partial': 5000.0, 'unit': 'steps',
      'trackRate': 0.85, 'successRate': 0.70, 'skipRate': 0.05,
    },
  ];

  // ── Public entry point ────────────────────────────────────────────────────

  static Future<void> seed(HabitsManager manager) async {
    if (!kDebugMode) return;

    final categoryMap = await _ensureCategories(manager);
    await _ensureHabits(manager, categoryMap);
    await _seedEvents(manager);
    // Reload from DB so both home-screen calendar and statistics use the same
    // data, then sync the category list so the filter row is up to date.
    await manager.initModel();
    await manager.loadCategories();
  }

  // ── Category helpers ──────────────────────────────────────────────────────

  static Future<Map<String, Category>> _ensureCategories(
      HabitsManager manager) async {
    final result = <String, Category>{};

    for (final def in _categoryDefs) {
      final title = def['title'] as String;
      final icon = def['icon'] as int;

      final existing =
          manager.allCategories.where((c) => c.title == title).firstOrNull;

      if (existing != null) {
        result[title] = existing;
      } else {
        await manager.addCategory(title, icon);
        result[title] = manager.allCategories.last;
      }
    }

    return result;
  }

  // ── Habit helpers ─────────────────────────────────────────────────────────

  static Future<void> _ensureHabits(
      HabitsManager manager, Map<String, Category> categoryMap) async {
    final habitRepo =
        ServiceLocator.instance.repositoryFactory.habitRepository;

    for (final def in _habitDefs) {
      final title = def['title'] as String;
      final catName = def['category'];
      final isNumeric = def['type'] == 'numeric';

      if (manager.allHabits.any((h) => h.habitData.title == title)) continue;

      final categories = catName != null && categoryMap.containsKey(catName)
          ? [categoryMap[catName as String]!]
          : <Category>[];

      final habit = Habit(
        habitData: HabitData(
          position: manager.allHabits.length,
          title: title,
          twoDayRule: false,
          cue: '',
          routine: '',
          reward: '',
          showReward: false,
          advanced: false,
          events: SplayTreeMap<DateTime, List>(),
          notification: false,
          notTime: const TimeOfDay(hour: 8, minute: 0),
          sanction: '',
          showSanction: false,
          accountant: '',
          habitType: isNumeric ? HabitType.numeric : HabitType.boolean,
          targetValue: (def['target'] as num?)?.toDouble() ?? 1.0,
          partialValue: (def['partial'] as num?)?.toDouble() ?? 1.0,
          unit: (def['unit'] as String?) ?? '',
          categories: categories,
        ),
      );

      final id = await habitRepo.createHabit(habit);
      habit.setId = id;
      manager.allHabits.add(habit);

      if (categories.isNotEmpty) {
        await manager.updateHabitCategories(id, categories);
      }
    }
  }

  // ── Event seeding ─────────────────────────────────────────────────────────

  static Future<void> _seedEvents(HabitsManager manager) async {
    final eventRepo =
        ServiceLocator.instance.repositoryFactory.eventRepository;

    final now = DateTime.now();
    // Use UTC noon to match transformDate(), which is what the UI uses for all
    // event key lookups. Midnight UTC keys would never match and marks wouldn't show.
    final yearStart = DateTime.utc(now.year, 1, 1, 12);
    final today = DateTime.utc(now.year, now.month, now.day, 12);

    // Only seed dummy habits — identified by title match — to avoid
    // overwriting events on any habits the user created themselves.
    final dummyDefsByTitle = {
      for (final d in _habitDefs) d['title'] as String: d,
    };

    for (final habit in manager.allHabits) {
      final id = habit.habitData.id;
      if (id == null) continue;
      final def = dummyDefsByTitle[habit.habitData.title];
      if (def == null) continue;

      final trackRate = (def['trackRate'] as num).toDouble();
      final successRate = (def['successRate'] as num).toDouble();
      final skipRate = (def['skipRate'] as num).toDouble();

      final events = _generateEvents(
        habitId: id,
        start: yearStart,
        end: today,
        habitType: habit.habitData.habitType,
        targetValue: habit.habitData.targetValue,
        partialValue: habit.habitData.partialValue,
        trackRate: trackRate,
        successRate: successRate,
        skipRate: skipRate,
      );

      // Write to DB.
      await eventRepo.insertEventsForHabit(id, events);

      // Also update in-memory so the home-screen calendar shows events
      // immediately without relying solely on the subsequent initModel reload.
      habit.habitData.events
        ..clear()
        ..addAll(events);
    }
  }

  // ── Event generation ──────────────────────────────────────────────────────

  /// Generates one event per tracked day in [[start], [end]].
  ///
  /// A single RNG roll per day determines both whether the habit is tracked
  /// and, if so, its outcome:
  ///   roll ∈ [0, 1 − trackRate)        → no event (untracked day)
  ///   roll ∈ [1 − trackRate, ...)
  ///     normalized ∈ [0, successRate)  → completed
  ///     normalized ∈ [successRate, successRate + skipRate) → skipped
  ///     normalized ∈ [successRate + skipRate, 1)           → fail / partial
  ///
  /// [end] is always overwritten with a completed event so the home screen
  /// shows activity for today.
  static Map<DateTime, List> _generateEvents({
    required int habitId,
    required DateTime start,
    required DateTime end,
    required HabitType habitType,
    required double targetValue,
    required double partialValue,
    required double trackRate,
    required double successRate,
    required double skipRate,
  }) {
    final rng = Random(habitId * 2053 + 17);
    final events = <DateTime, List>{};
    final isNumeric = habitType == HabitType.numeric;

    var day = start;
    while (!day.isAfter(end)) {
      final roll = rng.nextDouble();

      if (roll < 1.0 - trackRate) {
        // Untracked day — no event logged.
        day = day.add(const Duration(days: 1));
        continue;
      }

      // Normalise the roll into [0, 1) within the "tracked" portion.
      final outcome = (roll - (1.0 - trackRate)) / trackRate;

      final List event;
      if (outcome < successRate) {
        event = isNumeric
            ? [DayType.progress, '', targetValue]
            : [DayType.check, ''];
      } else if (outcome < successRate + skipRate) {
        event = [DayType.skip, ''];
      } else {
        event = isNumeric
            ? [DayType.progress, '', partialValue]
            : [DayType.fail, ''];
      }

      events[day] = event;
      day = day.add(const Duration(days: 1));
    }

    // Today is always completed so the home screen shows a green indicator.
    events[end] = isNumeric
        ? [DayType.progress, '', targetValue]
        : [DayType.check, ''];

    return events;
  }
}
