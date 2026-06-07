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

/// Seeds 10 dummy habits (boolean + progressive) across three categories with
/// a full year of events up to and including the day the button is tapped.
///
/// Event distribution per day:
///   40 % → completed  (check for boolean; full progress for numeric)
///   15 % → skipped
///   45 % → not so successful  (fail for boolean; partial progress for numeric)
///
/// The tap date is always forced to "completed" so statistics show fresh data.
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
  // type     : 'boolean' | 'numeric'
  // category : category title string, or null for uncategorised
  // target   : (numeric only) goal value per day
  // partial  : (numeric only) value counted as "not so successful" (< target)
  // unit     : (numeric only) display unit label

  static const _habitDefs = [
    // ── Boolean (checkable) ──────────────────────────────────────────────
    {'title': 'Morning Run',        'category': 'Health',    'type': 'boolean'},
    {'title': 'Cold Shower',        'category': 'Health',    'type': 'boolean'},
    {'title': 'Meditate',           'category': 'Mind',      'type': 'boolean'},
    {'title': 'Journal',            'category': 'Mind',      'type': 'boolean'},
    {'title': 'No Social Media',    'category': 'Lifestyle', 'type': 'boolean'},
    {'title': 'Gratitude Practice', 'category': null,        'type': 'boolean'},
    // ── Numeric (progressive) ────────────────────────────────────────────
    {
      'title': 'Drink Water', 'category': 'Health', 'type': 'numeric',
      'target': 8.0, 'partial': 4.0, 'unit': 'glasses',
    },
    {
      'title': 'Read',        'category': 'Mind',   'type': 'numeric',
      'target': 30.0, 'partial': 15.0, 'unit': 'min',
    },
    {
      'title': 'Workout',     'category': 'Health', 'type': 'numeric',
      'target': 60.0, 'partial': 30.0, 'unit': 'min',
    },
    {
      'title': 'Daily Steps', 'category': 'Lifestyle', 'type': 'numeric',
      'target': 10000.0, 'partial': 5000.0, 'unit': 'steps',
    },
  ];

  // ── Public entry point ────────────────────────────────────────────────────

  static Future<void> seed(HabitsManager manager) async {
    if (!kDebugMode) return;

    final categoryMap = await _ensureCategories(manager);
    await _ensureHabits(manager, categoryMap);
    await _seedEvents(manager);
    await manager.initModel();
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
    final yearStart = DateTime.utc(now.year, 1, 1);
    final today = DateTime.utc(now.year, now.month, now.day);

    for (final habit in manager.allHabits) {
      final id = habit.habitData.id;
      if (id == null) continue;

      final events = _generateEvents(
        habitId: id,
        start: yearStart,
        end: today,
        habitType: habit.habitData.habitType,
        targetValue: habit.habitData.targetValue,
        partialValue: habit.habitData.partialValue,
      );
      await eventRepo.insertEventsForHabit(id, events);
    }
  }

  // ── Event generation ──────────────────────────────────────────────────────

  /// Generates one event entry per day in [[start], [end]].
  ///
  /// Boolean habits:
  ///   40 % → [DayType.check, '']
  ///   15 % → [DayType.skip,  '']
  ///   45 % → [DayType.fail,  '']
  ///
  /// Numeric habits:
  ///   40 % → [DayType.progress, '', targetValue]   (full completion)
  ///   15 % → [DayType.skip,     '']
  ///   45 % → [DayType.progress, '', partialValue]  (partial — not so successful)
  ///
  /// [end] is always overwritten with a completed event.
  static Map<DateTime, List> _generateEvents({
    required int habitId,
    required DateTime start,
    required DateTime end,
    required HabitType habitType,
    required double targetValue,
    required double partialValue,
  }) {
    final rng = Random(habitId * 2053 + 17);
    final events = <DateTime, List>{};
    final isNumeric = habitType == HabitType.numeric;

    var day = start;
    while (!day.isAfter(end)) {
      final roll = rng.nextDouble();

      final List event;
      if (roll < 0.40) {
        // 40 % completed
        event = isNumeric
            ? [DayType.progress, '', targetValue]
            : [DayType.check, ''];
      } else if (roll < 0.55) {
        // 15 % skipped
        event = [DayType.skip, ''];
      } else {
        // 45 % not so successful
        event = isNumeric
            ? [DayType.progress, '', partialValue]
            : [DayType.fail, ''];
      }

      events[day] = event;
      day = day.add(const Duration(days: 1));
    }

    // Today is always completed.
    events[end] = isNumeric
        ? [DayType.progress, '', targetValue]
        : [DayType.check, ''];

    return events;
  }
}
