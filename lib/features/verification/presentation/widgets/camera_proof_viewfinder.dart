import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';

class CameraProofViewfinder extends StatelessWidget {
  final String? photoPath;
  final bool requiresFreshPhoto;
  final String? requiredObject;
  final String? requiredPlace;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickGallery;
  final VoidCallback onClear;

  const CameraProofViewfinder({
    super.key,
    required this.photoPath,
    this.requiresFreshPhoto = false,
    this.requiredObject,
    this.requiredPlace,
    required this.onTakePhoto,
    required this.onPickGallery,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoPath != null && photoPath!.isNotEmpty;
    final subject = requiredObject ?? requiredPlace ?? 'Waypoint';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasPhoto ? AppColors.primary : AppColors.border,
          width: hasPhoto ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Camera Proof: $subject',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium,
                ),
              ),
              if (hasPhoto) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.refresh, size: 16, color: AppColors.accentDanger),
                  label: Text('Retake', style: AppTypography.caption.copyWith(color: AppColors.accentDanger)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),

          if (requiresFreshPhoto)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Live In-App Capture Required (Gallery disabled for freshness)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (hasPhoto)
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.photo_camera_back_rounded, size: 48, color: AppColors.primary),
                      const SizedBox(height: 10),
                      Text(
                        'Photo Proof Attached',
                        style: AppTypography.titleMedium.copyWith(color: AppColors.primary),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          photoPath!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption,
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check, size: 14, color: Colors.black),
                          const SizedBox(width: 4),
                          Text(
                            'READY',
                            style: AppTypography.caption.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (requiresFreshPhoto)
            // Fresh photo only: single prominent in-app camera capture button
            InkWell(
              onTap: onTakePhoto,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.camera_alt_rounded, color: AppColors.primary, size: 40),
                    const SizedBox(height: 10),
                    Text(
                      'Open In-App Quest Camera',
                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Snap a live photo of $subject',
                      style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            )
          else
            // Standard photo proof: allows camera or gallery
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onTakePhoto,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.camera_alt_rounded, color: AppColors.primary, size: 32),
                          const SizedBox(height: 8),
                          Text('Open Camera', style: AppTypography.bodyMedium),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: onPickGallery,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.photo_library_rounded, color: AppColors.accentLocation, size: 32),
                          const SizedBox(height: 8),
                          Text('Photo Gallery', style: AppTypography.bodyMedium),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
