import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quest_up/features/friends/data/datasources/friends_local_datasource.dart';
import 'package:quest_up/features/friends/data/datasources/friends_remote_datasource.dart';
import 'package:quest_up/features/friends/data/repositories/friends_repository_impl.dart';
import 'package:quest_up/features/friends/domain/entities/friend_profile.dart';
import 'package:quest_up/features/friends/domain/entities/friend_request.dart';
import 'package:quest_up/features/friends/domain/repositories/friends_repository.dart';
import 'package:quest_up/features/profile/presentation/providers/user_providers.dart';

// Data Source & Repo Providers
final friendsLocalDataSourceProvider = Provider<IFriendsLocalDataSource>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return FriendsLocalDataSource(storage);
});

final friendsRemoteDataSourceProvider = Provider<IFriendsRemoteDataSource>((ref) {
  return FriendsRemoteDataSource();
});

final friendsRepositoryProvider = Provider<IFriendsRepository>((ref) {
  final localDataSource = ref.watch(friendsLocalDataSourceProvider);
  final remoteDataSource = ref.watch(friendsRemoteDataSourceProvider);
  final userRepo = ref.watch(userRepositoryProvider);
  return FriendsRepositoryImpl(
    localDataSource: localDataSource,
    remoteDataSource: remoteDataSource,
    userRepository: userRepo,
  );
});

class FriendsState {
  final String myPlayerTag;
  final List<FriendProfile> friends;
  final List<FriendRequest> pendingRequests;
  final List<FriendRequest> sentRequests;
  final List<FriendProfile> suggestedPlayers;
  final FriendProfile? selectedFriend;
  final FriendProfile? searchResult;
  final bool isLoading;
  final bool isSearching;
  final String? errorMessage;
  final String? successMessage;

  const FriendsState({
    this.myPlayerTag = 'QST-0000',
    this.friends = const [],
    this.pendingRequests = const [],
    this.sentRequests = const [],
    this.suggestedPlayers = const [],
    this.selectedFriend,
    this.searchResult,
    this.isLoading = false,
    this.isSearching = false,
    this.errorMessage,
    this.successMessage,
  });

  int get incomingRequestsCount => pendingRequests.length;

  FriendsState copyWith({
    String? myPlayerTag,
    List<FriendProfile>? friends,
    List<FriendRequest>? pendingRequests,
    List<FriendRequest>? sentRequests,
    List<FriendProfile>? suggestedPlayers,
    FriendProfile? selectedFriend,
    FriendProfile? searchResult,
    bool clearSearchResult = false,
    bool? isLoading,
    bool? isSearching,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return FriendsState(
      myPlayerTag: myPlayerTag ?? this.myPlayerTag,
      friends: friends ?? this.friends,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      sentRequests: sentRequests ?? this.sentRequests,
      suggestedPlayers: suggestedPlayers ?? this.suggestedPlayers,
      selectedFriend: selectedFriend ?? this.selectedFriend,
      searchResult: clearSearchResult ? null : (searchResult ?? this.searchResult),
      isLoading: isLoading ?? this.isLoading,
      isSearching: isSearching ?? this.isSearching,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }
}

class FriendsNotifier extends StateNotifier<FriendsState> {
  final IFriendsRepository _repository;

  FriendsNotifier(this._repository) : super(const FriendsState()) {
    loadFriendsData();
  }

  Future<void> loadFriendsData() async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      final tag = await _repository.getMyPlayerTag();
      final friends = await _repository.getFriends();
      final incoming = await _repository.getPendingIncomingRequests();
      final sent = await _repository.getSentRequests();
      final suggested = await _repository.getSuggestedPlayers();

      state = state.copyWith(
        myPlayerTag: tag,
        friends: friends,
        pendingRequests: incoming,
        sentRequests: sent,
        suggestedPlayers: suggested,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('AppException: ', ''),
      );
    }
  }

  Future<void> searchPlayer(String query) async {
    final clean = query.replaceAll('#', '').trim();
    if (clean.isEmpty) {
      state = state.copyWith(clearSearchResult: true, isSearching: false, clearMessages: true);
      return;
    }

    state = state.copyWith(isSearching: true, clearSearchResult: true, clearMessages: true);
    try {
      final match = await _repository.searchPlayer(clean);
      state = state.copyWith(
        searchResult: match,
        isSearching: false,
        errorMessage: match == null ? 'No player found matching "$query".' : null,
      );
    } catch (e) {
      state = state.copyWith(
        isSearching: false,
        errorMessage: e.toString().replaceFirst('AppException: ', ''),
      );
    }
  }

  Future<bool> sendFriendRequest(String targetPlayerTagOrId) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      await _repository.sendFriendRequest(targetPlayerTagOrId: targetPlayerTagOrId);
      final sent = await _repository.getSentRequests();
      final suggested = await _repository.getSuggestedPlayers();

      state = state.copyWith(
        isLoading: false,
        sentRequests: sent,
        suggestedPlayers: suggested,
        clearSearchResult: true,
        successMessage: 'Friend request sent successfully! 🚀',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('AppException: ', ''),
      );
      return false;
    }
  }

  Future<void> acceptFriendRequest(String requestId) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      await _repository.acceptFriendRequest(requestId);
      final friends = await _repository.getFriends();
      final incoming = await _repository.getPendingIncomingRequests();
      final suggested = await _repository.getSuggestedPlayers();

      state = state.copyWith(
        isLoading: false,
        friends: friends,
        pendingRequests: incoming,
        suggestedPlayers: suggested,
        successMessage: 'Friend request accepted! Squad expanded. 🎉',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('AppException: ', ''),
      );
    }
  }

  Future<void> rejectFriendRequest(String requestId) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      await _repository.rejectFriendRequest(requestId);
      final incoming = await _repository.getPendingIncomingRequests();

      state = state.copyWith(
        isLoading: false,
        pendingRequests: incoming,
        successMessage: 'Friend request declined.',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('AppException: ', ''),
      );
    }
  }

  Future<void> removeFriend(String friendUserId) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      await _repository.removeFriend(friendUserId);
      final friends = await _repository.getFriends();
      final suggested = await _repository.getSuggestedPlayers();

      state = state.copyWith(
        isLoading: false,
        friends: friends,
        suggestedPlayers: suggested,
        successMessage: 'Friend removed from squad.',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('AppException: ', ''),
      );
    }
  }

  Future<FriendProfile?> loadFriendDetail(String friendUserId) async {
    try {
      final profile = await _repository.getFriendProfile(friendUserId);
      if (profile != null) {
        state = state.copyWith(selectedFriend: profile);
      }
      return profile;
    } catch (e) {
      return null;
    }
  }

  void clearMessages() {
    state = state.copyWith(clearMessages: true);
  }
}

final friendsNotifierProvider =
    StateNotifierProvider<FriendsNotifier, FriendsState>((ref) {
  final repo = ref.watch(friendsRepositoryProvider);
  return FriendsNotifier(repo);
});

final pendingFriendRequestsCountProvider = Provider<int>((ref) {
  final state = ref.watch(friendsNotifierProvider);
  return state.incomingRequestsCount;
});
