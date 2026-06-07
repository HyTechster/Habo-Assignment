# Habo — Enhanced Statistics Module: Implementation Blueprint

> **For Claude Code.** Read this file top to bottom before writing any code. Do not skip phases or combine them. After completing each phase, print the stop prompt exactly as written and wait for the user to type **continue**.

---

## Phase Overview

| # | Title | What It Does |
|---|---|---|
| 1 | Extended Data Classes | Add four new data structs to `statistics.dart` to hold heatmap, weekly trend, comparison, and best-day/time data |
| 2 | Calculation Logic | Implement four new pure calculation methods inside `Statistics` class |
| 3 | HabitsManager Bridge | Expose a new `getFutureEnhancedStatsData()` method on `HabitsManager` |
| 4 | Heatmap Widget | Build `YearlyHeatmapCard` using a custom `GridView` or `Wrap` |
| 5 | Weekly Trend Widget | Build `WeeklyTrendCard` using `fl_chart LineChart` |
| 6 | Comparison Bar Chart Widget | Build `HabitComparisonCard` using `fl_chart BarChart` |
| 7 | Best-Day & Best-Time Widget | Build `BestDayTimeCard` as a summary info card |
| 8 | Screen Integration | Wire all four new cards into `StatisticsScreen` |
| 9 | Localization | Add all new string keys to the `.arb` file and generated class |
| 10 | Testing & Polish | Write unit tests for calculation logic; fix edge cases; verify empty states |

---

---

## Phase 1 — Extended Data Classes

**Goal:** Define the four new data containers that the calculation layer (Phase 2) will populate and the UI layer (Phases 4–7) will consume. No logic yet — data shapes only.

### Files to modify
- `lib/statistics/statistics.dart`

### Instructions

Open `lib/statistics/statistics.dart`. This file already contains `StatisticsData`, `OverallStatisticsData`, and `AllStatistics`. You will add four new classes **below** the existing class definitions but **above** the `Statistics` class that contains the calculation methods.

Do not modify any existing class. Do not rename or remove any existing field.

---

**1.1 — `HeatmapData`**

Create a class `HeatmapData` with the following fields:

- `String title` — the habit name (copy from `StatisticsData.title`)
- `Map<DateTime, int> dailyCounts` — keys are `DateTime` values normalised to midnight UTC (date only, no time component). Values are an integer from 0–3 representing the completion level for that day:
  - `0` = no event logged or `DayType.clear`
  - `1` = `DayType.skip`
  - `2` = `DayType.fail` OR partial `DayType.progress` (progress logged but target not reached)
  - `3` = `DayType.check` OR completed `DayType.progress` (progress reached target)
- `int year` — the year this heatmap covers; default to `DateTime.now().year`

> **Note:** The key type is `DateTime` normalised to midnight UTC so that two entries for the same calendar day are equal under `==`. Use `DateTime.utc(year, month, day)` when inserting keys. Do not use the raw event `dateTime` (which is stored at noon UTC) as a map key directly.

---

**1.2 — `WeeklyTrendData`**

Create a class `WeeklyTrendData` with the following fields:

- `String title` — habit name
- `List<double> weeklyRates` — exactly 12 elements. Index 0 = oldest week, index 11 = most recent (current or last completed) week. Each value is a completion rate in the range `[0.0, 1.0]`: the number of `check`-equivalent days in that week divided by the number of days that had any non-clear event logged that week. If a week has zero logged events, store `0.0` (do not divide by zero).
- `List<String> weekLabels` — exactly 12 elements. Each label is a short human-readable string identifying the week start date, formatted as `"MMM d"` (e.g. `"May 5"`). Index alignment matches `weeklyRates`.

---

**1.3 — `ComparisonData`**

Create a class `ComparisonData` with the following fields:

- `List<String> habitTitles` — ordered list of habit names; one entry per active (non-archived) habit
- `List<double> checkRates` — one entry per habit. Each value is `checks / totalLoggedDays` where `totalLoggedDays = checks + fails + skips + progress`. If `totalLoggedDays == 0`, store `0.0`.
- `List<int> topStreaks` — one entry per habit. Copied from `StatisticsData.topStreak`.
- `List<Color?> colors` — reserved for future per-habit color assignment; populate with `null` for every entry in this phase. The UI layer will fall back to the shared `checkColor` from `SettingsManager`.

> **Warning — Archived habits:** `getFutureStatsData()` currently passes `allHabits`, which includes archived habits. For comparison purposes, you should only include non-archived habits. The filtering will happen in Phase 2 inside the calculation method, not here. This class holds whatever the calculation layer decides to include.

---

**1.4 — `BestDayTimeData`**

Create a class `BestDayTimeData` with the following fields:

- `String? bestDayOfWeek` — the full English name of the weekday (e.g. `"Monday"`) on which the user completes the most habits on average. `null` if insufficient data (fewer than 14 total check-equivalent events across all habits).
- `double bestDayRate` — the average check rate on `bestDayOfWeek` as a fraction `[0.0, 1.0]`. `0.0` if `bestDayOfWeek` is null.
- `String? bestTimeOfDay` — one of `"Morning"`, `"Afternoon"`, `"Evening"`, or `"Night"`. Derived from the `notTime` field on habits (the scheduled notification time), not from event timestamps, because events are stored at noon UTC regardless of when the user actually logs them. The time buckets are: Morning = 05:00–11:59, Afternoon = 12:00–16:59, Evening = 17:00–20:59, Night = 21:00–04:59. If no habit has a notification time set, this is `null`.
- `Map<String, double> dayOfWeekRates` — keys are full English weekday names (`"Monday"` through `"Sunday"`), values are the average check rates for that weekday across all habits. Always has exactly 7 entries; use `0.0` for days with no data.

