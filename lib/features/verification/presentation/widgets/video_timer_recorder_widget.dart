import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';
import 'package:quest_up/core/services/camera_service.dart';

enum TimerState {
  initial,
  running,
  paused,
  completed,
}

class VideoTimerRecorderWidget extends StatefulWidget {
  final int requiredDurationSeconds; // e.g. 600 for 10 minutes
  final bool requiresVideoProof;
  final ICameraService cameraService;
  final Function(int actualDurationSeconds, String? videoProofPath, bool isSatisfied) onSessionUpdated;

  const VideoTimerRecorderWidget({
    super.key,
    required this.requiredDurationSeconds,
    this.requiresVideoProof = false,
    required this.cameraService,
    required this.onSessionUpdated,
  });

  @override
  State<VideoTimerRecorderWidget> createState() => _VideoTimerRecorderWidgetState();
}

class _VideoTimerRecorderWidgetState extends State<VideoTimerRecorderWidget> {
  Timer? _timer;
  int _elapsedSeconds = 0;
  TimerState _timerState = TimerState.initial;
  String? _capturedVideoPath;
  String? _statusFeedback;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _timerState = TimerState.running;
      _statusFeedback = null;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
      });

      final isSatisfied = _elapsedSeconds >= widget.requiredDurationSeconds;
      if (isSatisfied && _timerState == TimerState.running) {
        _statusFeedback = '🎉 Required duration reached (${_formatTime(widget.requiredDurationSeconds)})!';
      }

      widget.onSessionUpdated(_elapsedSeconds, _capturedVideoPath, isSatisfied);
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _timerState = TimerState.paused;
    });
  }

  void _resumeTimer() {
    _startTimer();
  }

  void _stopAndValidate() {
    _timer?.cancel();
    final isSatisfied = _elapsedSeconds >= widget.requiredDurationSeconds;

    setState(() {
      _timerState = TimerState.completed;
      if (isSatisfied) {
        _statusFeedback = '✅ Completed: ${_formatTime(_elapsedSeconds)} activity session verified.';
      } else {
        final remaining = widget.requiredDurationSeconds - _elapsedSeconds;
        _statusFeedback = '❌ Incomplete: Need ${_formatTime(remaining)} more to complete the required ${_formatTime(widget.requiredDurationSeconds)}.';
      }
    });

    widget.onSessionUpdated(_elapsedSeconds, _capturedVideoPath, isSatisfied);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _elapsedSeconds = 0;
      _timerState = TimerState.initial;
      _statusFeedback = null;
    });
    widget.onSessionUpdated(0, _capturedVideoPath, false);
  }

  Future<void> _recordVideo() async {
    final videoPath = await widget.cameraService.recordVideo(
      maxDuration: Duration(seconds: widget.requiredDurationSeconds + 60),
    );

    if (videoPath != null) {
      setState(() {
        _capturedVideoPath = videoPath;
      });
      final isSatisfied = _elapsedSeconds >= widget.requiredDurationSeconds;
      widget.onSessionUpdated(_elapsedSeconds, videoPath, isSatisfied);
    }
  }

  String _formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final targetSec = widget.requiredDurationSeconds > 0 ? widget.requiredDurationSeconds : 600;
    final progress = (_elapsedSeconds / targetSec).clamp(0.0, 1.0);
    final isSatisfied = _elapsedSeconds >= targetSec;

    return Container(
      padding: const EdgeInsets.all(20),
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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      widget.requiresVideoProof ? Icons.videocam_rounded : Icons.timer_rounded,
                      color: isSatisfied ? AppColors.accentSuccess : AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.requiresVideoProof ? 'Timed Video Verification' : 'Activity Timer',
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
                  color: isSatisfied
                      ? AppColors.accentSuccess.withValues(alpha: 0.15)
                      : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSatisfied ? AppColors.accentSuccess : AppColors.border,
                  ),
                ),
                child: Text(
                  'Target: ${_formatTime(targetSec)}',
                  style: AppTypography.caption.copyWith(
                    color: isSatisfied ? AppColors.accentSuccess : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Digital Timer Display & Circular Ring
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isSatisfied ? AppColors.accentSuccess : AppColors.primary,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(_elapsedSeconds),
                    style: AppTypography.displayMedium.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      color: isSatisfied ? AppColors.accentSuccess : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isSatisfied
                        ? 'COMPLETED'
                        : (_timerState == TimerState.running ? 'IN PROGRESS' : 'READY'),
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSatisfied ? AppColors.accentSuccess : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Timer Controls
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              if (_timerState == TimerState.initial)
                ElevatedButton.icon(
                  onPressed: _startTimer,
                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.black),
                  label: const Text('START TIMER', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )
              else if (_timerState == TimerState.running) ...[
                OutlinedButton.icon(
                  onPressed: _pauseTimer,
                  icon: const Icon(Icons.pause_rounded, color: AppColors.secondary),
                  label: const Text('PAUSE', style: TextStyle(color: AppColors.secondary)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.secondary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _stopAndValidate,
                  icon: const Icon(Icons.stop_rounded, color: Colors.white),
                  label: const Text('STOP & CHECK'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSatisfied ? AppColors.accentSuccess : AppColors.accentDanger,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ] else if (_timerState == TimerState.paused) ...[
                ElevatedButton.icon(
                  onPressed: _resumeTimer,
                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.black),
                  label: const Text('RESUME', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _stopAndValidate,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('STOP & CHECK'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ] else if (_timerState == TimerState.completed) ...[
                OutlinedButton.icon(
                  onPressed: _resetTimer,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('RESTART'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ],
          ),

          // Optional Video Recording Button if requested
          if (widget.requiresVideoProof) ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: _recordVideo,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _capturedVideoPath != null ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _capturedVideoPath != null ? Icons.videocam_rounded : Icons.video_camera_back_outlined,
                      color: _capturedVideoPath != null ? AppColors.primary : AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _capturedVideoPath != null ? 'Video Proof Attached' : 'Record Activity Video Proof',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          color: _capturedVideoPath != null ? AppColors.primary : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Feedback message banner
          if (_statusFeedback != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSatisfied
                    ? AppColors.accentSuccess.withValues(alpha: 0.15)
                    : AppColors.accentDanger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSatisfied ? AppColors.accentSuccess : AppColors.accentDanger,
                ),
              ),
              child: Text(
                _statusFeedback!,
                style: AppTypography.bodyMedium.copyWith(
                  color: isSatisfied ? AppColors.accentSuccess : AppColors.accentDanger,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
