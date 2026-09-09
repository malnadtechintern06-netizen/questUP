import 'dart:math' as math;
import 'package:flutter/material.dart';

class FloatingParticlesWidget extends StatefulWidget {
  final int particleCount;
  final Color color;
  final double maxSpeed;
  final Widget? child;

  const FloatingParticlesWidget({
    super.key,
    int? numberOfParticles,
    int particleCount = 20,
    Color? particleColor,
    Color color = const Color(0xFF00E5FF),
    this.maxSpeed = 0.4,
    this.child,
  })  : particleCount = numberOfParticles ?? particleCount,
        color = particleColor ?? color;

  @override
  State<FloatingParticlesWidget> createState() => _FloatingParticlesWidgetState();
}

class _FloatingParticlesWidgetState extends State<FloatingParticlesWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _particles = List.generate(
      widget.particleCount,
      (_) => _Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 1.5 + _random.nextDouble() * 2.5,
        speedX: (_random.nextDouble() - 0.5) * widget.maxSpeed * 0.002,
        speedY: -(_random.nextDouble() * widget.maxSpeed * 0.003 + 0.0005),
        alpha: 0.15 + _random.nextDouble() * 0.45,
      ),
    );

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              for (var p in _particles) {
                p.update();
              }
              return CustomPaint(
                painter: _FloatingParticlesPainter(
                  particles: _particles,
                  color: widget.color,
                ),
                size: Size.infinite,
              );
            },
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _Particle {
  double x;
  double y;
  double size;
  double speedX;
  double speedY;
  double alpha;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.alpha,
  });

  void update() {
    x += speedX;
    y += speedY;

    if (x < 0) x = 1.0;
    if (x > 1) x = 0.0;
    if (y < 0) y = 1.0;
    if (y > 1) y = 0.0;
  }
}

class _FloatingParticlesPainter extends CustomPainter {
  final List<_Particle> particles;
  final Color color;

  _FloatingParticlesPainter({
    required this.particles,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final paint = Paint()
        ..color = color.withValues(alpha: p.alpha)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingParticlesPainter oldDelegate) => true;
}