---

**1.5 — Extend `AllStatistics`**

Add four new fields to the existing `AllStatistics` class:

- `List<HeatmapData> heatmaps` — one per habit, same order as `habitsData`
- `WeeklyTrendData? overallWeeklyTrend` — aggregate across all habits; `null` if no data
- `ComparisonData? comparison` — `null` if fewer than 2 non-archived habits exist
- `BestDayTimeData bestDayTime`

Initialise all four fields in `AllStatistics`'s constructor with appropriate defaults (empty list, null, null, and a zeroed `BestDayTimeData`).

---

### Verify before continuing
- `flutter analyze lib/statistics/statistics.dart` reports zero errors.
- No existing class or field has been renamed, removed, or had its type changed.
- `AllStatistics` still compiles correctly with its four original fields intact.

---

> ✅ Phase 1 complete. Review the changes above, then type **continue** to proceed to Phase 2.

---

---

## Phase 2 — Calculation Logic

**Goal:** Implement the four calculation methods inside the `Statistics` class. These are pure functions — no Flutter widgets, no Provider access. They read from `List<Habit>` (or the already-computed `AllStatistics`) and write into the new data classes from Phase 1.

### Files to modify
- `lib/statistics/statistics.dart`

### Context: what already exists

The existing `Statistics.calculateStatistics(List<Habit>? habits)` method:
- Iterates habits in forward chronological order using `habit.habitData.events.forEach()` (SplayTreeMap, ascending)
- Events are stored as `SplayTreeMap<DateTime, List>` where the list is `[DayType, comment, progressValue?, targetValue?]`
- `DayType.clear` events are skipped via a guard (`value[0] != null && value[0] != DayType.clear`)
- Archived habits are included because `allHabits` is passed unfiltered

Your new methods must follow the same iteration conventions and respect the same guard for `DayType.clear`.

---

### Instructions

**2.1 — `calculateHeatmaps(List<Habit> habits, int year)`**

Add a new `static` method. It takes the full habits list and a target year (default to `DateTime.now().year`).

For each habit:
1. Create a `HeatmapData` with `title` and `year`.
2. Iterate `habit.habitData.events` using `forEach`. For each entry where `key.year == year` and `value[0] != null && value[0] != DayType.clear`:
   - Normalise the key to midnight UTC: `DateTime.utc(key.year, key.month, key.day)`.
   - Determine the level integer (0–3) according to the rules in Phase 1 §1.1. For `DayType.progress`, read `event[2]` (progressValue) and `event[3]` (targetValue, falling back to `habit.habitData.targetValue`) to determine if the progress is complete.
   - Store `normalisedDate → level` in `dailyCounts`.
3. Append to the result list.

Return `List<HeatmapData>`.

> **Edge case:** If `events` is empty, the heatmap for that habit will have an empty `dailyCounts` map. That is correct — the widget will render a blank grid.

---

**2.2 — `calculateWeeklyTrend(List<Habit> habits)`**

Add a new `static` method. Returns `WeeklyTrendData?` (null if the combined event map has no events in the past 12 weeks).

Algorithm:
1. Determine the 12-week window. The window ends at `DateTime.now()` (today) and starts at `today - 83 days` (12 × 7 = 84 days inclusive).
2. For each of the 12 weeks (week 0 = oldest), determine the start and end date.
3. Build a `Map<DateTime, List<int>>` aggregating across all habits: key = normalised day (midnight UTC), value = list of event-level integers for every habit that logged on that day. Use the same 0–3 level scale from §2.1.
4. For each week slot, compute `weeklyRate` as: (count of days in that week where at least one habit had level 3) divided by (count of days in that week where at least one habit had any non-zero level). If denominator is zero, store `0.0`.
5. Compute `weekLabels` by formatting the Monday of each week using `DateFormat('MMM d')`. Use `intl` package — it is already a transitive dependency via `flutter_intl`.
6. If all 12 `weeklyRates` are `0.0`, return `null`.

Return the populated `WeeklyTrendData`.

> **Note:** Do not call `DateFormat` inside a tight loop without caching the formatter instance — create it once before the loop.

---

**2.3 — `calculateComparison(List<Habit> habits)`**

Add a new `static` method. Returns `ComparisonData?`.

Algorithm:
1. Filter `habits` to exclude archived ones: `habit.habitData.archived == true` should be skipped. This is different from the existing `calculateStatistics` behaviour, which includes archived habits. Explicitly document this difference with a comment.
2. If fewer than 2 non-archived habits remain, return `null`.
3. For each non-archived habit, compute:
   - `totalLoggedDays` = sum of checks + fails + skips + progress events (use the already-computed counts if you call this after `calculateStatistics`, or re-count from events)
   - `checkEquivalentDays` = checks + completed-progress events (where progressValue ≥ targetValue)
   - `checkRate` = `checkEquivalentDays / totalLoggedDays` (or `0.0` if zero)
   - `topStreak` from `StatisticsData` — or re-compute from the habit's events using the same forward-scan logic from the existing method
4. Populate `ComparisonData` fields in the same order as the filtered habits list.
5. Set all `colors` entries to `null`.

Return `ComparisonData`.

> **Implementation tip:** To avoid duplicating streak logic, call `calculateStatistics` first (it already runs in `getFutureStatsData`), then re-use its `habitsData` results when building the comparison. Pass the existing `AllStatistics` in as a parameter, or restructure so `calculateComparison` accepts a `List<StatisticsData>` alongside the habits list. Either approach is acceptable; consistency with the existing code style matters more.

---

**2.4 — `calculateBestDayTime(List<Habit> habits)`**

Add a new `static` method. Returns `BestDayTimeData`.

Algorithm:

