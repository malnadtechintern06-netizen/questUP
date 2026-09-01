import 'package:flutter/material.dart';
import 'package:quest_up/app/theme/app_colors.dart';
import 'package:quest_up/app/theme/app_typography.dart';

class DrawingPoint {
  final Offset offset;
  final Paint paint;

  const DrawingPoint({required this.offset, required this.paint});
}

class DrawingStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final bool isEraser;

  DrawingStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.isEraser = false,
  });
}

class DrawingCanvasWidget extends StatefulWidget {
  final String title;
  final Function(String drawingProofSummary) onDrawingReady;

  const DrawingCanvasWidget({
    super.key,
    required this.title,
    required this.onDrawingReady,
  });

  @override
  State<DrawingCanvasWidget> createState() => _DrawingCanvasWidgetState();
}

class _DrawingCanvasWidgetState extends State<DrawingCanvasWidget> {
  final List<DrawingStroke> _strokes = [];
  final List<DrawingStroke> _redoStrokes = [];
  DrawingStroke? _currentStroke;

  Color _selectedColor = AppColors.primary;
  double _strokeWidth = 4.0;
  bool _isEraser = false;

  final List<Color> _palette = const [
    AppColors.primary,
    AppColors.secondary,
    AppColors.accentLocation,
    AppColors.accentDanger,
    Color(0xFF8B5CF6), // Purple
    Color(0xFF0F172A), // Dark Slate
    Color(0xFF64748B), // Slate Grey
  ];

  void _onPanStart(DragStartDetails details) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);

    setState(() {
      _currentStroke = DrawingStroke(
        points: [localPosition],
        color: _isEraser ? Colors.white : _selectedColor,
        strokeWidth: _isEraser ? _strokeWidth * 2.5 : _strokeWidth,
        isEraser: _isEraser,
      );
      _redoStrokes.clear();
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_currentStroke == null) return;
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);

    setState(() {
      _currentStroke!.points.add(localPosition);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentStroke != null) {
      setState(() {
        _strokes.add(_currentStroke!);
        _currentStroke = null;
      });

      if (_strokes.length >= 2) {
        widget.onDrawingReady('drawing_strokes_${_strokes.length}_proof.png');
      }
    }
  }

  void _undo() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _redoStrokes.add(_strokes.removeLast());
      });
      if (_strokes.length >= 2) {
        widget.onDrawingReady('drawing_strokes_${_strokes.length}_proof.png');
      }
    }
  }

  void _redo() {
    if (_redoStrokes.isNotEmpty) {
      setState(() {
        _strokes.add(_redoStrokes.removeLast());
      });
      widget.onDrawingReady('drawing_strokes_${_strokes.length}_proof.png');
    }
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _redoStrokes.clear();
      _currentStroke = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar with Tools
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.brush_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Canvas: ${_strokes.length} Strokes',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(fontSize: 14),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.undo_rounded, size: 20),
                  onPressed: _strokes.isNotEmpty ? _undo : null,
                  tooltip: 'Undo',
                  color: AppColors.textPrimary,
                ),
                IconButton(
                  icon: const Icon(Icons.redo_rounded, size: 20),
                  onPressed: _redoStrokes.isNotEmpty ? _redo : null,
                  tooltip: 'Redo',
                  color: AppColors.textPrimary,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded, size: 20, color: AppColors.accentDanger),
                  onPressed: _strokes.isNotEmpty ? _clear : null,
                  tooltip: 'Clear Canvas',
                ),
              ],
            ),
          ),

          // Interactive Drawing Pad
          SizedBox(
            height: 280,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(0),
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: CustomPaint(
                  painter: CanvasPainter(
                    strokes: _strokes,
                    currentStroke: _currentStroke,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),

          // Palette & Brush Controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                // Colors + Eraser Row
                Row(
                  children: [
                    // Eraser Toggle Button
                    InkWell(
                      onTap: () => setState(() => _isEraser = !_isEraser),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isEraser ? AppColors.accentDanger.withValues(alpha: 0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isEraser ? AppColors.accentDanger : AppColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_fix_high_rounded,
                              size: 16,
                              color: _isEraser ? AppColors.accentDanger : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Eraser',
                              style: AppTypography.caption.copyWith(
                                color: _isEraser ? AppColors.accentDanger : AppColors.textSecondary,
                                fontWeight: _isEraser ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Color swatches
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _palette.map((color) {
                            final isSelected = !_isEraser && _selectedColor == color;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedColor = color;
                                  _isEraser = false;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? Colors.black : Colors.white,
                                    width: isSelected ? 2.5 : 1.5,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: color.withValues(alpha: 0.4),
                                            blurRadius: 6,
                                          )
                                        ]
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Stroke Size Selector
                Row(
                  children: [
                    Text('Size: ', style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                    ...[2.0, 4.0, 8.0, 16.0].map((size) {
                      final isSelected = _strokeWidth == size;
                      return InkWell(
                        onTap: () => setState(() => _strokeWidth = size),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryLight : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.border,
                            ),
                          ),
                          child: Text(
                            '${size.toInt()}px',
                            style: AppTypography.caption.copyWith(
                              color: isSelected ? AppColors.primary : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CanvasPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final DrawingStroke? currentStroke;

  CanvasPainter({
    required this.strokes,
    required this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fill white background
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Draw grid guide pattern
    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1.0;
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Paint finished strokes
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    // Paint active stroke
    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!);
    }
  }

  void _drawStroke(Canvas canvas, DrawingStroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.points.length == 1) {
      canvas.drawCircle(stroke.points.first, stroke.strokeWidth / 2, paint..style = PaintingStyle.fill);
      return;
    }

    final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (int i = 1; i < stroke.points.length; i++) {
      path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) => true;
}
