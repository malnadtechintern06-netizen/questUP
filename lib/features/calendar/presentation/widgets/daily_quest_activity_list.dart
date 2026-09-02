import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/entities/quest_calendar_entry.dart';

class DailyQuestActivityList extends StatefulWidget {
  final DateTime selectedDate;
  final List<QuestCalendarEntry> entries;

  const DailyQuestActivityList({
    super.key,
    required this.selectedDate,
    required this.entries,
  });

  @override
  State<DailyQuestActivityList> createState() => _DailyQuestActivityListState();
}

class _DailyQuestActivityListState extends State<DailyQuestActivityList> {
  int _selectedFilterIndex = 0; // 0 = All, 1 = Completed, 2 = Incomplete, 3 = Failed

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const List<String> _dayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'landmark':
        return Icons.account_balance_rounded;
      case 'nature':
      case 'outdoors':
        return Icons.park_rounded;
      case 'fitness':
        return Icons.directions_run_rounded;
      case 'culture':
      case 'writing':
        return Icons.palette_rounded;
      case 'mystery':
        return Icons.psychology_rounded;
      default:
        return Icons.explore_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.selectedDate;
    final dayOfWeek = _dayNames[date.weekday - 1];
    final monthName = _monthNames[date.month - 1];
    final formattedDate = '$dayOfWeek, $monthName ${date.day}, ${date.year}';

    final completed = widget.entries.where((e) => e.isCompleted).toList();
    final incomplete = widget.entries.where((e) => e.isIncomplete).toList();
    final failed = widget.entries.where((e) => e.isFailed).toList();

    List<QuestCalendarEntry> displayedEntries;
    switch (_selectedFilterIndex) {
      case 1:
        displayedEntries = completed;
        break;
      case 2:
        displayedEntries = incomplete;
        break;
      case 3:
        displayedEntries = failed;
        break;
      default:
        displayedEntries = widget.entries;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date Header & Daily Summary Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      formattedDate,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '${widget.entries.length} Quests',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Status Summary Badges
              Row(
                children: [
                  _buildDailyStatBadge(
                    icon: Icons.check_circle_rounded,
                    count: completed.length,
                    label: 'Completed',
                    color: AppColors.accentSuccess,
                  ),
                  const SizedBox(width: 8),
                  _buildDailyStatBadge(
                    icon: Icons.pending_rounded,
                    count: incomplete.length,
                    label: 'Incomplete',
                    color: const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 8),
                  _buildDailyStatBadge(
                    icon: Icons.cancel_rounded,
                    count: failed.length,
                    label: 'Failed',
                    color: AppColors.accentDanger,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Filter Pills Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildFilterPill(0, 'All (${widget.entries.length})', AppColors.primary),
              const SizedBox(width: 8),
              _buildFilterPill(1, '🟢 Completed (${completed.length})', AppColors.accentSuccess),
              const SizedBox(width: 8),
              _buildFilterPill(2, '🟡 Incomplete (${incomplete.length})', const Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              _buildFilterPill(3, '🔴 Failed (${failed.length})', AppColors.accentDanger),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Quest Activity Cards List
        if (displayedEntries.isEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.event_note_rounded, size: 40, color: AppColors.textMuted),
                  const SizedBox(height: 8),
                  Text(
                    'No Quests in this Category',
                    style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No quest entries recorded for this day matching the filter.',
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          )
        else
          ...displayedEntries.map((entry) => _buildQuestEntryCard(context, entry)),
      ],
    );
  }

  Widget _buildDailyStatBadge({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                '$count $label',
                style: AppTypography.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(int index, String label, Color activeColor) {
    final isSelected = _selectedFilterIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedFilterIndex = index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.2) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isSelected ? activeColor : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildQuestEntryCard(BuildContext context, QuestCalendarEntry entry) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (entry.isCompleted) {
      statusColor = AppColors.accentSuccess;
      statusLabel = 'COMPLETED';
      statusIcon = Icons.check_circle_rounded;
    } else if (entry.isFailed) {
      statusColor = AppColors.accentDanger;
      statusLabel = 'FAILED';
      statusIcon = Icons.cancel_rounded;
    } else {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'INCOMPLETE';
      statusIcon = Icons.pending_rounded;
    }

    final categoryIcon = _getCategoryIcon(entry.category);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Category Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(categoryIcon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),

              // Title & Category
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.questTitle,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          entry.category,
                          style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                        ),
                        const SizedBox(width: 6),
                        Text('•', style: AppTypography.caption.copyWith(color: AppColors.border)),
                        const SizedBox(width: 6),
                        Text(
                          '+${entry.xpReward} XP',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: AppTypography.caption.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Failure Reason Banner (if failed)
          if (entry.isFailed && entry.failureReason != null && entry.failureReason!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accentDanger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accentDanger.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.accentDanger),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Reason: ${entry.failureReason}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.accentDanger,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 8),

          // Action Button Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}',
                style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 10),
              ),
              if (entry.isFailed)
                InkWell(
                  onTap: () {
                    context.push(RoutePaths.questDetailPath(entry.questId));
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.accentDanger.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accentDanger.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.replay_rounded, size: 12, color: AppColors.accentDanger),
                        const SizedBox(width: 4),
                        Text(
                          'RETRY QUEST',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.accentDanger,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (entry.isIncomplete)
                InkWell(
                  onTap: () {
                    context.push(RoutePaths.questDetailPath(entry.questId));
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow_rounded, size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'START QUEST',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on_rounded, size: 12, color: AppColors.secondary),
                    const SizedBox(width: 3),
                    Text(
                      '+${entry.coinReward} Coins Claimed',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
