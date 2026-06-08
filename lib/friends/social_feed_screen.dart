import 'package:flutter/material.dart';
import 'package:habo/constants.dart';
import 'package:habo/friends/friends_manager.dart';
import 'package:habo/friends/model/friend.dart';
import 'package:habo/habits/habits_manager.dart';
import 'package:provider/provider.dart';

/// The "Social" tab: a top [TabBar] splitting the space between "My Habits"
/// (your own habits plus the reactions/comments friends left on them — the
/// answer to "where can I see that someone liked my habit?") and "Friends"
/// (an aggregated feed of every accepted friend's currently visible habits —
/// see migrations 006/007 — each reactable/commentable). This is the main
/// embedded body shown by HabitsScreen's bottom navigation bar, not a pushed
/// route, so it has no Scaffold/AppBar of its own.
class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen({super.key});

  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen>
    with SingleTickerProviderStateMixin {
  // Looking up a provider via `context` inside dispose() throws ("Looking up
  // a deactivated widget's ancestor is unsafe") — capture the reference while
  // it's safe, mirroring the fix already applied to FriendProfileScreen.
  FriendsManager? _friendsManager;
  late final TabController _tabController = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _friendsManager?.loadSocialFeed();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _friendsManager = Provider.of<FriendsManager>(context, listen: false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _friendsManager?.clearSocialFeed();
    _friendsManager?.clearMyHabitsActivitySummary();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: HaboColors.primary,
          unselectedLabelColor: Colors.grey[500],
          indicatorColor: HaboColors.primary,
          tabs: const [
            Tab(text: 'My Habits'),
            Tab(text: 'Friends'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _MyHabitsTab(),
              _FriendsFeedTab(),
            ],
          ),
        ),
      ],
    );
  }
}

/// "My Habits" — the signed-in user's own habits with their streak, plus how
/// many friends reacted and a way to open the comment thread, so the owner
/// can see who's cheering them on without leaving the Social tab.
class _MyHabitsTab extends StatefulWidget {
  const _MyHabitsTab();

  @override
  State<_MyHabitsTab> createState() => _MyHabitsTabState();
}

class _MyHabitsTabState extends State<_MyHabitsTab> {
  // Cache provider references in didChangeDependencies (always runs before
  // the first postFrameCallback) rather than calling Provider.of(context)
  // from the callback — State.mounted stays true while deactivated, so a
  // delayed context lookup can still throw "Looking up a deactivated
  // widget's ancestor is unsafe". Mirrors the fix applied throughout
  // friend_profile_screen.dart / social_feed_screen.dart.
  FriendsManager? _friendsManager;
  HabitsManager? _habitsManager;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _friendsManager = Provider.of<FriendsManager>(context, listen: false);
    _habitsManager = Provider.of<HabitsManager>(context, listen: false);
  }

  void _load() {
    final localIds = _habitsManager?.activeHabits
            .map((habit) => habit.habitData.id)
            .whereType<int>()
            .toList() ??
        const <int>[];
    _friendsManager?.loadMyHabitsActivitySummary(localIds);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<HabitsManager, FriendsManager>(
      builder: (context, habitsManager, friendsManager, _) {
        final habits = habitsManager.activeHabits;
        if (habits.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'Add a habit on the Home tab to start tracking — your '
                "friends' reactions and comments will show up here.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 16),
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _load(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: habits.length,
            itemBuilder: (context, index) {
              final habitData = habits[index].habitData;
              final localId = habitData.id;
              final cloudId =
                  localId == null ? null : friendsManager.cloudIdForLocalHabit(localId);
              return _MyHabitCard(
                title: habitData.title,
                streak: habitData.streak,
                cloudHabitId: cloudId,
                isLoadingCloudId:
                    localId != null && friendsManager.myHabitsSocialStatus == LoadStatus.loading,
              );
            },
          ),
        );
      },
    );
  }
}

class _MyHabitCard extends StatelessWidget {
  const _MyHabitCard({
    required this.title,
    required this.streak,
    required this.cloudHabitId,
    required this.isLoadingCloudId,
  });

  final String title;
  final int streak;
  final String? cloudHabitId;
  final bool isLoadingCloudId;

  void _openComments(BuildContext context) {
    final cloudId = cloudHabitId;
    if (cloudId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CommentsSheet(habitId: cloudId),
    );
  }

