# Habo — Statistics Cards Adjustment Blueprint

> **For Claude Code.** Read the actual source files listed in each phase before writing any code. Do not skip phases or combine them. Do not rewrite files from scratch — adjust only what each phase specifies. After completing each phase, print the stop prompt exactly as written and wait for the user to type **continue**.

---

## Pre-flight: files to read before starting

Before Phase 1, read all of the following files in full. Do not write any code yet.

```
lib/statistics/statistics.dart
lib/statistics/statistics_screen.dart
lib/statistics/habit_comparison_card.dart
lib/statistics/weekly_trend_card.dart
lib/statistics/yearly_heatmap_card.dart
lib/statistics/best_day_time_card.dart
lib/habits/habits_manager.dart
```

Also read `lib/statistics/monthly_graph.dart` for toggle-button and fl_chart conventions you must match.

---

## Phase Overview

| # | Title | Scope |
|---|---|---|
| 1 | Data layer — leaderboard fields | Add `actualStreaks`, `habitCategories`, `habitColors` to `ComparisonData` in `statistics.dart` |
| 2 | Data layer — heatmap fields | Add `habitColor`, `categoryTitle`, `categoryId` to `HeatmapData`; add streak-run map to `HeatmapData` |
| 3 | Data layer — weekly trend tooltip payload | Add `List<List<String>> weekHabitTitles` to `WeeklyTrendData` |
| 4 | Calculation — leaderboard | Populate new `ComparisonData` fields in `calculateComparison()` |
| 5 | Calculation — heatmap | Populate new `HeatmapData` fields in `calculateHeatmaps()` |
| 6 | Calculation — weekly trend tooltip | Populate `weekHabitTitles` in `calculateWeeklyTrend()` |
| 7 | Widget — `HabitComparisonCard` (leaderboard) | Replace bar chart implementation with horizontal ranked bar list + 3 toggle modes + category filter/sort |
| 8 | Widget — `WeeklyTrendCard` | Add stat boxes, percentage Y-axis, tap tooltip, category filter |
| 9 | Widget — `YearlyHeatmapCard` | One row per habit, streak-based colour darkening, category + habit filter dropdowns, grouped section labels |
| 10 | Screen — ordering & wiring | Reorder cards in `StatisticsScreen`; confirm `BestDayTimeCard` is untouched |
| 11 | Localization | Add new ARB keys for all new labels |
| 12 | Polish & verify | Analyzer, edge cases, empty states |

---

---

## Phase 1 — Data Layer: Leaderboard Fields

**Goal:** Extend `ComparisonData` so it carries everything the new leaderboard widget needs — actual (current) streaks, category names per habit, and a placeholder for per-habit color.

### Files to modify
- `lib/statistics/statistics.dart`

### Read first
Open `statistics.dart` and locate the `ComparisonData` class built in the previous blueprint. It currently has:
- `List<String> habitTitles`
- `List<double> checkRates`
- `List<int> topStreaks`
- `List<Color?> colors` (all nulls)

### Instructions

**1.1 — Add `List<int> actualStreaks`**

Add a new field to `ComparisonData`:
- `List<int> actualStreaks` — one entry per habit, in the same index order as `habitTitles`. Each value is the habit's `actualStreak` from `StatisticsData` (the forward-scan current streak). Will be populated in Phase 4.

Initialise to an empty list in the constructor.

**1.2 — Add `List<String> habitCategories`**

Add a new field:
- `List<String> habitCategories` — one entry per habit. Each value is a comma-joined string of that habit's category titles (e.g. `"Health, Morning"`) taken from the `Habit` object's categories list. If the habit has no categories, use an empty string `""`. This is used for grouping and filtering in the leaderboard UI.

Initialise to an empty list in the constructor.

**1.3 — Add `List<List<String>> habitCategoryList`**

Add a new field:
- `List<List<String>> habitCategoryList` — one entry per habit. Each entry is the raw list of category title strings for that habit (not joined). The UI uses this for filter matching.

Initialise to an empty list in the constructor.

**1.4 — Add `List<String> allCategoryTitles`**

Add a new field:
- `List<String> allCategoryTitles` — the deduplicated, sorted list of all category names that appear across any non-archived habit. Used to populate the filter dropdown. Empty list if no categories exist.

Initialise to an empty list in the constructor.

> **Note:** Do not change the type or meaning of `List<Color?> colors`. It remains all-nulls for now; the leaderboard will fall back to `checkColor` from `SettingsManager` when a color is null. Per-habit coloring is a future enhancement.

---

### Verify before continuing
- `flutter analyze lib/statistics/statistics.dart` — zero errors.
- `ComparisonData` constructor still accepts its existing positional/named parameters without breaking callers in `statistics_screen.dart` or `habit_comparison_card.dart`. If the constructor is positional, add the new fields with default values (`= const []`) so existing call sites don't break.

---

> ✅ Phase 1 complete. Review the changes above, then type **continue** to proceed to Phase 2.

---

---

## Phase 2 — Data Layer: Heatmap Fields

**Goal:** Extend `HeatmapData` so each habit row in the new multi-row heatmap has a per-habit color, its category information, and a map of current streak run lengths per day (for colour-darkening logic).

### Files to modify
- `lib/statistics/statistics.dart`

### Read first
Locate `HeatmapData` in `statistics.dart`. It currently has:
- `String title`
- `Map<DateTime, int> dailyCounts` — level 0–3 integers
- `int year`

### Instructions

**2.1 — Add `Color? habitColor`**

Add a field:
- `Color? habitColor` — reserved for a future per-habit color. Populated as `null` for now. The heatmap widget will fall back to `checkColor` from `SettingsManager` when null. Do not import `dart:ui` or `package:flutter/material.dart` into `statistics.dart` if it is not already imported — if Color is not available, use `int? habitColorValue` storing the ARGB int instead, and document that the widget converts it with `Color(habitColorValue!)`.

**2.2 — Add `String categoryTitle` and `int? categoryId`**

Add two fields:
- `String categoryTitle` — the primary (first) category title for this habit. Empty string if the habit has no categories. Used for grouping rows under section headers in the heatmap.
- `int? categoryId` — the primary category's ID. `null` if no categories. Used for sort-order consistency.

**2.3 — Add `Map<DateTime, int> streakRunLengths`**

Add a field:
- `Map<DateTime, int> streakRunLengths` — keys are the same midnight-UTC `DateTime` keys as in `dailyCounts`. Values are the length of the consecutive check/complete-progress streak that ends on (or includes) that day. A day with level 3 that is the first day of a streak has value `1`; the second consecutive check day has value `2`; and so on up to a cap of `10` (day 10 and beyond all store `10`, since the darkening plateaus at day 10+). Days with level 0, 1, or 2 are not included as keys in this map (or may store `0` — either is acceptable, as long as missing keys default to `0` in the widget lookup).

