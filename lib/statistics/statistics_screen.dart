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
          title: Text(S.of(context).statistics),
          backgroundColor: Colors.transparent,
          iconTheme: Theme.of(context).iconTheme,
        ),
        body: const StatisticsBody(),
      ),
    );
  }
}

/// The scrollable statistics content without any Scaffold or AppBar.
/// Used both by [StatisticsScreen] (full-page navigation) and as an
/// inline tab body inside [HabitsScreen].
class StatisticsBody extends StatelessWidget {
  const StatisticsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Provider.of<HabitsManager>(context).getFutureStatsData(),
      builder: (BuildContext context, AsyncSnapshot<AllStatistics> snapshot) {
        if (snapshot.hasData) {
          if (snapshot.data!.habitsData.isEmpty) {
            return const EmptyStatisticsImage();
          } else {
            // Note: getFutureStatsData() is called inside build(),
            // which recreates the Future on every HabitsManager
            // notification while this screen is open — known
            // anti-pattern. Do not fix here to avoid regressions.
            final habitsData = snapshot.data!.habitsData;
            return ListView(
              scrollDirection: Axis.vertical,
              physics: const BouncingScrollPhysics(),
              children: [
                OverallStatisticsCard(
                  total: snapshot.data!.total,
                  habits: habitsData.length,
                ),
                if (snapshot.data!.comparison != null)
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: HabitComparisonCard(
                      data: snapshot.data!.comparison!,
                    ),
                  ),
                if (snapshot.data!.overallWeeklyTrend != null)
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: WeeklyTrendCard(
                      data: snapshot.data!.overallWeeklyTrend!,
                    ),
                  ),
                if (snapshot.data!.heatmaps.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: YearlyHeatmapCard(
                      allHeatmaps: snapshot.data!.heatmaps,
                      allCategoryTitles: snapshot.data!.allCategoryTitles,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: BestDayTimeCard(data: snapshot.data!.bestDayTime),
                ),
              ],
            );
          }
        } else {
          return const Center(
            child: CircularProgressIndicator(color: HaboColors.primary),
          );
        }
      },
    );
  }
}
