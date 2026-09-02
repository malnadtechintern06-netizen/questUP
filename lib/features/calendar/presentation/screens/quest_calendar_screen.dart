import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../providers/quest_calendar_providers.dart';
import '../widgets/daily_quest_activity_list.dart';
import '../widgets/interactive_calendar_grid.dart';

class QuestCalendarScreen extends ConsumerWidget {
  const QuestCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarState = ref.watch(questCalendarNotifierProvider);
    final notifier = ref.read(questCalendarNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quest Activity Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today_rounded),
            tooltip: 'Jump to Today',
            onPressed: () => notifier.selectDate(DateTime.now()),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Calendar',
            onPressed: () => notifier.loadCalendarData(),
          ),
        ],
      ),
      body: calendarState.error != null
          ? ErrorStateWidget(
              message: calendarState.error!,
              onRetry: () => notifier.loadCalendarData(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Banner: Explorer Calendar Progress
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1F1C36),
                          AppColors.surface,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(alpha: 0.18),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                          ),
                          child: const Icon(
                            Icons.calendar_month_rounded,
                            color: AppColors.primary,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Activity Timeline', style: AppTypography.titleMedium),
                              const SizedBox(height: 3),
                              Text(
                                'Track your completed, incomplete, and failed missions on any day.',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Interactive Month Calendar Grid
                  InteractiveCalendarGrid(
                    currentMonth: calendarState.currentMonth,
                    selectedDate: calendarState.selectedDate,
                    statusMap: calendarState.monthStatusMap,
                    onDateSelected: (date) => notifier.selectDate(date),
                    onMonthChange: (offset) => notifier.changeMonth(offset),
                  ),

                  // Loading or Daily List
                  if (calendarState.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      child: QuestCardShimmer(),
                    )
                  else
                    DailyQuestActivityList(
                      selectedDate: calendarState.selectedDate,
                      entries: calendarState.selectedDateEntries,
                    ),
                ],
              ),
            ),
    );
  }
}
