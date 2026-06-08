import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habo/auth/auth_service.dart';
import 'package:habo/friends/data/friends_repository.dart';
import 'package:habo/friends/data/nudge_repository.dart';
import 'package:habo/friends/friend_requests_screen.dart';
import 'package:habo/friends/friends_list_screen.dart';
import 'package:habo/friends/friends_manager.dart';
import 'package:habo/friends/model/friend.dart';
import 'package:habo/friends/widgets/nudge_button.dart';
import 'package:habo/generated/l10n.dart';
import 'package:habo/habits/edit_habit_screen.dart';
import 'package:habo/habits/habits_manager.dart';
import 'package:habo/model/habit_data.dart';
import 'package:habo/navigation/app_state_manager.dart';
import 'package:habo/repositories/category_repository.dart';
import 'package:habo/repositories/event_repository.dart';
import 'package:habo/repositories/habit_repository.dart';
import 'package:habo/services/backup_service.dart';
import 'package:habo/services/notification_service.dart';
import 'package:habo/services/ui_feedback_service.dart';
import 'package:habo/settings/settings_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockFriendsRepository extends Mock implements FriendsRepository {}

class MockNudgeRepository extends Mock implements NudgeRepository {}

class MockRealtimeChannel extends Mock implements RealtimeChannel {}

/// mocktail needs a dummy instance to satisfy `any()` matchers for types it
/// can't construct itself — `Fake` is the standard way to provide one.
class FakeRealtimeChannel extends Fake implements RealtimeChannel {}

class MockHabitRepository extends Mock implements HabitRepository {}

class MockEventRepository extends Mock implements EventRepository {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

class MockBackupService extends Mock implements BackupService {}

class MockNotificationService extends Mock implements NotificationService {}

class MockUIFeedbackService extends Mock implements UIFeedbackService {}

/// Stand-in for AuthService that reports "signed in" without touching the
/// real Supabase client (which isn't initialized in the test environment).
class FakeAuthService extends AuthService {
  @override
  bool get isSignedIn => true;

