import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:habo/auth/auth_service.dart';
import 'package:habo/friends/data/friends_repository.dart';
import 'package:habo/friends/data/nudge_repository.dart';
import 'package:habo/friends/model/friend.dart';
import 'package:habo/constants.dart' show DayType;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loading/error wrapper so screens can render consistent empty/error states
/// without each one re-implementing the same tri-state logic.
enum LoadStatus { idle, loading, loaded, error }

/// Central state holder for the Friends feature. Mirrors the role
/// [HabitsManager]/[SyncService] play for their respective features: it owns
/// the data, talks to the repositories, and notifies listeners so Provider
/// can rebuild the relevant screens.
///
/// All social data is opt-in and gracefully degrades offline: every public
/// method becomes a no-op (or surfaces [FriendsUnavailableException]) when
/// Supabase isn't configured or the user isn't signed in, so the rest of the
/// app keeps working untouched.
class FriendsManager extends ChangeNotifier {
  /// [repository] and [nudgeRepository] are injectable (defaulting to real
  /// Supabase-backed implementations) purely so widget/unit tests can supply
  /// mocks — mirrors how HabitsManager takes its repositories as parameters.
  FriendsManager(
    this._authService, {
    FriendsRepository? repository,
    NudgeRepository? nudgeRepository,
  })  : _repository = repository ?? FriendsRepository(),
        _nudgeRepository =
            nudgeRepository ?? NudgeRepository(repository ?? FriendsRepository()) {
    _authService.addListener(_onAuthChanged);
    if (_authService.isSignedIn) {
      _onAuthChanged();
    }
  }

  final AuthService _authService;
  final FriendsRepository _repository;
  final NudgeRepository _nudgeRepository;

  RealtimeChannel? _realtimeChannel;
  RealtimeChannel? _interactionChannel;

  List<Friend> _friends = [];
  List<FriendRequest> _requests = [];
  List<FriendProfile> _searchResults = [];
  List<SharedHabit> _selectedFriendHabits = [];
  FriendProfile? _myProfile;
  List<FeedHabit> _feedHabits = [];
  List<HabitComment> _comments = [];
  String? _activeCommentsHabitId;
  List<FriendProfile> _reactors = [];
  List<ActivityEntry> _activity = [];

  /// When the user last opened the Activity screen — drives the unseen-dot
  /// badge on its entry point. Stored locally (per-account) rather than in
  /// Supabase since it's purely a "have I looked" UI affordance, not data
  /// that needs to sync across devices.
  DateTime? _lastSeenActivityAt;

  /// Per-habit reaction counts and "did the current user react" — derived
  /// from a single fetchReactions() covering the whole feed (see
  /// _loadFeedReactions) rather than one query per card.
  Map<String, int> _reactionCounts = {};
  Set<String> _myReactedHabitIds = {};

  /// Per-habit comment totals — keyed by cloud habit id, same as
  /// [_reactionCounts], so both the Friends feed and "My Habits" tab can
  /// share one map (loaded via [_mergeCommentCounts]).
  Map<String, int> _commentCounts = {};

  /// Maps a *local* habit id (sqlite rowid) to its synced cloud id, for the
  /// "My Habits" tab — it needs to look up reactions/comments (keyed by cloud
  /// id) for habits the local HabitsManager only knows by local id. Absence
  /// of an entry means the habit hasn't synced to the cloud yet.
  Map<int, String> _myHabitCloudIds = {};
  LoadStatus _myHabitsSocialStatus = LoadStatus.idle;

  LoadStatus _friendsStatus = LoadStatus.idle;
  LoadStatus _requestsStatus = LoadStatus.idle;
  LoadStatus _searchStatus = LoadStatus.idle;
  LoadStatus _friendHabitsStatus = LoadStatus.idle;
  LoadStatus _myProfileStatus = LoadStatus.idle;
  LoadStatus _feedStatus = LoadStatus.idle;
  LoadStatus _commentsStatus = LoadStatus.idle;
  LoadStatus _reactorsStatus = LoadStatus.idle;
  LoadStatus _activityStatus = LoadStatus.idle;

