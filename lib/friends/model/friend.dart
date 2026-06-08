/// Status of a friend request as stored in `public.friend_requests`.
enum FriendRequestStatus { pending, accepted, rejected }

FriendRequestStatus friendRequestStatusFromString(String value) {
  switch (value) {
    case 'accepted':
      return FriendRequestStatus.accepted;
    case 'rejected':
      return FriendRequestStatus.rejected;
    case 'pending':
    default:
      return FriendRequestStatus.pending;
  }
}

String friendRequestStatusToString(FriendRequestStatus status) {
  switch (status) {
    case FriendRequestStatus.accepted:
      return 'accepted';
    case FriendRequestStatus.rejected:
      return 'rejected';
    case FriendRequestStatus.pending:
      return 'pending';
  }
}

/// Public profile of another Habo user (mirrors `public.profiles`).
class FriendProfile {
  FriendProfile({
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.shareAllHabits = false,
  });

  final String userId;
  final String username;
  final String? avatarUrl;

  /// When true, every (non-archived) habit this user owns is summarized for
  /// friends — overriding the per-habit `habit_shares` opt-in. Only present
  /// when the query selected `share_all_habits` (e.g. fetchOwnProfile);
  /// other profile lookups simply default it to false.
  final bool shareAllHabits;

  factory FriendProfile.fromMap(Map<String, dynamic> map) {
    return FriendProfile(
      userId: map['user_id'] as String,
      username: map['username'] as String,
      avatarUrl: map['avatar_url'] as String?,
      shareAllHabits: map['share_all_habits'] as bool? ?? false,
    );
  }
}

/// A confirmed friend, paired with their public profile.
class Friend {
  Friend({required this.profile});

  final FriendProfile profile;
}

/// A pending/accepted/rejected friend request between two users.
class FriendRequest {
  FriendRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    this.senderProfile,
    this.receiverProfile,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final FriendRequestStatus status;

  /// Populated when the request is fetched joined with profile info so the
  /// UI can show a username without an extra round trip.
  final FriendProfile? senderProfile;
  final FriendProfile? receiverProfile;

  bool isOutgoing(String currentUserId) => senderId == currentUserId;

  factory FriendRequest.fromMap(Map<String, dynamic> map) {
    final sender = map['sender'];
    final receiver = map['receiver'];
    return FriendRequest(
      id: map['id'] as String,
      senderId: map['sender_id'] as String,
      receiverId: map['receiver_id'] as String,
      status: friendRequestStatusFromString(map['status'] as String),
      senderProfile:
          sender is Map<String, dynamic> ? FriendProfile.fromMap(sender) : null,
      receiverProfile: receiver is Map<String, dynamic>
          ? FriendProfile.fromMap(receiver)
          : null,
    );
  }
}

/// One entry in the Social feed: a friend's visible habit paired with that
/// friend's profile, so the feed card can show whose habit it is.
class FeedHabit {
  FeedHabit({required this.habit, required this.owner});

  final SharedHabit habit;
  final FriendProfile owner;
}

/// A comment left on a habit (by its owner or one of their friends), shown in
/// the Social feed's comment sheet. Mirrors `public.habit_comments`.
class HabitComment {
  HabitComment({
    required this.id,
    required this.habitId,
    required this.userId,
    required this.username,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String habitId;
  final String userId;
  final String username;
  final String body;
  final DateTime createdAt;

  factory HabitComment.fromMap(Map<String, dynamic> map) {
    final author = map['author'];
    return HabitComment(
      id: map['id'] as String,
      habitId: map['habit_id'] as String,
      userId: map['user_id'] as String,
      username: author is Map<String, dynamic>
          ? (author['username'] as String? ?? 'A friend')
          : 'A friend',
      body: map['body'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// What kind of interaction an [ActivityEntry] represents.
enum ActivityType { reaction, comment }

/// A reaction or comment a friend left on one of *your* habits, shown in the
/// Activity screen (lib/friends/activity_screen.dart) so you can see who's
/// cheering you on. Built by merging `habit_reactions`/`habit_comments` rows
/// where the habit's owner is the current user — see
/// FriendsRepository.fetchActivity.
class ActivityEntry {
  ActivityEntry({
    required this.type,
    required this.habitId,
    required this.habitTitle,
    required this.actorUsername,
    this.actorAvatarUrl,
    this.commentBody,
    required this.createdAt,
  });

  final ActivityType type;
  final String habitId;
  final String habitTitle;
  final String actorUsername;
  final String? actorAvatarUrl;

  /// Populated for [ActivityType.comment] entries only.
  final String? commentBody;
  final DateTime createdAt;

  factory ActivityEntry.fromMap(Map<String, dynamic> map, ActivityType type) {
    final actor = map['actor'];
    final habit = map['habit'];
    return ActivityEntry(
      type: type,
      habitId: map['habit_id'] as String,
      habitTitle: habit is Map<String, dynamic>
          ? (habit['title'] as String? ?? 'a habit')
          : 'a habit',
      actorUsername: actor is Map<String, dynamic>
          ? (actor['username'] as String? ?? 'A friend')
          : 'A friend',
      actorAvatarUrl: actor is Map<String, dynamic> ? actor['avatar_url'] as String? : null,
      commentBody: type == ActivityType.comment ? map['body'] as String? : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// A habit that a friend has opted to share, including the read-only summary
/// data shown on the Friend Profile screen.
class SharedHabit {
  SharedHabit({
    required this.habitId,
    required this.ownerId,
    required this.title,
    required this.currentStreak,
    required this.completionProgress,
  });

  final String habitId;
  final String ownerId;
  final String title;

  /// Number of consecutive completed days up to today.
  final int currentStreak;

  /// Fraction (0.0-1.0) of the last 30 days that were completed.
  final double completionProgress;
}
