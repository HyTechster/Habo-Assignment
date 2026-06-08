import 'package:flutter/material.dart';
import 'package:habo/constants.dart';
import 'package:habo/friends/friends_manager.dart';
import 'package:habo/friends/model/friend.dart';
import 'package:habo/friends/widgets/nudge_button.dart';
import 'package:provider/provider.dart';

/// Read-only view of a friend's opted-in shared habits: title, current
/// streak and a completion-progress bar, plus a "Send Nudge" action per
/// habit. Only habits the friend has explicitly toggled to share appear here
/// — enforced server-side by RLS on `habit_shares` (see migration 003).
class FriendProfileScreen extends StatefulWidget {
  const FriendProfileScreen({super.key, required this.friend});

  final Friend friend;

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  // Looking up a provider via `context` inside dispose() throws ("Looking up
  // a deactivated widget's ancestor is unsafe") because the element is
  // already deactivated by then — so capture the reference while it's safe,
  // mirroring the fix in SearchUsersScreen.
  FriendsManager? _friendsManager;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // `mounted` alone isn't enough: a widget can be deactivated (and its
      // context's ancestor lookups become unsafe) before it's unmounted, if
      // the user navigates away within the same frame this callback was
      // scheduled. Use the reference captured in didChangeDependencies
      // instead of touching `context` again here.
      _friendsManager?.loadFriendHabits(widget.friend.profile.userId);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _friendsManager = Provider.of<FriendsManager>(context, listen: false);
  }

  @override
  void dispose() {
    _friendsManager?.clearSelectedFriendHabits();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.friend.profile;
    return Scaffold(
      appBar: AppBar(
        title: Text(profile.username),
        backgroundColor: Colors.transparent,
        iconTheme: Theme.of(context).iconTheme,
      ),
      body: Consumer<FriendsManager>(
        builder: (context, manager, _) {
          switch (manager.friendHabitsStatus) {
            case LoadStatus.idle:
            case LoadStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case LoadStatus.error:
              return Center(
                child: Text(
                  'Couldn\'t load shared habits. Check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500]),
                ),
              );
            case LoadStatus.loaded:
              final habits = manager.selectedFriendHabits;
              if (habits.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      '${profile.username} hasn\'t shared any habits yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500], fontSize: 16),
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: habits.length,
                itemBuilder: (context, index) {
                  return _SharedHabitCard(
                    habit: habits[index],
                    friendId: profile.userId,
                  );
                },
              );
          }
        },
      ),
    );
  }
}

class _SharedHabitCard extends StatelessWidget {
  const _SharedHabitCard({required this.habit, required this.friendId});

  final SharedHabit habit;
  final String friendId;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              habit.title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.local_fire_department, color: HaboColors.orange, size: 18),
                const SizedBox(width: 4),
                Text('${habit.currentStreak} day streak'),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: habit.completionProgress,
                minHeight: 8,
                backgroundColor: HaboColors.progressBackground,
                valueColor: const AlwaysStoppedAnimation(HaboColors.progress),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(habit.completionProgress * 100).round()}% completed (last 30 days)',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            const SizedBox(height: 4),
            // Nudges are for encouraging a friend to get going on a habit —
            // not for ones they're already keeping up, so the button only
            // appears once their streak has lapsed (currentStreak == 0).
            if (habit.currentStreak == 0)
              Align(
                alignment: Alignment.centerRight,
                child: NudgeButton(
                  friendId: friendId,
                  habitId: habit.habitId,
                  habitTitle: habit.title,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
