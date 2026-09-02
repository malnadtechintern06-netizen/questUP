import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quest_up/app/config/app_constants.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';

abstract class IAppExternalService {
  Future<bool> openPrivacyPolicy({BuildContext? context});
  Future<bool> openRateUs({BuildContext? context});
  Future<bool> shareQuestUp({BuildContext? context});
}

class AppExternalService implements IAppExternalService {
  const AppExternalService();

  @override
  Future<bool> openPrivacyPolicy({BuildContext? context}) async {
    try {
      final uri = Uri.parse(AppConstants.privacyPolicyUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context != null && context.mounted) {
        _showErrorSnackBar(context, 'Unable to open Privacy Policy.');
      }
      return launched;
    } catch (e) {
      dev.log('[EXTERNAL] Error opening Privacy Policy: $e', name: 'AppExternalService');
      if (context != null && context.mounted) {
        _showErrorSnackBar(context, 'Unable to open Privacy Policy.');
      }
      return false;
    }
  }

  @override
  Future<bool> openRateUs({BuildContext? context}) async {
    try {
      // 1. First attempt to open direct Google Play Store market intent
      final marketUri = Uri.parse(AppConstants.playStoreMarketUri);
      bool launched = false;
      try {
        launched = await launchUrl(
          marketUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        launched = false;
      }

      // 2. Fallback to HTTPS Google Play Store Web URL
      if (!launched) {
        final webUri = Uri.parse(AppConstants.playStoreWebUrl);
        launched = await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
      }

      if (!launched && context != null && context.mounted) {
        _showErrorSnackBar(context, 'Unable to open Google Play Store listing.');
      }
      return launched;
    } catch (e) {
      dev.log('[EXTERNAL] Error opening Rate Us: $e', name: 'AppExternalService');
      if (context != null && context.mounted) {
        _showErrorSnackBar(context, 'Unable to open Google Play Store listing.');
      }
      return false;
    }
  }

  @override
  Future<bool> shareQuestUp({BuildContext? context}) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: AppConstants.shareMessage,
          subject: AppConstants.shareSubject,
        ),
      );

      return result.status == ShareResultStatus.success || result.status == ShareResultStatus.dismissed;
    } catch (e) {
      dev.log('[EXTERNAL] Error opening Share Sheet: $e', name: 'AppExternalService');
      if (context != null && context.mounted) {
        _showErrorSnackBar(context, 'Unable to open share sheet.');
      }
      return false;
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodyMedium.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.accentDanger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
