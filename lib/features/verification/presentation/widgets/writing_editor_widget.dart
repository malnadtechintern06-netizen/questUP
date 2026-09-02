import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';

class WritingEditorWidget extends StatefulWidget {
  final int requiredWords;
  final int requiredLines;
  final String promptHint;
  final Function(String text, int wordCount, bool isSatisfied) onTextChanged;
  final Function(String text, int wordCount, bool isSatisfied, bool isAuthentic, int pastedChars)? onDetailedTextChanged;
  final bool enableAntiCheat;

  const WritingEditorWidget({
    super.key,
    this.requiredWords = 50,
    this.requiredLines = 0,
    this.promptHint = 'Start writing your response here...',
    required this.onTextChanged,
    this.onDetailedTextChanged,
    this.enableAntiCheat = true,
  });

  @override
  State<WritingEditorWidget> createState() => _WritingEditorWidgetState();
}

class _WritingEditorWidgetState extends State<WritingEditorWidget> {
  final TextEditingController _controller = TextEditingController();
  int _wordCount = 0;
  int _lineCount = 0;

  // Anti-Cheat and Originality Tracking
  String _previousText = '';
  int _keystrokeCount = 0;
  int _pastedCharactersCount = 0;
  bool _isPastedDetected = false;
  int _activeTypingSeconds = 0;
  Timer? _activeTypingTimer;
  DateTime? _lastTypingTimestamp;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChangedListener);
  }

  @override
  void dispose() {
    _activeTypingTimer?.cancel();
    _controller.removeListener(_onTextChangedListener);
    _controller.dispose();
    super.dispose();
  }

  void _startTypingTimerIfNeeded() {
    _lastTypingTimestamp = DateTime.now();
    if (_activeTypingTimer == null || !_activeTypingTimer!.isActive) {
      _activeTypingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_lastTypingTimestamp != null &&
            DateTime.now().difference(_lastTypingTimestamp!).inSeconds < 4) {
          setState(() {
            _activeTypingSeconds++;
          });
        }
      });
    }
  }

  void _onTextChangedListener() {
    final currentText = _controller.text;
    final text = currentText.trim();
    final words = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final lines = text.isEmpty ? 0 : text.split('\n').length;

    // Detect large bursts inserted in a single event (> 20 characters added in one go)
    final charDelta = currentText.length - _previousText.length;
    if (widget.enableAntiCheat) {
      _startTypingTimerIfNeeded();

      if (charDelta > 0) {
        if (charDelta > 20 && _previousText.isNotEmpty) {
          // Large burst insertion detected: flagged as copy-paste from external app (e.g. ChatGPT)
          _isPastedDetected = true;
          _pastedCharactersCount += charDelta;
        } else {
          _keystrokeCount += charDelta;
        }
      } else if (currentText.isEmpty) {
        // Reset cheat flag on clear
        _isPastedDetected = false;
        _pastedCharactersCount = 0;
        _keystrokeCount = 0;
      }
    }

    _previousText = currentText;

    final isAuthentic = !_isPastedDetected && _pastedCharactersCount <= 10;
    final isSatisfied = (widget.requiredWords == 0 || words >= widget.requiredWords) &&
        (widget.requiredLines == 0 || lines >= widget.requiredLines) &&
        isAuthentic;

    setState(() {
      _wordCount = words;
      _lineCount = lines;
    });

    widget.onTextChanged(text, words, isSatisfied);
    widget.onDetailedTextChanged?.call(text, words, isSatisfied, isAuthentic, _pastedCharactersCount);
  }

  void _clearAndReset() {
    _controller.clear();
    setState(() {
      _isPastedDetected = false;
      _pastedCharactersCount = 0;
      _keystrokeCount = 0;
      _activeTypingSeconds = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.requiredWords > 0
        ? (_wordCount / widget.requiredWords).clamp(0.0, 1.0)
        : 1.0;
    final isWordTargetMet = widget.requiredWords == 0 || _wordCount >= widget.requiredWords;
    final isAuthentic = !_isPastedDetected && _pastedCharactersCount <= 10;
    final isSatisfied = isWordTargetMet && isAuthentic;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isPastedDetected
              ? AppColors.accentDanger
              : (isSatisfied ? AppColors.accentSuccess : AppColors.border),
          width: (_isPastedDetected || isSatisfied) ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar with Word Count Meter & Anti-Cheat Shield Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            _isPastedDetected
                                ? Icons.warning_amber_rounded
                                : (isSatisfied ? Icons.check_circle_rounded : Icons.edit_note_rounded),
                            color: _isPastedDetected
                                ? AppColors.accentDanger
                                : (isSatisfied ? AppColors.accentSuccess : AppColors.primary),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Word Counter',
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
                        color: _isPastedDetected
                            ? AppColors.accentDanger.withValues(alpha: 0.15)
                            : (isSatisfied
                                ? AppColors.accentSuccess.withValues(alpha: 0.15)
                                : AppColors.surface),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _isPastedDetected
                              ? AppColors.accentDanger
                              : (isSatisfied ? AppColors.accentSuccess : AppColors.border),
                        ),
                      ),
                      child: Text(
                        '$_wordCount / ${widget.requiredWords} words',
                        style: AppTypography.caption.copyWith(
                          color: _isPastedDetected
                              ? AppColors.accentDanger
                              : (isSatisfied ? AppColors.accentSuccess : AppColors.textPrimary),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isPastedDetected
                          ? AppColors.accentDanger
                          : (isSatisfied ? AppColors.accentSuccess : AppColors.primary),
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),

          // Anti-Cheat Warning Banner if pasted content is detected
          if (_isPastedDetected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentDanger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accentDanger.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: AppColors.accentDanger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Anti-Cheat Security Alert: Copy-Paste Detected',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.accentDanger,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pasting text generated from ChatGPT, notes, or web sources is not permitted. Please type your submission directly in the editor to verify originality and earn quest rewards.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: _clearAndReset,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accentDanger,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Clear & Type Authentically',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Multi-line Text Field
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _controller,
              maxLines: 8,
              minLines: 5,
              style: AppTypography.bodyLarge.copyWith(height: 1.5),
              decoration: InputDecoration(
                hintText: widget.promptHint,
                hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          // Anti-Cheat Status & Live Typing Telemetry Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: AppColors.surfaceElevated,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Icon(
                  _isPastedDetected
                      ? Icons.lock_clock_rounded
                      : Icons.verified_user_rounded,
                  size: 14,
                  color: _isPastedDetected ? AppColors.accentDanger : AppColors.accentSuccess,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _isPastedDetected
                        ? 'External Paste Detected (Blocked)'
                        : 'Authentic Live Typing Verified',
                    style: AppTypography.caption.copyWith(
                      color: _isPastedDetected ? AppColors.accentDanger : AppColors.accentSuccess,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (_activeTypingSeconds > 0)
                  Text(
                    '⏱️ ${_activeTypingSeconds}s active',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),

          // Footer Info Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Lines: $_lineCount | Chars: ${_controller.text.length} | Keystrokes: $_keystrokeCount',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(width: 8),
                if (_isPastedDetected)
                  Text(
                    'Paste Blocked',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.accentDanger,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else if (isSatisfied)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check, size: 14, color: AppColors.accentSuccess),
                      const SizedBox(width: 4),
                      Text(
                        'Requirement Met',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.accentSuccess,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    '${widget.requiredWords - _wordCount} words left',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
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