  String? _error;
  String? _nudgeFeedback;
  String? _usernameError;

  List<Friend> get friends => _friends;
  List<FriendRequest> get requests => _requests;
  List<FriendProfile> get searchResults => _searchResults;
  List<SharedHabit> get selectedFriendHabits => _selectedFriendHabits;
  FriendProfile? get myProfile => _myProfile;
  List<FeedHabit> get feedHabits => _feedHabits;
  List<HabitComment> get comments => _comments;
  List<FriendProfile> get reactors => _reactors;
  List<ActivityEntry> get activity => _activity;

  /// True when there's at least one activity entry newer than the last time
  /// the user opened the Activity screen — drives the badge dot on its icon.
  bool get hasUnseenActivity {
    final lastSeen = _lastSeenActivityAt;
    if (_activity.isEmpty) return false;
    if (lastSeen == null) return true;
    return _activity.first.createdAt.isAfter(lastSeen);
  }

  LoadStatus get friendsStatus => _friendsStatus;
  LoadStatus get requestsStatus => _requestsStatus;
  LoadStatus get searchStatus => _searchStatus;
  LoadStatus get friendHabitsStatus => _friendHabitsStatus;
  LoadStatus get myProfileStatus => _myProfileStatus;
  LoadStatus get feedStatus => _feedStatus;
  LoadStatus get commentsStatus => _commentsStatus;
  LoadStatus get reactorsStatus => _reactorsStatus;
  LoadStatus get activityStatus => _activityStatus;

  String? get error => _error;
  String? get nudgeFeedback => _nudgeFeedback;
  String? get usernameError => _usernameError;

  int reactionCount(String habitId) => _reactionCounts[habitId] ?? 0;
  bool hasReacted(String habitId) => _myReactedHabitIds.contains(habitId);
  int commentCount(String habitId) => _commentCounts[habitId] ?? 0;

  LoadStatus get myHabitsSocialStatus => _myHabitsSocialStatus;

  /// Cloud id for [localHabitId], or null if it hasn't synced yet — in which
  /// case "My Habits" can't show reactions/comments for it (no cloud row to
  /// query against).
  String? cloudIdForLocalHabit(int localHabitId) => _myHabitCloudIds[localHabitId];

  /// Whether the Friends tab should even be shown. Unauthenticated users see
  /// zero changes to their experience — the tab is simply absent.
  bool get isAvailable => _authService.isSignedIn;

  /// The signed-in user's habit-visibility mode:
  ///  - true  -> every habit is summarized for friends (set in Profile)
  ///  - false -> only individually-chosen habits are (toggle via the eye icon
  ///             on each habit row)
  /// Defaults to false until [_myProfile] has loaded.
  bool get shareAllHabits => _myProfile?.shareAllHabits ?? false;

  List<FriendRequest> get incomingRequests => _requests
      .where((r) => r.receiverId == _repository.currentUserId)
      .toList();

  List<FriendRequest> get outgoingRequests => _requests
      .where((r) => r.senderId == _repository.currentUserId)
      .toList();

  void clearNudgeFeedback() {
    _nudgeFeedback = null;
  }

  // -------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------

  void _onAuthChanged() {
    // AuthService.notifyListeners() can fire synchronously from Supabase's
    // onAuthStateChange stream mid-frame (e.g. while the widget tree is
    // locked during build/layout). _resetState()/_bootstrap() call
    // notifyListeners() almost immediately, which would then throw
    // "setState() ... called when widget tree was locked" on
    // _InheritedProviderScope<FriendsManager?>. Deferring to a microtask
    // breaks that synchronous chain — mirrors how SyncService._onAuthChanged
    // defers via the async SharedPreferences.getInstance().then(...).
    scheduleMicrotask(() {
      if (_authService.isSignedIn) {
        _bootstrap();
      } else {
        _resetState();
      }
    });
  }

