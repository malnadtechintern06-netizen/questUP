import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quest_up/app/theme/app_theme.dart';
import 'package:quest_up/features/auth/presentation/screens/login_screen.dart';
import 'package:quest_up/features/auth/presentation/screens/register_screen.dart';
import 'package:quest_up/features/auth/presentation/screens/welcome_screen.dart';
import 'package:quest_up/features/calendar/presentation/screens/quest_calendar_screen.dart';
import 'package:quest_up/features/calendar/presentation/widgets/home_calendar_widget.dart';
import 'package:quest_up/features/location_permission/presentation/screens/location_permission_screen.dart';
import 'package:quest_up/features/profile/domain/entities/user_profile.dart';
import 'package:quest_up/features/profile/domain/repositories/user_repository.dart';
import 'package:quest_up/features/profile/domain/usecases/get_user_profile_usecase.dart';
import 'package:quest_up/features/profile/domain/usecases/update_user_profile_usecase.dart';
import 'package:quest_up/features/profile/presentation/providers/user_providers.dart';
import 'package:quest_up/features/profile/presentation/screens/profile_screen.dart';
import 'package:quest_up/features/profile/presentation/widgets/avatar_selector_sheet.dart';
import 'package:quest_up/features/quests/domain/entities/quest.dart';
import 'package:quest_up/features/quests/presentation/widgets/google_maps_marker_card_widget.dart';
import 'package:quest_up/features/verification/presentation/widgets/drawing_canvas_widget.dart';
import 'package:quest_up/features/verification/presentation/widgets/writing_editor_widget.dart';
import 'package:quest_up/features/friends/presentation/screens/friends_screen.dart';
import 'package:quest_up/features/friends/presentation/screens/friend_detail_screen.dart';
import 'package:quest_up/features/friends/presentation/providers/friends_providers.dart';
import 'package:quest_up/features/friends/domain/entities/friend_profile.dart';
import 'package:quest_up/features/friends/domain/entities/friend_request.dart';