The calculation to populate this map is described in Phase 5. Define the field here with an empty map default.

**2.4 — Add `List<String> allCategoryTitles` to the top-level `AllStatistics`**

Locate `AllStatistics`. Add one field:
- `List<String> allCategoryTitles` — the deduplicated, sorted list of all category names across all non-archived habits. Shared between the leaderboard filter and the heatmap filter. Computed once and stored here to avoid recomputing in each widget. Initialise to empty list.

> **Important:** Both `ComparisonData.allCategoryTitles` (Phase 1) and `AllStatistics.allCategoryTitles` (this step) carry the same data. The reason for both is that `HabitComparisonCard` receives `ComparisonData` while `YearlyHeatmapCard` receives `List<HeatmapData>` — a single source on `AllStatistics` lets `statistics_screen.dart` pass it to either widget without recalculating.

---

### Verify before continuing
- `flutter analyze lib/statistics/statistics.dart` — zero errors.
- No existing fields on `HeatmapData` or `AllStatistics` have been renamed or removed.
- All new fields have default values so no existing constructor call sites break.

---

> ✅ Phase 2 complete. Review the changes above, then type **continue** to proceed to Phase 3.

---

---

## Phase 3 — Data Layer: Weekly Trend Tooltip Payload

**Goal:** Extend `WeeklyTrendData` so each of the 12 week slots knows which habit titles were completed that week — needed to render the tap-tooltip.

### Files to modify
- `lib/statistics/statistics.dart`

### Read first
Locate `WeeklyTrendData`. It currently has:
- `String title`
- `List<double> weeklyRates` — 12 elements
- `List<String> weekLabels` — 12 elements

### Instructions

**3.1 — Add `List<List<String>> weekCompletedHabits`**

Add a field:
- `List<List<String>> weekCompletedHabits` — exactly 12 elements (one per week slot, same index alignment as `weeklyRates`). Each inner list contains the titles of all habits that had at least one check-equivalent (level 3) event during that week. The inner list may be empty (no completions that week). Titles should appear in the same order as they appear in `allHabits`. Populated in Phase 6.

Initialise to a list of 12 empty lists in the constructor.

**3.2 — Add `List<String> allCategoryTitles` to `WeeklyTrendData`**

Add a field:
- `List<String> allCategoryTitles` — the deduplicated, sorted category names across all habits included in this trend calculation. Used to populate the category filter dropdown in `WeeklyTrendCard`. Initialise to an empty list.

> **Note on category filtering for weekly trend:** When the user filters by category, the `weeklyRates` and `weekCompletedHabits` need to be recomputed for only the habits in that category. Rather than storing per-category pre-computed rates (expensive), the widget will recompute rates client-side from `weekCompletedHabits` when a filter is applied. So `weekCompletedHabits` must store the full unfiltered list of habit titles per week, and the widget filters them at render time. This is described in Phase 8.

---

### Verify before continuing
- `flutter analyze lib/statistics/statistics.dart` — zero errors.
- `WeeklyTrendData` constructor has default values for new fields so existing call sites do not break.

---

> ✅ Phase 3 complete. Review the changes above, then type **continue** to proceed to Phase 4.

---

---

## Phase 4 — Calculation: Leaderboard Data

**Goal:** Populate the new `ComparisonData` fields added in Phase 1 inside the existing `calculateComparison()` method.

### Files to modify
- `lib/statistics/statistics.dart`

### Read first
Locate `calculateComparison()` in the `Statistics` class. Understand what it currently does: it filters to non-archived habits, computes `checkRates` and `topStreaks`, and populates `ComparisonData`. Also read the `Habit` model — specifically how `habit.habitData.categories` is structured (it is a `List<Category>` where each `Category` has a `title` and an `id`).

### Instructions

**4.1 — Populate `actualStreaks`**

Within the loop that builds each habit's entry in `ComparisonData`, retrieve `actualStreak` from the corresponding `StatisticsData` entry. The calculation method has access to the habits list and optionally to the already-computed `habitsData` from the outer `calculateStatistics` call.

Strategy: `calculateComparison` is called from the end of `calculateStatistics`, which has already built `stats.habitsData`. Pass `stats.habitsData` as a parameter to `calculateComparison`, or restructure so that after filtering to non-archived habits, the method looks up `StatisticsData` by matching habit title (or index). Use whichever approach requires fewer changes to existing code.

Append the `actualStreak` value to `actualStreaks` for each habit entry.

**4.2 — Populate `habitCategories`, `habitCategoryList`, and `allCategoryTitles`**

For each non-archived habit:
- Get `habit.habitData.categories` — a `List<Category>`.
- Build `habitCategoryList[i]` = `categories.map((c) => c.title).toList()`.
- Build `habitCategories[i]` = `habitCategoryList[i].join(', ')`.

After the loop, build `allCategoryTitles`:
- Collect all category titles from every `habitCategoryList` entry into a flat set (to deduplicate).
- Sort alphabetically.
- Assign to `ComparisonData.allCategoryTitles`.

Also assign the same list to `AllStatistics.allCategoryTitles` so `statistics_screen.dart` can pass it to `YearlyHeatmapCard` and `WeeklyTrendCard`.

---

### Verify before continuing
- `flutter analyze lib/statistics/statistics.dart` — zero errors.
- Trace through a scenario with 2 non-archived habits, one in category "Health", one in no category: `habitCategoryList` = `[["Health"], []]`, `allCategoryTitles` = `["Health"]`.

---

> ✅ Phase 4 complete. Review the changes above, then type **continue** to proceed to Phase 5.

---

---

## Phase 5 — Calculation: Heatmap Streak Runs and Category Fields

**Goal:** Populate the new `HeatmapData` fields added in Phase 2 inside the existing `calculateHeatmaps()` method.

### Files to modify
- `lib/statistics/statistics.dart`

### Read first
Locate `calculateHeatmaps()`. It currently iterates each habit's events, normalises dates to midnight UTC, and stores level integers (0–3) in `dailyCounts`.

### Instructions

**5.1 — Populate `categoryTitle` and `categoryId`**

After creating each `HeatmapData` object, before the events loop:
- Set `heatmapData.categoryTitle` = the title of the first category in `habit.habitData.categories`, or `""` if the list is empty.
- Set `heatmapData.categoryId` = the ID of the first category, or `null` if none.

**5.2 — Populate `streakRunLengths`**