  Future<void> _bootstrap() async {
    try {
      await _repository.ensureProfileExists();
    } catch (e) {
      debugPrint('[FriendsManager] Failed to ensure profile: $e');
    }
    // loadMyProfile is included here (not just lazily on the Profile screen)
    // because `shareAllHabits` drives whether HabitHeader shows the per-habit
    // eye icon — that decision needs to be available as soon as the user is
    // signed in, not only after they've opened their Profile once.
    await Future.wait([loadFriends(), loadRequests(), loadMyProfile()]);
    _subscribeToRealtimeUpdates();
  }

  void _resetState() {
    _friends = [];
    _requests = [];
    _searchResults = [];
    _selectedFriendHabits = [];
    _myProfile = null;
    _feedHabits = [];
    _comments = [];
    _activeCommentsHabitId = null;
    _reactors = [];
    _reactorsStatus = LoadStatus.idle;
    _reactionCounts = {};
    _myReactedHabitIds = {};
    _commentCounts = {};
    _activity = [];
    _lastSeenActivityAt = null;
    _myHabitCloudIds = {};
    _myHabitsSocialStatus = LoadStatus.idle;
    _friendsStatus = LoadStatus.idle;
    _requestsStatus = LoadStatus.idle;
    _searchStatus = LoadStatus.idle;
    _friendHabitsStatus = LoadStatus.idle;
    _myProfileStatus = LoadStatus.idle;
    _feedStatus = LoadStatus.idle;
    _commentsStatus = LoadStatus.idle;
    _activityStatus = LoadStatus.idle;
    _error = null;
    _usernameError = null;
    _unsubscribeFromRealtimeUpdates();
    notifyListeners();
  }

  void _subscribeToRealtimeUpdates() {
    final uid = _repository.currentUserId;
    if (uid == null) return;
    _realtimeChannel ??= _repository.subscribeToFriendChanges(uid, () {
      // Friend/requests changed remotely (e.g. friend accepted on another
      // device) — refresh so the UI stays in sync without manual pull.
      loadFriends();
      loadRequests();
    });
    // Without this, a friend reacting/commenting while the feed (or "My
    // Habits" tab) is open would only be reflected after a manual
    // pull-to-refresh re-ran the one-shot count queries below.
    _interactionChannel ??= _repository.subscribeToInteractionChanges(
      uid,
      _refreshInteractionCounts,
    );
  }

  void _unsubscribeFromRealtimeUpdates() {
    final channel = _realtimeChannel;
    if (channel != null) {
      _repository.unsubscribe(channel);
      _realtimeChannel = null;
    }
    final interactionChannel = _interactionChannel;
    if (interactionChannel != null) {
      _repository.unsubscribe(interactionChannel);
      _interactionChannel = null;
    }
  }

  /// Re-fetches reaction/comment counts for every habit currently visible
  /// (the Friends feed and/or "My Habits" tab) in response to a realtime
  /// change on `habit_reactions`/`habit_comments` — keeps counts live
  /// without requiring the user to pull-to-refresh.
  Future<void> _refreshInteractionCounts() async {
    if (!_authService.isSignedIn) return;
    final habitIds = <String>{
      for (final feedHabit in _feedHabits) feedHabit.habit.habitId,
      ..._myHabitCloudIds.values,
    }.toList();
    if (habitIds.isEmpty) return;
    try {
      await _loadFeedReactions(habitIds);
      await _mergeCommentCounts(habitIds);
      notifyListeners();
    } catch (e) {
      debugPrint('[FriendsManager] _refreshInteractionCounts error: $e');
    }
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    _unsubscribeFromRealtimeUpdates();
    super.dispose();
  }

  // -------------------------------------------------------------------
  // Friends & requests
  // -------------------------------------------------------------------

  Future<void> loadFriends() async {
    if (!_authService.isSignedIn) return;
    _friendsStatus = LoadStatus.loading;
    notifyListeners();
    try {
      _friends = await _repository.fetchFriends();
      _friendsStatus = LoadStatus.loaded;
    } catch (e) {
      _error = e.toString();
      _friendsStatus = LoadStatus.error;
      debugPrint('[FriendsManager] loadFriends error: $e');
    }
    notifyListeners();
  }