  @override
  User? get currentUser => null;
}

const _currentUserId = 'me-0000-0000';

/// Builds a minimally-filled HabitData — every field HabitData requires is
/// supplied so tests don't have to repeat the full constructor each time.
HabitData _buildHabitData({required int id, required String title}) {
  return HabitData(
    id: id,
    position: 0,
    title: title,
    twoDayRule: false,
    cue: '',
    routine: '',
    reward: '',
    showReward: false,
    advanced: false,
    events: SplayTreeMap<DateTime, List>(),
    notification: false,
    notTime: const TimeOfDay(hour: 12, minute: 0),
    sanction: '',
    showSanction: false,
    accountant: '',
  );
}

/// Wraps [child] with every provider the Friends screens (and EditHabitScreen,
/// for the share-toggle test) expect, plus the localization delegates Habo's
/// generated `S.of(context)` strings rely on.
Widget _wrap(
  Widget child, {
  required FriendsManager friendsManager,
  HabitsManager? habitsManager,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppStateManager>(create: (_) => AppStateManager()),
      ChangeNotifierProvider<SettingsManager>(create: (_) => SettingsManager()),
      ChangeNotifierProvider<FriendsManager>.value(value: friendsManager),
      if (habitsManager != null)
        ChangeNotifierProvider<HabitsManager>.value(value: habitsManager),
      ChangeNotifierProvider<AuthService>(create: (_) => FakeAuthService()),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_buildHabitData(id: 0, title: 'fallback'));
    registerFallbackValue(FakeRealtimeChannel());
  });

  late MockFriendsRepository mockRepository;
  late MockNudgeRepository mockNudgeRepository;

  setUp(() {
    mockRepository = MockFriendsRepository();
    mockNudgeRepository = MockNudgeRepository();
    when(() => mockRepository.currentUserId).thenReturn(_currentUserId);
    when(() => mockRepository.ensureProfileExists()).thenAnswer((_) async {});
    when(() => mockRepository.fetchOwnProfile()).thenAnswer((_) async => null);
    when(() => mockRepository.subscribeToFriendChanges(any(), any()))
        .thenReturn(MockRealtimeChannel());
    when(() => mockRepository.subscribeToInteractionChanges(any(), any()))
        .thenReturn(MockRealtimeChannel());
    when(() => mockRepository.unsubscribe(any())).thenAnswer((_) async {});
  });

  FriendsManager buildManager() {
    return FriendsManager(
      FakeAuthService(),
      repository: mockRepository,
      nudgeRepository: mockNudgeRepository,
    );
  }

  group('FriendsList rendering', () {
    testWidgets('shows friends with mock data', (tester) async {
      when(() => mockRepository.fetchFriends()).thenAnswer((_) async => [
            Friend(profile: FriendProfile(userId: 'u1', username: 'alice')),
            Friend(profile: FriendProfile(userId: 'u2', username: 'bob')),
          ]);
      when(() => mockRepository.fetchPendingRequests()).thenAnswer((_) async => []);

      final manager = buildManager();
      await tester.pumpWidget(_wrap(const FriendsListScreen(), friendsManager: manager));
      await tester.pumpAndSettle();

      expect(find.text('alice'), findsOneWidget);
      expect(find.text('bob'), findsOneWidget);
    });

    testWidgets('shows empty state when there are no friends', (tester) async {
      when(() => mockRepository.fetchFriends()).thenAnswer((_) async => []);
      when(() => mockRepository.fetchPendingRequests()).thenAnswer((_) async => []);

      final manager = buildManager();
      await tester.pumpWidget(_wrap(const FriendsListScreen(), friendsManager: manager));
      await tester.pumpAndSettle();

      expect(find.text('No friends yet'), findsOneWidget);
    });
  });

  group('FriendRequest accept/reject flow', () {
    testWidgets('accepting an incoming request calls respondToRequest(accept: true)',
        (tester) async {
      final incoming = FriendRequest(
        id: 'req-1',
        senderId: 'u1',
        receiverId: _currentUserId,
        status: FriendRequestStatus.pending,
        senderProfile: FriendProfile(userId: 'u1', username: 'alice'),
      );
      when(() => mockRepository.fetchPendingRequests()).thenAnswer((_) async => [incoming]);
      when(() => mockRepository.fetchFriends()).thenAnswer((_) async => []);
      when(() => mockRepository.respondToRequest(any(), accept: any(named: 'accept')))
          .thenAnswer((_) async {});

      final manager = buildManager();
      await tester.pumpWidget(_wrap(const FriendRequestsScreen(), friendsManager: manager));
      await tester.pumpAndSettle();

      expect(find.text('alice'), findsOneWidget);

      await tester.tap(find.byTooltip('Accept'));
      await tester.pumpAndSettle();

      verify(() => mockRepository.respondToRequest('req-1', accept: true)).called(1);
    });

    testWidgets('rejecting an incoming request calls respondToRequest(accept: false)',
        (tester) async {
      final incoming = FriendRequest(
        id: 'req-2',
        senderId: 'u3',
        receiverId: _currentUserId,
        status: FriendRequestStatus.pending,
        senderProfile: FriendProfile(userId: 'u3', username: 'carol'),
      );
      when(() => mockRepository.fetchPendingRequests()).thenAnswer((_) async => [incoming]);
      when(() => mockRepository.fetchFriends()).thenAnswer((_) async => []);
      when(() => mockRepository.respondToRequest(any(), accept: any(named: 'accept')))
          .thenAnswer((_) async {});

      final manager = buildManager();
      await tester.pumpWidget(_wrap(const FriendRequestsScreen(), friendsManager: manager));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Reject'));
      await tester.pumpAndSettle();

      verify(() => mockRepository.respondToRequest('req-2', accept: false)).called(1);
    });
  });

  group('Habit share toggle behavior', () {
    late HabitsManager habitsManager;
    late HabitData habit;

    setUp(() {
      final mockCategoryRepository = MockCategoryRepository();
      when(() => mockCategoryRepository.getAllCategories())
          .thenAnswer((_) async => []);

      habitsManager = HabitsManager(
        habitRepository: MockHabitRepository(),
        eventRepository: MockEventRepository(),
        categoryRepository: mockCategoryRepository,
        backupService: MockBackupService(),
        notificationService: MockNotificationService(),
        uiFeedbackService: MockUIFeedbackService(),
      );
      habit = _buildHabitData(id: 1, title: 'Read 10 pages');

      when(() => mockRepository.fetchFriends()).thenAnswer((_) async => []);
      when(() => mockRepository.fetchPendingRequests()).thenAnswer((_) async => []);
      when(() => mockRepository.cloudHabitIdForLocalId(1))
          .thenAnswer((_) async => 'cloud-uuid-1');
    });

    testWidgets('turning the toggle on shares the habit immediately', (tester) async {
      when(() => mockRepository.isHabitShared('cloud-uuid-1')).thenAnswer((_) async => false);
      when(() => mockRepository.setHabitShared('cloud-uuid-1', true))
          .thenAnswer((_) async {});

      final manager = buildManager();
      await tester.pumpWidget(_wrap(
        EditHabitScreen(habitData: habit),
        friendsManager: manager,
        habitsManager: habitsManager,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Share with friends'), findsOneWidget);
      expect(find.text('Hidden from friends'), findsOneWidget);

      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();

      verify(() => mockRepository.setHabitShared('cloud-uuid-1', true)).called(1);
      expect(find.text('Friends can see this habit\'s streak and progress'), findsOneWidget);
    });

    testWidgets('turning the toggle off hides the habit immediately', (tester) async {
      when(() => mockRepository.isHabitShared('cloud-uuid-1')).thenAnswer((_) async => true);
      when(() => mockRepository.setHabitShared('cloud-uuid-1', false))
          .thenAnswer((_) async {});

      final manager = buildManager();
      await tester.pumpWidget(_wrap(
        EditHabitScreen(habitData: habit),
        friendsManager: manager,
        habitsManager: habitsManager,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Friends can see this habit\'s streak and progress'), findsOneWidget);

      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();

      verify(() => mockRepository.setHabitShared('cloud-uuid-1', false)).called(1);
      expect(find.text('Hidden from friends'), findsOneWidget);
    });
  });

  group('Nudge rate limiting logic', () {
    testWidgets('blocked nudge surfaces the rate-limit message instead of sending twice',
        (tester) async {
      when(() => mockNudgeRepository.sendNudge(
            receiverId: any(named: 'receiverId'),
            habitId: any(named: 'habitId'),
            habitTitle: any(named: 'habitTitle'),
            senderUsername: any(named: 'senderUsername'),
          )).thenThrow(const NudgeRateLimitException());
      when(() => mockRepository.fetchFriends()).thenAnswer((_) async => []);
      when(() => mockRepository.fetchPendingRequests()).thenAnswer((_) async => []);

      final manager = buildManager();
      await tester.pumpWidget(_wrap(
        Scaffold(
          body: NudgeButton(friendId: 'u1', habitId: 'habit-1', habitTitle: 'Run 5k'),
        ),
        friendsManager: manager,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send Nudge'));
      await tester.pumpAndSettle();

      verify(() => mockNudgeRepository.sendNudge(
            receiverId: 'u1',
            habitId: 'habit-1',
            habitTitle: 'Run 5k',
            senderUsername: any(named: 'senderUsername'),
          )).called(1);
      expect(
        find.text('You can only nudge a friend about this habit once per day.'),
        findsOneWidget,
      );
    });

    testWidgets('a successful nudge shows confirmation feedback', (tester) async {
      when(() => mockNudgeRepository.sendNudge(
            receiverId: any(named: 'receiverId'),
            habitId: any(named: 'habitId'),
            habitTitle: any(named: 'habitTitle'),
            senderUsername: any(named: 'senderUsername'),
          )).thenAnswer((_) async {});
      when(() => mockRepository.fetchFriends()).thenAnswer((_) async => []);
      when(() => mockRepository.fetchPendingRequests()).thenAnswer((_) async => []);

      final manager = buildManager();
      await tester.pumpWidget(_wrap(
        Scaffold(
          body: NudgeButton(friendId: 'u1', habitId: 'habit-1', habitTitle: 'Run 5k'),
        ),
        friendsManager: manager,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send Nudge'));
      await tester.pumpAndSettle();

      expect(find.text('Nudge sent!'), findsOneWidget);
    });
  });
}