After the events loop that builds `dailyCounts`, compute `streakRunLengths` as a second pass over `dailyCounts`:
- Sort the keys of `dailyCounts` in ascending date order (they should already be ordered but sort explicitly to be safe).
- Walk through the sorted keys. Maintain a running counter `currentRun = 0`.
- For each date:
  - If `dailyCounts[date] == 3` (check/complete): increment `currentRun`. Set `streakRunLengths[date] = min(currentRun, 10)`.
  - If `dailyCounts[date] != 3`: reset `currentRun = 0`. Do not add an entry to `streakRunLengths` for this date (or store 0 — either is fine).
  - When checking for consecutiveness: a streak run only continues if the previous level-3 day was exactly the day before. If there is a gap, reset `currentRun`.

Correct consecutiveness check: compare each date against the previous processed date. If `date.difference(prevDate).inDays > 1`, reset `currentRun = 0` before incrementing for the current date.

**5.3 — Populate `AllStatistics.allCategoryTitles`**

After building `stats.heatmaps`, compute `AllStatistics.allCategoryTitles`:
- Collect all non-empty `categoryTitle` values from `stats.heatmaps`.
- Deduplicate and sort alphabetically.
- Assign to `stats.allCategoryTitles`.

If `calculateComparison()` already sets this field (Phase 4), verify that the value is consistent. If both set it, the second assignment wins — ensure both use the same deduplication logic so the result is identical.

---

### Verify before continuing
- `flutter analyze lib/statistics/statistics.dart` — zero errors.
- Trace: habit with check events on Jan 1, 2, 3, then gap, then Jan 10 → `streakRunLengths` = `{Jan1: 1, Jan2: 2, Jan3: 3, Jan10: 1}`. Jan 10 resets because Jan 4–9 are not level-3 days.

---

> ✅ Phase 5 complete. Review the changes above, then type **continue** to proceed to Phase 6.

---

---

## Phase 6 — Calculation: Weekly Trend Tooltip Payload

**Goal:** Populate `weekCompletedHabits` and `WeeklyTrendData.allCategoryTitles` inside `calculateWeeklyTrend()`.

### Files to modify
- `lib/statistics/statistics.dart`

### Read first
Locate `calculateWeeklyTrend()`. It currently computes 12 weekly rates and labels by aggregating all habit events into a day-level map, then counting per week.

### Instructions

**6.1 — Track completed habits per week**

The current implementation aggregates days across all habits into a single `Map<DateTime, List<int>>`. To also know which habits completed each week, you need to track per-habit completion per week.

Strategy: Extend the inner loop. For each habit, for each event in the 12-week window, if the level is 3 (check-equivalent), record `habitTitle` as having completed on that day. After processing all habits and all days, for each of the 12 week slots, collect the distinct habit titles that had at least one level-3 day during that week.

Concretely:
- Build `Map<int, Set<String>> weekCompletedHabitSets` — key is week index (0–11), value is a set of habit titles.
- For each habit, for each day in its events that falls within the 12-week window and has level 3, find the week index for that day and add the habit's title to the corresponding set.
- After all habits are processed, convert each set to a sorted list and assign to `weekCompletedHabits[weekIndex]`.

**6.2 — Populate `WeeklyTrendData.allCategoryTitles`**

After building the `WeeklyTrendData` object, populate its `allCategoryTitles` field:
- Use `AllStatistics.allCategoryTitles` if it is already computed at this point in the call sequence, or recompute from the habits list the same way as in Phase 4.
- The ordering of calls at the end of `calculateStatistics()` matters: if `allCategoryTitles` is set before `calculateWeeklyTrend()` is called, you can just copy it. If not, compute it inline.

---

### Verify before continuing
- `flutter analyze lib/statistics/statistics.dart` — zero errors.
- Trace: two habits A and B, both checked on the same Monday of week 11 → `weekCompletedHabits[11]` contains both "A" and "B" (or whichever order the sort produces).

---

> ✅ Phase 6 complete. Review the changes above, then type **continue** to proceed to Phase 7.

---

---

## Phase 7 — Widget: `HabitComparisonCard` (Leaderboard)

**Goal:** Replace the grouped bar chart in `habit_comparison_card.dart` with a horizontal ranked bar list. The card lists all non-archived habits as rows, sorted by the active metric, with medal icons for top 3 and rank numbers for the rest. Three toggle modes: current streak, top streak, completion rate. Sortable: highest-first, lowest-first, or by category. Filterable by a single category.

### Files to modify
- `lib/statistics/habit_comparison_card.dart`

### Read first
- Read the current `habit_comparison_card.dart` in full.
- Read `monthly_graph.dart` for the toggle-button pattern (32×32 `Material` buttons).
- Read `overall_statistics_card.dart` for the `Wrap` icon-row pattern.
- The card currently uses `fl_chart BarChart`. **The bar chart is being removed entirely.** The fl_chart import may still be needed if used elsewhere in the file; otherwise remove it.

### Instructions

**7.1 — State variables**

`HabitComparisonCard` is already a `StatefulWidget`. Adjust the state class to have these state variables (remove any state variables that were specific to the old bar chart):

```
enum LeaderboardMetric { currentStreak, topStreak, completionRate }
enum LeaderboardSort { highestFirst, lowestFirst, byCategory }

LeaderboardMetric _metric = LeaderboardMetric.currentStreak
LeaderboardSort _sort = LeaderboardSort.highestFirst
String? _selectedCategory   // null = all categories
```

**7.2 — Compute sorted/filtered list**

Add a private method (or computed getter) that derives the display list from `widget.data`:

1. Start with a zipped list of index → (title, currentStreak, topStreak, checkRate, categoryList). Index maps back into `widget.data` lists.
2. Apply category filter: if `_selectedCategory != null`, keep only entries where `widget.data.habitCategoryList[i]` contains `_selectedCategory`.
3. Apply sort:
   - `highestFirst`: sort descending by the active metric value.
   - `lowestFirst`: sort ascending by the active metric value.
   - `byCategory`: sort by primary category title alphabetically, then by active metric descending within each category.
4. Return the sorted, filtered list as a list of records/maps (or a small data class) preserving the original index for data lookup.

**7.3 — Header row: metric toggles + sort control + category filter**

Replace the existing header row with:

- **Three metric toggle buttons** (matching the 32×32 `Material` pattern from `MonthlyGraph`):
  - Current streak: icon `Icons.local_fire_department`
  - Top streak: icon `Icons.emoji_events`
  - Completion rate: icon `Icons.check_circle_outline`
  - Active button: `checkColor` background, white icon. Inactive: `primaryContainer` background, coloured icon.

- **Sort control**: a small `DropdownButton<LeaderboardSort>` with three options: "Highest first", "Lowest first", "By category". Place it to the right of the toggle buttons.

