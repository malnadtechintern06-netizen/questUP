import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';

class InAppGameTrackerWidget extends StatefulWidget {
  final int targetPlayTimeSeconds;
  final Function(int playTimeSeconds, int moves, bool isSatisfied) onGameSessionUpdated;

  const InAppGameTrackerWidget({
    super.key,
    this.targetPlayTimeSeconds = 300, // 5 mins
    required this.onGameSessionUpdated,
  });

  @override
  State<InAppGameTrackerWidget> createState() => _InAppGameTrackerWidgetState();
}

class _InAppGameTrackerWidgetState extends State<InAppGameTrackerWidget> {
  Timer? _gameTimer;
  int _playSeconds = 0;
  int _moves = 0;
  int _matchedPairs = 0;

  // Simple memory card puzzle grid
  late List<String> _cards;
  late List<bool> _revealed;
  int? _firstSelectedIndex;
  bool _isProcessing = false;

  final List<String> _symbols = const ['🏛️', '🌿', '🧭', '⭐', '🔥', '🛡️'];

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  void _initGame() {
    final list = [..._symbols, ..._symbols]..shuffle();
    _cards = list;
    _revealed = List.filled(list.length, false);
    _firstSelectedIndex = null;
    _matchedPairs = 0;
    _moves = 0;
    _isProcessing = false;

    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _playSeconds++;
      });
      final isSatisfied = _playSeconds >= widget.targetPlayTimeSeconds || _matchedPairs == _symbols.length;
      widget.onGameSessionUpdated(_playSeconds, _moves, isSatisfied);
    });
  }

  void _onCardTap(int index) {
    if (_isProcessing || _revealed[index] || _firstSelectedIndex == index) return;

    setState(() {
      _revealed[index] = true;
    });

    if (_firstSelectedIndex == null) {
      _firstSelectedIndex = index;
    } else {
      _moves++;
      _isProcessing = true;
      final firstIdx = _firstSelectedIndex!;

      if (_cards[firstIdx] == _cards[index]) {
        // Matched!
        _matchedPairs++;
        _firstSelectedIndex = null;
        _isProcessing = false;

        final isSatisfied = _playSeconds >= widget.targetPlayTimeSeconds || _matchedPairs == _symbols.length;
        widget.onGameSessionUpdated(_playSeconds, _moves, isSatisfied);
      } else {
        // Mismatch - hide back after short delay
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) {
            setState(() {
              _revealed[firstIdx] = false;
              _revealed[index] = false;
              _firstSelectedIndex = null;
              _isProcessing = false;
            });
          }
        });
      }
    }
  }

  String _formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isSatisfied = _playSeconds >= widget.targetPlayTimeSeconds || _matchedPairs == _symbols.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSatisfied ? AppColors.accentSuccess : AppColors.border,
          width: isSatisfied ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.sports_esports_rounded, color: AppColors.accentXp, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Quest Match Puzzle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSatisfied ? AppColors.accentSuccess.withValues(alpha: 0.15) : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isSatisfied ? AppColors.accentSuccess : AppColors.border),
                ),
                child: Text(
                  'Time: ${_formatTime(_playSeconds)}',
                  style: AppTypography.caption.copyWith(
                    color: isSatisfied ? AppColors.accentSuccess : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Flexible(child: Text('Pairs: $_matchedPairs/${_symbols.length}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption)),
              Flexible(child: Text('Moves: $_moves', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption)),
              Flexible(child: Text('Goal: ${_formatTime(widget.targetPlayTimeSeconds)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption.copyWith(color: AppColors.primary))),
            ],
          ),
          const SizedBox(height: 14),

          // Puzzle Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _cards.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              final isShown = _revealed[index];
              return InkWell(
                onTap: () => _onCardTap(index),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isShown ? AppColors.surfaceLight : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isShown ? AppColors.primary : AppColors.border,
                      width: isShown ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      isShown ? _cards[index] : '❓',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          if (isSatisfied)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accentSuccess.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accentSuccess),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.accentSuccess, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Gameplay Requirement Verified! Ready to complete.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.accentSuccess,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
