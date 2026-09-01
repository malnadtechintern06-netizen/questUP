import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';
import 'package:quest_up/core/utils/distance_calculator.dart';

class WalkingDistanceTrackerWidget extends StatefulWidget {
  final double requiredDistanceMeters; // e.g. 1000 for 1.0 km
  final Function(double actualDistanceMeters, bool isSatisfied) onWalkingUpdated;

  const WalkingDistanceTrackerWidget({
    super.key,
    required this.requiredDistanceMeters,
    required this.onWalkingUpdated,
  });

  @override
  State<WalkingDistanceTrackerWidget> createState() => _WalkingDistanceTrackerWidgetState();
}

class _WalkingDistanceTrackerWidgetState extends State<WalkingDistanceTrackerWidget> {
  StreamSubscription<Position>? _positionSubscription;
  Timer? _elapsedTimer;

  Position? _lastPosition;
  double _accumulatedDistanceMeters = 0.0;
  int _elapsedSeconds = 0;
  bool _isTracking = false;
  String? _statusMessage;

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  void _startTracking() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      setState(() {
        _statusMessage = 'GPS permission is required to track walking distance.';
      });
      return;
    }

    setState(() {
      _isTracking = true;
      _statusMessage = null;
    });

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsedSeconds++;
      });
    });

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3, // Trigger every 3 meters
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      if (_lastPosition != null) {
        final distanceDelta = DistanceCalculator.calculateDistanceMeters(
          lat1: _lastPosition!.latitude,
          lon1: _lastPosition!.longitude,
          lat2: position.latitude,
          lon2: position.longitude,
        );

        // Anti-teleport jump filtering: ignore delta if speed > 30 m/s (108 km/h)
        if (distanceDelta > 0.5 && distanceDelta < 150) {
          setState(() {
            _accumulatedDistanceMeters += distanceDelta;
          });

          final isSatisfied = _accumulatedDistanceMeters >= widget.requiredDistanceMeters;
          widget.onWalkingUpdated(_accumulatedDistanceMeters, isSatisfied);
        }
      }
      _lastPosition = position;
    }, onError: (e) {
      setState(() {
        _statusMessage = 'GPS Stream note: $e';
      });
    });
  }

  void _stopTracking() {
    _positionSubscription?.cancel();
    _elapsedTimer?.cancel();
    setState(() {
      _isTracking = false;
    });
    final isSatisfied = _accumulatedDistanceMeters >= widget.requiredDistanceMeters;
    widget.onWalkingUpdated(_accumulatedDistanceMeters, isSatisfied);
  }

  void _resetTracking() {
    _stopTracking();
    setState(() {
      _accumulatedDistanceMeters = 0.0;
      _elapsedSeconds = 0;
      _lastPosition = null;
      _statusMessage = null;
    });
    widget.onWalkingUpdated(0.0, false);
  }

  String _formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.requiredDistanceMeters > 0 ? widget.requiredDistanceMeters : 1000.0;
    final progress = (_accumulatedDistanceMeters / target).clamp(0.0, 1.0);
    final isSatisfied = _accumulatedDistanceMeters >= target;

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
                      Icons.directions_walk_rounded,
                      color: isSatisfied ? AppColors.accentSuccess : AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'GPS Walking Tracker',
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
                  'Goal: ${DistanceCalculator.formatDistance(target)}',
                  style: AppTypography.caption.copyWith(
                    color: isSatisfied ? AppColors.accentSuccess : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Distance Numbers Banner
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      DistanceCalculator.formatDistance(_accumulatedDistanceMeters),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.displayMedium.copyWith(
                        color: isSatisfied ? AppColors.accentSuccess : AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                      ),
                    ),
                    Text('DISTANCE WALKED', style: AppTypography.caption.copyWith(fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: AppColors.divider),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _formatTime(_elapsedSeconds),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.displayMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 26,
                      ),
                    ),
                    Text('ELAPSED TIME', style: AppTypography.caption.copyWith(fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                isSatisfied ? AppColors.accentSuccess : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toInt()}% completed',
                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
              ),
              if (isSatisfied)
                Text(
                  'Goal Reached! ✅',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.accentSuccess,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else
                Flexible(
                  child: Text(
                    '${DistanceCalculator.formatDistance(target - _accumulatedDistanceMeters)} remaining',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Action Controls
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              if (!_isTracking)
                ElevatedButton.icon(
                  onPressed: _startTracking,
                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.black),
                  label: const Text('START WALKING TRACKER', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )
              else ...[
                ElevatedButton.icon(
                  onPressed: _stopTracking,
                  icon: const Icon(Icons.pause_rounded, color: Colors.black),
                  label: const Text('PAUSE / FINISH', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSatisfied ? AppColors.accentSuccess : AppColors.secondary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
              if (_accumulatedDistanceMeters > 0 && !_isTracking) ...[
                OutlinedButton.icon(
                  onPressed: _resetTracking,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('RESET'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ],
          ),

          if (_statusMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _statusMessage!,
              style: AppTypography.caption.copyWith(color: AppColors.accentDanger),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