  Future<void> loadRequests() async {
    if (!_authService.isSignedIn) return;
    _requestsStatus = LoadStatus.loading;
    notifyListeners();
    try {
      _requests = await _repository.fetchPendingRequests();
      _requestsStatus = LoadStatus.loaded;
    } catch (e) {
      _error = e.toString();
      _requestsStatus = LoadStatus.error;
      debugPrint('[FriendsManager] loadRequests error: $e');
    }
    notifyListeners();
  }

  Future<void> sendFriendRequest(String receiverId) async {
    try {
      await _repository.sendFriendRequest(receiverId);
      await loadRequests();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> acceptRequest(FriendRequest request) async {
    await _respond(request, accept: true);
  }

  Future<void> rejectRequest(FriendRequest request) async {
    await _respond(request, accept: false);
  }

  Future<void> _respond(FriendRequest request, {required bool accept}) async {
    try {
      await _repository.respondToRequest(request.id, accept: accept);
      await Future.wait([loadFriends(), loadRequests()]);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> cancelRequest(FriendRequest request) async {
    try {
      await _repository.cancelRequest(request.id);
      await loadRequests();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // -------------------------------------------------------------------
  // Own profile (Profile screen — view/change username)
  // -------------------------------------------------------------------

  Future<void> loadMyProfile() async {
    if (!_authService.isSignedIn) return;
    _myProfileStatus = LoadStatus.loading;
    notifyListeners();
    try {
      _myProfile = await _repository.fetchOwnProfile();
      _myProfileStatus = LoadStatus.loaded;
    } catch (e) {
      _error = e.toString();
      _myProfileStatus = LoadStatus.error;
      debugPrint('[FriendsManager] loadMyProfile error: $e');
    }
    notifyListeners();
  }

  void clearUsernameError() {
    _usernameError = null;
  }

  /// Switches between "share every habit" and "choose individually". Updates
  /// optimistically and reverts on failure (e.g. offline) so the UI always
  /// reflects what's actually stored — friends' visibility changes the moment
  /// this succeeds, enforced server-side by RLS (migration 006).
  Future<bool> setShareAllHabits(bool value) async {
    final uid = _myProfile?.userId ?? _repository.currentUserId;
    if (uid == null) return false;
    final previous = _myProfile;
    _myProfile = FriendProfile(
      userId: uid,
      username: previous?.username ?? '',
      avatarUrl: previous?.avatarUrl,
      shareAllHabits: value,
    );
    notifyListeners();
    try {
      await _repository.setShareAllHabits(value);
      return true;
    } catch (e) {
      _myProfile = previous;
      _error = e.toString();
      debugPrint('[FriendsManager] setShareAllHabits error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Attempts to change the signed-in user's username. Returns true on
  /// success; on failure [usernameError] holds a friendly message (e.g. the
  /// name is already taken) for the screen to display.
  Future<bool> updateUsername(String username) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) {
      _usernameError = 'Username cannot be empty.';
      notifyListeners();
      return false;
    }
    try {
      await _repository.updateUsername(trimmed);
      final uid = _myProfile?.userId ?? _repository.currentUserId ?? '';
      _myProfile = FriendProfile(
        userId: uid,
        username: trimmed,
        avatarUrl: _myProfile?.avatarUrl,
      );
      _usernameError = null;
      notifyListeners();
      return true;
    } on UsernameTakenException catch (e) {
      _usernameError = e.toString();
    } on FriendsUnavailableException catch (e) {
      _usernameError = e.toString();
    } catch (e) {
      _usernameError = 'Could not update username. Please try again.';
      debugPrint('[FriendsManager] updateUsername error: $e');
    }
    notifyListeners();
    return false;
  }

  // -------------------------------------------------------------------
  // Search — debounced by the screen; repository paginates server-side.
  // -------------------------------------------------------------------

  Future<void> searchUsers(String query, {int page = 0}) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      _searchStatus = LoadStatus.idle;
      notifyListeners();
      return;
    }
    _searchStatus = LoadStatus.loading;
    notifyListeners();
    try {
      _searchResults = await _repository.searchUsersByUsername(query, page: page);
      _searchStatus = LoadStatus.loaded;
    } catch (e) {
      _error = e.toString();
      _searchStatus = LoadStatus.error;
      debugPrint('[FriendsManager] searchUsers error: $e');
    }
    notifyListeners();
  }

  void clearSearch() {
    _searchResults = [];
    _searchStatus = LoadStatus.idle;
    // Called from SearchUsersScreen.dispose() while its element is being
    // torn down — the widget tree can be locked at that point, so notifying
    // synchronously throws "widget tree was locked" on
    // _InheritedProviderScope<FriendsManager?>. Defer like _onAuthChanged.
    scheduleMicrotask(notifyListeners);
  }

  // -------------------------------------------------------------------
  // Friend's shared habits (Friend Profile screen)
  // -------------------------------------------------------------------

  Future<void> loadFriendHabits(String friendUserId) async {
    _friendHabitsStatus = LoadStatus.loading;
    notifyListeners();
    try {
      final raw = await _repository.fetchSharedHabitsRaw(friendUserId);
      _selectedFriendHabits = raw.map((entry) {
        final entries = (entry['entries'] as List).cast<Map<String, dynamic>>();
        return SharedHabit(
          habitId: entry['habit_id'] as String,
          ownerId: friendUserId,
          title: entry['title'] as String,
          currentStreak: _computeStreak(entries),
          completionProgress: _computeCompletionProgress(entries),
        );
      }).toList();
      _friendHabitsStatus = LoadStatus.loaded;
    } catch (e) {
      _error = e.toString();
      _friendHabitsStatus = LoadStatus.error;
      debugPrint('[FriendsManager] loadFriendHabits error: $e');
    }
    notifyListeners();
  }

  void clearSelectedFriendHabits() {
    _selectedFriendHabits = [];
    _friendHabitsStatus = LoadStatus.idle;
  }

  /// Counts consecutive "check"/"progress" days working backwards from the
  /// most recent entry. Mirrors the local DayType enum used for habit days.
  int _computeStreak(List<Map<String, dynamic>> entriesByDateDesc) {
    int streak = 0;
    for (final entry in entriesByDateDesc) {
      final dayType = DayType.values[entry['day_type'] as int];
      if (dayType == DayType.check || dayType == DayType.progress) {
        streak++;
      } else if (dayType == DayType.fail) {
        break;
      }
      // `clear`/`skip` days don't break or extend the streak.
    }
    return streak;
  }

  /// Fraction of the fetched window (up to the last 30 days) that were
  /// completed — a simple, friend-facing summary of how things are going.
  double _computeCompletionProgress(List<Map<String, dynamic>> entries) {
    if (entries.isEmpty) return 0.0;
    final completed = entries.where((entry) {
      final dayType = DayType.values[entry['day_type'] as int];
      return dayType == DayType.check || dayType == DayType.progress;
    }).length;
    return completed / entries.length;
  }

  // -------------------------------------------------------------------
  // Nudges
  // -------------------------------------------------------------------

  Future<void> sendNudge({
    required String receiverId,
    required String habitId,
    required String habitTitle,
  }) async {
    final username = await _currentUsername();
    try {
      await _nudgeRepository.sendNudge(
        receiverId: receiverId,
        habitId: habitId,
        habitTitle: habitTitle,
        senderUsername: username,
      );
      _nudgeFeedback = 'Nudge sent!';
    } on NudgeRateLimitException catch (e) {
      _nudgeFeedback = e.toString();
    } on FriendsUnavailableException catch (e) {
      _nudgeFeedback = e.toString();
    } catch (e) {
      _nudgeFeedback = 'Could not send nudge. Please try again.';
      debugPrint('[FriendsManager] sendNudge error: $e');
    }
    notifyListeners();
  }

  Future<String> _currentUsername() async {
    final uid = _repository.currentUserId;
    if (uid == null) return 'A friend';
    final mine = _friends.where((f) => f.profile.userId == uid);
    if (mine.isNotEmpty) return mine.first.profile.username;
    return _authService.currentUser?.email?.split('@').first ?? 'A friend';
  }

  // -------------------------------------------------------------------
  // Habit sharing (used by EditHabitScreen toggle)
  // -------------------------------------------------------------------

  /// Resolves a local habit's cloud uuid (habits are synced by [SyncService]
  /// before they can be shared — see cloudHabitIdForLocalId for details).
  Future<String?> cloudHabitIdForLocalId(int localId) {
    return _repository.cloudHabitIdForLocalId(localId);
  }

  Future<void> setHabitShared(String cloudHabitId, bool isShared) {
    return _repository.setHabitShared(cloudHabitId, isShared);
  }

  Future<bool> isHabitShared(String cloudHabitId) {
    return _repository.isHabitShared(cloudHabitId);
  }

  // -------------------------------------------------------------------
  // Social feed (Social tab) — every friend's visible habits, with
  // reactions and comments.
  // -------------------------------------------------------------------

  /// Loads every accepted friend's currently-visible habits into one feed.
  /// Reuses fetchSharedHabitsRaw per friend (already RLS-filtered to exactly
  /// what that friend has made visible — see migrations 006/007) rather than
  /// a bespoke aggregate query, so the feed automatically honours the same
  /// visibility rules as the Friend Profile screen.
  Future<void> loadSocialFeed() async {
    if (!_authService.isSignedIn) return;
    _feedStatus = LoadStatus.loading;
    notifyListeners();
    try {
      if (_friends.isEmpty && _friendsStatus != LoadStatus.loaded) {
        await loadFriends();
      }
      final feed = <FeedHabit>[];
      for (final friend in _friends) {
        final raw = await _repository.fetchSharedHabitsRaw(friend.profile.userId);
        for (final entry in raw) {
          final entries = (entry['entries'] as List).cast<Map<String, dynamic>>();
          feed.add(FeedHabit(
            owner: friend.profile,
            habit: SharedHabit(
              habitId: entry['habit_id'] as String,
              ownerId: friend.profile.userId,
              title: entry['title'] as String,
              currentStreak: _computeStreak(entries),
              completionProgress: _computeCompletionProgress(entries),
            ),
          ));
        }
      }
      _feedHabits = feed;
      final habitIds = feed.map((f) => f.habit.habitId).toList();
      await _loadFeedReactions(habitIds);
      await _mergeCommentCounts(habitIds);
      _feedStatus = LoadStatus.loaded;
    } catch (e) {
      _error = e.toString();
      _feedStatus = LoadStatus.error;
      debugPrint('[FriendsManager] loadSocialFeed error: $e');
    }
    notifyListeners();
  }

  void clearSocialFeed() {
    _feedHabits = [];
    _reactionCounts = {};
    _myReactedHabitIds = {};
    _commentCounts = {};
    _feedStatus = LoadStatus.idle;
  }

  /// Loads total comment counts for [habitIds] in one round trip and merges
  /// them into [_commentCounts] — shared by the Friends feed and "My Habits"
  /// tab (cloud habit ids are globally unique, so merging is safe). Mirrors
  /// [_loadFeedReactions].
  Future<void> _mergeCommentCounts(List<String> habitIds) async {
    if (habitIds.isEmpty) return;
    final rows = await _repository.fetchCommentCounts(habitIds);
    for (final id in habitIds) {
      _commentCounts[id] = 0;
    }
    for (final row in rows) {
      final habitId = row['habit_id'] as String;
      _commentCounts[habitId] = (_commentCounts[habitId] ?? 0) + 1;
    }
  }

  /// For the "My Habits" tab: resolves [localHabitIds] to their cloud ids and
  /// loads how many reactions each has received from others — so the owner
  /// can see who's cheering them on without leaving the Social tab. Counts
  /// are merged into the same [_reactionCounts] map the Friends feed uses
  /// (cloud habit ids are globally unique, so there's no collision risk),
  /// letting both tabs share [reactionCount].
  Future<void> loadMyHabitsActivitySummary(List<int> localHabitIds) async {
    if (!_authService.isSignedIn) return;
    _myHabitsSocialStatus = LoadStatus.loading;
    notifyListeners();
    try {
      _myHabitCloudIds = await _repository.cloudHabitIdsForLocalIds(localHabitIds);
      final cloudIds = _myHabitCloudIds.values.toList();
      final rows = await _repository.fetchReactions(cloudIds);
      for (final cloudId in cloudIds) {
        _reactionCounts[cloudId] = 0;
      }
      for (final row in rows) {
        final habitId = row['habit_id'] as String;
        _reactionCounts[habitId] = (_reactionCounts[habitId] ?? 0) + 1;
      }
      await _mergeCommentCounts(cloudIds);
      _myHabitsSocialStatus = LoadStatus.loaded;
    } catch (e) {
      _error = e.toString();
      _myHabitsSocialStatus = LoadStatus.error;
      debugPrint('[FriendsManager] loadMyHabitsActivitySummary error: $e');
    }
    notifyListeners();
  }

  void clearMyHabitsActivitySummary() {
    _myHabitCloudIds = {};
    _myHabitsSocialStatus = LoadStatus.idle;
  }

  /// Loads reaction counts for [habitIds] and merges them into
  /// [_reactionCounts]/[_myReactedHabitIds] — merging (rather than replacing
  /// the maps wholesale) matters because the Friends feed and "My Habits"
  /// tab call this with *different* id sets but share the same maps; a
  /// wholesale replace would wipe out whichever set wasn't just queried
  /// (e.g. switching to the feed would reset "My Habits" cards to "No
  /// reactions yet" until they were reloaded). Mirrors [_mergeCommentCounts].
  Future<void> _loadFeedReactions(List<String> habitIds) async {
    if (habitIds.isEmpty) return;
    final rows = await _repository.fetchReactions(habitIds);
    final uid = _repository.currentUserId;
    for (final id in habitIds) {
      _reactionCounts[id] = 0;
      _myReactedHabitIds.remove(id);
    }
    for (final row in rows) {
      final habitId = row['habit_id'] as String;
      _reactionCounts[habitId] = (_reactionCounts[habitId] ?? 0) + 1;
      if (row['user_id'] == uid) _myReactedHabitIds.add(habitId);
    }
  }

  /// Toggles the current user's reaction on [habitId]. Updates optimistically
  /// (the feed should feel instant) and reverts if the write fails.
  Future<void> toggleReaction(String habitId) async {
    if (_repository.currentUserId == null) return;
    final wasReacted = _myReactedHabitIds.contains(habitId);
    _applyReactionChange(habitId, react: !wasReacted);
    notifyListeners();
    try {
      if (wasReacted) {
        await _repository.removeReaction(habitId);
      } else {
        await _repository.addReaction(habitId);
      }
    } catch (e) {
      _applyReactionChange(habitId, react: wasReacted);
      _error = e.toString();
      debugPrint('[FriendsManager] toggleReaction error: $e');
      notifyListeners();
    }
  }

  void _applyReactionChange(String habitId, {required bool react}) {
    final current = _reactionCounts[habitId] ?? 0;
    if (react) {
      _myReactedHabitIds.add(habitId);
      _reactionCounts[habitId] = current + 1;
    } else {
      _myReactedHabitIds.remove(habitId);
      _reactionCounts[habitId] = current > 0 ? current - 1 : 0;
    }
  }

  /// Loads the comment thread for [habitId] (e.g. when the comment sheet for
  /// a feed card opens).
  Future<void> loadComments(String habitId) async {
    _activeCommentsHabitId = habitId;
    _commentsStatus = LoadStatus.loading;
    notifyListeners();
    try {
      final raw = await _repository.fetchComments(habitId);
      _comments = raw.map((row) => HabitComment.fromMap(row)).toList();
      _commentsStatus = LoadStatus.loaded;
    } catch (e) {
      _error = e.toString();
      _commentsStatus = LoadStatus.error;
      debugPrint('[FriendsManager] loadComments error: $e');
    }
    notifyListeners();
  }

  /// Posts [body] as a comment on [habitId] and refreshes the thread.
  /// Returns false (without throwing) on failure so the sheet can show
  /// friendly feedback instead of crashing.
  Future<bool> addComment(String habitId, String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return false;
    try {
      await _repository.addComment(habitId, trimmed);
      _commentCounts[habitId] = (_commentCounts[habitId] ?? 0) + 1;
      if (_activeCommentsHabitId == habitId) {
        await loadComments(habitId);
      } else {
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('[FriendsManager] addComment error: $e');
      notifyListeners();
      return false;
    }
  }

  void clearComments() {
    _comments = [];
    _commentsStatus = LoadStatus.idle;
    _activeCommentsHabitId = null;
  }

  /// Loads everyone who reacted to [habitId] (e.g. when the "who reacted?"
  /// sheet for a card opens) — mirrors [loadComments].
  Future<void> loadReactors(String habitId) async {
    _reactorsStatus = LoadStatus.loading;
    notifyListeners();
    try {
      final raw = await _repository.fetchReactors(habitId);
      _reactors = raw.map((row) {
        final actor = row['actor'];
        final profile = actor is Map<String, dynamic> ? actor : const {};
        return FriendProfile(
          userId: row['user_id'] as String,
          username: profile['username'] as String? ?? 'A friend',
          avatarUrl: profile['avatar_url'] as String?,
        );
      }).toList();
      _reactorsStatus = LoadStatus.loaded;
    } catch (e) {
      _error = e.toString();
      _reactorsStatus = LoadStatus.error;
      debugPrint('[FriendsManager] loadReactors error: $e');
    }
    notifyListeners();
  }

  void clearReactors() {
    _reactors = [];
    _reactorsStatus = LoadStatus.idle;
  }

  // -------------------------------------------------------------------
  // Activity (reactions/comments friends left on *your* habits)
  // -------------------------------------------------------------------

  String? get _lastSeenActivityPrefsKey {
    final uid = _repository.currentUserId;
    return uid == null ? null : 'last_seen_activity_at_$uid';
  }

  /// Loads who's reacted to/commented on the signed-in user's own habits,
  /// merging both kinds of interaction into one newest-first feed. Also
  /// restores the locally-stored "last seen" timestamp so [hasUnseenActivity]
  /// is accurate as soon as the list loads.
  Future<void> loadActivity() async {
    if (!_authService.isSignedIn) return;
    _activityStatus = LoadStatus.loading;
    notifyListeners();
    try {
      await _loadLastSeenActivity();
      final raw = await _repository.fetchActivity();
      _activity = raw
          .map((row) => ActivityEntry.fromMap(
                row,
                row['_activity_type'] == 'comment'
                    ? ActivityType.comment
                    : ActivityType.reaction,
              ))
          .toList();
      _activityStatus = LoadStatus.loaded;
    } catch (e) {
      _error = e.toString();
      _activityStatus = LoadStatus.error;
      debugPrint('[FriendsManager] loadActivity error: $e');
    }
    notifyListeners();
  }

  void clearActivity() {
    _activity = [];
    _activityStatus = LoadStatus.idle;
  }

  Future<void> _loadLastSeenActivity() async {
    final key = _lastSeenActivityPrefsKey;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(key);
    _lastSeenActivityAt = stored == null ? null : DateTime.tryParse(stored);
  }

  /// Stamps "now" as the last-seen time so the unseen-dot badge clears —
  /// call when the user opens the Activity screen.
  Future<void> markActivitySeen() async {
    final key = _lastSeenActivityPrefsKey;
    if (key == null) return;
    final now = DateTime.now().toUtc();
    _lastSeenActivityAt = now;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, now.toIso8601String());
  }
}