- **Category filter**: if `widget.data.allCategoryTitles.isNotEmpty`, show a second `DropdownButton<String?>` with "All" (null) plus each category title. Place it to the right of the sort dropdown, or on a second row if horizontal space is tight. When a category is selected, `setState(() { _selectedCategory = value; })`.

**7.4 — Ranked bar rows**

Below the header, render the sorted/filtered list as a `Column` of rows (not a `ListView` — the entire card is inside the outer scrolling `ListView` in `StatisticsScreen`, so use `Column` with `shrinkWrap` logic or just `Column`).

Each row contains:
1. **Rank indicator** (fixed 32px width):
   - Rank 1: `🥇` gold medal icon — use `Icons.looks_one` tinted gold (`Color(0xFFFFD700)`) or a Unicode medal emoji in a `Text` widget. Medal emoji is simpler: `"🥇"`, `"🥈"`, `"🥉"`.
   - Rank 4 and beyond: a `Text` of the rank number (e.g. `"4"`) in muted grey, `fontSize 13`, right-aligned in the 32px slot.
   - Note: ranks 1–3 always refer to position in the currently displayed sorted/filtered list, not the original habit order.

2. **Habit name** (flexible, ellipsized): `Text(title, overflow: TextOverflow.ellipsis)`, `fontSize 14`.

3. **Filled bar**: A `Fraction`-based horizontal bar. Use a `LayoutBuilder` or a `FractionallySizedBox`. The bar fills from 0 to `value / maxValue` where `maxValue` is the maximum value in the current filtered+sorted list for the active metric (not the global maximum — rescale to the visible data). If all values are 0, bars are all empty.
   - Bar colour: `checkColor` from `SettingsManager` at full opacity.
   - Bar background (empty part): `checkColor.withOpacity(0.15)`.
   - Bar height: 8px. Rounded ends (`BorderRadius.circular(4)`).
   - Wrap the bar in a `ClipRect` to prevent overflow.

4. **Exact value** (fixed right side, 48px width, right-aligned):
   - For streaks: `"${value}d"` (days), `fontSize 13`.
   - For completion rate: `"${(rate * 100).round()}%"`, `fontSize 13`.

Row layout: `Row([rankWidget, 8px gap, Expanded(nameText), 8px gap, Expanded(flex:2, bar), 8px gap, valueText])`.

Add a `Divider` with `height: 1` between rows. When `_sort == LeaderboardSort.byCategory`, also insert a **category section label** row (not a data row) between groups: a `Text` of the category name in a muted, small style (`fontSize 11`, `fontWeight.w600`, `colorScheme.onSurface.withOpacity(0.5)`), left-padded, preceded by a slightly thicker `Divider`.

**7.5 — Empty states**

- If the filtered list is empty (no habits in selected category): show a centred `Text("No habits in this category")` in grey.
- If `widget.data` itself is null (passed from screen with a null guard): this widget is never rendered — the screen guards it with `if (comparison != null)`.

**7.6 — Remove old bar chart code**

Delete all `BarChart`, `BarChartGroupData`, `BarChartRodData`, and `fl_chart` usage that was specific to the old implementation. Remove the old `showCheckRate` and `showTopStreak` boolean state variables. Remove the old legend row. Remove the old `SingleChildScrollView` horizontal scroll wrapper (the new layout is vertical and does not need it).

If `fl_chart` is no longer used at all in this file, remove its import.

---

### Verify before continuing
- `flutter analyze lib/statistics/habit_comparison_card.dart` — zero errors.
- With 5 habits, all three metric toggles produce a correctly sorted ranked list.
- With a category filter active, only habits in that category appear, and ranks restart from 1.
- `byCategory` sort produces section dividers between category groups.
- With 1 habit visible, no crash (bar fills to 100%, rank shows 🥇).
- With all values at 0 (no events), bars are all empty but rows still render.

---

> ✅ Phase 7 complete. Review the changes above, then type **continue** to proceed to Phase 8.

---

---

## Phase 8 — Widget: `WeeklyTrendCard`

**Goal:** Adjust the existing `WeeklyTrendCard` to add two stat boxes (this week / 12-week average), a percentage Y-axis, a tap-to-show speech-bubble tooltip with the week's percentage and list of completed habits, and a category filter that recomputes rates client-side.

### Files to modify
- `lib/statistics/weekly_trend_card.dart`

### Read first
Read `weekly_trend_card.dart` in full. It is currently a `StatelessWidget`. Note:
- The `LineChart` currently uses `minY: 0.0`, `maxY: 1.0`.
- The left axis currently shows `"0%"`, `"50%"`, `"100%"`.
- `lineTouchData` is currently disabled.

### Instructions

**8.1 — Convert to `StatefulWidget`**

Convert `WeeklyTrendCard` from `StatelessWidget` to `StatefulWidget`. Add state variables:

```
String? _selectedCategory   // null = all
int? _tappedSpotIndex       // null = no tooltip shown; 0–11 = which week dot was tapped
```

**8.2 — Category filter**

If `widget.data.allCategoryTitles.isNotEmpty`, add a `DropdownButton<String?>` in the header row (to the right of the title):
- Options: `null` → `"All habits"` plus each category title.
- On change: `setState(() { _selectedCategory = value; _tappedSpotIndex = null; })`.

**8.3 — Derived rates for filtered view**

Add a private method `List<double> _filteredRates()`:
- If `_selectedCategory == null`, return `widget.data.weeklyRates` as-is.
- Otherwise, for each of the 12 week slots:
  - Get `widget.data.weekCompletedHabits[weekIndex]` — the list of all habit titles that completed that week.
  - Filter this list to only habits whose title belongs to the selected category. To determine which habits are in a category, use `widget.data.allCategoryTitles` — but wait, the widget only knows category names and week completion lists, not which habit is in which category. 

  **Resolution:** The `WeeklyTrendData.weekCompletedHabits` list contains habit titles. The widget needs to know which habits belong to which category to filter. Pass this information by adding a `Map<String, List<String>> habitCategoryMap` field to `WeeklyTrendData` — key = habit title, value = list of category titles that habit belongs to. Add this field to `WeeklyTrendData` in `statistics.dart` and populate it in `calculateWeeklyTrend()` from the habits list. Then `_filteredRates()` can do: for each week, count how many habits in `weekCompletedHabits[i]` have `habitCategoryMap[title]?.contains(_selectedCategory) == true`, divide by total habits in the selected category that had any logged event that week.

  Actually, a simpler proxy: for each week, denominator = total habits in selected category (fixed, from `habitCategoryMap`), numerator = count of those habit titles that appear in `weekCompletedHabits[weekIndex]`. This gives completion rate = "what fraction of filtered habits completed this week", which is the correct filtered interpretation.

  Return 12 doubles. If the denominator for a week is 0, store `0.0`.

