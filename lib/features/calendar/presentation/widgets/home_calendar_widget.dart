import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quest_up/app/router/route_paths.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';
import 'package:quest_up/features/calendar/domain/entities/quest_calendar_entry.dart';
import 'package:quest_up/features/calendar/presentation/providers/quest_calendar_providers.dart';

class HomeCalendarWidget extends ConsumerWidget {
  const HomeCalendarWidget({super.key});

  static const List<String> _weekDayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarState = ref.watch(questCalendarNotifierProvider);
    final now = DateTime.now();

    // Compute the 7 days of current week (Monday through Sunday)
    final currentWeekday = now.weekday; // 1 = Monday, 7 = Sunday
    final monday = now.subtract(Duration(days: currentWeekday - 1));
    final weekDays = List.generate(7, (i) => monday.add(Duration(days: i)));

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => context.push(RoutePaths.calendar),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.secondary.withValues(alpha: 0.2),
                            AppColors.primary.withValues(alpha: 0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.secondary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        color: AppColors.secondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Quest Activity Calendar',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Daily tracking for quests',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Full View',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 9,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // 7-Day Interactive Weekday Strip
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: weekDays.map((date) {
                      final isToday = date.year == now.year &&
                          date.month == now.month &&
                          date.day == now.day;
                      final isSelected = date.year == calendarState.selectedDate.year &&
                          date.month == calendarState.selectedDate.month &&
                          date.day == calendarState.selectedDate.day;

                      // Status dots for this date if in currentMonth
                      List<QuestActivityStatus> dayStatuses = [];
                      if (date.month == calendarState.currentMonth.month &&
                          date.year == calendarState.currentMonth.year) {
                        dayStatuses = calendarState.monthStatusMap[date.day] ?? [];
                      }

                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            ref.read(questCalendarNotifierProvider.notifier).selectDate(date);
                            context.push(RoutePaths.calendar);
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.25)
                                  : (isToday
                                      ? AppColors.surface
                                      : Colors.transparent),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isToday
                                        ? AppColors.secondary.withValues(alpha: 0.6)
                                        : Colors.transparent),
                                width: isSelected || isToday ? 1.5 : 1.0,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _weekDayLabels[date.weekday - 1],
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 10,
                                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                    color: isToday ? AppColors.secondary : AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${date.day}',
                                  maxLines: 1,
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: isSelected
                                        ? AppColors.primary
                                        : (isToday ? AppColors.secondary : AppColors.textPrimary),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                // Dots indicator row
                                SizedBox(
                                  height: 5,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (dayStatuses.contains(QuestActivityStatus.completed))
                                        _buildMiniDot(AppColors.accentSuccess),
                                      if (dayStatuses.contains(QuestActivityStatus.incomplete))
                                        _buildMiniDot(const Color(0xFFF59E0B)),
                                      if (dayStatuses.contains(QuestActivityStatus.failed))
                                        _buildMiniDot(AppColors.accentDanger),
                                      if (dayStatuses.isEmpty)
                                        const SizedBox(width: 3, height: 3),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 12),

                // Today's Stats Breakdown Chips
                Row(
                  children: [
                    Expanded(
                      child: _buildStatusStatPill(
                        label: 'Completed',
                        count: calendarState.dailyCompletedCount,
                        color: AppColors.accentSuccess,
                        icon: Icons.check_circle_rounded,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildStatusStatPill(
                        label: 'Incomplete',
                        count: calendarState.dailyIncompleteCount,
                        color: const Color(0xFFF59E0B),
                        icon: Icons.schedule_rounded,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildStatusStatPill(
                        label: 'Failed',
                        count: calendarState.dailyFailedCount,
                        color: AppColors.accentDanger,
                        icon: Icons.cancel_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniDot(Color color) {
    return Container(
      width: 3.5,
      height: 3.5,
      margin: const EdgeInsets.symmetric(horizontal: 0.8),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildStatusStatPill({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$count $label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 10.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
