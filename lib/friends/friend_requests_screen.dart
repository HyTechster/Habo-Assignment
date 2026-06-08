import 'package:flutter/material.dart';
import 'package:habo/constants.dart';
import 'package:habo/friends/friends_manager.dart';
import 'package:habo/friends/model/friend.dart';
import 'package:provider/provider.dart';

/// Shows incoming requests (with accept/reject actions) and outgoing
/// requests (with a cancel action) the current user has pending.
class FriendRequestsScreen extends StatelessWidget {
  const FriendRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friend Requests'),
        backgroundColor: Colors.transparent,
        iconTheme: Theme.of(context).iconTheme,
      ),
      body: Consumer<FriendsManager>(
        builder: (context, manager, _) {
          if (manager.requestsStatus == LoadStatus.loading &&
              manager.requests.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final incoming = manager.incomingRequests;
          final outgoing = manager.outgoingRequests;

          if (incoming.isEmpty && outgoing.isEmpty) {
            return Center(
              child: Text(
                'No pending requests',
                style: TextStyle(color: Colors.grey[500], fontSize: 16),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: manager.loadRequests,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: [
                if (incoming.isNotEmpty)
                  _SectionHeader(title: 'Incoming (${incoming.length})'),
                ...incoming.map((request) => _IncomingRequestTile(request: request)),
                if (outgoing.isNotEmpty)
                  _SectionHeader(title: 'Sent (${outgoing.length})'),
                ...outgoing.map((request) => _OutgoingRequestTile(request: request)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: Colors.grey[500],
          fontSize: 13,
        ),
      ),
    );
  }
}

class _IncomingRequestTile extends StatelessWidget {
  const _IncomingRequestTile({required this.request});

  final FriendRequest request;

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<FriendsManager>(context, listen: false);
    final username = request.senderProfile?.username ?? 'Unknown user';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(username, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('wants to be your friend'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle, color: HaboColors.primary),
              tooltip: 'Accept',
              onPressed: () => manager.acceptRequest(request),
            ),
            IconButton(
              icon: Icon(Icons.cancel, color: Colors.grey[400]),
              tooltip: 'Reject',
              onPressed: () => manager.rejectRequest(request),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutgoingRequestTile extends StatelessWidget {
  const _OutgoingRequestTile({required this.request});

  final FriendRequest request;

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<FriendsManager>(context, listen: false);
    final username = request.receiverProfile?.username ?? 'Unknown user';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(username, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Request pending'),
        trailing: TextButton(
          onPressed: () => manager.cancelRequest(request),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