**8.4 — Stat boxes: This Week and 12-Week Average**

Above the chart (below the header row), add a `Row` with two equal-width `Expanded` boxes:

- **This week box**: label `"This week"`, value = `"${(_filteredRates().last * 100).round()}%"`. Use the last element (index 11) of the filtered rates.
- **12-week average box**: label `"12-wk avg"`, value = `"${(filteredRates.reduce((a, b) => a + b) / 12 * 100).round()}%"`.

Style: each box is a small `Container` with `primaryContainer` colour at 60% opacity, rounded corners (8px), padding 8/12. Label in `bodySmall` grey, value in `fontSize 20`, bold, `checkColor`.

**8.5 — Y-axis as percentages**

The Y-axis currently shows `"0%"`, `"50%"`, `"100%"`. Confirm this is already implemented. If the existing implementation uses raw fraction values (0.0, 0.5, 1.0) and formats them with `%`, no change is needed. If it shows raw decimals, change the `getTitlesWidget` for the left axis to format as `"${(value * 100).round()}%"`.

**8.6 — Tap tooltip**

Change `lineTouchData` from disabled to enabled with a custom handler:

- Set `LineTouchData(enabled: true, touchCallback: ...)`.
- In the touch callback, when the event is a `FlTapUpEvent` (tap only, not pan/hover):
  - Get the touched spot index (0–11).
  - `setState(() { _tappedSpotIndex = tappedIndex; })`.
  - If the same index is tapped again, toggle off: `_tappedSpotIndex = null`.
- In `touchTooltipData`, configure a `LineTouchTooltipData`:
  - `tooltipBgColor`: `colorScheme.surface` with 95% opacity.
  - `tooltipRoundedRadius: 8`.
  - The tooltip body: return a list of `LineTooltipItem`s. Build the tooltip text as:
    - First line: `"Week of {weekLabel}: {rate}%"` — the week label from `widget.data.weekLabels[index]` and the filtered rate for that index.
    - Subsequent lines: up to 5 habit titles from `widget.data.weekCompletedHabits[index]` that pass the category filter, one per line. If more than 5, show `"… +N more"` on the last line.
    - If no habits completed that week: `"No completions"`.
  - Position: `tooltipPosition` set to `LineTooltipPosition.topSide` if available in the installed `fl_chart` version, otherwise use the default (above the dot).

- Also show a visible dot on the tapped index: in `dotData`, customise so the tapped index dot is larger (radius 6) and has a white border (`strokeWidth: 2, strokeColor: Colors.white`). Non-tapped dots keep their default size.

- Tapping anywhere outside a dot (empty space) should dismiss the tooltip. Handle this with a `GestureDetector` wrapping the chart `SizedBox`, listening for `onTapDown` on positions not matching a spot — or simply allow re-tapping the same spot to dismiss (simpler).

**8.7 — Use filtered rates in the chart**

Replace `widget.data.weeklyRates` everywhere in the chart's `spots` list with `_filteredRates()`. Cache the result in a local variable at the top of `build` to avoid calling the method multiple times.

---

### Verify before continuing
- `flutter analyze lib/statistics/weekly_trend_card.dart` — zero errors.
- Tapping a dot shows the tooltip above it with percentage and habit list.
- Tapping the same dot again hides it.
- Switching categories updates the stat boxes and chart line.
- With no category filter, output matches original behaviour.
- With no habits completing any week, stat boxes show `"0%"` and the line is flat at zero — no crash.

---

> ✅ Phase 8 complete. Review the changes above, then type **continue** to proceed to Phase 9.

---

---

## Phase 9 — Widget: `YearlyHeatmapCard`

**Goal:** Replace the single-habit-per-card heatmap grid with a multi-row layout where each row is one habit. Cell colouring changes: fail/no-event = blank, skip = fixed yellow tint, partial progress = fixed light tint of `progressColor`, completed = `checkColor` darkening from lightest (day 1 of streak) to full (day 10+). Add a category multi-select dropdown and a habit multi-select dropdown (grouped by category). Group rows under category section labels with a coloured dot.

### Files to modify
- `lib/statistics/yearly_heatmap_card.dart`

### Read first
Read `yearly_heatmap_card.dart` in full. Understand:
- It is currently a `StatefulWidget` with `HeatmapData data` as its single input (for one habit).
- The grid is built as a horizontal `SingleChildScrollView` of 53 columns × 7 rows.
- The year selector dropdown is already present.

The widget's **constructor signature will change** in Phase 10 (screen integration): it will receive `List<HeatmapData> allHeatmaps` and `List<String> allCategoryTitles` instead of a single `HeatmapData`. Make this change now — it affects how you structure the state.

### Instructions

**9.1 — Change constructor**

Change the widget constructor from:
```
YearlyHeatmapCard({required HeatmapData data})
```
to:
```
YearlyHeatmapCard({required List<HeatmapData> allHeatmaps, required List<String> allCategoryTitles})
```

This will break the call site in `statistics_screen.dart` — it will be fixed in Phase 10.

**9.2 — State variables**

Update state variables:
```
int _year                           // initialised in initState
Set<String> _selectedCategories     // empty = all categories shown
Set<String> _selectedHabitTitles    // empty = all habits shown
```

Remove any state related to the old single-habit year selector (the year selector remains but now applies globally to all rows).

`initState`:
- `_year = widget.allHeatmaps.isNotEmpty ? widget.allHeatmaps.first.dailyCounts.keys.fold(DateTime.now().year, (prev, d) => d.year > prev ? d.year : prev) : DateTime.now().year` — find the most recent year that has any data across all habits, defaulting to current year.
- `_selectedCategories = {}` (empty = all)
- `_selectedHabitTitles = {}` (empty = all)

**9.3 — Derived display list**

Add a private method `List<HeatmapData> _visibleHabits()`:
1. Start with `widget.allHeatmaps`.
2. If `_selectedCategories.isNotEmpty`, keep only entries where `heatmap.categoryTitle` is in `_selectedCategories` (or where `categoryTitle` is empty and the "No category" option is selected — handle this by using `""` as a valid category option key).
3. If `_selectedHabitTitles.isNotEmpty`, keep only entries where `heatmap.title` is in `_selectedHabitTitles`.
4. Return filtered list. If empty, return empty list (the widget renders an empty state).

**9.4 — Header: year selector + category filter + habit filter**

Replace the existing header row with:

- **Year dropdown** (left): same behaviour as before but built from the union of all years present across all `widget.allHeatmaps`. On change: `setState(() { _year = value; })`.

