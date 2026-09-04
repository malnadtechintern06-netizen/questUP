import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quest_up/app/config/app_constants.dart';
import 'package:quest_up/app/router/route_paths.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';
import 'package:quest_up/core/widgets/premium_3d_button.dart';
import 'package:quest_up/features/auth/presentation/providers/auth_providers.dart';
import 'package:quest_up/features/profile/presentation/providers/user_providers.dart';
import 'package:quest_up/features/quests/presentation/providers/quest_providers.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String? email;

  const OtpVerificationScreen({
    super.key,
    this.email,
  });

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  static const int _otpLength = 6;
  static const int _resendCooldownSeconds = 60;

  final List<TextEditingController> _controllers =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_otpLength, (_) => FocusNode());

  Timer? _timer;
  int _secondsRemaining = _resendCooldownSeconds;
  bool _canResend = false;
  String? _debugPreviewCode;

  String get _targetEmail {
    final authState = ref.read(authNotifierProvider);
    return widget.email ?? authState.pendingOtpEmail ?? '';
  }

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _loadDebugOtpPreview();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() {
      _secondsRemaining = _resendCooldownSeconds;
      _canResend = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
          _canResend = true;
        });
      }
    });
  }

  Future<void> _loadDebugOtpPreview() async {
    if (!kDebugMode) return;
    try {
      final storage = ref.read(localStorageServiceProvider);
      final raw = await storage.getJson(AppConstants.keyPendingOtps);
      if (raw is Map<String, dynamic> && raw.containsKey(_targetEmail)) {
        final record = raw[_targetEmail];
        if (record is Map<String, dynamic>) {
          setState(() {
            _debugPreviewCode = record['otp_code'] as String?;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String _getCombinedOtp() {
    return _controllers.map((c) => c.text.trim()).join();
  }

  void _onOtpDigitChanged(int index, String value) {
    if (value.length > 1) {
      // User pasted multiple characters
      final digits = value.replaceAll(RegExp(r'\D'), '');
      if (digits.isNotEmpty) {
        for (int i = 0; i < _otpLength; i++) {
          if (i < digits.length) {
            _controllers[i].text = digits[i];
          }
        }
        final nextIndex = digits.length < _otpLength ? digits.length : _otpLength - 1;
        _focusNodes[nextIndex].requestFocus();

        if (digits.length >= _otpLength) {
          _handleVerify();
        }
      }
      return;
    }

    if (value.isNotEmpty) {
      if (index < _otpLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        if (_getCombinedOtp().length == _otpLength) {
          _handleVerify();
        }
      }
    }
  }

  void _onOtpKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  Future<void> _handleVerify() async {
    if (ref.read(authNotifierProvider).isLoading) return;
    final otp = _getCombinedOtp();
    if (otp.length != _otpLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the full 6-digit code.'),
          backgroundColor: AppColors.accentDanger,
        ),
      );
      return;
    }

    final success = await ref.read(authNotifierProvider.notifier).verifyOtp(
          email: _targetEmail,
          otp: otp,
        );

    if (success && mounted) {
      final isLocationReady =
          await ref.read(locationServiceProvider).isLocationEnabledAndPermitted();

      if (!mounted) return;

      if (isLocationReady) {
        context.go(RoutePaths.home);
      } else {
        context.go(RoutePaths.locationPermission);
      }
    }
  }

  Future<void> _handleResend() async {
    if (!_canResend) return;

    final success = await ref
        .read(authNotifierProvider.notifier)
        .resendOtp(email: _targetEmail);

    if (success && mounted) {
      _startResendTimer();
      _loadDebugOtpPreview();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A fresh verification code has been sent to your email!'),
          backgroundColor: AppColors.secondary,
        ),
      );
    }
  }

  void _quickFillOtp(String code) {
    if (code.length != _otpLength) return;
    for (int i = 0; i < _otpLength; i++) {
      _controllers[i].text = code[i];
    }
    _handleVerify();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
          onPressed: () {
            ref.read(authNotifierProvider.notifier).clearError();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RoutePaths.login);
            }
          },
        ),
        title: Text(
          'Security Verification',
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              // Glowing Shield Emblem
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.primary, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mark_email_read_rounded,
                  color: AppColors.primary,
                  size: 44,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Enter Verification Code',
                style: AppTypography.displayMedium.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Description with highlighted email
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(text: 'We sent a 6-digit security OTP to\n'),
                    TextSpan(
                      text: _targetEmail.isNotEmpty ? _targetEmail : 'your email address',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Error Banner (if any)
              if (authState.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.accentDanger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accentDanger.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.accentDanger, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          authState.errorMessage!,
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.close, size: 16, color: Colors.white70),
                        onPressed: () => ref.read(authNotifierProvider.notifier).clearError(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
              ],

              // 6-Pin Input Boxes Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_otpLength, (index) {
                  return _buildOtpDigitBox(index);
                }),
              ),
              const SizedBox(height: 24),

              // Resend Timer & Button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive the code? ",
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  if (_canResend)
                    TextButton(
                      onPressed: authState.isResendingOtp ? null : _handleResend,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: authState.isResendingOtp
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : Text(
                              'Resend Code',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                    )
                  else
                    Text(
                      'Resend in ${_secondsRemaining}s',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),

              // Verify & Login Button
              Premium3DButton(
                text: authState.isLoading ? 'VERIFYING...' : 'VERIFY & ENTER QUESTUP',
                icon: Icons.verified_user_rounded,
                isLoading: authState.isLoading,
                width: double.infinity,
                onPressed: authState.isLoading ? null : _handleVerify,
              ),
              const SizedBox(height: 18),

              // Change Email / Back to Login
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    ref.read(authNotifierProvider.notifier).clearError();
                    context.go(RoutePaths.login);
                  },
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18, color: AppColors.textMuted),
                  label: Text(
                    'Wrong email? Switch account',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                  ),
                ),
              ),

              // Debug / Dev Preview Badge (visible in debug mode for test ease)
              if (kDebugMode && _debugPreviewCode != null) ...[
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bug_report_rounded, color: Colors.amber, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Dev OTP: $_debugPreviewCode',
                        style: AppTypography.caption.copyWith(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: () => _quickFillOtp(_debugPreviewCode!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Auto-Fill',
                            style: AppTypography.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpDigitBox(int index) {
    return SizedBox(
      width: 48,
      height: 58,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) => _onOtpKeyEvent(index, event),
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: AppTypography.gameNumber.copyWith(
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
            fontSize: 22,
          ),
          inputFormatters: [
            LengthLimitingTextInputFormatter(6),
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            filled: true,
            fillColor: AppColors.surface,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 2.2),
            ),
          ),
          onChanged: (value) => _onOtpDigitChanged(index, value),
        ),
      ),
    );
  }
}
