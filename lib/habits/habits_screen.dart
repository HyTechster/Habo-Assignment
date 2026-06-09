import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:habo/auth/auth_service.dart';
import 'package:habo/constants.dart';
import 'package:habo/generated/l10n.dart';
import 'package:habo/notifications.dart';
import 'package:provider/provider.dart';
import 'package:habo/friends/friends_manager.dart';
import 'package:habo/friends/social_feed_screen.dart';
import 'package:habo/habits/calendar_column.dart';
import 'package:habo/statistics/statistics_screen.dart';
import 'package:habo/habits/habits_manager.dart';
import 'package:habo/settings/settings_manager.dart';
import 'package:habo/navigation/navigation.dart';

class HabitsScreen extends StatefulWidget {
  static MaterialPage page() {
    return MaterialPage(
      name: Routes.habitsPath,
      key: ValueKey(Routes.habitsPath),
      child: const HabitsScreen(),
    );
  }

  const HabitsScreen({
    super.key,
  });

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  /// 0 = Home (habits list), 1 = Social (friends' habit feed). The Social
  /// tab is opt-in social functionality, so it (and the bar itself) only
  /// appears for signed-in users — see _showSocialTab below.
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    if (platformSupportsNotifications()) {
      Future.delayed(const Duration(seconds: 0), () async {
        if (!mounted) return;
        showNotificationDialog(context);
      });
    }
  }

  void _showArchivedHabitsDialog(BuildContext context) {
    final habitsManager = Provider.of<HabitsManager>(context, listen: false);
    final archivedHabits = habitsManager.archivedHabits;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(S.of(context).archivedHabits),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: archivedHabits.isEmpty
                ? Center(
                    child: Text(
                      S.of(context).noArchivedHabits,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: archivedHabits.length,
                    itemBuilder: (context, index) {
                      final habit = archivedHabits[index];
                      return ListTile(
                        title: Text(habit.habitData.title),
                        trailing: IconButton(
                          icon: const Icon(Icons.unarchive),
                          onPressed: () {
                            habitsManager.unarchiveHabit(habit.habitData.id!);
                            Navigator.of(context).pop();
                          },
                          tooltip: S.of(context).unarchiveHabit,
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          Provider.of<AppStateManager>(context, listen: false)
                              .goEditHabit(habit.habitData);
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(S.of(context).close),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateManager>(
      builder: (
        context,
        appStateManager,
        child,
      ) {
        // Tab indices: 0 = Home, 1 = Stats, 2 = Social (signed-in only).
        // If the user was on Social and signs out, fall back to Home.
        final showSocialTab = Provider.of<AuthService>(context).isSignedIn;
        final selectedTab =
            (!showSocialTab && _selectedTab == 2) ? 0 : _selectedTab;
        final showingStats = selectedTab == 1;
        final showingSocial = showSocialTab && selectedTab == 2;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              showingSocial
                  ? 'Social'
                  : showingStats
                      ? S.of(context).statistics
                      : 'Habo',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            backgroundColor: Colors.transparent,
            actions: <Widget>[
              // Friends tab is opt-in social functionality — unauthenticated
              // users must see zero changes to their experience, so the icon
              // is hidden entirely unless the user is signed in.
              if (Provider.of<AuthService>(context).isSignedIn)
                IconButton(
                  icon: Icon(
                    Icons.people_outline,
                    semanticLabel: 'Friends',
                  ),
                  color: Colors.grey[400],
                  tooltip: 'Friends',
                  onPressed: () {
                    Provider.of<HabitsManager>(context, listen: false)
                        .hideSnackBar();
                    Provider.of<AppStateManager>(context, listen: false)
                        .goFriends(true);
                  },
                ),
              // "Where can I see that a friend liked/commented on my habit?"
              // — this bell is the answer. Badged with a dot when there's
              // activity newer than the last time the user opened it.
              if (Provider.of<AuthService>(context).isSignedIn)
                Consumer<FriendsManager>(
                  builder: (context, friendsManager, _) => IconButton(
                    icon: Badge(
                      isLabelVisible: friendsManager.hasUnseenActivity,
                      smallSize: 8,
                      child: Icon(
                        Icons.notifications_outlined,
                        semanticLabel: 'Activity',
                      ),
                    ),
                    color: Colors.grey[400],
                    tooltip: 'Activity',
                    onPressed: () {
                      Provider.of<HabitsManager>(context, listen: false)
                          .hideSnackBar();
                      Provider.of<AppStateManager>(context, listen: false)
                          .goActivity(true);
                    },
                  ),
                ),
              IconButton(
                icon: Icon(
                  Icons.archive,
                  semanticLabel: S.of(context).archivedHabits,
                ),
                color: Colors.grey[400],
                tooltip: S.of(context).viewArchivedHabits,
                onPressed: () {
                  Provider.of<HabitsManager>(context, listen: false)
                      .hideSnackBar();
                  _showArchivedHabitsDialog(context);
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.help_outline_rounded,
                  semanticLabel: 'Help',
                ),
                color: Colors.grey[400],
                tooltip: 'Help',
                onPressed: () {
                  Provider.of<AppStateManager>(context, listen: false)
                      .goHelp(true);
                  Provider.of<HabitsManager>(context, listen: false)
                      .hideSnackBar();
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.settings,
                  semanticLabel: S.of(context).settings,
                ),
                color: Colors.grey[400],
                tooltip: S.of(context).settings,
                onPressed: () {
                  Provider.of<AppStateManager>(context, listen: false)
                      .goSettings(true);
                  Provider.of<HabitsManager>(context, listen: false)
                      .hideSnackBar();
                },
              ),
            ],
          ),
          body: showingSocial
              ? const SocialFeedScreen()
              : showingStats
                  ? const StatisticsBody()
                  : const CalendarColumn(),
          // Add habit only makes sense on the Home tab.
          floatingActionButton: (showingSocial || showingStats)
              ? null
              : FloatingActionButton(
                  tooltip: S.of(context).add,
                  onPressed: () {
                    Provider.of<AppStateManager>(context, listen: false)
                        .goCreateHabit(true);
                    Provider.of<HabitsManager>(context, listen: false)
                        .hideSnackBar();
                  },
                  child: Icon(
                    Icons.add,
                    color: Colors.white,
                    semanticLabel: S.of(context).add,
                    size: 35.0,
                  ),
                ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: selectedTab,
            onTap: (index) {
              Provider.of<HabitsManager>(context, listen: false)
                  .hideSnackBar();
              setState(() => _selectedTab = index);
            },
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_outlined),
                activeIcon: Icon(Icons.bar_chart),
                label: 'Stats',
              ),
              if (showSocialTab)
                const BottomNavigationBarItem(
                  icon: Icon(Icons.groups_outlined),
                  activeIcon: Icon(Icons.groups),
                  label: 'Social',
                ),
            ],
          ),
        );
      },
    );
  }

  void showNotificationDialog(BuildContext context) {
    AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        if (!context.mounted) return;
        showRestoreDialog(context);
      } else {
        resetNotifications();
      }
    });
  }

  void showRestoreDialog(BuildContext context) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.info,
      headerAnimationLoop: false,
      animType: AnimType.bottomSlide,
      title: S.of(context).notifications,
      desc: S.of(context).haboNeedsPermission,
      btnOkText: S.of(context).allow,
      btnCancelText: S.of(context).cancel,
      btnCancelColor: Colors.grey,
      btnOkColor: HaboColors.primary,
      btnCancelOnPress: () {},
      btnOkOnPress: () {
        AwesomeNotifications()
            .requestPermissionToSendNotifications()
            .then((value) {
          resetNotifications();
        });
      },
    ).show();
  }

  void resetNotifications() {
    Provider.of<SettingsManager>(context, listen: false).resetAppNotification();
    Provider.of<HabitsManager>(context, listen: false)
        .resetHabitsNotifications();
  }
}
