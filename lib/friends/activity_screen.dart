import 'package:flutter/material.dart';
import 'package:habo/constants.dart';
import 'package:habo/friends/friends_manager.dart';
import 'package:habo/friends/model/friend.dart';
import 'package:habo/navigation/app_state_manager.dart';
import 'package:habo/navigation/routes.dart';
import 'package:provider/provider.dart';

/// Shows reactions and comments friends have left on *your* habits — the
/// answer to "where can I see that someone liked/commented on my habit?".
/// Pushed from HabitsScreen's app bar bell icon, mirroring FriendsListScreen.
class ActivityScreen extends StatefulWidget {
  static MaterialPage page() {
    return MaterialPage(
      name: Routes.activityPath,
      key: ValueKey(Routes.activityPath),
      child: const ActivityScreen(),
    );
  }

  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final manager = Provider.of<FriendsManager>(context, listen: false);
      manager.loadActivity();
      // Marking "seen" as soon as the list is requested (rather than waiting
      // for it to load) means the badge clears the moment the user looks,
      // matching how most apps treat "opened the notifications screen".
      manager.markActivitySeen();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Provider.of<AppStateManager>(context, listen: false).goActivity(false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Activity'),
          backgroundColor: Colors.transparent,
          iconTheme: Theme.of(context).iconTheme,
        ),
        body: Consumer<FriendsManager>(
          builder: (context, manager, _) {
            switch (manager.activityStatus) {
              case LoadStatus.idle:
              case LoadStatus.loading:
                return const Center(
                  child: CircularProgressIndicator(color: HaboColors.primary),
                );
              case LoadStatus.error:
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Couldn't load your activity. Check your connection and try again.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: manager.loadActivity,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              case LoadStatus.loaded:
                final entries = manager.activity;
                if (entries.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        "No activity yet — when friends react to or comment on your habits, you'll see it here.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500], fontSize: 16),
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: manager.loadActivity,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) => _ActivityTile(entry: entries[index]),
                  ),
                );
            }
          },
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.entry});

  final ActivityEntry entry;

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().toUtc().difference(time.toUtc());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}/${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isReaction = entry.type == ActivityType.reaction;
    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: HaboColors.primary.withValues(alpha: 0.15),
        backgroundImage:
            entry.actorAvatarUrl != null ? NetworkImage(entry.actorAvatarUrl!) : null,
        child: entry.actorAvatarUrl == null
            ? Text(
                entry.actorUsername.isNotEmpty ? entry.actorUsername[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: HaboColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: entry.actorUsername,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: isReaction
                  ? ' reacted to your habit '
                  : ' commented on your habit ',
            ),
            TextSpan(
              text: '"${entry.habitTitle}"',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isReaction && entry.commentBody != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '"${entry.commentBody}"',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            Text(
              _relativeTime(entry.createdAt),
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      ),
      trailing: Icon(
        isReaction ? Icons.favorite : Icons.mode_comment_outlined,
        color: isReaction ? Colors.redAccent : Colors.grey[500],
        size: 20,
      ),
    );
  }
}
