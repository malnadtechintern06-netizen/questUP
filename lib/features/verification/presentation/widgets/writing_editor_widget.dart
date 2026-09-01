import 'package:flutter/material.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';

class WritingEditorWidget extends StatefulWidget {
  final int requiredWords;
  final int requiredLines;
  final String promptHint;
  final Function(String text, int wordCount, bool isSatisfied) onTextChanged;

  const WritingEditorWidget({
    super.key,
    this.requiredWords = 50,
    this.requiredLines = 0,
    this.promptHint = 'Start writing your response here...',
    required this.onTextChanged,
  });

  @override
  State<WritingEditorWidget> createState() => _WritingEditorWidgetState();
}

class _WritingEditorWidgetState extends State<WritingEditorWidget> {
  final TextEditingController _controller = TextEditingController();
  int _wordCount = 0;
  int _lineCount = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateCounts);
  }

  @override
  void dispose() {
    _controller.removeListener(_updateCounts);
    _controller.dispose();
    super.dispose();
  }

  void _updateCounts() {
    final text = _controller.text.trim();
    final words = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final lines = text.isEmpty ? 0 : text.split('\n').length;

    final isSatisfied = (widget.requiredWords == 0 || words >= widget.requiredWords) &&
        (widget.requiredLines == 0 || lines >= widget.requiredLines);

    setState(() {
      _wordCount = words;
      _lineCount = lines;
    });

    widget.onTextChanged(text, words, isSatisfied);
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.requiredWords > 0
        ? (_wordCount / widget.requiredWords).clamp(0.0, 1.0)
        : 1.0;
    final isSatisfied = widget.requiredWords == 0 || _wordCount >= widget.requiredWords;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSatisfied ? AppColors.accentSuccess : AppColors.border,
          width: isSatisfied ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar with Word Count Meter
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
                            isSatisfied ? Icons.check_circle_rounded : Icons.edit_note_rounded,
                            color: isSatisfied ? AppColors.accentSuccess : AppColors.primary,
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
                        color: isSatisfied
                            ? AppColors.accentSuccess.withValues(alpha: 0.15)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSatisfied ? AppColors.accentSuccess : AppColors.border,
                        ),
                      ),
                      child: Text(
                        '$_wordCount / ${widget.requiredWords} words',
                        style: AppTypography.caption.copyWith(
                          color: isSatisfied ? AppColors.accentSuccess : AppColors.textPrimary,
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
                      isSatisfied ? AppColors.accentSuccess : AppColors.primary,
                    ),
                    minHeight: 6,
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
                    'Lines: $_lineCount | Chars: ${_controller.text.length}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(width: 8),
                if (isSatisfied)
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
