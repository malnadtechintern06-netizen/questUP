import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quest_up/app/router/route_paths.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';
import 'package:quest_up/core/widgets/custom_button.dart';
import 'package:quest_up/core/widgets/empty_state_widget.dart';
import 'package:quest_up/core/widgets/premium_3d_button.dart';
import 'package:quest_up/features/friends/domain/entities/friend_profile.dart';
import 'package:quest_up/features/friends/domain/entities/friend_request.dart';
import 'package:quest_up/features/friends/presentation/providers/friends_providers.dart';
import 'package:quest_up/features/profile/presentation/providers/user_providers.dart';
import 'package:quest_up/features/profile/presentation/widgets/avatar_selector_sheet.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  int _selectedTab = 0; // 0 = Squad, 1 = Add Friend, 2 = Requests
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final friendsState = ref.watch(friendsNotifierProvider);
    final userProfile = ref.watch(userProfileNotifierProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Squad & Explorer Friends',
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Friends',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: () => ref.read(friendsNotifierProvider.notifier).loadFriendsData(),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(friendsNotifierProvider.notifier).loadFriendsData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. My Unique Player Pass Card
              _buildMyPlayerPassCard(userProfile, friendsState.myPlayerTag),

              const SizedBox(height: 16),

              // Feedback Banners
              if (friendsState.errorMessage != null) ...[
                _buildFeedbackBanner(
                  message: friendsState.errorMessage!,
                  isError: true,
                  onDismiss: () => ref.read(friendsNotifierProvider.notifier).clearMessages(),
                ),
                const SizedBox(height: 12),
              ],
              if (friendsState.successMessage != null) ...[
                _buildFeedbackBanner(
                  message: friendsState.successMessage!,
                  isError: false,
                  onDismiss: () => ref.read(friendsNotifierProvider.notifier).clearMessages(),
                ),
                const SizedBox(height: 12),
              ],

              // 2. Segmented 3D Tabs
              _buildSegmentedTabs(friendsState),

              const SizedBox(height: 16),

              // 3. Tab Body
              if (_selectedTab == 0)
                _buildSquadTab(friendsState)
              else if (_selectedTab == 1)
                _buildAddFriendTab(friendsState)
              else
                _buildRequestsTab(friendsState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackBanner({
    required String message,
    required bool isError,
    required VoidCallback onDismiss,
  }) {
    final color = isError ? AppColors.accentDanger : AppColors.accentSuccess;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyMedium.copyWith(color: Colors.white, fontSize: 13),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.close, size: 16, color: Colors.white70),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }

  Widget _buildMyPlayerPassCard(dynamic userProfile, String myTag) {
    final avatarColor = AvatarSelectorSheet.getColorForAvatar(userProfile?.avatarKey ?? 'avatar_1');
    final avatarIcon = AvatarSelectorSheet.getIconForAvatar(userProfile?.avatarKey ?? 'avatar_1');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderBright, width: 1.2),
        gradient: const RadialGradient(
          center: Alignment(-0.6, -0.6),
          radius: 1.2,
          colors: [
            Color(0xFF1E2842),
            Color(0xFF0F1523),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // 3D Avatar
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: avatarColor.withValues(alpha: 0.25),
              border: Border.all(color: avatarColor, width: 2.2),
              boxShadow: [
                BoxShadow(
                  color: avatarColor.withValues(alpha: 0.35),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Icon(avatarIcon, color: avatarColor, size: 30),
            ),
          ),
          const SizedBox(width: 14),

          // Player Tag & Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        userProfile?.name ?? 'Explorer',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'LVL ${userProfile?.level ?? 1}',
                        style: AppTypography.badge.copyWith(color: AppColors.primary, fontSize: 9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Unique Player ID: ',
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                    ),
                    Flexible(
                      child: Text(
                        myTag,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Copy ID Button
          ElevatedButton.icon(
            onPressed: () => _copyToClipboard(myTag, 'Player ID "$myTag" copied to clipboard! 📋'),
            icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.black),
            label: const Text('COPY', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedTabs(FriendsState state) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _buildTabButton(0, 'Squad (${state.friends.length})', Icons.groups_rounded),
          _buildTabButton(1, 'Add Friend', Icons.person_add_rounded),
          _buildTabButton(
            2,
            'Requests',
            Icons.mark_email_unread_rounded,
            badgeCount: state.incomingRequestsCount,
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon, {int badgeCount = 0}) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedTab = index);
          ref.read(friendsNotifierProvider.notifier).clearMessages();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: AppTypography.caption.copyWith(
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: const BoxDecoration(
                    color: AppColors.accentDanger,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: SQUAD / FRIENDS LIST
  // -------------------------------------------------------------
  Widget _buildSquadTab(FriendsState state) {
    if (state.friends.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.group_off_rounded, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              'Your Squad is Empty',
              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Add friends using their unique Player Tag to view their quest history, ranks, and achievements.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'ADD A FRIEND',
              icon: Icons.person_add_rounded,
              onPressed: () => setState(() => _selectedTab = 1),
            ),
          ],
        ),
      );
    }

    return Column(
      children: state.friends.map((friend) => _buildFriendCard(friend)).toList(),
    );
  }

  Widget _buildFriendCard(FriendProfile friend) {
    final avatarColor = AvatarSelectorSheet.getColorForAvatar(friend.avatarKey);
    final avatarIcon = AvatarSelectorSheet.getIconForAvatar(friend.avatarKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderBright, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push(RoutePaths.friendDetailPath(friend.userId)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar with online pulse
                Stack(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: avatarColor.withValues(alpha: 0.2),
                        border: Border.all(color: avatarColor, width: 1.8),
                      ),
                      child: Icon(avatarIcon, color: avatarColor, size: 26),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: friend.isOnline ? AppColors.accentSuccess : AppColors.textMuted,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surface, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              friend.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              'RANK #${friend.rank}',
                              style: AppTypography.badge.copyWith(color: AppColors.secondary, fontSize: 8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            friend.playerTag,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•  LVL ${friend.level}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '•  ${friend.completedQuestsCount} Quests',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: ADD FRIEND BY UNIQUE ID / TAG
  // -------------------------------------------------------------
  Widget _buildAddFriendTab(FriendsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter Player ID or Tag',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                'Search with exact Player Tag (e.g. QST-1001, QST-1002) or Explorer Name.',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),

              // Search Bar with Paste Button
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: AppTypography.bodyMedium.copyWith(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'e.g. QST-1001 or Elena',
                        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.tag_rounded, color: AppColors.primary),
                        filled: true,
                        fillColor: AppColors.surfaceElevated,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                      onSubmitted: (query) =>
                          ref.read(friendsNotifierProvider.notifier).searchPlayer(query),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: state.isSearching
                        ? null
                        : () => ref.read(friendsNotifierProvider.notifier).searchPlayer(_searchController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: state.isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.search_rounded, color: Colors.black, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Searching Loading State
        if (state.isSearching) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
                SizedBox(width: 12),
                Text(
                  'Searching QuestUP player database...',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],

        // Error / Not Found Message
        if (state.errorMessage != null && !state.isSearching) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.accentDanger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accentDanger.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.accentDanger, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    state.errorMessage!,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.accentDanger),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Search Result Preview Card
        if (state.searchResult != null) ...[
          const SizedBox(height: 16),
          Text(
            'Search Result',
            style: AppTypography.badge.copyWith(color: AppColors.primary, fontSize: 11),
          ),
          const SizedBox(height: 8),
          _buildSearchResultCard(state.searchResult!, state),
        ],

        const SizedBox(height: 22),

        // Suggested Explorers to Connect
        if (state.suggestedPlayers.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DISCOVER PLAYERS (REAL IDs)',
                style: AppTypography.badge.copyWith(color: AppColors.secondary, fontSize: 11, letterSpacing: 0.8),
              ),
              Text(
                '${state.suggestedPlayers.length} Active',
                style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Explore real players from the database. Tap their Player Tag to copy or ADD to send a friend request.',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 12),
          ...state.suggestedPlayers.map((player) => _buildSuggestedPlayerCard(player, state)),
        ],
      ],
    );
  }

  Widget _buildSearchResultCard(FriendProfile player, FriendsState state) {
    final avatarColor = AvatarSelectorSheet.getColorForAvatar(player.avatarKey);
    final avatarIcon = AvatarSelectorSheet.getIconForAvatar(player.avatarKey);
    final isAlreadyFriend = state.friends.any((f) => f.userId == player.userId);
    final isPending = state.sentRequests.any((r) => r.receiverId == player.userId || r.receiverTag == player.playerTag);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: avatarColor.withValues(alpha: 0.2),
                  border: Border.all(color: avatarColor, width: 2),
                ),
                child: Icon(avatarIcon, color: avatarColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name,
                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tag: ${player.playerTag}  •  LVL ${player.level}',
                      style: AppTypography.caption.copyWith(color: AppColors.secondary, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${player.completedQuestsCount} Quests Cleared  •  Rank #${player.rank}',
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isAlreadyFriend)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('ALREADY IN YOUR SQUAD', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11)),
            )
          else if (isPending)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('FRIEND REQUEST PENDING ⏳', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 11)),
            )
          else
            Premium3DButton(
              text: 'SEND FRIEND REQUEST',
              icon: Icons.person_add_rounded,
              color: AppColors.primary,
              onPressed: () => ref.read(friendsNotifierProvider.notifier).sendFriendRequest(player.playerTag),
            ),
        ],
      ),
    );
  }

  Widget _buildSuggestedPlayerCard(FriendProfile player, FriendsState state) {
    final avatarColor = AvatarSelectorSheet.getColorForAvatar(player.avatarKey);
    final avatarIcon = AvatarSelectorSheet.getIconForAvatar(player.avatarKey);
    final isAlreadyFriend = state.friends.any((f) => f.userId == player.userId || f.playerTag == player.playerTag);
    final isPending = state.sentRequests.any((r) => r.receiverId == player.userId || r.receiverTag == player.playerTag);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: avatarColor.withValues(alpha: 0.2),
              border: Border.all(color: avatarColor, width: 1.8),
            ),
            child: Icon(avatarIcon, color: avatarColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Clickable Player Tag Chip
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        _searchController.text = player.playerTag;
                        _copyToClipboard(player.playerTag, 'Player ID ${player.playerTag} copied & filled in search! 📋');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.secondary.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              player.playerTag,
                              style: const TextStyle(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(Icons.copy_rounded, size: 10, color: AppColors.secondary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'LVL ${player.level}  •  ${player.completedQuestsCount} Quests  •  Rank #${player.rank}',
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isAlreadyFriend)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'SQUAD ✓',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 10),
              ),
            )
          else if (isPending)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'PENDING ⏳',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 10),
              ),
            )
          else
            ElevatedButton(
              onPressed: state.isLoading
                  ? null
                  : () => ref.read(friendsNotifierProvider.notifier).sendFriendRequest(player.playerTag),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 3,
              ),
              child: const Text(
                'ADD +',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 3: FRIEND REQUESTS VAULT
  // -------------------------------------------------------------
  Widget _buildRequestsTab(FriendsState state) {
    if (state.pendingRequests.isEmpty && state.sentRequests.isEmpty) {
      return Column(
        children: [
          if (state.errorMessage != null) ...[
            _buildFeedbackBanner(
              message: state.errorMessage!,
              isError: true,
              onDismiss: () => ref.read(friendsNotifierProvider.notifier).clearMessages(),
            ),
            const SizedBox(height: 12),
          ],
          if (state.successMessage != null) ...[
            _buildFeedbackBanner(
              message: state.successMessage!,
              isError: false,
              onDismiss: () => ref.read(friendsNotifierProvider.notifier).clearMessages(),
            ),
            const SizedBox(height: 12),
          ],
          const EmptyStateWidget(
            title: 'No Pending Requests',
            description: 'You have no incoming or outgoing friend requests at the moment.',
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.errorMessage != null) ...[
          _buildFeedbackBanner(
            message: state.errorMessage!,
            isError: true,
            onDismiss: () => ref.read(friendsNotifierProvider.notifier).clearMessages(),
          ),
          const SizedBox(height: 12),
        ],
        if (state.successMessage != null) ...[
          _buildFeedbackBanner(
            message: state.successMessage!,
            isError: false,
            onDismiss: () => ref.read(friendsNotifierProvider.notifier).clearMessages(),
          ),
          const SizedBox(height: 12),
        ],
        if (state.pendingRequests.isNotEmpty) ...[
          Text(
            'INCOMING SQUAD INVITATIONS (${state.pendingRequests.length})',
            style: AppTypography.badge.copyWith(color: AppColors.primary, fontSize: 11),
          ),
          const SizedBox(height: 10),
          ...state.pendingRequests.map((req) => _buildIncomingRequestCard(req, state)),
          const SizedBox(height: 20),
        ],
        if (state.sentRequests.isNotEmpty) ...[
          Text(
            'SENT REQUESTS (${state.sentRequests.length})',
            style: AppTypography.badge.copyWith(color: AppColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 10),
          ...state.sentRequests.map((req) => _buildSentRequestCard(req)),
        ],
      ],
    );
  }

  Widget _buildIncomingRequestCard(FriendRequest req, FriendsState state) {
    final avatarColor = AvatarSelectorSheet.getColorForAvatar(req.senderAvatarKey);
    final avatarIcon = AvatarSelectorSheet.getIconForAvatar(req.senderAvatarKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: avatarColor.withValues(alpha: 0.2),
                  border: Border.all(color: avatarColor, width: 1.5),
                ),
                child: Icon(avatarIcon, color: avatarColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.senderName,
                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      'Tag: ${req.senderTag}  •  LVL ${req.senderLevel}',
                      style: AppTypography.caption.copyWith(color: AppColors.secondary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: state.isLoading
                      ? null
                      : () => ref.read(friendsNotifierProvider.notifier).rejectFriendRequest(req.id),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.accentDanger),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('DECLINE', style: TextStyle(color: AppColors.accentDanger, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: state.isLoading
                      ? null
                      : () => ref.read(friendsNotifierProvider.notifier).acceptFriendRequest(req.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentSuccess,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: state.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Text('ACCEPT', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSentRequestCard(FriendRequest req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.outgoing_mail, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Request sent to ${req.receiverTag}',
              style: AppTypography.bodyMedium.copyWith(fontSize: 13),
            ),
          ),
          Text(
            'Pending...',
            style: AppTypography.caption.copyWith(color: AppColors.secondary, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
