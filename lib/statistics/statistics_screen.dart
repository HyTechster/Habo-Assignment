import 'package:flutter/material.dart';
import 'package:habo/constants.dart';
import 'package:habo/generated/l10n.dart';
import 'package:habo/habits/habits_manager.dart';
import 'package:habo/navigation/routes.dart';
import 'package:habo/statistics/empty_statistics_image.dart';
import 'package:habo/statistics/overall_statistics_card.dart';
import 'package:habo/statistics/statistics.dart';
import 'package:habo/statistics/best_day_time_card.dart';
import 'package:habo/statistics/habit_comparison_card.dart';
import 'package:habo/statistics/statistics_card.dart';
import 'package:habo/statistics/weekly_trend_card.dart';
import 'package:habo/statistics/yearly_heatmap_card.dart';
import 'package:habo/navigation/app_state_manager.dart';
import 'package:provider/provider.dart';

class StatisticsScreen extends StatefulWidget {
  static MaterialPage page() {
    return MaterialPage(
      name: Routes.statisticsPath,
      key: ValueKey(Routes.statisticsPath),
      child: const StatisticsScreen(),
    );
  }

  const StatisticsScreen({
    super.key,
  });

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Provider.of<AppStateManager>(context, listen: false)
            .goStatistics(false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            S.of(context).statistics,
          ),
          backgroundColor: Colors.transparent,
          iconTheme: Theme.of(context).iconTheme,
        ),
        body: FutureBuilder(
            future: Provider.of<HabitsManager>(context).getFutureStatsData(),
            builder:
                (BuildContext context, AsyncSnapshot<AllStatistics> snapshot) {
              if (snapshot.hasData) {
                if (snapshot.data!.habitsData.isEmpty) {
                  return const EmptyStatisticsImage();
                } else {
                  // Note: getFutureStatsData() is called inside build(),
                  // which recreates the Future on every HabitsManager
                  // notification while this screen is open — known
                  // anti-pattern. Do not fix here to avoid regressions.
                  final habitsData = snapshot.data!.habitsData;
                  final heatmaps = snapshot.data!.heatmaps;

                  // Reusable section-header style for "Per Habit" /
                  // "Overall Trends" dividers.
                  TextStyle sectionStyle = TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  );

                  return ListView(
                    scrollDirection: Axis.vertical,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // ── Overall pie chart ───────────────────────────────
                      OverallStatisticsCard(
                        total: snapshot.data!.total,
                        habits: habitsData.length,
                      ),

                      // ── Per Habit ───────────────────────────────────────
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(S.of(context).statisticsPerHabit, style: sectionStyle),
                      ),
                      // Inner non-scrolling list: each habit gets a
                      // StatisticsCard followed immediately by its
                      // YearlyHeatmapCard (Option A from blueprint §8.6).
                      // Both lists (habitsData, heatmaps) are guaranteed to be
                      // the same length — they are built from the same
                      // allHabits iteration in calculateStatistics.
                      ListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: List.generate(
                          habitsData.length,
                          (i) => Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: StatisticsCard(data: habitsData[i]),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    12, 0, 12, 12),
                                child:
                                    YearlyHeatmapCard(data: heatmaps[i]),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Overall Trends ──────────────────────────────────
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child:
                            Text(S.of(context).statisticsOverallTrends, style: sectionStyle),
                      ),
                      // WeeklyTrendCard: null when the 12-week window has
                      // no logged events.
                      if (snapshot.data!.overallWeeklyTrend != null)
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: WeeklyTrendCard(
                            data: snapshot.data!.overallWeeklyTrend!,
                          ),
                        ),
                      // HabitComparisonCard: null when fewer than 2
                      // non-archived habits exist.
                      if (snapshot.data!.comparison != null)
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: HabitComparisonCard(
                            data: snapshot.data!.comparison!,
                          ),
                        ),
                      // BestDayTimeCard: never null — carries zeroed
                      // defaults when there is insufficient data.
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: BestDayTimeCard(
                          data: snapshot.data!.bestDayTime,
                        ),
                      ),
                    ],
                  );
                }
              } else {
                return const Center(
                  child: CircularProgressIndicator(
                    color: HaboColors.primary,
                  ),
                );
              }
            }),
      ),
    );
  }
}
