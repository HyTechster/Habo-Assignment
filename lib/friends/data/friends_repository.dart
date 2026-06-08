import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:habo/friends/model/friend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown by [FriendsRepository] methods when Supabase isn't configured
/// (offline-first build) so callers can show a friendly "needs internet /
/// sign-in" message instead of a raw exception.
class FriendsUnavailableException implements Exception {
  const FriendsUnavailableException();

  @override
  String toString() =>
      'Social features require an internet connection and a signed-in account.';
}

/// Thrown by [FriendsRepository.updateUsername] when the chosen name is
/// already in use — `profiles.username` has a unique constraint.
class UsernameTakenException implements Exception {
  const UsernameTakenException();

  @override
  String toString() => 'That username is already taken — try another one.';
}

/// All Supabase access for the Friends feature lives here, mirroring how
/// [SyncService] talks to Supabase directly via `Supabase.instance.client`.
/// Every read/write relies on the RLS policies defined in
/// supabase/migrations/003_e4_friends.sql — this class never bypasses them
/// (e.g. it never requests columns beyond username/avatar for other users).
class FriendsRepository {
  bool get _isSupabaseAvailable {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  SupabaseClient get _client => Supabase.instance.client;

  String? get currentUserId => _isSupabaseAvailable
      ? _client.auth.currentUser?.id
      : null;

  void _requireSupabase() {
    if (!_isSupabaseAvailable || currentUserId == null) {
      throw const FriendsUnavailableException();
    }
  }

  // ---------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------

  static const _usernamePrefix = 'habouser';
  static final _random = math.Random();

  /// Generates a default display name like `habouser482913`. Habo doesn't
  /// collect usernames at sign-up, so every new account gets a random one
  /// that the user can change later from the Profile screen.
  String _randomUsername() =>
      '$_usernamePrefix${100000 + _random.nextInt(900000)}';

  /// Ensures the signed-in user has a row in `profiles`, lazily creating one
  /// with a random username the first time they sign in (e.g. when the
  /// Friends tab is first opened). Retries with a fresh random suffix on the
  /// rare chance of a collision — `username` has a unique constraint.
  Future<void> ensureProfileExists() async {
    _requireSupabase();
    final uid = currentUserId!;
    final existing =
        await _client.from('profiles').select('user_id').eq('user_id', uid).maybeSingle();
    if (existing != null) return;

    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        await _client.from('profiles').insert({
          'user_id': uid,
          'username': _randomUsername(),
        });
        return;
      } on PostgrestException catch (e) {
        if (e.code != '23505' || attempt == 4) rethrow;
      }
    }
  }

  /// Fetches the signed-in user's own public profile, for the Profile screen
  /// (includes `share_all_habits`, unlike the lighter-weight friend lookups).
  Future<FriendProfile?> fetchOwnProfile() async {
    _requireSupabase();
    final row = await _client
        .from('profiles')
        .select('user_id, username, avatar_url, share_all_habits')
        .eq('user_id', currentUserId!)
        .maybeSingle();
    return row == null ? null : FriendProfile.fromMap(row);
  }

  /// Sets the user's global habit-visibility mode:
  ///  - true  -> every (non-archived) habit is summarized for friends
  ///  - false -> only habits individually marked shared via [setHabitShared]
  /// RLS (see migration 006) enforces this server-side via
  /// `is_habit_visible_to_friend`, so the change takes effect immediately.
  Future<void> setShareAllHabits(bool value) async {
    _requireSupabase();
    await _client
        .from('profiles')
        .update({'share_all_habits': value}).eq('user_id', currentUserId!);
  }

  Future<void> updateUsername(String username) async {
    _requireSupabase();
    try {
      await _client
          .from('profiles')
          .update({'username': username}).eq('user_id', currentUserId!);
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw const UsernameTakenException();
      rethrow;
    }
  }

  // ---------------------------------------------------------------------
  // Search (paginated to avoid letting a client scrape the whole table)
  // ---------------------------------------------------------------------

  static const int searchPageSize = 20;

  Future<List<FriendProfile>> searchUsersByUsername(
    String query, {
    int page = 0,
  }) async {
    _requireSupabase();
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final from = page * searchPageSize;
    final to = from + searchPageSize - 1;

    final rows = await _client
        .from('profiles')
        .select('user_id, username, avatar_url')
        .ilike('username', '%$trimmed%')
        .neq('user_id', currentUserId!)
        .range(from, to);

    return (rows as List)
        .map((row) => FriendProfile.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------
  // Friend requests
  // ---------------------------------------------------------------------

  Future<void> sendFriendRequest(String receiverId) async {
    _requireSupabase();
    await _client.from('friend_requests').insert({
      'sender_id': currentUserId!,
      'receiver_id': receiverId,
      'status': 'pending',
    });
  }

  Future<void> respondToRequest(String requestId, {required bool accept}) async {
    _requireSupabase();
    await _client
        .from('friend_requests')
        .update({'status': accept ? 'accepted' : 'rejected'}).eq('id', requestId);
  }

  /// Lets the sender withdraw a request they no longer want pending.
  Future<void> cancelRequest(String requestId) async {
    _requireSupabase();
    await _client.from('friend_requests').delete().eq('id', requestId);
  }

  /// Returns pending requests where the current user is sender or receiver,
  /// joined with the other party's public profile for display.
  Future<List<FriendRequest>> fetchPendingRequests() async {
    _requireSupabase();
    final uid = currentUserId!;
    final rows = await _client
        .from('friend_requests')
        .select(
            'id, sender_id, receiver_id, status, sender:sender_id(user_id, username, avatar_url), receiver:receiver_id(user_id, username, avatar_url)')
        .eq('status', 'pending')
        .or('sender_id.eq.$uid,receiver_id.eq.$uid')
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => FriendRequest.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------
  // Friends
  // ---------------------------------------------------------------------

  Future<List<Friend>> fetchFriends() async {
    _requireSupabase();
    final uid = currentUserId!;
    final rows = await _client
        .from('friendships')
        .select(
            'user_id_1, user_id_2, profile1:user_id_1(user_id, username, avatar_url), profile2:user_id_2(user_id, username, avatar_url)')
        .or('user_id_1.eq.$uid,user_id_2.eq.$uid');

    return (rows as List).map((row) {
      final map = row as Map<String, dynamic>;
      // Whichever side isn't "me" is the friend.
      final isFirst = map['user_id_1'] == uid;
      final profileMap =
          (isFirst ? map['profile2'] : map['profile1']) as Map<String, dynamic>;
      return Friend(profile: FriendProfile.fromMap(profileMap));
    }).toList();
  }

  Future<void> removeFriend(String friendUserId) async {
    _requireSupabase();
    final uid = currentUserId!;
    final a = uid.compareTo(friendUserId) < 0 ? uid : friendUserId;
    final b = uid.compareTo(friendUserId) < 0 ? friendUserId : uid;
    await _client
        .from('friendships')
        .delete()
        .eq('user_id_1', a)
        .eq('user_id_2', b);
  }

  // ---------------------------------------------------------------------
  // Habit sharing
  // ---------------------------------------------------------------------

  /// Sharing keys off the habit's *cloud* row (uuid), but the local SQLite
  /// store only knows the integer rowid. This resolves between the two using
  /// the `(user_id, local_id)` pair the sync feature already maintains.
  /// Returns null if the habit hasn't been synced to the cloud yet — in that
  /// case sharing simply isn't available until the next sync completes.
  Future<String?> cloudHabitIdForLocalId(int localId) async {
    _requireSupabase();
    final row = await _client
        .from('habits')
        .select('id')
        .eq('user_id', currentUserId!)
        .eq('local_id', localId)
        .maybeSingle();
    return row?['id'] as String?;
  }

  /// Batched form of [cloudHabitIdForLocalId] — resolves every local habit id
  /// to its cloud id in one round trip, for screens (e.g. "My Habits" in the
  /// Social tab) that need to map several local habits to cloud ids at once
  /// rather than looping. Habits that haven't synced yet are simply absent
  /// from the result map.
  Future<Map<int, String>> cloudHabitIdsForLocalIds(List<int> localIds) async {
    _requireSupabase();
    if (localIds.isEmpty) return {};
    final rows = await _client
        .from('habits')
        .select('id, local_id')
        .eq('user_id', currentUserId!)
        .inFilter('local_id', localIds);
    final result = <int, String>{};
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      final localId = row['local_id'] as int?;
      final cloudId = row['id'] as String?;
      if (localId != null && cloudId != null) {
        result[localId] = cloudId;
      }
    }
    return result;
  }

  /// Creates/updates the `habit_shares` row for [habitId]. Setting
  /// [isShared] to false hides the habit from friends immediately because
  /// the RLS policy on `habit_shares` only allows friends to read rows where
  /// `is_shared = true`.
  Future<void> setHabitShared(String habitId, bool isShared) async {
    _requireSupabase();
    await _client.from('habit_shares').upsert({
      'habit_id': habitId,
      'user_id': currentUserId!,
      'is_shared': isShared,
    });
  }

  /// In "Chosen habits" mode every habit is visible by default — the eye
  /// icon lets the owner explicitly hide individual ones (migration 007).
  /// So the absence of a `habit_shares` row means "shown", not "hidden";
  /// only an explicit `is_shared = false` row opts a habit out.
  Future<bool> isHabitShared(String habitId) async {
    _requireSupabase();
    final row = await _client
        .from('habit_shares')
        .select('is_shared')
        .eq('habit_id', habitId)
        .eq('user_id', currentUserId!)
        .maybeSingle();
    return row == null || row['is_shared'] == true;
  }

  /// Fetches the habits visible to the current user on [friendUserId]'s
  /// profile, including title and recent entries for streak/completion
  /// summaries. RLS (`is_habit_visible_to_friend`, migrations 006/007)
  /// guarantees a plain `habits` query already returns exactly the rows the
  /// friend has made visible — whether via "share all" or "chosen" mode —
  /// so there's no need to branch on their visibility mode here at all.
  Future<List<Map<String, dynamic>>> fetchSharedHabitsRaw(
      String friendUserId) async {
    _requireSupabase();

    final rows = await _client
        .from('habits')
        .select('id, title')
        .eq('user_id', friendUserId)
        .eq('archived', false);
    final habits = (rows as List).cast<Map<String, dynamic>>();

    final result = <Map<String, dynamic>>[];
    for (final habit in habits) {
      final entries = await _client
          .from('habit_entries')
          .select('entry_date, day_type')
          .eq('habit_id', habit['id'])
          .order('entry_date', ascending: false)
          .limit(30);

      result.add({
        'habit_id': habit['id'],
        'title': habit['title'],
        'entries': entries,
      });
    }
    return result;
  }

  // ---------------------------------------------------------------------
  // Social feed — reactions & comments on visible habits (own or friends')
  // ---------------------------------------------------------------------

  /// Reaction rows (`habit_id`, `user_id`) for [habitIds], used by
  /// FriendsManager to derive per-habit counts and "did I react" state for
  /// the feed in one round trip rather than one query per card.
  Future<List<Map<String, dynamic>>> fetchReactions(List<String> habitIds) async {
    _requireSupabase();
    if (habitIds.isEmpty) return [];
    final rows = await _client
        .from('habit_reactions')
        .select('habit_id, user_id')
        .inFilter('habit_id', habitIds);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Everyone who reacted to [habitId], oldest first, joined with their
  /// public profile — for the "who reacted?" sheet opened by tapping a
  /// reaction count. Mirrors [fetchComments]'s author join.
  Future<List<Map<String, dynamic>>> fetchReactors(String habitId) async {
    _requireSupabase();
    final rows = await _client
        .from('habit_reactions')
        .select('user_id, created_at, actor:user_id(username, avatar_url)')
        .eq('habit_id', habitId)
        .order('created_at');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Reactions are a single on/off toggle per user per habit (no emoji
  /// picker) — `unique (habit_id, user_id)` makes insert/delete sufficient,
  /// no need for upsert semantics.
  Future<void> addReaction(String habitId) async {
    _requireSupabase();
    await _client.from('habit_reactions').insert({
      'habit_id': habitId,
      'user_id': currentUserId!,
    });
  }

  Future<void> removeReaction(String habitId) async {
    _requireSupabase();
    await _client
        .from('habit_reactions')
        .delete()
        .eq('habit_id', habitId)
        .eq('user_id', currentUserId!);
  }

  /// Comments on [habitId], oldest first, joined with the author's public
  /// profile so the feed can show who said what without extra round trips.
  /// Requires `habit_comments.user_id` to reference `public.profiles` for
  /// PostgREST to embed it (see migration 008).
  Future<List<Map<String, dynamic>>> fetchComments(String habitId) async {
    _requireSupabase();
    final rows = await _client
        .from('habit_comments')
        .select('id, habit_id, user_id, body, created_at, author:user_id(username, avatar_url)')
        .eq('habit_id', habitId)
        .order('created_at');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// `habit_id` of every comment on [habitIds], for FriendsManager to derive
  /// per-habit counts in one round trip — mirrors [fetchReactions], which
  /// does the same for the heart toggle.
  Future<List<Map<String, dynamic>>> fetchCommentCounts(List<String> habitIds) async {
    _requireSupabase();
    if (habitIds.isEmpty) return [];
    final rows = await _client
        .from('habit_comments')
        .select('habit_id')
        .inFilter('habit_id', habitIds);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> addComment(String habitId, String body) async {
    _requireSupabase();
    await _client.from('habit_comments').insert({
      'habit_id': habitId,
      'user_id': currentUserId!,
      'body': body,
    });
  }

  Future<void> deleteComment(String commentId) async {
    _requireSupabase();
    await _client.from('habit_comments').delete().eq('id', commentId);
  }

  /// Reactions and comments left by *other* users on habits the current user
  /// owns — i.e. "who's interacted with my stuff", for the Activity screen.
  /// Each row is tagged with its source table so FriendsManager can build the
  /// right [ActivityEntry] without a second round trip; merging/sorting by
  /// `created_at` happens client-side since these come from two tables.
  /// `!inner` on the habit join lets us filter on the embedded resource
  /// (`habit.user_id`) server-side via RLS-friendly PostgREST syntax.
  Future<List<Map<String, dynamic>>> fetchActivity({int limit = 50}) async {
    _requireSupabase();
    final uid = currentUserId!;
    final reactionRows = await _client
        .from('habit_reactions')
        .select(
            'habit_id, user_id, created_at, actor:user_id(username, avatar_url), habit:habit_id!inner(title, user_id)')
        .eq('habit.user_id', uid)
        .neq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    final commentRows = await _client
        .from('habit_comments')
        .select(
            'habit_id, user_id, body, created_at, actor:user_id(username, avatar_url), habit:habit_id!inner(title, user_id)')
        .eq('habit.user_id', uid)
        .neq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    final reactions = (reactionRows as List).cast<Map<String, dynamic>>();
    final comments = (commentRows as List).cast<Map<String, dynamic>>();
    for (final row in reactions) {
      row['_activity_type'] = 'reaction';
    }
    for (final row in comments) {
      row['_activity_type'] = 'comment';
    }
    final merged = [...reactions, ...comments];
    merged.sort((a, b) =>
        (b['created_at'] as String).compareTo(a['created_at'] as String));
    return merged.take(limit).toList();
  }

  // ---------------------------------------------------------------------
  // Real-time subscriptions
  // ---------------------------------------------------------------------

  /// Subscribes to changes on `friend_requests` and `friendships` involving
  /// the current user, so the Friends tab updates live without polling.
  /// Returns the channel so the caller can unsubscribe in dispose().
  RealtimeChannel subscribeToFriendChanges(String userId, VoidCallback onChange) {
    final channel = _client.channel('friends_changes_$userId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friend_requests',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friendships',
          callback: (_) => onChange(),
        )
        .subscribe();
    return channel;
  }

  /// Live updates for reaction/comment counts — without this, a friend
  /// reacting or commenting while the feed is open would only show up after
  /// a manual pull-to-refresh re-ran the one-shot count queries.
  RealtimeChannel subscribeToInteractionChanges(
    String userId,
    VoidCallback onChange,
  ) {
    final channel = _client.channel('habit_interactions_$userId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'habit_reactions',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'habit_comments',
          callback: (_) => onChange(),
        )
        .subscribe();
    return channel;
  }

  Future<void> unsubscribe(RealtimeChannel channel) => _client.removeChannel(channel);
}