*Best day of week:*
1. Build a map `Map<int, List<double>>` keyed on weekday (1=Monday … 7=Sunday, matching Dart's `DateTime.weekday`).
2. For each habit, for each non-clear event in the full history: normalise the key date, get its `weekday`, determine if it is check-equivalent (level 3), and append `1.0` (check) or `0.0` (not check) to the list for that weekday.
3. For each weekday, compute the mean of its list. Store all 7 means in `dayOfWeekRates` using full English weekday names as keys.
4. The best day is the weekday with the highest mean. If total sample size across all weekdays is fewer than 14 events, set `bestDayOfWeek = null` and `bestDayRate = 0.0`.

*Best time of day:*
1. For each habit that has `notification == true` (i.e. `habit.habitData.notification == true`) and a non-empty `notTime` string:
   - Parse `notTime` as `"HH:MM"`, extract the hour integer.
   - Classify into a time bucket (see Phase 1 §1.4).
2. Count how many habits fall into each bucket. The bucket with the most habits wins.
3. If no habits have notifications enabled, set `bestTimeOfDay = null`.
4. Ties: pick the bucket that comes earliest in the day (Morning > Afternoon > Evening > Night) as the tiebreaker.

Return the populated `BestDayTimeData`.

---

**2.5 — Wire into `calculateStatistics`**

At the end of the existing `calculateStatistics` method, after the main forEach loop and before returning `stats`, add calls to your four new methods and assign their results to the new fields on `stats`:

```
stats.heatmaps = calculateHeatmaps(habits, DateTime.now().year)
stats.overallWeeklyTrend = calculateWeeklyTrend(habits)
stats.comparison = calculateComparison(habits)   // or pass stats.habitsData
stats.bestDayTime = calculateBestDayTime(habits)
```

All four methods are called within the same async computation already scheduled on an isolate-friendly path (the method is `async` but does CPU work synchronously). No additional isolate wrapping is needed for now.

---

### Verify before continuing
- `flutter analyze lib/statistics/statistics.dart` reports zero errors.
- Run `flutter test test/statistics_test.dart` if it exists — all pre-existing tests must still pass.
- Mentally trace through a habit with 3 check events on Mon/Wed/Fri: `calculateBestDayTime` should return a non-null `bestDayOfWeek` only when total events ≥ 14. With only 3 events it should return `null`.

---

> ✅ Phase 2 complete. Review the changes above, then type **continue** to proceed to Phase 3.

---

---

## Phase 3 — HabitsManager Bridge

**Goal:** Expose the enhanced statistics data through `HabitsManager` so the UI can consume it via `Provider`, matching the existing pattern used by `getFutureStatsData()`.

### Files to modify
- `lib/habits/habits_manager.dart`

### Context: existing pattern

`HabitsManager` already has:
```dart
Future<AllStatistics> getFutureStatsData() {
  return Statistics.calculateStatistics(allHabits);
}
```

This is called inside `StatisticsScreen` via `FutureBuilder`. The known Flutter anti-pattern (creating a new Future on every `build`) is documented in STATISTICS_MODULE.md §7 — do not attempt to fix it in this phase.

### Instructions

**3.1** — Since `AllStatistics` now contains all four new data sets (added in Phase 1), `getFutureStatsData()` already returns them — the new fields are populated by the extended `calculateStatistics` (Phase 2 §2.5). No new method is strictly required.

Verify this by checking: does `getFutureStatsData()` call `Statistics.calculateStatistics(allHabits)`? If yes, and if Phase 2 §2.5 wired the new calculations into `calculateStatistics`, then `getFutureStatsData()` already returns `AllStatistics` with all four new fields populated. You do not need a separate bridge method.

**3.2** — However, add a convenience getter to `HabitsManager` for use in the comparison chart, which only applies to non-archived habits:

```dart
List<Habit> get activeHabits => allHabits.where((h) => !h.habitData.archived).toList();
```

This makes the filtering intent explicit and reusable.

**3.3** — Add a brief inline comment above `getFutureStatsData()` noting that `allHabits` includes archived habits and that the comparison sub-calculation filters them internally. This prevents future developers from accidentally removing the archive filter in Phase 2.

---

### Verify before continuing
- `flutter analyze lib/habits/habits_manager.dart` reports zero errors.
- `HabitsManager` compiles without change to its public API signature for `getFutureStatsData()`.

---

> ✅ Phase 3 complete. Review the changes above, then type **continue** to proceed to Phase 4.

---

---

## Phase 4 — Yearly Heatmap Widget

**Goal:** Build `YearlyHeatmapCard`, a stateful widget that renders a GitHub-contribution-style 53-column × 7-row grid of coloured squares for a single habit's year of data.

### Files to create
- `lib/statistics/yearly_heatmap_card.dart`

### Files to read first (do not modify)
- `lib/statistics/statistics_card.dart` — follow the same card structure (rounded corners, `primaryContainer` background, elevation 2)
- `lib/statistics/monthly_graph.dart` — follow the same toggle-button and year-selector patterns

### Instructions

**4.1 — Widget scaffold**

Create `YearlyHeatmapCard` as a `StatefulWidget`. Constructor takes one argument: `HeatmapData data`.

State variables:
- `int year` — initialized in `initState` to `data.year`

If `data.dailyCounts` is empty and only one year is available, the widget should still render — it will show a blank grid.

**4.2 — Year selector**

At the top of the card, render a row containing:
- The habit title (left-aligned, matching the style in `StatisticsCard`: fontSize 20, bold, ellipsized)
- A `DropdownButton<int>` (right-aligned) built from the set of years present as keys in `data.dailyCounts`, plus the current calendar year. Always include `DateTime.now().year` even if it has no data. Sort descending (newest first).

When the year changes, call `setState(() { year = newValue; })`.

**4.3 — Grid layout**

Below the year selector, render the 53 × 7 heatmap grid.

Layout strategy:
- Use a horizontal `SingleChildScrollView` wrapping a `Row` of 53 columns, each column being a `Column` of 7 squares. This is more performant than a flat `GridView` for this fixed shape and avoids fighting `GridView`'s axis constraints inside a vertical `ListView`.
- Each square is a 10 × 10 `Container` with 1.5px margin on all sides and a `BorderRadius.circular(2)`.
- Square colour is determined by the level (0–3) read from `data.dailyCounts` for that date:
  - Level 0 (no data): `Theme.of(context).colorScheme.surfaceVariant` (a neutral grey-ish tone)
  - Level 1 (skip): `skipColor` from `SettingsManager` at 40% opacity
  - Level 2 (fail/partial): `failColor` from `SettingsManager` at 60% opacity
  - Level 3 (check/complete): `checkColor` from `SettingsManager` at full opacity
- Read colours using `Provider.of<SettingsManager>(context, listen: false)` — consistent with the existing pattern in `StatisticsCard` and `MonthlyGraph`.

**4.4 — Grid date mapping**

To build the grid:
1. Compute `startOfYear = DateTime.utc(year, 1, 1)`.
2. Find the Monday on or before `startOfYear` — this is the first cell of column 0. (If `startOfYear` is already Monday, use it; otherwise step back to the previous Monday.)
3. Fill 53 columns × 7 rows = 371 cells. For each cell, compute `cellDate = gridStart + Duration(days: column * 7 + row)`.
4. If `cellDate.year != year`, render the square with level 0 (grey — it's padding outside the year).
5. Otherwise, look up `data.dailyCounts[cellDate]` for the level (default 0 if absent).

**4.5 — Month labels**

Above the grid (or immediately inside the scroll view, aligned to column starts), render abbreviated month labels. For each month January–December, compute which column index that month's 1st falls in and place a `Text` widget (`fontSize 9`, `bodySmall` color) at that column offset. Use `DateFormat('MMM')` for labels.

**4.6 — Legend**

Below the grid, render a simple horizontal legend row:
- Label: `"Less"` — four squares showing levels 0, 1, 2, 3 — label: `"More"`
- Use the same colour mapping as §4.3. Small text (fontSize 10), grey.

**4.7 — Tooltip on tap (optional but recommended)**

Wrap each square `Container` in a `GestureDetector`. On tap, show a `Tooltip` or a `ScaffoldMessenger.of(context).showSnackBar()` with the date formatted as `"d MMM yyyy"` and the level description. This is a nice-to-have; implement it only if it does not significantly complicate the grid construction.

---

### Verify before continuing
- Widget renders without overflow in a `ListView` context.
- `flutter analyze lib/statistics/yearly_heatmap_card.dart` reports zero errors.
- A habit with no events renders a fully grey grid without throwing.
- The grid correctly shows Jan 1 through Dec 31 with padding columns before/after where applicable.

---

> ✅ Phase 4 complete. Review the changes above, then type **continue** to proceed to Phase 5.

---

---

## Phase 5 — Weekly Trend Line Chart Widget

**Goal:** Build `WeeklyTrendCard`, a stateless widget rendering a `fl_chart LineChart` of the past 12 weeks' completion rates for the overall aggregate.

### Files to create
- `lib/statistics/weekly_trend_card.dart`

### Files to read first
- `lib/statistics/monthly_graph.dart` — see how `fl_chart BarChart` is configured: `maxY`, `BarTouchData`, axis label formatting, animation duration (150ms linear). Mirror these conventions for the `LineChart`.

### Instructions

**5.1 — Widget scaffold**

Create `WeeklyTrendCard` as a `StatelessWidget`. Constructor takes one argument: `WeeklyTrendData data`.

**5.2 — Card shell**

Wrap everything in a `Card` with:
- `color: Theme.of(context).colorScheme.primaryContainer`
- `elevation: 2`
- `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))`
- Consistent padding (16px all sides) matching `StatisticsCard`.

**5.3 — Header row**

A `Row` containing:
- Left: section title text (e.g. `S.of(context).weeklyTrend` — the localization key to be added in Phase 9; for now use a hardcoded string `"12-Week Trend"` as a placeholder)
- The title should use `TextStyle(fontSize: 16, fontWeight: FontWeight.bold)`

**5.4 — Line chart**

Render a `SizedBox(height: 140)` containing a `LineChart`.

`LineChartData` configuration:
- `minY: 0.0`, `maxY: 1.0`
- `lineBarsData`: a single `LineChartBarData`:
  - `spots`: map `data.weeklyRates` to `FlSpot(index.toDouble(), rate)` for each of the 12 entries
  - `isCurved: true`, `curveSmoothness: 0.3`
  - `color`: `checkColor` from `SettingsManager` (read with `listen: false`)
  - `barWidth: 2.5`
  - `dotData`: show dots, `radius: 3`, same colour as the line
  - `belowBarData`: `BarAreaData(show: true)` with the same colour at 20% opacity, for a fill effect
- `gridData`: show horizontal grid lines only, at 0.25, 0.50, 0.75 intervals; use `FlLine(color: surfaceVariant, strokeWidth: 1)`
- `borderData`: `FlBorderData(show: false)` — no border box
- `titlesData`:
  - Bottom axis: show labels for indices 0, 3, 6, 9, 11 only (to avoid crowding); use `data.weekLabels[index]` as the label; `fontSize: 9`
  - Left axis: show `"0%"`, `"50%"`, `"100%"` at 0.0, 0.5, 1.0; `fontSize: 9`
- `lineTouchData`: `LineTouchData(enabled: false)` — consistent with `MonthlyGraph` which also disables touch
- Animation: `duration: const Duration(milliseconds: 150)`, `curve: Curves.linear`

**5.5 — Empty / null guard**

`WeeklyTrendData?` can be null (returned by the calculation when no data exists). The caller (Phase 8) will check for null before rendering this widget. Inside the widget itself, if `data.weeklyRates` is all zeros, display the chart anyway — a flat zero line is a valid and informative state.

---

### Verify before continuing
- `flutter analyze lib/statistics/weekly_trend_card.dart` reports zero errors.
- Widget does not overflow in a `ListView` at standard phone widths (360–414 dp).
- 12 spots render without any assertion errors from `fl_chart`.

---

> ✅ Phase 5 complete. Review the changes above, then type **continue** to proceed to Phase 6.

---

---

## Phase 6 — Per-Habit Comparison Bar Chart Widget

**Goal:** Build `HabitComparisonCard`, a stateful widget showing all non-archived habits side by side on one grouped bar chart (check rate + top streak, two rods per habit group).

### Files to create
- `lib/statistics/habit_comparison_card.dart`

### Files to read first
- `lib/statistics/monthly_graph.dart` — the existing `BarChart` implementation. The comparison chart uses the same `fl_chart BarChart` API.
- STATISTICS_MODULE.md §10 — rod width strategy (decreases as more series are shown): adapt this for a fixed two-rod-per-group layout.

### Instructions

**6.1 — Widget scaffold**

Create `HabitComparisonCard` as a `StatefulWidget`. Constructor takes `ComparisonData data`.

State variables:
- `bool showCheckRate = true`
- `bool showTopStreak = true`

**6.2 — Card shell**

Same `Card` configuration as `WeeklyTrendCard` (Phase 5 §5.2).

**6.3 — Header and toggles**

A `Row` containing:
- Left: section title `"Habit Comparison"` (placeholder; real key in Phase 9)
- Right: two toggle buttons (one for check rate, one for top streak), using the same 32×32 `Material`-button pattern from `MonthlyGraph`:
  - Check rate toggle: uses `checkColor` when active, `primaryContainer` background when inactive, icon `Icons.check_circle_outline`
  - Top streak toggle: uses an amber/orange color (`Colors.orange`) when active, icon `Icons.local_fire_department`

**6.4 — Scroll + bar chart**

Because there could be many habits (potentially 10+), the chart must scroll horizontally. Wrap the `BarChart` in a `SingleChildScrollView(scrollDirection: Axis.horizontal)` and give the inner `SizedBox` a calculated width: `max(screenWidth, habitCount * 60.0)` where `habitCount = data.habitTitles.length`.

`BarChartData` configuration:
- `maxY`: dynamically computed as the maximum top-streak value in `data.topStreaks`, rounded up to the nearest 5. Minimum 10.
- One `BarChartGroupData` per habit. Each group has up to 2 rods (conditional on `showCheckRate` and `showTopStreak`):
  - Rod 1 (check rate): `toY = data.checkRates[i] * maxY` (scaled to the same axis as streak, so both rods share the y-axis). Wait — **this is a design problem**: check rates are 0–1 and streaks are 0–N. Mixing them on one y-axis would make check-rate bars invisible next to streak bars.

  **Resolution:** Use a **dual-normalised** approach. Normalise all values to the range `[0.0, maxY]` for display purposes only. Check rate rod: `toY = data.checkRates[i] * maxY`. Top streak rod: `toY = data.topStreaks[i].toDouble()`. Label each rod type clearly in the legend (see §6.5). The visual heights are comparable in relative terms even if the units differ.

- Rod width: `showCheckRate && showTopStreak` → width 8; only one active → width 12
- Rod colours: check rate rod = `checkColor` from `SettingsManager`; top streak rod = `Colors.orange`
- `barTouchData`: `BarTouchData(enabled: false)` for simplicity
- Bottom axis: show abbreviated habit title for each group. Use `data.habitTitles[index]` truncated to 6 characters with `"…"` suffix if longer. `fontSize: 9`, rotated 45°? — try without rotation first; if titles overlap, add rotation using a `Transform.rotate` inside a custom `getTitlesWidget`.
- Left axis: show 0, half of maxY, maxY. `fontSize: 9`.
- Grid: horizontal lines only.
- Animation: 150ms linear.

**6.5 — Legend**

Below the chart, render a `Wrap` legend row:
- Green square + `"Check rate (scaled)"` label
- Orange square + `"Top streak (days)"` label
- Font size 10, grey text. Use the same icon-row style as `OverallStatisticsCard`'s Wrap.

**6.6 — Null guard**

`ComparisonData?` can be null (fewer than 2 active habits). The caller (Phase 8) will guard against null before rendering this widget.

---

### Verify before continuing
- `flutter analyze lib/statistics/habit_comparison_card.dart` reports zero errors.
- Widget renders with 2, 5, and 10 habits without overflow (horizontal scroll handles the overflow).
- Toggling both rods off shows an empty-looking chart gracefully (no crash).

---

> ✅ Phase 6 complete. Review the changes above, then type **continue** to proceed to Phase 7.

---

---

## Phase 7 — Best-Day & Best-Time Summary Card

**Goal:** Build `BestDayTimeCard`, a stateless widget displaying the most consistent day of week and time of day as a clean summary card with a horizontal bar mini-chart showing all 7 days.

### Files to create
- `lib/statistics/best_day_time_card.dart`

### Files to read first
- `lib/statistics/overall_statistics_card.dart` — follow the icon+count row layout pattern using `Wrap`.

### Instructions

**7.1 — Widget scaffold**

Create `BestDayTimeCard` as a `StatelessWidget`. Constructor takes `BestDayTimeData data`.

**7.2 — Card shell**

Same `Card` configuration as previous cards.

**7.3 — Layout**

Arrange the card contents as follows (top to bottom):

1. **Section title row**: `"Best Day & Time"` (placeholder; real key in Phase 9), bold, fontSize 16.

2. **Best day highlight**: A `Row` containing:
   - Icon: `Icons.calendar_today`, coloured with `checkColor` from `SettingsManager`
   - Text: `"Best day: {bestDayOfWeek}"` where `{bestDayOfWeek}` is `data.bestDayOfWeek ?? "Not enough data"`. If null, render the entire row in a muted grey.
   - Spacer, then: `"{rate}%"` where rate is `(data.bestDayRate * 100).round()`. Hide this if `bestDayOfWeek` is null.

3. **Best time highlight**: A `Row` containing:
   - Icon: `Icons.schedule`, coloured with `progressColor` from `SettingsManager`
   - Text: `"Best time: {bestTimeOfDay}"` where `{bestTimeOfDay}` is `data.bestTimeOfDay ?? "No notifications set"`. Muted if null.

4. **Day-of-week mini bar chart**: A `SizedBox(height: 80)` containing a `BarChart` with 7 groups (Mon–Sun). Each group has a single rod:
   - `toY`: the rate value from `data.dayOfWeekRates[dayName]` scaled to 100 (i.e. multiply by 100 for percentage display)
   - `maxY: 100`
   - Rod colour: `checkColor` from `SettingsManager`
   - Bottom axis: 3-letter weekday abbreviations (`"Mon"`, `"Tue"`, etc.), fontSize 9
   - No left axis labels (the values are implicit from bar height)
   - No grid, no border, no touch
   - Highlight the best day's rod: if `data.bestDayOfWeek` matches this weekday, use full `checkColor` opacity; all others at 50% opacity.
   - Animation: 150ms linear.

5. **Disclaimer text** (small, muted): `"Time is based on habit notification schedules."` — fontSize 10, grey. Only show if `data.bestTimeOfDay` is not null.

---

### Verify before continuing
- `flutter analyze lib/statistics/best_day_time_card.dart` reports zero errors.
- `bestDayOfWeek == null` renders without throwing (shows "Not enough data" gracefully).
- `bestTimeOfDay == null` renders without throwing (shows "No notifications set" gracefully).

---

> ✅ Phase 7 complete. Review the changes above, then type **continue** to proceed to Phase 8.

---

---

## Phase 8 — Screen Integration

**Goal:** Wire all four new cards into `StatisticsScreen` so they appear below the existing per-habit cards.

### Files to modify
- `lib/statistics/statistics_screen.dart`

### Files to read first
- `lib/statistics/statistics_screen.dart` in full — understand the existing `FutureBuilder` structure, the `ListView` layout, and how `OverallStatisticsCard` and the inner `ListView` of `StatisticsCard`s are arranged.
- STATISTICS_MODULE.md §7 — the known FutureBuilder anti-pattern (Future created inside `build`). **Do not attempt to fix this in Phase 8.** Document it with a comment if you encounter it, but leave the pattern unchanged to avoid unrelated regressions.

### Instructions

**8.1 — Import new widgets**

At the top of `statistics_screen.dart`, add import statements for:
- `yearly_heatmap_card.dart`
- `weekly_trend_card.dart`
- `habit_comparison_card.dart`
- `best_day_time_card.dart`

**8.2 — Locate the insertion point**

Find the outer `ListView` in the `FutureBuilder`'s `hasData` branch. It currently contains:
1. `OverallStatisticsCard`
2. An inner `ListView` of `StatisticsCard` widgets (shrinkWrap, NeverScrollableScrollPhysics)

The new cards go **after** item 2, as additional children of the outer `ListView`.

**8.3 — Add `WeeklyTrendCard`**

After the inner `StatisticsCard` list, add:
```
if (snapshot.data!.overallWeeklyTrend != null)
  Padding(padding: EdgeInsets.all(12), child: WeeklyTrendCard(data: snapshot.data!.overallWeeklyTrend!))
```

**8.4 — Add `HabitComparisonCard`**

After `WeeklyTrendCard`:
```
if (snapshot.data!.comparison != null)
  Padding(padding: EdgeInsets.all(12), child: HabitComparisonCard(data: snapshot.data!.comparison!))
```

**8.5 — Add `BestDayTimeCard`**

After `HabitComparisonCard`:
```
Padding(padding: EdgeInsets.all(12), child: BestDayTimeCard(data: snapshot.data!.bestDayTime))
```

`BestDayTimeData` is never null (it has default zero values when there is no data), so no null guard is needed.

**8.6 — Add per-habit `YearlyHeatmapCard`s**

This is the most significant layout change. You have two options — **choose Option A** for now:

**Option A (simpler):** Place all per-habit heatmaps inside the existing inner `ListView` of `StatisticsCard` widgets: after each `StatisticsCard`, immediately add its corresponding `YearlyHeatmapCard`. The existing inner `ListView` iterates `habitsData` — add a `HeatmapData` lookup by habit index alongside it. Both lists (`habitsData` and `heatmaps`) are in the same order.

```
for (int i = 0; i < habitsData.length; i++) {
  StatisticsCard(data: habitsData[i])
  Padding(..., child: YearlyHeatmapCard(data: heatmaps[i]))
}
```

Convert the inner `ListView.builder` to an explicit `Column` if needed, or keep `ListView.builder` and index into both lists by `index`.

**Option B (future enhancement):** Move heatmaps to a separate section header `"Activity Heatmaps"` above the weekly trend card. Do not implement Option B in this phase.

**8.7 — Section headers (optional)**

Consider adding small section header `Text` widgets between groups of cards to aid navigation:
- `"Per Habit"` — above the `StatisticsCard`/`YearlyHeatmapCard` block
- `"Overall Trends"` — above `WeeklyTrendCard`, `HabitComparisonCard`, `BestDayTimeCard`

Style: `fontSize 13`, `fontWeight.w600`, `color: colorScheme.onSurface.withOpacity(0.5)`, left-padded 16px. This is optional if the visual flow already feels clear.

---

### Verify before continuing
- `flutter analyze lib/statistics/statistics_screen.dart` reports zero errors.
- Hot-restart the app. Navigate to the Statistics screen. All four new cards should appear below the existing content without overflow errors.
- Test with zero habits: the existing `EmptyStatisticsImage` still shows — none of the new cards should appear.
- Test with one non-archived habit: `HabitComparisonCard` does not appear (comparison is null with < 2 habits). All other cards appear.
- Test with one archived habit and one active: comparison still shows null (archived habit excluded).

---

> ✅ Phase 8 complete. Review the changes above, then type **continue** to proceed to Phase 9.

---

---

## Phase 9 — Localization

**Goal:** Add all user-visible strings from the new widgets to the localization system so they are translatable. English strings only in this phase; other languages will fall back to English automatically until translated.

### Files to modify
- `lib/l10n/intl_en.arb` (the English source `.arb` file — verify the exact filename by listing `lib/l10n/`)
- Run `flutter gen-l10n` after editing the `.arb` file to regenerate the `S` class

### Files to read first
- Open `lib/l10n/intl_en.arb` and read its structure. Keys follow camelCase convention and values are English strings. Some keys have `@key` metadata entries (description) — add these for your new keys too.

### Instructions

**9.1 — Identify all hardcoded strings**

Search the four new widget files for any hardcoded English string literals used as user-visible text. You should find at minimum:

| Widget | Hardcoded string | Suggested ARB key |
|---|---|---|
| `YearlyHeatmapCard` | `"Less"` | `heatmapLegendLess` |
| `YearlyHeatmapCard` | `"More"` | `heatmapLegendMore` |
| `WeeklyTrendCard` | `"12-Week Trend"` | `weeklyTrendTitle` |
| `HabitComparisonCard` | `"Habit Comparison"` | `habitComparisonTitle` |
| `HabitComparisonCard` | `"Check rate (scaled)"` | `comparisonCheckRateLabel` |
| `HabitComparisonCard` | `"Top streak (days)"` | `comparisonTopStreakLabel` |
| `BestDayTimeCard` | `"Best Day & Time"` | `bestDayTimeTitle` |
| `BestDayTimeCard` | `"Best day: "` | `bestDayLabel` |
| `BestDayTimeCard` | `"Best time: "` | `bestTimeLabel` |
| `BestDayTimeCard` | `"Not enough data"` | `notEnoughData` |
| `BestDayTimeCard` | `"No notifications set"` | `noNotificationsSet` |
| `BestDayTimeCard` | `"Time is based on habit notification schedules."` | `bestTimeDisclaimer` |

Check for additional strings in section headers (Phase 8 §8.7) if you added them.

**9.2 — Add entries to `intl_en.arb`**

For each string in §9.1, add two entries to the `.arb` file: the key-value pair and its `@key` metadata with a `"description"` field. Follow the exact format already used in the file.

**9.3 — Replace hardcoded strings in widgets**

In each of the four widget files, replace every hardcoded string from §9.1 with a call to `S.of(context).keyName`. Ensure `S` is imported correctly (it will be in `lib/generated/intl/messages_all.dart` or similar — check the import used in existing statistics widgets like `statistics_screen.dart`).

**9.4 — Regenerate**

Run:
```bash
flutter gen-l10n
```

Confirm the `S` class is regenerated without errors and the new keys are accessible.

---

### Verify before continuing
- `flutter analyze lib/` reports zero errors.
- `flutter gen-l10n` completes without errors.
- Hot-restart the app; all new card titles and labels appear in English.
- No remaining hardcoded user-visible English strings in the four new widget files (error messages, debug strings, and comments are exempt).

---

> ✅ Phase 9 complete. Review the changes above, then type **continue** to proceed to Phase 10.

---

---

## Phase 10 — Testing & Polish

**Goal:** Write unit tests for the calculation logic, verify all edge cases from STATISTICS_MODULE.md, and do a final visual polish pass.

### Files to create
- `test/statistics_enhanced_test.dart`

### Files to modify (polish only, no logic changes)
- `lib/statistics/yearly_heatmap_card.dart`
- `lib/statistics/weekly_trend_card.dart`
- `lib/statistics/habit_comparison_card.dart`
- `lib/statistics/best_day_time_card.dart`

### Instructions

**10.1 — Unit tests: `calculateHeatmaps`**

Write tests in `test/statistics_enhanced_test.dart`. Use `mocktail` or plain Dart test stubs (the existing test suite uses `mocktail` — follow that pattern).

Test cases:
- Habit with no events → `HeatmapData.dailyCounts` is empty, no crash
- Habit with one check event on Jan 15 → `dailyCounts[DateTime.utc(year, 1, 15)] == 3`
- Habit with one fail event → level 2
- Habit with one skip event → level 1
- Habit with partial progress event (progressValue < targetValue) → level 2
- Habit with complete progress event (progressValue >= targetValue) → level 3
- Event outside target year → not included in `dailyCounts`
- `DayType.clear` event → not included in `dailyCounts`

**10.2 — Unit tests: `calculateWeeklyTrend`**

Test cases:
- All habits with no events → returns `null`
- One habit with check events in the last 3 weeks and nothing before → indices 0–8 are `0.0`, indices 9–11 reflect the data
- Week with mixed check and fail events → rate is between 0 and 1 (not 0 and not 1)
- Week with only skip events → rate is `0.0` (skips are not check-equivalent)

**10.3 — Unit tests: `calculateComparison`**

Test cases:
- Zero habits → returns `null`
- One non-archived habit → returns `null`
- Two non-archived habits → returns `ComparisonData` with 2 entries
- One non-archived + one archived → returns `null` (only 1 qualifies)
- Habit with zero logged events → `checkRates[i] == 0.0`, no division-by-zero crash

**10.4 — Unit tests: `calculateBestDayTime`**

Test cases:
- All habits with no events → `bestDayOfWeek == null`, all `dayOfWeekRates` values == 0.0
- Fewer than 14 total events → `bestDayOfWeek == null`
- 14+ events all on Mondays → `bestDayOfWeek == "Monday"`, `bestDayRate == 1.0`
- No habits with notifications enabled → `bestTimeOfDay == null`
- All habits with morning notification times → `bestTimeOfDay == "Morning"`
- Tie between two buckets → Morning wins (earliest tiebreaker)

**10.5 — Known quirks to verify (from STATISTICS_MODULE.md)**

Manually verify (with a real device or simulator) the following known quirks still behave as expected — they should not be changed, just confirmed:

- **Quirk 1:** Archived habits appear in heatmaps and weekly trend (because `allHabits` is passed). This is acceptable. Confirm the comparison card correctly excludes them.
- **Quirk 2:** FutureBuilder re-runs on HabitsManager notifications while stats screen is open. All four new cards reload with a spinner on every habit change. This is the known anti-pattern — acceptable; do not fix.
- **Quirk 6:** `actualStreak` from forward scan may show a streak from the distant past. The new cards do not display `actualStreak` directly, so this is not a concern for the new features.

**10.6 — Polish pass**

Review each of the four new widget files and check:
- Card paddings are consistent with `StatisticsCard` (12px outer `Padding`, 16px inner `Card` padding).
- All `Text` widgets use the theme's `TextTheme` styles where possible, not hardcoded `Color` values.
- No hardcoded `Colors.white` or `Colors.black` — use `colorScheme.onPrimary` / `colorScheme.onSurface` instead for dark/light mode compatibility.
- All `SettingsManager` reads use `listen: false` (as documented in STATISTICS_MODULE.md §13 — color changes are not live-reactive within the statistics screen without a full rebuild; this is the existing convention, maintain it).
- The heatmap grid does not cause jank on scroll — confirm by profiling on a debug build with 365 populated cells.

**10.7 — Run full test suite**

```bash
flutter test
```

All pre-existing tests must still pass. The new tests in `statistics_enhanced_test.dart` must all pass.

**10.8 — Run analyzer**

```bash
flutter analyze lib/ test/
```

Zero errors. Warnings about deprecated APIs should be noted in a comment but not necessarily fixed in this phase.

---

### Verify before continuing (final checklist)

- [ ] `flutter test` — all tests pass, including new ones
- [ ] `flutter analyze lib/ test/` — zero errors
- [ ] Statistics screen displays all four new cards on a device/simulator with habits that have data
- [ ] Statistics screen shows `EmptyStatisticsImage` when no habits exist — no new cards render
- [ ] Dark mode: all new cards use theme colours correctly, no white-on-white or black-on-black
- [ ] OLED Black theme: cards use `primaryContainer` which will be very dark — confirm readability
- [ ] Horizontal scrolling in `YearlyHeatmapCard` and `HabitComparisonCard` does not interfere with the outer vertical `ListView` scroll (test on both Android and iOS gesture behaviours)
- [ ] Heatmap month labels are aligned correctly to their columns

---

> ✅ Phase 10 complete. The Enhanced Statistics Module implementation is finished. All four features — yearly heatmap, weekly trend line chart, per-habit comparison bar chart, and best-day/best-time summary card — are implemented, tested, and integrated into the statistics screen.

---

## Appendix: File Map

| Phase | Action | File path |
|---|---|---|
| 1, 2 | Modify | `lib/statistics/statistics.dart` |
| 3 | Modify | `lib/habits/habits_manager.dart` |
| 4 | Create | `lib/statistics/yearly_heatmap_card.dart` |
| 5 | Create | `lib/statistics/weekly_trend_card.dart` |
| 6 | Create | `lib/statistics/habit_comparison_card.dart` |
| 7 | Create | `lib/statistics/best_day_time_card.dart` |
| 8 | Modify | `lib/statistics/statistics_screen.dart` |
| 9 | Modify | `lib/l10n/intl_en.arb` |
| 10 | Create | `test/statistics_enhanced_test.dart` |
| 10 | Modify | All four new widget files (polish only) |

## Appendix: Critical Warnings Summary

1. **Archived habits** — `HabitsManager.getFutureStatsData()` passes `allHabits` unfiltered. Heatmaps and weekly trend include archived habits. Comparison does not (filtered in Phase 2 §2.3). This asymmetry is intentional and must be preserved.
2. **FutureBuilder anti-pattern** — Do not attempt to fix the Future-in-build anti-pattern documented in STATISTICS_MODULE.md §7. Fixing it is out of scope and risks regressions.
3. **`listen: false` for SettingsManager** — All four new widgets must use `Provider.of<SettingsManager>(context, listen: false)` when reading colours, following the existing convention. Color changes will not be live-reactive.
4. **DateTime normalisation** — Heatmap keys must be `DateTime.utc(y, m, d)` (midnight), not the raw event datetime (which is stored at noon UTC). Getting this wrong causes lookup misses.
5. **SplayTreeMap iteration order** — `habit.habitData.events.forEach()` iterates in ascending key order (chronological). All new calculation methods must rely on this assumption.
6. **`DayType.clear` guard** — Every event iteration must include the guard `value[0] != null && value[0] != DayType.clear`, matching the existing `calculateStatistics` behaviour.
