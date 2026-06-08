import 'package:flutter/material.dart';
import 'package:habo/constants.dart';
import 'package:habo/friends/model/friend.dart';

/// A single row in the Friends List screen: avatar, username. Tapping opens
/// the Friend Profile screen.
class FriendCard extends StatelessWidget {
  const FriendCard({
    super.key,
    required this.friend,
    this.onTap,
  });

  final Friend friend;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final profile = friend.profile;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: HaboColors.primary.withValues(alpha: 0.15),
          backgroundImage:
              profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
          child: profile.avatarUrl == null
              ? Text(
                  profile.username.isNotEmpty
                      ? profile.username[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: HaboColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          profile.username,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