- **Category filter** (middle): if `widget.allCategoryTitles.isNotEmpty`, show a `DropdownButton` or a custom multi-select control. For simplicity, implement as a single-tap `DropdownButton` that opens a `showDialog` with `CheckboxListTile`s for each category plus a "No category" option (for habits with empty `categoryTitle`). On confirm, `setState(() { _selectedCategories = selected; })`.

  If implementing a dialog is too complex for this phase, use a simpler `DropdownButton<String?>` (single select, not multi) where selecting a category replaces the current filter. Document this simplification with a TODO comment. Multi-select can be added later.

- **Habit filter** (right): same approach — a button that opens a dialog with checkboxes for each habit title, grouped by category. Habits in the dialog should only show habits from the currently selected categories (if any). On confirm, `setState(() { _selectedHabitTitles = selected; })`.

**9.5 — Multi-row grid layout**

Replace the body with a `Column` of habit rows. Each row is rendered by a private method `_buildHabitRow(HeatmapData heatmap)`.

Group rows by category. To group:
1. Build a list of groups: for each unique `categoryTitle` in `_visibleHabits()` (preserving first-occurrence order), collect the habits with that category.
2. Habits with `categoryTitle == ""` go into a final group labelled `"Other"` (or no label if it's the only group).

For each group:
- If there are 2 or more distinct categories visible, render a **section header row**:
  - A small filled `Container` (10×10, `BorderRadius.circular(5)`) coloured with `checkColor` at 70% opacity (placeholder — per-category color is a future feature).
  - Followed by `Text(categoryTitle)` in `fontSize 12`, `fontWeight.w600`, `colorScheme.onSurface.withOpacity(0.6)`.
  - Full-width `Divider` above the section header (except for the very first group).
- Then render each habit's row.

**9.6 — `_buildHabitRow(HeatmapData heatmap)`**

Each row is a `Row` of two parts:

- **Label column** (fixed width 80px): `Text(heatmap.title, overflow: TextOverflow.ellipsis, fontSize: 11)`, right-padded 4px, vertically centred.
- **Grid**: a horizontal `SingleChildScrollView` containing a `Row` of 53 columns, each a `Column` of 7 cells — exactly as in the current single-habit implementation, but now one row per habit.

Each cell is 10×10 with 1.5px margin and `BorderRadius.circular(2)`. The colour is determined by the level and streak run length:

| Condition | Colour |
|---|---|
| Level 0 (no event) | Transparent (no square drawn — or `Colors.transparent`) |
| Level 1 (skip) | `skipColor` (from `SettingsManager`) at 35% opacity — fixed, no darkening |
| Level 2 (fail or partial progress — `DayType.fail` or partial `DayType.progress`) | `failColor` at 25% opacity for fail; `progressColor` at 25% opacity for partial progress. To distinguish these two sub-cases, you need level 2a vs 2b. **Resolution:** Change the level encoding in `HeatmapData.dailyCounts` — use `2` for fail and a new value `5` for partial progress. Or keep level 2 for both and accept the same colour. The simplest approach that matches the spec is to use `failColor` at 25% for level 2 (both fail and partial are visually the same muted tint) — document this as a simplification with a TODO. |
| Level 3 (check or complete progress) | `checkColor` darkened by streak run length: day 1 = 20% opacity, day 2 = 32%, day 3 = 44%, day 4 = 56%, day 5 = 68%, day 6 = 80%, day 7 = 86%, day 8 = 92%, day 9 = 96%, day 10+ = 100%. Look up `heatmap.streakRunLengths[cellDate] ?? 0` for the run length. If run length is 0 but level is 3, use 20% opacity (defensive fallback for day 1). |

The opacity mapping for level 3 can be precomputed as a list: `[0.0, 0.20, 0.32, 0.44, 0.56, 0.68, 0.80, 0.86, 0.92, 0.96, 1.00]` indexed by `min(runLength, 10)`.

**Date mapping** (same as existing, no change): start from the Monday on or before Jan 1 of `_year`, fill 53×7 cells, skip cells where `cellDate.year != _year` by rendering them transparent.

**Month labels** (same as existing, no change): render above the grid row of the first habit only, or above each group's first habit. Simpler: render month labels once, above all rows, in a separate `Row` that aligns with the grid columns. Wrap both the label row and the habit rows in a horizontal `SingleChildScrollView` with the same scroll controller so they scroll together.

> **Scroll synchronisation:** To keep the month label row and all habit grid rows horizontally in sync, use a single `ScrollController` and pass it to every `SingleChildScrollView` in the column. Create the controller in `initState` and dispose it in `dispose`.

**9.7 — Empty state**

If `_visibleHabits()` returns an empty list (filters excluded everything), render:
```
Center(child: Text("No habits match the current filter", style: grey))
```

**9.8 — Remove old card structure**

The old widget wrapped a single habit's grid in a `Card`. The new widget is a multi-habit layout. The outer `Card` shell (rounded corners, `primaryContainer` background, elevation 2) should remain wrapping the entire multi-row layout. The year-selector row and filter controls are inside the card. The label column + grid rows are also inside the card, inside a vertical scroll if needed — but prefer the outer `ListView` handling vertical scroll.

---

### Verify before continuing
- `flutter analyze lib/statistics/yearly_heatmap_card.dart` — zero errors.
- With 3 habits across 2 categories: category section headers appear, 3 rows of grids render.
- Level 3 cells on day 1 of a streak are visibly lighter than level 3 cells on day 7+ of a streak.
- Skip cells show a yellow tint distinct from fail cells.
- Transparent cells (no event, or outside-year padding) are invisible (no grey square).
- All habit rows scroll horizontally in sync with the month labels.
- Category filter hides rows correctly.
- Habit filter hides individual rows correctly.
- With a single habit and no categories, no section header is rendered.

---

> ✅ Phase 9 complete. Review the changes above, then type **continue** to proceed to Phase 10.

---

---

## Phase 10 — Screen Integration and Ordering

**Goal:** Update `statistics_screen.dart` to use the updated widget signatures and enforce the required card order: leaderboard, weekly trend, heatmap, best day & time. `BestDayTimeCard` requires no changes — confirm it is untouched.

### Files to modify
- `lib/statistics/statistics_screen.dart`

### Files to confirm untouched
- `lib/statistics/best_day_time_card.dart` — open it, read it, make no changes, confirm it still compiles.

### Read first
Read `statistics_screen.dart` in full. Identify the current order in which the four new cards are rendered inside the outer `ListView`. According to the previous blueprint (Phase 8), the order was:
1. `OverallStatisticsCard`
2. Inner `ListView` of `StatisticsCard` + `YearlyHeatmapCard` pairs
3. `WeeklyTrendCard`
4. `HabitComparisonCard`
5. `BestDayTimeCard`

The new required order (within the outer `ListView`, after `OverallStatisticsCard` and the per-habit `StatisticsCard` block) is:
1. `HabitComparisonCard` (leaderboard)
2. `WeeklyTrendCard`
3. `YearlyHeatmapCard` (now a single widget for all habits — moved out of the per-habit inner ListView)
4. `BestDayTimeCard`

### Instructions

**10.1 — Update `YearlyHeatmapCard` call site**

The `YearlyHeatmapCard` constructor now accepts `List<HeatmapData> allHeatmaps` and `List<String> allCategoryTitles` instead of a single `HeatmapData`.

Remove all per-habit `YearlyHeatmapCard` widgets from inside the inner `ListView`. Instead, add a single `YearlyHeatmapCard` in the outer `ListView` after `WeeklyTrendCard`:
```
YearlyHeatmapCard(
  allHeatmaps: snapshot.data!.heatmaps,
  allCategoryTitles: snapshot.data!.allCategoryTitles,
)
```

Wrapped in `Padding(padding: EdgeInsets.all(12))`.

Only render it if `snapshot.data!.heatmaps.isNotEmpty`.

**10.2 — Reorder the outer `ListView` children**

Ensure the outer `ListView` children are in this exact order:
1. `OverallStatisticsCard` (unchanged)
2. Inner block: `ListView` of `StatisticsCard` widgets (unchanged — `YearlyHeatmapCard` is no longer interleaved here)
3. Optional section header `"Leaderboard"` (if section headers were added in the previous blueprint)
4. `HabitComparisonCard` (if `comparison != null`)
5. Optional section header `"Weekly Trend"` (if used)
6. `WeeklyTrendCard` (if `overallWeeklyTrend != null`)
7. Optional section header `"Activity Heatmap"` (if used)
8. `YearlyHeatmapCard` (if `heatmaps.isNotEmpty`)
9. Optional section header `"Best Day & Time"` (if used)
10. `BestDayTimeCard` (always rendered, no null guard)

If section headers were not added in the previous blueprint, do not add them now unless they were already present.

**10.3 — Pass `allCategoryTitles` to `WeeklyTrendCard`**

If `WeeklyTrendData` already carries `allCategoryTitles` (added in Phase 3/6), no extra pass-through is needed — the data is already inside the `WeeklyTrendData` object that `WeeklyTrendCard` receives.

Confirm the `WeeklyTrendCard` call site passes `snapshot.data!.overallWeeklyTrend!` — the `allCategoryTitles` field is inside that object.

**10.4 — Confirm `BestDayTimeCard` is unchanged**

Open `best_day_time_card.dart`. Verify:
- Constructor signature is unchanged.
- No import errors.
- `flutter analyze lib/statistics/best_day_time_card.dart` — zero errors.

Make no changes to this file. Close it.

**10.5 — Remove orphaned imports**

In `statistics_screen.dart`, if the `YearlyHeatmapCard` was previously imported and its import path is unchanged, no action needed. Confirm all four card imports resolve correctly after the constructor change to `YearlyHeatmapCard`.

---

### Verify before continuing
- `flutter analyze lib/statistics/statistics_screen.dart` — zero errors.
- `flutter analyze lib/statistics/best_day_time_card.dart` — zero errors (no changes made).
- Hot-restart: statistics screen shows cards in the order: overall card → per-habit stats cards → leaderboard → weekly trend → heatmap (all habits in one card) → best day & time.
- With zero habits: `EmptyStatisticsImage` shows, no new cards render.
- With one non-archived habit: leaderboard does not render (comparison is null for < 2 habits); all other cards render.
- Heatmap card shows all habits in a single scrollable multi-row card.

---

> ✅ Phase 10 complete. Review the changes above, then type **continue** to proceed to Phase 11.

---

---

## Phase 11 — Localization

**Goal:** Add ARB keys for all new user-visible strings introduced in Phases 7–9.

### Files to modify
- `lib/l10n/intl_en.arb` (verify the exact filename by running `ls lib/l10n/`)

### After editing, run
```bash
flutter gen-l10n
```

### Read first
Open `lib/l10n/intl_en.arb`. Study the key naming convention and `@key` metadata format.

### Instructions

**11.1 — Identify all new hardcoded strings**

Search the three modified widget files for hardcoded English strings used as user-visible labels. You should find at minimum:

| Widget | Hardcoded string | Suggested ARB key |
|---|---|---|
| `HabitComparisonCard` | `"Highest first"` | `leaderboardSortHighest` |
| `HabitComparisonCard` | `"Lowest first"` | `leaderboardSortLowest` |
| `HabitComparisonCard` | `"By category"` | `leaderboardSortByCategory` |
| `HabitComparisonCard` | `"All"` / `"All categories"` | `leaderboardFilterAll` |
| `HabitComparisonCard` | `"No habits in this category"` | `leaderboardEmpty` |
| `WeeklyTrendCard` | `"This week"` | `weeklyTrendThisWeek` |
| `WeeklyTrendCard` | `"12-wk avg"` | `weeklyTrendAverage` |
| `WeeklyTrendCard` | `"All habits"` | `weeklyTrendFilterAll` |
| `WeeklyTrendCard` | `"No completions"` | `weeklyTrendNoCompletions` |
| `WeeklyTrendCard` | `"… +{n} more"` (parameterised) | `weeklyTrendMoreHabits` |
| `YearlyHeatmapCard` | `"All categories"` / `"Category"` | `heatmapFilterCategories` |
| `YearlyHeatmapCard` | `"All habits"` / `"Habits"` | `heatmapFilterHabits` |
| `YearlyHeatmapCard` | `"No habits match the current filter"` | `heatmapFilterEmpty` |
| `YearlyHeatmapCard` | `"Other"` (no-category group label) | `heatmapCategoryOther` |

Also check for any section header strings added in Phase 10 §10.2.

For the `"… +{n} more"` string, use ARB placeholders: `"{count} more habits"` with a `count` placeholder of type `int`.

**11.2 — Add entries to the ARB file**

For each string above, add the key-value pair and its `@key` metadata block with a `"description"` field.

**11.3 — Replace hardcoded strings in widgets**

In each widget file, replace every hardcoded string with `S.of(context).keyName`. For the parameterised `"more"` string, use `S.of(context).weeklyTrendMoreHabits(n)`.

**11.4 — Regenerate and verify**

```bash
flutter gen-l10n
flutter analyze lib/
```

Zero errors.

---

### Verify before continuing
- All new ARB keys appear in the generated `S` class.
- No remaining hardcoded user-visible English strings in the three modified widget files.
- `flutter gen-l10n` produces no errors or warnings.

---

> ✅ Phase 11 complete. Review the changes above, then type **continue** to proceed to Phase 12.

---

---

## Phase 12 — Polish & Verify

**Goal:** Run the full analyzer and test suite, check all edge cases, and confirm visual correctness on device/simulator.

### Files to modify
- Any of the modified files, for polish fixes only — no new features.

### Instructions

**12.1 — Run analyzer**

```bash
flutter analyze lib/ test/
```

Fix all errors. For warnings about deprecated APIs, add a `// TODO: update when fl_chart API stabilises` comment and leave them.

**12.2 — Run tests**

```bash
flutter test
```

All pre-existing tests must pass. If any test references `ComparisonData`, `HeatmapData`, or `WeeklyTrendData` constructors, update them to include the new fields with their default values.

**12.3 — Edge case checklist**

Verify each of the following on device or simulator:

**Leaderboard:**
- [ ] 0 non-archived habits → card does not render (null guard in screen)
- [ ] 1 non-archived habit → card does not render (null guard in screen)
- [ ] 2+ habits with identical metric values → stable sort (no flicker on rebuild)
- [ ] Habit with 0 events → check rate = 0%, streak = 0, appears at bottom of "highest first" sort, rank shown correctly
- [ ] Very long habit title → ellipsized, does not overflow the row
- [ ] Very large streak value (e.g. 500) → bar fills to 100%, value shown as `"500d"`, other bars proportionally shorter
- [ ] Category filter with 0 habits passing → `"No habits in this category"` message shown

**Weekly trend:**
- [ ] All 12 weeks with 0 completions → flat line at 0%, stat boxes show `"0%"`
- [ ] This week partially complete → "This week" box reflects current partial state
- [ ] Tooltip shows correctly on the first dot (index 0, leftmost)
- [ ] Tooltip shows correctly on the last dot (index 11, rightmost)
- [ ] Tooltip dismissed by tapping same dot again
- [ ] Category filter with 0 habits → flat line at 0%, no crash
- [ ] 1 habit total → category filter shows its category (if any), filter works correctly

**Heatmap:**
- [ ] 1 habit, no categories → single row, no section header, no crash
- [ ] 10 habits across 3 categories → section headers render, rows grouped correctly
- [ ] Streak run of 1 day → lightest colour variant (20% opacity)
- [ ] Streak run of 10+ consecutive days → full colour (100% opacity)
- [ ] Skip cells → yellow tint, clearly distinct from check and fail cells
- [ ] Transparent cells (no event, outside-year padding) → invisible, no grey squares
- [ ] Month labels align correctly with grid columns across all months
- [ ] All habit rows scroll horizontally in sync with month labels
- [ ] Category filter hides entire groups + section header when all habits in that category are filtered out
- [ ] Habit filter hides individual rows within a group; section header remains if other habits in group are visible

**12.4 — Dark mode and OLED black**

Switch the device/simulator to dark mode, then to OLED Black theme (if available in Habo settings). Verify:
- [ ] All new cards readable in dark mode (no dark-on-dark text)
- [ ] Leaderboard bar background (`checkColor.withOpacity(0.15)`) is visible but subtle in both themes
- [ ] Heatmap transparent cells are truly transparent (background shows through), not a clashing colour
- [ ] Tooltip background contrasts with chart background in dark mode

**12.5 — Final sign-off**

```bash
flutter analyze lib/ test/
flutter test
```

Both must pass cleanly before this blueprint is considered complete.

---

> ✅ Phase 12 complete. All adjustments to the four statistics cards are implemented, tested, and verified. The statistics screen now shows: leaderboard → weekly trend → heatmap → best day & time.

---

## Appendix: File Map

| Phase | Action | File |
|---|---|---|
| 1 | Modify | `lib/statistics/statistics.dart` |
| 2 | Modify | `lib/statistics/statistics.dart` |
| 3 | Modify | `lib/statistics/statistics.dart` |
| 4 | Modify | `lib/statistics/statistics.dart` |
| 5 | Modify | `lib/statistics/statistics.dart` |
| 6 | Modify | `lib/statistics/statistics.dart` |
| 7 | Modify | `lib/statistics/habit_comparison_card.dart` |
| 8 | Modify | `lib/statistics/weekly_trend_card.dart` |
| 9 | Modify | `lib/statistics/yearly_heatmap_card.dart` |
| 10 | Modify | `lib/statistics/statistics_screen.dart` |
| 10 | Read-only confirm | `lib/statistics/best_day_time_card.dart` |
| 11 | Modify | `lib/l10n/intl_en.arb` |
| 12 | Any modified file | Polish fixes only |

## Appendix: What Is NOT Changing

- `lib/statistics/best_day_time_card.dart` — no changes
- `lib/statistics/statistics_card.dart` — no changes
- `lib/statistics/overall_statistics_card.dart` — no changes
- `lib/statistics/monthly_graph.dart` — no changes
- `lib/statistics/empty_statistics_image.dart` — no changes
- `lib/habits/habits_manager.dart` — no changes
- `lib/model/` — no changes
- `lib/repositories/` — no changes

## Appendix: Critical Warnings

1. **Do not rewrite from scratch.** Each phase says "adjust" — read the existing file first, then make the minimum changes needed. Rewriting risks losing logic not described in this blueprint.
2. **Constructor default values.** Every new field added to `ComparisonData`, `HeatmapData`, `WeeklyTrendData`, and `AllStatistics` must have a default value (`= const []`, `= null`, etc.) to avoid breaking existing constructor call sites.
3. **`listen: false` for `SettingsManager`.** All new colour reads in the widgets must use `Provider.of<SettingsManager>(context, listen: false)` — consistent with the existing pattern documented in STATISTICS_MODULE.md §13.
4. **`DayType.clear` guard.** Any new event iteration in `statistics.dart` must include `value[0] != null && value[0] != DayType.clear`.
5. **Scroll controller disposal.** The `ScrollController` added to `YearlyHeatmapCard` in Phase 9 must be disposed in the widget's `dispose()` method to avoid memory leaks.
6. **FutureBuilder anti-pattern.** Do not attempt to fix the known anti-pattern in `statistics_screen.dart`. Leave it as-is.
7. **Archived habits in heatmaps and weekly trend.** By design, `allHabits` is passed unfiltered, so archived habits appear in these two cards. The leaderboard excludes them. Do not change this asymmetry.
8. **`YearlyHeatmapCard` constructor change breaks the screen.** Phase 9 changes the constructor. Phase 10 fixes the call site. Do not attempt to fix the screen in Phase 9 — let the compile error wait until Phase 10.