void main() {
  testWidgets('WelcomeScreen renders logo, tagline, and CTA buttons', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const ProviderScope(
          child: WelcomeScreen(),
        ),
      ),
    );

    expect(find.text('QuestUP'), findsOneWidget);
    expect(find.text('Turn the Real World Into a Game'), findsOneWidget);
    expect(find.text('GET STARTED'), findsOneWidget);
    expect(find.text('I HAVE AN ACCOUNT - LOGIN'), findsOneWidget);
  });

  testWidgets('LoginScreen renders email, password fields and login button', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const ProviderScope(
          child: LoginScreen(),
        ),
      ),
    );

    expect(find.text('Welcome Back, Explorer'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('LOGIN TO QUESTUP'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
  });

  testWidgets('RegisterScreen renders all input fields and register button', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const ProviderScope(
          child: RegisterScreen(),
        ),
      ),
    );

    expect(find.text('Join QuestUP'), findsOneWidget);
    expect(find.text('Explorer Name'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
    expect(find.text('CREATE ACCOUNT & EXPLORE'), findsOneWidget);
  });

  testWidgets('LocationPermissionScreen renders explanation and buttons', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const ProviderScope(
          child: LocationPermissionScreen(),
        ),
      ),
    );

    expect(find.text('📍 Enable Location'), findsOneWidget);
    expect(find.text('ALLOW LOCATION'), findsOneWidget);
    expect(find.text('Maybe Later'), findsOneWidget);
  });

  testWidgets('WritingEditorWidget counts words and enforces targets in real-time', (WidgetTester tester) async {
    int lastWordCount = 0;
    bool isMet = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: WritingEditorWidget(
            requiredWords: 5,
            promptHint: 'Write here',
            onTextChanged: (text, words, satisfied) {
              lastWordCount = words;
              isMet = satisfied;
            },
          ),
        ),
      ),
    );

    expect(find.text('Word Counter'), findsOneWidget);
    expect(find.text('0 / 5 words'), findsOneWidget);

    // Enter 3 words
    await tester.enterText(find.byType(TextField), 'Hello world explorer');
    await tester.pump();

    expect(lastWordCount, equals(3));
    expect(isMet, isFalse);
    expect(find.text('3 / 5 words'), findsOneWidget);

    // Enter 5 words
    await tester.enterText(find.byType(TextField), 'Hello world explorer quest up');
    await tester.pump();

    expect(lastWordCount, equals(5));
    expect(isMet, isTrue);
    expect(find.text('Requirement Met'), findsOneWidget);
  });

  testWidgets('DrawingCanvasWidget renders stroke tools, undo, redo, and clear', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: DrawingCanvasWidget(
            title: 'Sketch Landmark',
            onDrawingReady: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Canvas: 0 Strokes'), findsOneWidget);
    expect(find.byIcon(Icons.brush_rounded), findsOneWidget);
    expect(find.byIcon(Icons.undo_rounded), findsOneWidget);
    expect(find.byIcon(Icons.redo_rounded), findsOneWidget);
    expect(find.text('Eraser'), findsOneWidget);
  });

  testWidgets('GoogleMapsMarkerCardWidget renders Google Maps pinpoint marker and coordinates', (WidgetTester tester) async {
    const testQuest = Quest(
      id: 'q_bus_stand',
      title: 'Visit Hosanagara Bus Station',
      description: 'Find the central bus station',
      storyline: 'Transit hub',
      category: QuestCategory.landmark,
      difficulty: QuestDifficulty.easy,
      latitude: 13.9182,
      longitude: 75.0682,
      locationName: 'Hosanagara Bus Station',
      radiusMeters: 100,
      xpReward: 50,
      coinReward: 25,
      requiredLevel: 1,
      placeCategory: 'bus_station',
      requirements: [],
      iconKey: 'landmark',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: GoogleMapsMarkerCardWidget(
            quest: testQuest,
            height: 100,
          ),
        ),
      ),
    );

    expect(find.text('13.9182°, 75.0682°'), findsOneWidget);
    expect(find.byIcon(Icons.directions_bus_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });


  testWidgets('AvatarSelectorSheet renders without overflowing', (WidgetTester tester) async {
    String selected = 'avatar_ranger';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: AvatarSelectorSheet(
            selectedKey: selected,
            onSelect: (key) => selected = key,
          ),
        ),
      ),
    );

    expect(find.text('Choose Your Persona Avatar'), findsOneWidget);
    expect(find.text('Forest Ranger'), findsOneWidget);
    expect(find.text('Cyber Knight'), findsOneWidget);
    expect(find.text('Mystic Sage'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('QuestCalendarScreen renders calendar grid, month switcher, and stats cards', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const ProviderScope(
          child: QuestCalendarScreen(),
        ),
      ),
    );

    expect(find.text('Quest Activity Calendar'), findsOneWidget);
    expect(find.text('Activity Timeline'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Incomplete'), findsWidgets);
    expect(find.text('Failed'), findsWidgets);
  });

  testWidgets('HomeCalendarWidget renders on reader/home screen with week strip and stats pills', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: ProviderScope(
            child: SingleChildScrollView(
              child: HomeCalendarWidget(),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Quest Activity Calendar'), findsOneWidget);
    expect(find.text('Daily tracking for quests'), findsOneWidget);
    expect(find.text('Full View'), findsOneWidget);
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Sun'), findsOneWidget);
    expect(find.textContaining('Completed'), findsOneWidget);
    expect(find.textContaining('Incomplete'), findsOneWidget);
    expect(find.textContaining('Failed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ProfileScreen renders ABOUT & SUPPORT with Privacy Policy, Rate Us, and Share QuestUP', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockProfile = UserProfile(
      id: 'test_user',
      name: 'Test Explorer',
      email: 'test@questup.com',
      avatarKey: 'avatar_ranger',
      level: 1,
      currentXp: 100,
      xpToNextLevel: 500,
      coins: 50,
      completedQuestIds: const [],
      earnedBadgeIds: const [],
      joinedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: ProviderScope(
          overrides: [
            userProfileNotifierProvider.overrideWith((ref) => FakeUserProfileNotifier(mockProfile)),
          ],
          child: const ProfileScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Explorer Profile'), findsOneWidget);
    expect(find.text('ABOUT & SUPPORT'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Learn how QuestUP handles your data'), findsOneWidget);
    expect(find.text('Rate Us'), findsOneWidget);
    expect(find.text('Enjoying QuestUP? Rate the app'), findsOneWidget);
    expect(find.text('Share QuestUP'), findsOneWidget);
    expect(find.text('Invite friends to join your quests'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
    expect(find.text('Log out of your QuestUP account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('FriendsScreen renders unique Player Tag, tabs, and friends cards', (WidgetTester tester) async {
    final mockFriend = FriendProfile(
      userId: 'comp_1',
      playerTag: 'QST-1001',
      name: 'Elena Shadowstride',
      avatarKey: 'avatar_mystic_sage',
      level: 6,
      currentXp: 3850,
      coins: 1950,
      rank: 1,
      rankTitle: 'Apex Mythic Explorer',
      completedQuestsCount: 18,
      gamesPlayedCount: 19,
      completedQuests: [
        FriendCompletedQuestSummary(
          questId: 'quest_fortress_1',
          title: 'Fortress Citadel Bastion Ascent',
          category: 'Historical Landmark',
          xpEarned: 350,
          coinsEarned: 180,
          completedAt: DateTime.now(),
          locationName: 'Ancient Hilltop Citadel',
        ),
      ],

      earnedBadges: const [
        FriendBadgeSummary(
          badgeId: 'badge_immortal_mythic',
          title: 'Immortal Mythic Legend',
          tier: 'Mythic',
          iconKey: 'badge_immortal_mythic',
          isHardcore: true,
        ),
      ],
      friendshipDate: DateTime.now(),
      isOnline: true,
      lastActiveText: 'Exploring Live Radar',
    );

    final mockRequest = FriendRequest(
      id: 'req_1',
      senderId: 'comp_2',
      senderName: 'Kai Horizon',
      senderTag: 'QST-1002',
      senderAvatarKey: 'avatar_sky_pilot',
      senderLevel: 5,
      receiverId: 'user_1',
      receiverTag: 'QST-7842',
      status: FriendRequestStatus.pending,
      createdAt: DateTime.now(),
    );

    final mockProfile = UserProfile(
      id: 'user_1',
      name: 'Alex Explorer',
      email: 'alex@questup.com',
      avatarKey: 'avatar_cyber_knight',
      level: 3,
      currentXp: 200,
      xpToNextLevel: 500,
      coins: 50,
      completedQuestIds: const [],
      earnedBadgeIds: const [],
      joinedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: ProviderScope(
          overrides: [
            userProfileNotifierProvider.overrideWith((ref) => FakeUserProfileNotifier(mockProfile)),
            friendsNotifierProvider.overrideWith(
              (ref) => FakeFriendsNotifier(
                FriendsState(
                  myPlayerTag: 'QST-7842',
                  friends: [mockFriend],
                  pendingRequests: [mockRequest],
                  suggestedPlayers: const [],
                ),
              ),
            ),
          ],
          child: const FriendsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Squad & Explorer Friends'), findsOneWidget);
    expect(find.text('QST-7842'), findsOneWidget);
    expect(find.text('COPY'), findsOneWidget);
    expect(find.text('Elena Shadowstride'), findsOneWidget);
    expect(find.text('RANK #1'), findsOneWidget);
    expect(find.text('Add Friend'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('FriendDetailScreen renders metrics, quest history, and earned badges', (WidgetTester tester) async {
    final mockFriend = FriendProfile(
      userId: 'comp_1',
      playerTag: 'QST-1001',
      name: 'Elena Shadowstride',
      avatarKey: 'avatar_mystic_sage',
      level: 6,
      currentXp: 3850,
      coins: 1950,
      rank: 1,
      rankTitle: 'Apex Mythic Explorer',
      completedQuestsCount: 18,
      gamesPlayedCount: 19,
      completedQuests: [
        FriendCompletedQuestSummary(
          questId: 'quest_fortress_1',
          title: 'Fortress Citadel Bastion Ascent',
          category: 'Historical Landmark',
          xpEarned: 350,
          coinsEarned: 180,
          completedAt: DateTime.now(),
          locationName: 'Ancient Hilltop Citadel',
        ),
      ],
      earnedBadges: const [
        FriendBadgeSummary(
          badgeId: 'badge_immortal_mythic',
          title: 'Immortal Mythic Legend',
          tier: 'Mythic',
          iconKey: 'badge_immortal_mythic',
          isHardcore: true,
        ),
      ],
      friendshipDate: DateTime.now(),
      isOnline: true,
      lastActiveText: 'Active on Radar',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: ProviderScope(
          overrides: [
            friendsNotifierProvider.overrideWith(
              (ref) => FakeFriendsNotifier(
                FriendsState(selectedFriend: mockFriend),
                friendToReturn: mockFriend,
              ),
            ),
          ],
          child: const FriendDetailScreen(friendUserId: 'comp_1'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Friend Game Profile'), findsOneWidget);
    expect(find.text('Elena Shadowstride'), findsOneWidget);
    expect(find.text('Unique ID: QST-1001'), findsOneWidget);
    expect(find.text('Quests Cleared'), findsOneWidget);
    expect(find.text('Current Rank'), findsOneWidget);
    expect(find.text('Total XP Score'), findsOneWidget);
    expect(find.text('Badges Earned'), findsOneWidget);
    expect(find.text('Fortress Citadel Bastion Ascent'), findsOneWidget);
    expect(find.text('Immortal Mythic Legend'), findsOneWidget);
    expect(find.text('CHALLENGE FRIEND ON RADAR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class FakeFriendsNotifier extends StateNotifier<FriendsState> implements FriendsNotifier {
  final FriendProfile? friendToReturn;
  FakeFriendsNotifier(super.state, {this.friendToReturn});

  @override
  Future<void> loadFriendsData() async {}
  @override
  Future<void> searchPlayer(String query) async {}
  @override
  Future<bool> sendFriendRequest(String targetPlayerTagOrId) async => true;
  @override
  Future<void> acceptFriendRequest(String requestId) async {}
  @override
  Future<void> rejectFriendRequest(String requestId) async {}
  @override
  Future<void> removeFriend(String friendUserId) async {}
  @override
  Future<FriendProfile?> loadFriendDetail(String friendUserId) async {
    return friendToReturn ?? state.selectedFriend;
  }
  @override
  void clearMessages() {}
}


class FakeUserProfileNotifier extends UserProfileNotifier {
  FakeUserProfileNotifier(UserProfile profile)
      : super(
          GetUserProfileUseCase(_MockSimpleUserRepo(profile)),
          UpdateUserProfileUseCase(_MockSimpleUserRepo(profile)),
          _MockSimpleUserRepo(profile),
        ) {
    state = AsyncValue.data(profile);
  }

  @override
  Future<void> loadProfile() async {}
}

class _MockSimpleUserRepo implements UserRepository {
  final UserProfile profile;
  _MockSimpleUserRepo(this.profile);
  @override
  Future<UserProfile> getUserProfile() async => profile;
  @override
  Future<void> saveUserProfile(UserProfile profile) async {}
  @override
  Future<UserProfile> addXpAndCoins({required int xp, required int coins, String? completedQuestId}) async => profile;
  @override
  Future<UserProfile> unlockBadge(String badgeId) async => profile;
}
