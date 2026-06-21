import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';

/// A full-screen twilight backdrop: the night-sky gradient, a soft glowing
/// "moon" haze, and a field of gently twinkling stars. Drop any [child] on top.
class MagicalBackground extends StatefulWidget {
  const MagicalBackground({super.key, required this.child, this.starCount = 70});

  final Widget child;
  final int starCount;

  @override
  State<MagicalBackground> createState() => _MagicalBackgroundState();
}

class _MagicalBackgroundState extends State<MagicalBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(42);
    _stars = List.generate(widget.starCount, (_) => _Star.random(rnd));
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: MagicColors.nightSky),
      child: Stack(
        children: [
          // Soft enchanted glow drifting near the top — like a hidden moon.
          Positioned(
            top: -120,
            right: -80,
            child: _GlowOrb(
              size: 320,
              color: MagicColors.lilac.withValues(alpha: 0.22),
            ),
          ),
          Positioned(
            bottom: -160,
            left: -120,
            child: _GlowOrb(
              size: 360,
              color: MagicColors.aurora.withValues(alpha: 0.10),
            ),
          ),
          // Twinkling stars.
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _StarPainter(_stars, _controller.value),
                ),
              ),
            ),
          ),
          // Foreground content.
          Positioned.fill(child: widget.child),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _Star {
  _Star(this.dx, this.dy, this.radius, this.phase, this.twinkleSpeed);

  /// Fractional position (0..1) within the canvas.
  final double dx;
  final double dy;
  final double radius;
  final double phase;
  final double twinkleSpeed;

  factory _Star.random(math.Random rnd) => _Star(
    rnd.nextDouble(),
    rnd.nextDouble(),
    0.5 + rnd.nextDouble() * 1.6,
    rnd.nextDouble(),
    0.5 + rnd.nextDouble() * 1.5,
  );
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.stars, this.t);

  final List<_Star> stars;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = MagicColors.textPrimary;
    for (final star in stars) {
      // Twinkle: opacity oscillates on a per-star phase & speed.
      final wave =
          (math.sin((t * star.twinkleSpeed + star.phase) * 2 * math.pi) + 1) / 2;
      final opacity = 0.25 + wave * 0.65;
      paint.color = (star.radius > 1.4 ? MagicColors.gold : MagicColors.textPrimary)
          .withValues(alpha: opacity);
      final center = Offset(star.dx * size.width, star.dy * size.height);
      canvas.drawCircle(center, star.radius, paint);
      // A faint halo on the brighter stars.
      if (star.radius > 1.3) {
        canvas.drawCircle(
          center,
          star.radius * 2.4,
          Paint()
            ..color = MagicColors.gold.withValues(alpha: opacity * 0.18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_StarPainter oldDelegate) => oldDelegate.t != t;
}