  void _openReactors(BuildContext context, String habitId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReactorsSheet(habitId: habitId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cloudId = cloudHabitId;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.local_fire_department, color: HaboColors.orange, size: 18),
                const SizedBox(width: 4),
                Text('$streak day streak'),
              ],
            ),
            const SizedBox(height: 8),
            if (cloudId == null)
              Text(
                isLoadingCloudId
                    ? 'Loading reactions and comments…'
                    : "This habit hasn't synced yet — reactions and comments will appear once it does.",
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              )
            else
              Row(
                children: [
                  Consumer<FriendsManager>(
                    builder: (context, manager, _) {
                      final count = manager.reactionCount(cloudId);
                      final row = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.favorite, size: 18, color: Colors.redAccent),
                          const SizedBox(width: 4),
                          Text(
                            count > 0 ? '$count reacted' : 'No reactions yet',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      );
                      if (count == 0) return row;
                      return InkWell(
                        onTap: () => _openReactors(context, cloudId),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: row,
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  Consumer<FriendsManager>(
                    builder: (context, manager, _) {
                      final count = manager.commentCount(cloudId);
                      return TextButton.icon(
                        onPressed: () => _openComments(context),
                        icon: Icon(Icons.mode_comment_outlined, size: 18, color: Colors.grey[600]),
                        label: Text(
                          count > 0 ? '$count comments' : 'Comments',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      );
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// "Friends" — the existing aggregated feed of every friend's visible habits.
class _FriendsFeedTab extends StatelessWidget {
  const _FriendsFeedTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<FriendsManager>(
      builder: (context, manager, _) {
        switch (manager.feedStatus) {
          case LoadStatus.idle:
          case LoadStatus.loading:
            return const Center(child: CircularProgressIndicator(color: HaboColors.primary));
          case LoadStatus.error:
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  "Couldn't load your friends' habits. Check your connection and try again.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ),
            );
          case LoadStatus.loaded:
            final feed = manager.feedHabits;
            if (feed.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    "When your friends share habits, they'll show up here for you to cheer on.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                ),
              );
            }
            // Group consecutive ownership into one card per friend so a
            // friend with several visible habits shows a single avatar/
            // username header with each habit listed underneath, rather than
            // a repeated card per habit.
            final grouped = <_FeedGroup>[];
            for (final feedHabit in feed) {
              if (grouped.isNotEmpty &&
                  grouped.last.owner.userId == feedHabit.owner.userId) {
                grouped.last.habits.add(feedHabit.habit);
              } else {
                grouped.add(_FeedGroup(owner: feedHabit.owner, habits: [feedHabit.habit]));
              }
            }
            return RefreshIndicator(
              onRefresh: manager.loadSocialFeed,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: grouped.length,
                itemBuilder: (context, index) => _FeedFriendCard(group: grouped[index]),
              ),
            );
        }
      },
    );
  }
}

/// One friend's run of consecutive feed entries, collapsed into a single
/// card — see the grouping pass in _SocialFeedScreenState.build.
class _FeedGroup {
  _FeedGroup({required this.owner, required this.habits});

  final FriendProfile owner;
  final List<SharedHabit> habits;
}

class _FeedFriendCard extends StatelessWidget {
  const _FeedFriendCard({required this.group});

  final _FeedGroup group;

  void _openComments(BuildContext context, String habitId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // FriendsManager is provided at the app root (above the Navigator), so
      // the sheet's own context can reach it directly — no need to re-wrap.
      builder: (_) => _CommentsSheet(habitId: habitId),
    );
  }

  void _openReactors(BuildContext context, String habitId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReactorsSheet(habitId: habitId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final owner = group.owner;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: HaboColors.primary.withValues(alpha: 0.15),
                  backgroundImage:
                      owner.avatarUrl != null ? NetworkImage(owner.avatarUrl!) : null,
                  child: owner.avatarUrl == null
                      ? Text(
                          owner.username.isNotEmpty ? owner.username[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: HaboColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    owner.username,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            for (var i = 0; i < group.habits.length; i++) ...[
              Divider(height: 24, color: Colors.grey[300]),
              _FeedHabitTile(
                habit: group.habits[i],
                onComment: () => _openComments(context, group.habits[i].habitId),
                onReactionCountTap: () => _openReactors(context, group.habits[i].habitId),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A single habit's summary plus its React/Comment row, shown inside a
/// _FeedFriendCard (one tile per visible habit that friend has).
class _FeedHabitTile extends StatelessWidget {
  const _FeedHabitTile({
    required this.habit,
    required this.onComment,
    required this.onReactionCountTap,
  });

  final SharedHabit habit;
  final VoidCallback onComment;
  final VoidCallback onReactionCountTap;

  @override
  Widget build(BuildContext context) {
    return Column(
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
        const SizedBox(height: 8),
        Row(
          children: [
            Consumer<FriendsManager>(
              builder: (context, manager, _) {
                final reacted = manager.hasReacted(habit.habitId);
                final count = manager.reactionCount(habit.habitId);
                final color = reacted ? Colors.redAccent : Colors.grey[600];
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => manager.toggleReaction(habit.habitId),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        reacted ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: reacted ? Colors.redAccent : Colors.grey,
                      ),
                    ),
                    InkWell(
                      // Separate from the heart toggle above so tapping the
                      // count itself opens "who reacted" instead of toggling.
                      onTap: count > 0 ? onReactionCountTap : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        child: Text(
                          count > 0 ? '$count' : 'React',
                          style: TextStyle(color: color),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            Consumer<FriendsManager>(
              builder: (context, manager, _) {
                final count = manager.commentCount(habit.habitId);
                return TextButton.icon(
                  onPressed: onComment,
                  icon: Icon(Icons.mode_comment_outlined, size: 18, color: Colors.grey[600]),
                  label: Text(
                    count > 0 ? '$count' : 'Comment',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// Bottom sheet listing a habit's comment thread, with a field to add a new
/// one. Loads on open and clears the manager's comment state on close so a
/// stale thread can't bleed into the next habit's sheet.
class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.habitId});

  final String habitId;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();
  bool _sending = false;
  FriendsManager? _friendsManager;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _friendsManager?.loadComments(widget.habitId);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _friendsManager = Provider.of<FriendsManager>(context, listen: false);
  }

  @override
  void dispose() {
    _controller.dispose();
    _friendsManager?.clearComments();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text;
    if (body.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = await _friendsManager?.addComment(widget.habitId, body) ?? false;
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Comments', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              const Divider(height: 1),
              Expanded(
                child: Consumer<FriendsManager>(
                  builder: (context, manager, _) {
                    switch (manager.commentsStatus) {
                      case LoadStatus.idle:
                      case LoadStatus.loading:
                        return const Center(child: CircularProgressIndicator(color: HaboColors.primary));
                      case LoadStatus.error:
                        return Center(
                          child: Text(
                            'Could not load comments. Please try again.',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        );
                      case LoadStatus.loaded:
                        final comments = manager.comments;
                        if (comments.isEmpty) {
                          return Center(
                            child: Text(
                              'No comments yet — be the first to cheer them on!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          );
                        }
                        return ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: comments.length,
                          itemBuilder: (context, index) {
                            final comment = comments[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: HaboColors.primary.withValues(alpha: 0.15),
                                child: Text(
                                  comment.username.isNotEmpty
                                      ? comment.username[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: HaboColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              title: Text(
                                comment.username,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              subtitle: Text(comment.body),
                            );
                          },
                        );
                    }
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        maxLength: 500,
                        textInputAction: TextInputAction.send,
                        decoration: const InputDecoration(
                          hintText: 'Add a comment…',
                          counterText: '',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send, color: HaboColors.primary),
                      onPressed: _sending ? null : _send,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Bottom sheet listing everyone who reacted to a habit, opened by tapping
/// its reaction count. Read-only — mirrors _CommentsSheet's loading/clearing
/// lifecycle without the input field.
class _ReactorsSheet extends StatefulWidget {
  const _ReactorsSheet({required this.habitId});

  final String habitId;

  @override
  State<_ReactorsSheet> createState() => _ReactorsSheetState();
}

class _ReactorsSheetState extends State<_ReactorsSheet> {
  FriendsManager? _friendsManager;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _friendsManager?.loadReactors(widget.habitId);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _friendsManager = Provider.of<FriendsManager>(context, listen: false);
  }

  @override
  void dispose() {
    _friendsManager?.clearReactors();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Reactions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            const Divider(height: 1),
            Expanded(
              child: Consumer<FriendsManager>(
                builder: (context, manager, _) {
                  switch (manager.reactorsStatus) {
                    case LoadStatus.idle:
                    case LoadStatus.loading:
                      return const Center(child: CircularProgressIndicator(color: HaboColors.primary));
                    case LoadStatus.error:
                      return Center(
                        child: Text(
                          'Could not load reactions. Please try again.',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      );
                    case LoadStatus.loaded:
                      final reactors = manager.reactors;
                      if (reactors.isEmpty) {
                        return Center(
                          child: Text(
                            'No reactions yet.',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        );
                      }
                      return ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: reactors.length,
                        itemBuilder: (context, index) {
                          final reactor = reactors[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: HaboColors.primary.withValues(alpha: 0.15),
                              backgroundImage: reactor.avatarUrl != null
                                  ? NetworkImage(reactor.avatarUrl!)
                                  : null,
                              child: reactor.avatarUrl == null
                                  ? Text(
                                      reactor.username.isNotEmpty
                                          ? reactor.username[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: HaboColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              reactor.username,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            trailing: const Icon(Icons.favorite, size: 16, color: Colors.redAccent),
                          );
                        },
                      );
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
