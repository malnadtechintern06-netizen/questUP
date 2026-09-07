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
  int _characterCount = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChangedListener);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChangedListener);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChangedListener() {
    final currentText = _controller.text;
    final text = currentText.trim();
    final words = text.isEmpty
        ? 0
        : text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final lines = text.isEmpty ? 0 : currentText.split('\n').length;
    final chars = currentText.length;

    final isSatisfied = (widget.requiredWords <= 0 || words >= widget.requiredWords) &&
        (widget.requiredLines <= 0 || lines >= widget.requiredLines) &&
        text.isNotEmpty;

    setState(() {
      _wordCount = words;
      _lineCount = lines;
      _characterCount = chars;
    });

    widget.onTextChanged(text, words, isSatisfied);
    widget.onDetailedTextChanged?.call(text, words, isSatisfied, true, 0);
  }

  void _clearText() {
    _controller.clear();
    setState(() {
      _wordCount = 0;
      _lineCount = 0;
      _characterCount = 0;
    });
    widget.onTextChanged('', 0, false);
    widget.onDetailedTextChanged?.call('', 0, false, true, 0);
  }

  @override
  Widget build(BuildContext context) {
    final targetWords = widget.requiredWords > 0 ? widget.requiredWords : 1;
    final progress = widget.requiredWords > 0
        ? (_wordCount / targetWords).clamp(0.0, 1.0)
        : (_wordCount > 0 ? 1.0 : 0.0);
    final isSatisfied = (widget.requiredWords <= 0 || _wordCount >= widget.requiredWords) &&
        (widget.requiredLines <= 0 || _lineCount >= widget.requiredLines) &&
        _controller.text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSatisfied ? AppColors.accentSuccess : AppColors.borderBright,
          width: isSatisfied ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isSatisfied
                ? AppColors.accentSuccess.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar with Word Count Meter & Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              border: const Border(bottom: BorderSide(color: AppColors.border)),
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
                            isSatisfied ? Icons.check_circle_rounded : Icons.edit_note_rounded,
                            color: isSatisfied ? AppColors.accentSuccess : AppColors.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Word Counter',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleMedium.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSatisfied
                            ? AppColors.accentSuccess.withValues(alpha: 0.18)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSatisfied ? AppColors.accentSuccess : AppColors.border,
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        '$_wordCount / ${widget.requiredWords} words',
                        style: AppTypography.caption.copyWith(
                          color: isSatisfied ? AppColors.accentSuccess : AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isSatisfied ? AppColors.accentSuccess : AppColors.primary,
                    ),
                    minHeight: 7,
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
              maxLines: null,
              minLines: 6,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: AppTypography.bodyLarge.copyWith(height: 1.55, fontSize: 15),
              decoration: InputDecoration(
                hintText: widget.promptHint.isNotEmpty
                    ? widget.promptHint
                    : 'Write your thoughts, description, or essay response here...',
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          // Footer Telemetry & Status Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(19)),
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Words: $_wordCount | Lines: $_lineCount | Chars: $_characterCount',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_controller.text.isNotEmpty)
                  InkWell(
                    onTap: _clearText,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        'Clear',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.accentDanger,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                if (isSatisfied)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 15, color: AppColors.accentSuccess),
                      const SizedBox(width: 4),
                      Text(
                        'Requirement Met',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.accentSuccess,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    '${(widget.requiredWords - _wordCount).clamp(0, widget.requiredWords)} words left',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
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
