import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/entities/quest_calendar_entry.dart';

class InteractiveCalendarGrid extends StatelessWidget {
  final DateTime currentMonth;
  final DateTime selectedDate;
  final DateTime? userJoinedAt;
  final Map<int, List<QuestActivityStatus>> statusMap;
  final Function(DateTime date) onDateSelected;
  final Function(int offset) onMonthChange;

  const InteractiveCalendarGrid({
    super.key,
    required this.currentMonth,
    required this.selectedDate,
    this.userJoinedAt,
    required this.statusMap,
    required this.onDateSelected,
    required this.onMonthChange,
  });

  static const List<String> _weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final year = currentMonth.year;
    final month = currentMonth.month;

    // First day of month (1 = Mon, ..., 7 = Sun)
    final firstDayWeekday = DateTime(year, month, 1).weekday; // 1 to 7
    final daysInMonth = DateTime(year, month + 1, 0).day;

    final totalGridItems = (firstDayWeekday - 1) + daysInMonth;
    final rowCount = (totalGridItems / 7).ceil();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Month navigation bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: AppColors.primary),
                onPressed: () => onMonthChange(-1),
                visualDensity: VisualDensity.compact,
              ),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  Text(
                    '${_monthNames[month - 1]} $year',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                onPressed: () => onMonthChange(1),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Weekday header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _weekDays.map((d) {
              return Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 8),

          // Calendar Days Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rowCount * 7,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - (firstDayWeekday - 2);

              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }

              final cellDate = DateTime(year, month, dayNumber);
              final regDay = userJoinedAt != null
                  ? DateTime(userJoinedAt!.year, userJoinedAt!.month, userJoinedAt!.day)
                  : null;
              final isBeforeRegistration = regDay != null && cellDate.isBefore(regDay);

              final isSelected = cellDate.year == selectedDate.year &&
                  cellDate.month == selectedDate.month &&
                  cellDate.day == selectedDate.day;
              final isToday = cellDate.year == now.year &&
                  cellDate.month == now.month &&
                  cellDate.day == now.day;

              final statuses = isBeforeRegistration ? <QuestActivityStatus>[] : (statusMap[dayNumber] ?? []);
              final hasCompleted = statuses.contains(QuestActivityStatus.completed);
              final hasFailed = statuses.contains(QuestActivityStatus.failed);
              final hasIncomplete = statuses.contains(QuestActivityStatus.incomplete);

              return InkWell(
                onTap: () => onDateSelected(cellDate),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.22)
                        : (isToday ? AppColors.surfaceLight : Colors.transparent),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : (isToday ? AppColors.secondary.withValues(alpha: 0.6) : Colors.transparent),
                      width: isSelected ? 1.8 : 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNumber',
                        style: AppTypography.bodyMedium.copyWith(
                          color: isSelected
                              ? AppColors.primary
                              : (isToday
                                  ? AppColors.secondary
                                  : (isBeforeRegistration
                                      ? AppColors.textMuted.withValues(alpha: 0.35)
                                      : AppColors.textPrimary)),
                          fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),

                      // Status Dots Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (hasCompleted)
                            _buildStatusDot(AppColors.accentSuccess),
                          if (hasFailed)
                            _buildStatusDot(AppColors.accentDanger),
                          if (hasIncomplete)
                            _buildStatusDot(const Color(0xFFF59E0B)),
                          if (!hasCompleted && !hasFailed && !hasIncomplete)
                            const SizedBox(height: 4),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Legend Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(AppColors.accentSuccess, 'Completed'),
              const SizedBox(width: 14),
              _buildLegendItem(const Color(0xFFF59E0B), 'Incomplete'),
              const SizedBox(width: 14),
              _buildLegendItem(AppColors.accentDanger, 'Failed'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDot(Color color) {
    return Container(
      width: 4.5,
      height: 4.5,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textMuted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
