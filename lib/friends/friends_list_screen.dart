import 'package:flutter/material.dart';
import 'package:habo/constants.dart';
import 'package:habo/friends/friend_profile_screen.dart';
import 'package:habo/friends/friend_requests_screen.dart';
import 'package:habo/friends/friends_manager.dart';
import 'package:habo/friends/model/friend.dart';
import 'package:habo/friends/search_users_screen.dart';
import 'package:habo/friends/widgets/friend_card.dart';
import 'package:habo/navigation/app_state_manager.dart';
import 'package:habo/navigation/routes.dart';
import 'package:provider/provider.dart';

/// Entry point for the Friends tab — lists accepted friends with a summary of
/// their shared habit streaks, and links to Requests / Search sub-screens.
///
/// This screen (and everything reachable from it) is only ever shown to
/// signed-in users; see [FriendsManager.isAvailable] / habits_screen.dart.
class FriendsListScreen extends StatefulWidget {
  static MaterialPage page() {
    return MaterialPage(
      name: Routes.friendsPath,
      key: ValueKey(Routes.friendsPath),
      child: const FriendsListScreen(),
    );
  }

  const FriendsListScreen({super.key});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final manager = Provider.of<FriendsManager>(context, listen: false);
      manager.loadFriends();
      manager.loadRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Provider.of<AppStateManager>(context, listen: false).goFriends(false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Friends'),
          backgroundColor: Colors.transparent,
          iconTheme: Theme.of(context).iconTheme,
          actions: [
            Consumer<FriendsManager>(
              builder: (context, manager, _) => IconButton(
                icon: Badge(
                  isLabelVisible: manager.incomingRequests.isNotEmpty,
                  label: Text('${manager.incomingRequests.length}'),
                  child: const Icon(Icons.mail_outline),
                ),
                tooltip: 'Friend requests',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FriendRequestsScreen()),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.person_add_alt_1),
              tooltip: 'Find friends',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchUsersScreen()),
              ),
            ),
          ],
        ),
        body: Consumer<FriendsManager>(
          builder: (context, manager, _) {
            switch (manager.friendsStatus) {
              case LoadStatus.idle:
              case LoadStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case LoadStatus.error:
                return _ErrorState(onRetry: manager.loadFriends);
              case LoadStatus.loaded:
                if (manager.friends.isEmpty) {
                  return const _EmptyFriendsState();
                }
                return RefreshIndicator(
                  onRefresh: manager.loadFriends,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: manager.friends.length,
                    itemBuilder: (context, index) {
                      final friend = manager.friends[index];
                      return FriendCard(
                        friend: friend,
                        onTap: () => _openFriendProfile(context, friend),
                      );
                    },
                  ),
                );
            }
          },
        ),
      ),
    );
  }

  void _openFriendProfile(BuildContext context, Friend friend) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FriendProfileScreen(friend: friend)),
    );
  }
}

class _EmptyFriendsState extends StatelessWidget {
  const _EmptyFriendsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No friends yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Use the search icon above to find people by username and send a friend request.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'Couldn\'t load friends. Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: HaboColors.primary),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
