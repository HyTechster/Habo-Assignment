import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:habo/auth/auth_service.dart';
import 'package:habo/constants.dart';
import 'package:habo/services/service_locator.dart';
import 'package:habo/settings/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SyncService extends ChangeNotifier {
  final AuthService _authService;
  final Future<void> Function() _onDataChanged;
  final SettingsManager? _settingsManager;

  bool _isSyncing = false;
  bool _pendingSync = false;
  DateTime? _lastSyncTime;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;

  SyncService(this._authService,
      {required Future<void> Function() onDataChanged,
      SettingsManager? settingsManager})
      : _onDataChanged = onDataChanged,
        _settingsManager = settingsManager {
    _authService.addListener(_onAuthChanged);

    // App launched with a restored session — ensure the stored user ID is
    // seeded so the listener doesn't mistake this for a new sign-in.
    if (_authService.isSignedIn) {
      SharedPreferences.getInstance().then((prefs) {
        final uid = _authService.currentUser?.id;
        if (uid != null && prefs.getString('synced_user_id') == null) {
          prefs.setString('synced_user_id', uid);
        }
        syncIfReady();
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Auth state handlers
  // ---------------------------------------------------------------------------

  void _onAuthChanged() {
    if (_authService.isSignedIn) {
      _handleSignIn();
    } else {
      _handleSignOut();
    }
  }

  /// Called whenever auth state fires a sign-in event.
  /// Distinguishes between "same user resuming" and "new/different user".
  void _handleSignIn() {
    SharedPreferences.getInstance().then((prefs) async {
      final storedUid = prefs.getString('synced_user_id');
      final currentUid = _authService.currentUser?.id;
      if (currentUid == null) return;

      if (storedUid == currentUid) {
        // Same account as before — load its settings then sync normally.
        await _settingsManager?.switchUser(currentUid);
        syncIfReady();
        return;
      }

      // Different (or first-time) account — mark immediately to prevent
      // double-execution if auth state fires more than once.
      await prefs.setString('synced_user_id', currentUid);
      await prefs.remove('last_sync_time');
      await _settingsManager?.switchUser(currentUid); // load this account's settings

      if (!_isSupabaseAvailable) return;

      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        // Offline at sign-in — defer to next connectivity event.
        return;
      }

      try {
        final existing = await _client
            .from('habits')
            .select('id')
            .eq('user_id', currentUid)
            .limit(1);

        if (existing.isEmpty) {
          // ── New account ──────────────────────────────────────────────────
          // Upload whatever is stored locally under this account.
          debugPrint('[SyncService] New account — uploading local habits');
          await syncIfReady();
        } else {
          // ── Existing account ─────────────────────────────────────────────
          // Wipe local data first, then pull the account's cloud data.
          debugPrint('[SyncService] Existing account — replacing local with cloud data');
          await _clearLocalData();
          await _onDataChanged(); // show empty app immediately while pulling
          await syncIfReady();   // pull everything from cloud
        }
      } catch (e) {
        debugPrint('[SyncService] Sign-in error: $e');
      }
    });
  }

  /// Called on sign-out: wipes all local habit data for a clean slate.
  /// We intentionally keep synced_user_id so that when the same account
  /// signs back in it goes through the normal sync path (full pull, since
  /// last_sync_time is removed) instead of the "existing account" clear
  /// path, which risks losing entries if the pull fails partway through.
  void _handleSignOut() {
    SharedPreferences.getInstance().then((prefs) async {
      await prefs.remove('last_sync_time'); // forces full pull on next sign-in
      // synced_user_id is intentionally kept
      await _clearLocalData();
      await _settingsManager?.switchUser(null); // reset settings to defaults
      await _onDataChanged(); // reload UI — will show empty habit list
    });
  }

  /// Deletes all habits and events from the local SQLite database.
  Future<void> _clearLocalData() async {
    await ServiceLocator.instance.haboModel.emptyTables();
  }

  // ---------------------------------------------------------------------------
  // Sign-out (push first, then clear)
  // ---------------------------------------------------------------------------

  /// Push all local data to cloud while still authenticated, then sign out.
  /// Always use this instead of [AuthService.signOut] from UI code so that
  /// nothing is lost when the local database is wiped by [_handleSignOut].
  Future<void> signOut() async {
    if (_isSupabaseAvailable && _authService.isSignedIn) {
      try {
        await _pushLocalHabits();
        await _pushLocalCategories();
        try {
          await _pushLocalHabitCategories();
        } catch (e) {
          debugPrint('[SyncService] Pre-signout push habit_categories error: $e');
        }
        await _pushLocalEntries();
      } catch (e) {
        debugPrint('[SyncService] Pre-signout push error: $e');
      }
    }
    await _authService.signOut();
    // _handleSignOut() fires via the auth-state listener and clears local data.
  }

  // ---------------------------------------------------------------------------
  // Cloud data reset
  // ---------------------------------------------------------------------------

  /// Deletes ALL data for the current user — both cloud (Supabase) and local
  /// SQLite. The habit list will be empty after this call.
  Future<void> clearAllData() async {
    if (!_isSupabaseAvailable || !_authService.isSignedIn) return;
    final userId = _authService.currentUser!.id;

    // Delete from cloud in child-first order to respect foreign-key constraints.
    await _client.from('habit_entries').delete().eq('user_id', userId);
    await _client.from('habit_categories').delete().eq('user_id', userId);
    await _client.from('habits').delete().eq('user_id', userId);
    await _client.from('categories').delete().eq('user_id', userId);

    // Wipe local SQLite data so the habit list becomes empty immediately.
    await _clearLocalData();

    // Clear the sync timestamp so a future sign-out/sign-in starts clean.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_sync_time');

    // Reload from the now-empty DB to refresh the UI.
    await _onDataChanged();

    debugPrint('[SyncService] clearAllData: cloud + local data deleted for user $userId');
  }

  // ---------------------------------------------------------------------------
  // Connectivity listener
  // ---------------------------------------------------------------------------

  void listenForConnectivity() {
    Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        syncIfReady();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Core sync
  // ---------------------------------------------------------------------------

  Future<void> syncIfReady() async {
    if (!_isSupabaseAvailable) return;
    if (!_authService.isSignedIn) return;
    if (_isSyncing) {
      _pendingSync = true; // retry after current sync finishes
      return;
    }

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return;

    _isSyncing = true;
    _pendingSync = false;
    notifyListeners();

    try {
      await _pushLocalHabits();
      await _pushLocalCategories();
      try {
        await _pushLocalHabitCategories();
      } catch (e) {
        debugPrint('[SyncService] push habit_categories error (non-fatal): $e');
      }
      await _pushLocalEntries();
      final dataChanged = await _pullRemoteChanges();
      _lastSyncTime = DateTime.now();
      if (dataChanged) {
        await _onDataChanged();
      }
    } catch (e) {
      debugPrint('[SyncService] Sync error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
      if (_pendingSync) syncIfReady(); // run the missed sync
    }
  }

  bool get _isSupabaseAvailable {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  SupabaseClient get _client => Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Push local → remote
  // ---------------------------------------------------------------------------

  Future<void> _pushLocalHabits() async {
    final habits = await ServiceLocator.instance.haboModel.getAllHabits();
    final userId = _authService.currentUser!.id;
    final now = DateTime.now().toUtc().toIso8601String();

    final rows = habits.map((habit) {
      final hd = habit.habitData;
      return {
        'user_id': userId,
        'local_id': hd.id,
        'title': hd.title,
        'position': hd.position,
        'two_day_rule': hd.twoDayRule,
        'cue': hd.cue,
        'routine': hd.routine,
        'reward': hd.reward,
        'show_reward': hd.showReward,
        'advanced': hd.advanced,
        'notification': hd.notification,
        'not_time': '${hd.notTime.hour}:${hd.notTime.minute}',
        'sanction': hd.sanction,
        'show_sanction': hd.showSanction,
        'accountant': hd.accountant,
        'habit_type': hd.habitType.index,
        'target_value': hd.targetValue,
        'partial_value': hd.partialValue,
        'unit': hd.unit,
        'archived': hd.archived,
        'updated_at': now,
      };
    }).toList();

    if (rows.isEmpty) return;
    await _client
        .from('habits')
        .upsert(rows, onConflict: 'user_id,local_id');
  }

  Future<void> _pushLocalEntries() async {
    final habits = await ServiceLocator.instance.haboModel.getAllHabits();
    final userId = _authService.currentUser!.id;

    debugPrint('[SyncService] push entries: ${habits.length} local habits');

    final remoteRows = await _client
        .from('habits')
        .select('id,local_id')
        .eq('user_id', userId);

    debugPrint('[SyncService] push entries: ${remoteRows.length} remote habits');

    final localIdToRemoteId = <int, String>{};
    for (final r in remoteRows) {
      final localId = (r['local_id'] as num?)?.toInt();
      final remoteId = r['id'] as String?;
      if (localId != null && remoteId != null) {
        localIdToRemoteId[localId] = remoteId;
      }
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final rows = <Map<String, dynamic>>[];

    for (final habit in habits) {
      final remoteHabitId = localIdToRemoteId[habit.habitData.id];
      if (remoteHabitId == null) {
        debugPrint('[SyncService] push entries: no remote id for local habit ${habit.habitData.id} (${habit.habitData.title})');
        continue;
      }

      for (final entry in habit.habitData.events.entries) {
        final date = entry.key;
        final value = entry.value;
        if (value.isEmpty) continue;
        final entryComment =
            (value.length > 1 ? value[1] as String? : null) ?? '';
        // DayType.clear with no comment means "no mark" — skip it.
        // DayType.clear WITH a comment is a note-only entry — push it.
        if ((value[0] as DayType) == DayType.clear && entryComment.isEmpty) continue;

        final dateStr =
            '${date.year.toString().padLeft(4, '0')}'
            '-${date.month.toString().padLeft(2, '0')}'
            '-${date.day.toString().padLeft(2, '0')}';

        rows.add({
          'user_id': userId,
          'habit_id': remoteHabitId,
          'entry_date': dateStr,
          'day_type': (value[0] as DayType).index,
          'comment': entryComment,
          'progress_value':
              (value.length > 2 ? value[2] as double? : null) ?? 0.0,
          'target_value':
              (value.length > 3 ? value[3] as double? : null) ?? 0.0,
          'updated_at': now,
        });
      }
    }

    debugPrint('[SyncService] push entries: ${rows.length} to push');

    // Send in batches — a single request per row would mean thousands of
    // network round-trips for a year of daily entries across many habits.
    // PostgREST accepts a list of rows per upsert call, so chunking keeps
    // each request body reasonably sized while cutting round-trips by ~200x.
    const batchSize = 200;
    var pushed = 0;
    for (var i = 0; i < rows.length; i += batchSize) {
      final end = (i + batchSize < rows.length) ? i + batchSize : rows.length;
      final batch = rows.sublist(i, end);
      try {
        await _client
            .from('habit_entries')
            .upsert(batch, onConflict: 'user_id,habit_id,entry_date');
        pushed += batch.length;
      } catch (e) {
        debugPrint('[SyncService] push entries: ✗ batch $i-$end FAILED — $e');
      }
    }
    debugPrint('[SyncService] push entries: done, pushed $pushed entries');
  }

  Future<void> _pushLocalCategories() async {
    final db = ServiceLocator.instance.haboModel.db;
    final userId = _authService.currentUser!.id;

    // Skip if local habits haven't been populated yet (e.g. fresh sign-in
    // before the pull). Wiping cloud categories at that point would lose data.
    final localHabits = await db.query('habits', columns: ['id'], limit: 1);
    if (localHabits.isEmpty) {
      debugPrint('[SyncService] push categories: local DB empty, skipping');
      return;
    }

    final cats = await db.query('categories');
    debugPrint('[SyncService] push categories: ${cats.length} local');

    // Upsert whatever exists locally.
    if (cats.isNotEmpty) {
      final now = DateTime.now().toUtc().toIso8601String();
      final rows = cats.map((cat) => {
            'user_id': userId,
            'local_id': cat['id'] as int,
            'title': cat['title'] ?? '',
            'icon_code_point': cat['iconCodePoint'] ?? 0,
            'font_family': cat['fontFamily'],
            'updated_at': now,
          }).toList();
      try {
        await _client
            .from('categories')
            .upsert(rows, onConflict: 'user_id,local_id');
      } catch (e) {
        debugPrint('[SyncService] push categories: ✗ upsert FAILED — $e');
      }
    }

    // Delete cloud categories that no longer exist locally (user deleted them).
    // Without this step a deleted category stays in the cloud and gets pulled
    // back on the next sync, making it reappear in the UI.
    try {
      final localIds = cats.map((c) => c['id'] as int).toList();
      if (localIds.isEmpty) {
        await _client.from('categories').delete().eq('user_id', userId);
      } else {
        // PostgREST "NOT IN list" syntax: not.in.(1,2,3)
        await _client
            .from('categories')
            .delete()
            .eq('user_id', userId)
            .not('local_id', 'in', '(${localIds.join(',')})');
      }
    } catch (e) {
      debugPrint('[SyncService] push categories: ✗ stale delete FAILED — $e');
    }
  }

  Future<void> _pushLocalHabitCategories() async {
    final db = ServiceLocator.instance.haboModel.db;
    final userId = _authService.currentUser!.id;

    // Build local→remote ID maps.
    final remoteHabits = await _client
        .from('habits')
        .select('id,local_id')
        .eq('user_id', userId);
    final localHabitToRemote = <int, String>{};
    for (final r in remoteHabits) {
      final localId = (r['local_id'] as num?)?.toInt();
      final remoteId = r['id'] as String?;
      if (localId != null && remoteId != null) localHabitToRemote[localId] = remoteId;
    }

    final remoteCats = await _client
        .from('categories')
        .select('id,local_id')
        .eq('user_id', userId);
    final localCatToRemote = <int, String>{};
    for (final r in remoteCats) {
      final localId = (r['local_id'] as num?)?.toInt();
      final remoteId = r['id'] as String?;
      if (localId != null && remoteId != null) localCatToRemote[localId] = remoteId;
    }

    final habitCats = await db.query('habit_categories');

    final toInsert = <Map<String, dynamic>>[];
    for (final hc in habitCats) {
      final remoteHabitId = localHabitToRemote[(hc['habit_id'] as num?)?.toInt()];
      final remoteCatId = localCatToRemote[(hc['category_id'] as num?)?.toInt()];
      if (remoteHabitId == null || remoteCatId == null) continue;
      toInsert.add({
        'user_id': userId,
        'habit_id': remoteHabitId,
        'category_id': remoteCatId,
      });
    }

    // Guard: if local habits table is empty, local data was just cleared by
    // sign-out. Deleting remote now would wipe cloud data before the pull can
    // restore it. Skip and let the pull bring everything back instead.
    final localHabits = await db.query('habits', columns: ['id'], limit: 1);
    if (localHabits.isEmpty) {
      debugPrint('[SyncService] push habit_categories: local empty, skipping to preserve remote');
      return;
    }

    // Full replace: wipe remote associations then reinsert from local truth.
    await _client.from('habit_categories').delete().eq('user_id', userId);
    if (toInsert.isNotEmpty) {
      try {
        await _client.from('habit_categories').insert(toInsert);
      } catch (e) {
        debugPrint('[SyncService] push habit_categories: ✗ FAILED — $e');
      }
    }
    debugPrint('[SyncService] push habit_categories: ${toInsert.length} associations');
  }

  // ---------------------------------------------------------------------------
  // Pull remote → local  (insert-only for records absent locally)
  // Returns true if any new records were written to SQLite.
  // ---------------------------------------------------------------------------

  Future<bool> _pullRemoteChanges() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync =
        prefs.getString('last_sync_time') ?? '1970-01-01T00:00:00.000Z';
    final userId = _authService.currentUser!.id;
    final db = ServiceLocator.instance.haboModel.db;

    debugPrint('[SyncService] pull: lastSync=$lastSync');

    // ── Fetch remote data (bulk requests, one per table) ───────────────────
    // Habits / categories / entries are delta-filtered by lastSync.
    // The id-index queries and habit_categories have no updated_at column
    // so they always return the full user set.
    //
    // PostgREST (Supabase) silently caps un-limited queries at 1000 rows.
    // Habits and categories are small enough that a generous explicit limit
    // suffices; entries are paginated in chunks of 1000 so a user with many
    // habits and months of history never loses rows silently.
    final remoteHabits = await _client
        .from('habits')
        .select()
        .eq('user_id', userId)
        .gte('updated_at', lastSync)
        .isFilter('deleted_at', null)
        .limit(10000);

    // Full habit id-index needed for entry and habit_category foreign-key mapping.
    final remoteHabitIndex = await _client
        .from('habits')
        .select('id,local_id')
        .eq('user_id', userId)
        .limit(10000);

    final remoteIdToLocalId = <String, int>{};
    for (final r in remoteHabitIndex) {
      final remoteId = r['id'] as String?;
      final localId = (r['local_id'] as num?)?.toInt();
      if (remoteId != null && localId != null) remoteIdToLocalId[remoteId] = localId;
    }

    List<Map<String, dynamic>> remoteCategories = [];
    List<Map<String, dynamic>> remoteHabitCats = [];
    final remoteCatToLocal = <String, int>{};

    try {
      remoteCategories = await _client
          .from('categories')
          .select()
          .eq('user_id', userId)
          .gte('updated_at', lastSync)
          .limit(10000);

      final remoteCatIndex = await _client
          .from('categories')
          .select('id,local_id')
          .eq('user_id', userId)
          .limit(10000);
      for (final r in remoteCatIndex) {
        final remoteId = r['id'] as String?;
        final localId = (r['local_id'] as num?)?.toInt();
        if (remoteId != null && localId != null) remoteCatToLocal[remoteId] = localId;
      }

      remoteHabitCats = await _client
          .from('habit_categories')
          .select()
          .eq('user_id', userId)
          .limit(10000);
    } catch (e) {
      debugPrint('[SyncService] pull categories fetch error (non-fatal): $e');
    }

    // Entries are the only table that can realistically exceed 1000 rows for
    // active users, so paginate in chunks of 1000 until the server returns a
    // partial page (signalling end-of-data).
    final remoteEntries = <Map<String, dynamic>>[];
    try {
      const entryPageSize = 1000;
      var entryOffset = 0;
      while (true) {
        final page = await _client
            .from('habit_entries')
            .select()
            .eq('user_id', userId)
            .gte('updated_at', lastSync)
            .range(entryOffset, entryOffset + entryPageSize - 1);
        remoteEntries.addAll(page);
        if (page.length < entryPageSize) break;
        entryOffset += entryPageSize;
      }
    } catch (e) {
      debugPrint('[SyncService] pull entries fetch error (non-fatal): $e');
    }

    debugPrint('[SyncService] pull: ${remoteHabits.length} habits, '
        '${remoteCategories.length} categories, '
        '${remoteHabitCats.length} habit_cats, '
        '${remoteEntries.length} entries');

    // ── Single SQLite batch transaction ────────────────────────────────────
    // The events table has PRIMARY KEY(id, dateTime) and habits has
    // INTEGER PRIMARY KEY — ConflictAlgorithm.ignore silently skips rows
    // that already exist, so no per-row SELECT existence check is needed.
    final sqlBatch = db.batch();

    for (final rh in remoteHabits) {
      final localId = (rh['local_id'] as num?)?.toInt();
      if (localId == null) continue;
      sqlBatch.insert(
        'habits',
        {
          'id': localId,
          'position': rh['position'] ?? 0,
          'title': rh['title'] ?? '',
          'twoDayRule': (rh['two_day_rule'] == true) ? 1 : 0,
          'cue': rh['cue'] ?? '',
          'routine': rh['routine'] ?? '',
          'reward': rh['reward'] ?? '',
          'showReward': (rh['show_reward'] == true) ? 1 : 0,
          'advanced': (rh['advanced'] == true) ? 1 : 0,
          'notification': (rh['notification'] == true) ? 1 : 0,
          'notTime': rh['not_time'] ?? '20:0',
          'sanction': rh['sanction'] ?? '',
          'showSanction': (rh['show_sanction'] == true) ? 1 : 0,
          'accountant': rh['accountant'] ?? '',
          'habitType': rh['habit_type'] ?? 0,
          'targetValue': ((rh['target_value'] as num?) ?? 1.0).toDouble(),
          'partialValue': ((rh['partial_value'] as num?) ?? 1.0).toDouble(),
          'unit': rh['unit'] ?? '',
          'archived': (rh['archived'] == true) ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    for (final rc in remoteCategories) {
      final localId = (rc['local_id'] as num?)?.toInt();
      if (localId == null) continue;
      sqlBatch.insert(
        'categories',
        {
          'id': localId,
          'title': rc['title'] ?? '',
          'iconCodePoint': (rc['icon_code_point'] as num?)?.toInt() ?? 0,
          'fontFamily': rc['font_family'],
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    for (final rhc in remoteHabitCats) {
      final localHabitId = remoteIdToLocalId[rhc['habit_id'] as String?];
      final localCatId = remoteCatToLocal[rhc['category_id'] as String?];
      if (localHabitId == null || localCatId == null) continue;
      sqlBatch.insert(
        'habit_categories',
        {'habit_id': localHabitId, 'category_id': localCatId},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    for (final re in remoteEntries) {
      final localHabitId = remoteIdToLocalId[re['habit_id'] as String?];
      if (localHabitId == null) continue;

      final dayTypeIndex = (re['day_type'] as num?)?.toInt() ?? 0;
      final pullComment = re['comment'] as String? ?? '';
      if (dayTypeIndex == 0 && pullComment.isEmpty) continue;

      final dateStr = re['entry_date'] as String;
      final dateParts = dateStr.split('-');
      final dateTimeStr = DateTime.utc(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        12,
      ).toString();

      sqlBatch.insert(
        'events',
        {
          'id': localHabitId,
          'dateTime': dateTimeStr,
          'dayType': dayTypeIndex,
          'comment': pullComment,
          'progressValue': ((re['progress_value'] as num?) ?? 0.0).toDouble(),
          'targetValue': ((re['target_value'] as num?) ?? 0.0).toDouble(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // noResult:false returns the rowid for each INSERT — ConflictAlgorithm
    // .ignore returns 0 when a row was skipped (already exists locally).
    // A positive rowid means a genuinely new row was written to SQLite.
    final batchResults = await sqlBatch.commit(noResult: false);
    final changed = batchResults.any((r) => r is int && r > 0);

    await prefs.setString(
        'last_sync_time', DateTime.now().toUtc().toIso8601String());

    debugPrint('[SyncService] pull: done, changed=$changed');
    return changed;
  }
}
