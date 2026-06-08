import 'dart:async';

import 'package:flutter/material.dart';
import 'package:habo/constants.dart';
import 'package:habo/friends/friends_manager.dart';
import 'package:habo/friends/model/friend.dart';
import 'package:provider/provider.dart';

/// Lets the user search for others by username and send friend requests.
///
/// Search is debounced client-side (300ms) and the repository paginates
/// results server-side (FriendsRepository.searchPageSize per page) — both
/// exist purely to stop a malicious client from rapidly scraping the
/// `profiles` table username-by-username.
class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  // Looking up a provider via `context` inside dispose() throws ("Looking up
  // a deactivated widget's ancestor is unsafe") because the element is
  // already deactivated by then — so capture the reference while it's safe.
  FriendsManager? _friendsManager;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _friendsManager = Provider.of<FriendsManager>(context, listen: false);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _friendsManager?.clearSearch();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      Provider.of<FriendsManager>(context, listen: false).searchUsers(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: Theme.of(context).iconTheme,
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search by username…',
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
      ),
      body: Consumer<FriendsManager>(
        builder: (context, manager, _) {
          switch (manager.searchStatus) {
            case LoadStatus.idle:
              return Center(
                child: Text(
                  'Type a username to find friends',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              );
            case LoadStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case LoadStatus.error:
              return Center(
                child: Text(
                  'Search failed. Check your connection and try again.',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              );
            case LoadStatus.loaded:
              if (manager.searchResults.isEmpty) {
                return Center(
                  child: Text(
                    'No users found',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: manager.searchResults.length,
                itemBuilder: (context, index) {
                  final profile = manager.searchResults[index];
                  return _SearchResultTile(profile: profile);
                },
              );
          }
        },
      ),
    );
  }
}

class _SearchResultTile extends StatefulWidget {
  const _SearchResultTile({required this.profile});

  final FriendProfile profile;

  @override
  State<_SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends State<_SearchResultTile> {
  bool _requestSent = false;

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<FriendsManager>(context, listen: false);
    final alreadyRequested = _requestSent ||
        manager.outgoingRequests
            .any((r) => r.receiverId == widget.profile.userId) ||
        manager.friends.any((f) => f.profile.userId == widget.profile.userId);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: HaboColors.primary.withValues(alpha: 0.15),
          child: Text(
            widget.profile.username.isNotEmpty
                ? widget.profile.username[0].toUpperCase()
                : '?',
            style: const TextStyle(color: HaboColors.primary, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(widget.profile.username),
        trailing: alreadyRequested
            ? Text('Pending', style: TextStyle(color: Colors.grey[500]))
            : ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: HaboColors.primary),
                onPressed: () async {
                  await manager.sendFriendRequest(widget.profile.userId);
                  if (!mounted) return;
                  setState(() => _requestSent = true);
                },
                child: const Text('Send Request'),
              ),
      ),
    );
  }
}
