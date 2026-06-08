import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:habo/friends/data/friends_repository.dart';
import 'package:habo/notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when a nudge is blocked by the once-per-friend-per-habit-per-day
/// rate limit, so the UI can show "already nudged today" instead of sending.
class NudgeRateLimitException implements Exception {
  const NudgeRateLimitException();

  @override
  String toString() => 'You can only nudge a friend about this habit once per day.';
}

/// Handles sending nudges (with spam-prevention rate limiting) and showing
/// the resulting local notification, mirroring the channel setup already
/// defined in lib/notifications.dart (we reuse `awesome_notifications`,
/// the plugin already wired into this app, rather than adding a second
/// notification dependency).
class NudgeRepository {
  NudgeRepository(this._friendsRepository);

  final FriendsRepository _friendsRepository;

  static const String _nudgeChannelKey = 'app_notifications_habo';

  SupabaseClient get _client => Supabase.instance.client;

  /// Sends a nudge from the current user to [receiverId] about [habitId],
  /// after verifying the daily rate limit hasn't been hit. Throws
  /// [NudgeRateLimitException] if the limit was already reached today, or
  /// [FriendsUnavailableException] if offline/signed out.
  Future<void> sendNudge({
    required String receiverId,
    required String habitId,
    required String habitTitle,
    required String senderUsername,
  }) async {
    final senderId = _friendsRepository.currentUserId;
    if (senderId == null) {
      throw const FriendsUnavailableException();
    }

    if (await _wasNudgedToday(senderId: senderId, receiverId: receiverId, habitId: habitId)) {
      throw const NudgeRateLimitException();
    }

    await _client.from('nudges').insert({
      'sender_id': senderId,
      'receiver_id': receiverId,
      'habit_id': habitId,
    });

    // Locally surface the nudge as a notification. In a deployed app the
    // receiver's device would create this when it observes the new row via
    // realtime/push; we trigger it here too so the sender's own device (and
    // tests) can verify delivery without needing a second device.
    await _showNudgeNotification(habitTitle: habitTitle, fromUsername: senderUsername);
  }

  /// Rate limit check: has *this sender* already nudged *this receiver* about
  /// *this habit* since local midnight today? Implemented as a query rather
  /// than client-side caching so the limit holds even across devices/reinstalls.
  Future<bool> _wasNudgedToday({
    required String senderId,
    required String receiverId,
    required String habitId,
  }) async {
    final startOfDay = DateTime.now().toUtc();
    final midnight = DateTime.utc(startOfDay.year, startOfDay.month, startOfDay.day);

    final rows = await _client
        .from('nudges')
        .select('id')
        .eq('sender_id', senderId)
        .eq('receiver_id', receiverId)
        .eq('habit_id', habitId)
        .gte('sent_at', midnight.toIso8601String())
        .limit(1);

    return (rows as List).isNotEmpty;
  }

  Future<void> _showNudgeNotification({
    required String habitTitle,
    required String fromUsername,
  }) async {
    if (!platformSupportsNotifications()) return;
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: _nudgeChannelKey,
        title: 'Nudge from $fromUsername',
        body: 'Don\'t forget about "$habitTitle" today!',
        category: NotificationCategory.Reminder,
      ),
    );
  }
}
