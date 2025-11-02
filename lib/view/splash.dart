import 'dart:math';
import 'package:e_repairkit/widget/auth_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NeonSplashScreen extends StatefulWidget {
  final Duration duration;
  final VoidCallback? onFinish;

  const NeonSplashScreen({
    super.key,
    this.duration = const Duration(milliseconds: 2400),
    this.onFinish,
  });

  @override
  State<NeonSplashScreen> createState() => _NeonSplashScreenState();
}

class _NeonSplashScreenState extends State<NeonSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<double> _glowPulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);

    _scale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );

    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );

    _glowPulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );

    _ctrl.forward();

    // 🔥 Navigate after animation ends
    Future.delayed(widget.duration, () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _buildNeonLines(BuildContext ctx) {
    final size = MediaQuery.of(ctx).size;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value;
        return CustomPaint(
          size: size,
          painter: _NeonLinesPainter(pulse: _glowPulse.value, progress: t),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const base = Color(0xFF00FFD1);
    const accent = Color(0xFF7A00FF);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-0.9, -1),
                end: Alignment(0.9, 1),
                colors: [
                  Color(0xFF05031A),
                  Color(0xFF0B052F),
                ],
              ),
            ),
          ),

          Opacity(
            opacity: 0.9,
            child: _buildNeonLines(context),
          ),

          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              return Center(
                child: Transform.scale(
                  scale: _scale.value,
                  child: Opacity(
                    opacity: _fade.value,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.scale(
                          scale: 1.6 * (0.9 + 0.1 * sin(_ctrl.value * pi * 2)),
                          child: Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                center: Alignment.center,
                                radius: 0.7,
                                colors: [
                                  base.withOpacity(0.18 * _glowPulse.value),
                                  accent.withOpacity(0.08 * _glowPulse.value),
                                  Colors.transparent,
                                ],
                                stops: const [0, 0.45, 1],
                              ),
                            ),
                          ),
                        ),

                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: base.withOpacity(0.25 * _glowPulse.value),
                                blurRadius: 36,
                                spreadRadius: 6,
                              ),
                              BoxShadow(
                                color: accent.withOpacity(0.12 * _glowPulse.value),
                                blurRadius: 60,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),

                        SizedBox(
                          width: 110,
                          height: 110,
                          child: Image.asset('lib/assets/appicon.png', fit: BoxFit.contain),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.14,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _ctrl,
                curve: const Interval(0.45, 1.0, curve: Curves.easeIn),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'E-Device RepairKit',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.robotoMono(
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        shadows: [
                          Shadow(blurRadius: 10, color: Color(0xFF00FFD1), offset: Offset(0, 0)),
                          Shadow(blurRadius: 30, color: Color(0xFF7A00FF), offset: Offset(0, 0)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Repair. Restore. Repeat.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NeonLinesPainter extends CustomPainter {
  final double pulse;
  final double progress;
  final Random _rand = Random(42);

  _NeonLinesPainter({required this.pulse, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke;
    final maxLines = 6;

    for (var i = 0; i < maxLines; i++) {
      final y = size.height * (0.12 + i * 0.12 + 0.06 * sin(progress * 3 + i));
      final start = Offset(-20.0, y);
      final end = Offset(size.width + 20, y + 6 * sin(progress * 1.5 + i));
      paint.strokeWidth = 1.2 + i * 0.35;

      paint.shader = LinearGradient(
        colors: [
          Color.lerp(const Color(0xFF00FFD1), const Color(0xFF7A00FF), i / maxLines)!
              .withOpacity(0.16 * pulse),
          Colors.transparent,
        ],
      ).createShader(Rect.fromPoints(start, end));

      canvas.drawLine(start, end, paint);

      if (_rand.nextDouble() > 0.8) {
        final sparkX = size.width * _rand.nextDouble();
        final sparkY = y + (10 * (_rand.nextDouble() - 0.5));
        final sparkPaint = Paint()..color = Colors.white.withOpacity(0.9 * pulse);
        canvas.drawCircle(Offset(sparkX, sparkY), 1.6 * (0.5 + pulse), sparkPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NeonLinesPainter oldDelegate) =>
      oldDelegate.pulse != pulse || oldDelegate.progress != progress;
}
