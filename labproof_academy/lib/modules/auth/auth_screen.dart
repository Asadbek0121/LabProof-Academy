import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_language.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/telegram_verification_service.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../data/models/academy_models.dart';
import 'student_onboarding.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _orbitController;
  late AnimationController _pulseController;
  late AnimationController _loadingController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..forward();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25), // Increased duration for much slower, more elegant movement
    )..repeat();
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _pulseController.dispose();
    _loadingController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  int _getPercentage(double progress) {
    if (progress < 0.15) {
      return (5 + (progress / 0.15) * 10).toInt(); // 5% to 15%
    } else if (progress < 0.35) {
      return (15 + ((progress - 0.15) / 0.20) * 17).toInt(); // 15% to 32%
    } else if (progress < 0.55) {
      return (32 + ((progress - 0.35) / 0.20) * 26).toInt(); // 32% to 58%
    } else if (progress < 0.75) {
      return (58 + ((progress - 0.55) / 0.20) * 14).toInt(); // 58% to 72%
    } else if (progress < 0.90) {
      return (72 + ((progress - 0.75) / 0.15) * 28).toInt(); // 72% to 100%
    } else {
      return 100;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0B1628), const Color(0xFF14223A)]
                : [const Color(0xFFFCFCFE), const Color(0xFFF5F3FF)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // Floating particles background
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: ParticlesPainter(_waveController.value, isDark),
                    );
                  },
                ),
              ),

              // Bottom wave mesh animation decoration
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 350, // Increased height so tall mountain peaks are not clipped
                child: AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: WaveMeshPainter(_waveController.value, isDark),
                    );
                  },
                ),
              ),

              // Main layouts (Orbits, logo, tagline, loaders)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const Spacer(),

                      // Logo text & layout
                      _buildLogo(isDark),

                      const SizedBox(height: 12),

                      // Tagline description
                      Text(
                        'Tibbiy bilimlarni ishonchli\nva zamonaviy platformada o\'rganing',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                        ),
                      ),

                      const Spacer(),

                      // Animated Loading text
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final opacity = 0.5 + (_pulseController.value * 0.5);

                          return Opacity(
                            opacity: opacity,
                            child: Text(
                              'Yuklanmoqda...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFB392FF) : const Color(0xFF7C4DFF),
                              ),
                            ),
                          );
                        },
                      ),

                      const Spacer(flex: 2),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCentralAnimation(bool isDark) {
    return Center(
      child: SizedBox(
        width: 260,
        height: 260,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Concentric Orbit 1 (outer)
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: (isDark ? const Color(0xFFB392FF) : const Color(0xFF7C4DFF)).withValues(alpha: 0.12),
                  width: 1.0,
                ),
              ),
            ),

            // Concentric Orbit 2 (inner)
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: (isDark ? const Color(0xFFB392FF) : const Color(0xFF7C4DFF)).withValues(alpha: 0.08),
                  width: 0.8,
                ),
              ),
            ),

            // Twinkling stars/particles around the orbits
            _buildSparkle(39, 56, 8, 0.6),
            _buildSparkle(212, 65, 7, 0.4),
            _buildSparkle(30, 186, 9, 0.5),
            _buildSparkle(203, 195, 10, 0.6),
            _buildSparkle(130, 13, 6, 0.8),
            _buildSparkle(104, 238, 7, 0.5),

            // Rotating icons on the outer orbit
            AnimatedBuilder(
              animation: _orbitController,
              builder: (context, child) {
                final angle = _orbitController.value * 2 * math.pi;
                return Stack(
                  children: [
                    // Shield (top-left offset by 5*pi/4)
                    _buildRotatingIcon(
                      angle: angle + (5 * math.pi / 4),
                      radius: 100,
                      icon: Icons.shield_rounded,
                      color: isDark ? const Color(0xFF8B5CF6) : const Color(0xFF7C4DFF),
                      isDark: isDark,
                    ),
                    // Flask (top-right offset by 7*pi/4)
                    _buildRotatingIcon(
                      angle: angle + (7 * math.pi / 4),
                      radius: 100,
                      icon: Icons.science_rounded,
                      color: isDark ? const Color(0xFF8B5CF6) : const Color(0xFF7C4DFF),
                      isDark: isDark,
                    ),
                    // Book (bottom-left offset by 3*pi/4)
                    _buildRotatingIcon(
                      angle: angle + (3 * math.pi / 4),
                      radius: 100,
                      icon: Icons.menu_book_rounded,
                      color: isDark ? const Color(0xFF8B5CF6) : const Color(0xFF7C4DFF),
                      isDark: isDark,
                    ),
                    // Chart (bottom-right offset by pi/4)
                    _buildRotatingIcon(
                      angle: angle + (math.pi / 4),
                      radius: 100,
                      icon: Icons.bar_chart_rounded,
                      color: isDark ? const Color(0xFF8B5CF6) : const Color(0xFF7C4DFF),
                      isDark: isDark,
                    ),
                  ],
                );
              },
            ),

            // Center Microscope Card with pulse animation
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + (_pulseController.value * 0.04);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C4DFF).withValues(alpha: isDark ? 0.3 : 0.12),
                          blurRadius: 24,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.biotech_rounded,
                        size: 46,
                        color: isDark ? const Color(0xFF9B6BFF) : const Color(0xFF7C4DFF),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSparkle(double x, double y, double size, double baseOpacity) {
    return Positioned(
      left: x,
      top: y,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final opacity = (baseOpacity + (_pulseController.value * (1.0 - baseOpacity) * 0.4)).clamp(0.0, 1.0);
          return Opacity(
            opacity: opacity,
            child: Icon(
              Icons.star_rounded,
              size: size,
              color: const Color(0xFF7C4DFF).withValues(alpha: 0.5),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRotatingIcon({
    required double angle,
    required double radius,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final x = 130.0 + radius * math.cos(angle) - 24; // 48 / 2
    final y = 130.0 + radius * math.sin(angle) - 24;

    return Positioned(
      left: x,
      top: y,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.25 : 0.1),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            size: 24,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'LABPROOF',
          style: TextStyle(
            fontFamily: 'Barabara',
            fontSize: 45,
            letterSpacing: 1.0,
            color: const Color(0xFF9B6BFF), // Matched light purple
          ),
        ),
        const SizedBox(height: 0),
        Text(
          'ACADEMY',
          style: TextStyle(
            fontFamily: 'Barabara',
            fontSize: 22,
            letterSpacing: 2.0,
            color: const Color(0xFF9B6BFF), // Matched light purple
          ),
        ),
      ],
    );
  }

  Widget _buildCircularLoader(bool isDark) {
    return AnimatedBuilder(
      animation: _loadingController,
      builder: (context, child) {
        final progress = _loadingController.value;
        final percentage = _getPercentage(progress);

        return Stack(
          alignment: Alignment.center,
          children: [
            // Rotating outer ring with gradient
            AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return SizedBox(
                  width: 120,
                  height: 120,
                  child: CustomPaint(
                    painter: GradientCircularProgressPainter(
                      progress: progress,
                      rotation: _waveController.value,
                      colors: const [Color(0xFF7C4DFF), Color(0xFFA855F7)],
                      isDark: isDark,
                    ),
                  ),
                );
              },
            ),

            // Icon & percentage in center
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = 0.95 + (_pulseController.value * 0.05); // 95% to 100%
                    final glowOpacity = 0.12 + (_pulseController.value * 0.12);
                    final glowSize = 12.0 + (_pulseController.value * 8.0);

                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7C4DFF).withValues(alpha: glowOpacity),
                              blurRadius: glowSize,
                              spreadRadius: 1.0,
                            ),
                          ],
                        ),
                        child: Center(
                          child: ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFF7C4DFF), Color(0xFFA855F7)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: const Icon(
                              Icons.school_rounded,
                              size: 26,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  '$percentage%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFB392FF) : const Color(0xFF7C4DFF),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class ParticlesPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  ParticlesPainter(this.progress, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final double phase = progress * 2 * math.pi;

    const int particleCount = 25;
    for (int i = 0; i < particleCount; i++) {
      // Deterministic pseudo-random seed values based on index i
      final double seedX = math.sin(i * 1.5) * 0.5 + 0.5; // 0.0 to 1.0
      final double seedY = math.cos(i * 2.3) * 0.5 + 0.5; // 0.0 to 1.0
      final double seedSpeed = (i % 3 + 1) * 0.18;

      // Calculate slow floating movement
      final double xOffset = math.sin(phase * seedSpeed + i) * 15.0;
      final double yOffset = math.cos(phase * seedSpeed * 0.5 + i) * 22.0;

      final double x = (seedX * size.width + xOffset).clamp(0.0, size.width);
      final double y = (seedY * size.height + yOffset).clamp(0.0, size.height);

      // Subtle size and opacity
      final double radius = 1.0 + (i % 3) * 0.6;
      final double opacity = 0.05 + math.sin(phase * 0.4 + i).abs() * 0.07;

      paint.color = (isDark ? const Color(0xFFB392FF) : const Color(0xFF7C4DFF)).withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}

class WaveMeshPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  WaveMeshPainter(this.progress, this.isDark);

  double _sharpenWave(double x) {
    return math.pow((x + 1.0) / 2.0, 1.5) * 2.0 - 1.0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const int rows = 60; // Optimized hyper resolution for smoothness
    const int cols = 200; // Optimized hyper resolution for smoothness

    final List<List<Offset>> grid = List.generate(
      rows,
      (r) => List.generate(cols, (c) => Offset.zero),
    );

    // Vanishing point above the canvas for dramatic 3D perspective
    final double vanishingPointX = size.width / 2;
    final double vanishingPointY = -size.height * 0.2;

    final double phase = progress * 2 * math.pi;

    for (int r = 0; r < rows; r++) {
      // tDepth goes from 0.0 (back/far) to 1.0 (front/near)
      final double baseTDepth = r / (rows - 1);

      for (int c = 0; c < cols; c++) {
        // tWidth goes from 0.0 (left) to 1.0 (right)
        final double tWidth = c / (cols - 1);
        double xNorm = tWidth * 2.0 - 1.0; // -1.0 to 1.0

        // Add organic horizontal and depth asymmetry (drift)
        // This breaks the rigid grid and turns it into a natural, scattered sea of particles
        final double driftX = math.sin(baseTDepth * 15.0 + phase * 2.5 + c * 0.2) * 0.12 + math.cos(r * 0.3) * 0.05;
        final double driftZ = math.cos(xNorm * 12.0 + phase * 1.8 + r * 0.15) * 0.08 + math.sin(c * 0.25) * 0.04;

        xNorm += driftX;
        final double effectiveTDepth = (baseTDepth + driftZ).clamp(0.0, 1.0);

        // Depth variable z varies per point now for true organic scattering
        final double z = 0.4 + (1.0 - effectiveTDepth) * 3.0;

        // 3D coordinates
        final double x3d = xNorm * size.width * 1.1;

        // Sea waves formula with Stokes-like sharpened peaks
        // High frequency to ensure at least 4-5 waves across the screen width
        final double sinVal1 = math.sin(xNorm * 12.5 - phase * 1.5 + effectiveTDepth * 4.0);
        final double wave1 = _sharpenWave(sinVal1) * 60.0;

        final double sinVal2 = math.cos(xNorm * 18.0 + phase * 1.2 - effectiveTDepth * 3.0);
        final double wave2 = _sharpenWave(sinVal2) * 35.0;

        // Add an asymmetric third wave to break uniformity
        final double wave3 = math.sin(xNorm * 25.0 - phase * 2.0 - effectiveTDepth * 2.0) * 20.0;

        // Add a fast high-frequency ripple
        final double wave4 = math.cos(xNorm * 35.0 + phase * 3.0 + effectiveTDepth * 5.0) * 10.0;

        // Attenuate height: mountains are very tall in the distance, but flat in the foreground.
        final double heightScale = 0.1 + (1.0 - effectiveTDepth) * 1.4;

        // Envelope to curve the sides up (valley layout)
        final double envelope = (xNorm * xNorm) * 60.0;

        final double y3d = (wave1 + wave2 + wave3 + wave4) * heightScale + envelope;

        // 3D Y coordinate: base height is calibrated to anchor the grid to the bottom of the widget
        final double baseHeight3d = size.height * 0.7 + (1.0 - effectiveTDepth) * size.height * 0.4;

        // Perspective projection
        final double screenX = vanishingPointX + x3d / z;
        final double screenY = vanishingPointY + (baseHeight3d - y3d) / z;

        grid[r][c] = Offset(screenX, screenY);
      }
    }

    // Set up paints
    final paintLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.2; // Very thin, barely visible threads

    final paintDot = Paint()
      ..style = PaintingStyle.fill;

    final Color frontColor = isDark ? const Color(0xFFB392FF) : const Color(0xFF7C4DFF);
    final Color backColor = isDark ? const Color(0xFF6366F1).withValues(alpha: 0.5) : const Color(0xFFE9D5FF);

    // Batch Drawing for Massive 60fps Performance on Ultra Grids
    // 1. Draw transverse (horizontal) lines
    for (int r = 0; r < rows; r++) {
      final double tDepth = r / (rows - 1);
      final double depthFade = 0.01 + (tDepth * 0.04);
      paintLine.color = Color.lerp(backColor, frontColor, tDepth)!.withValues(alpha: depthFade);

      final Path rowPath = Path();
      rowPath.moveTo(grid[r][0].dx, grid[r][0].dy);
      for (int c = 1; c < cols; c++) {
        rowPath.lineTo(grid[r][c].dx, grid[r][c].dy);
      }
      canvas.drawPath(rowPath, paintLine);
    }

    // 2. Draw longitudinal (depth) lines
    final paintColLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.2
      ..color = frontColor.withValues(alpha: 0.015);

    for (int c = 0; c < cols; c++) {
      final Path colPath = Path();
      colPath.moveTo(grid[0][c].dx, grid[0][c].dy);
      for (int r = 1; r < rows; r++) {
        colPath.lineTo(grid[r][c].dx, grid[r][c].dy);
      }
      canvas.drawPath(colPath, paintColLine);
    }

    // 3. Draw intersection dots using fast batch drawing
    paintDot.strokeCap = StrokeCap.round; // ensures points are drawn as circles
    for (int r = 0; r < rows; r++) {
      final double tDepth = r / (rows - 1);
      final double depthFade = 0.12 + (tDepth * 0.22);

      paintDot.color = Color.lerp(backColor, frontColor, tDepth)!.withValues(alpha: depthFade);
      paintDot.strokeWidth = (0.3 + (tDepth * 0.6)) * 2.0; // strokeWidth acts as diameter for PointMode.points

      canvas.drawPoints(ui.PointMode.points, grid[r], paintDot);
    }
  }

  @override
  bool shouldRepaint(covariant WaveMeshPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}

class GradientCircularProgressPainter extends CustomPainter {
  final double progress;
  final double rotation;
  final List<Color> colors;
  final bool isDark;

  GradientCircularProgressPainter({
    required this.progress,
    required this.rotation,
    required this.colors,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 2.5;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = isDark
          ? const Color(0xFF1E293B).withValues(alpha: 0.3)
          : const Color(0xFFF3E8FF).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final paint = Paint()
        ..shader = SweepGradient(
          colors: colors,
          startAngle: 0.0,
          endAngle: 2 * math.pi,
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-math.pi / 2 + rotation * 2 * math.pi);
      canvas.translate(-center.dx, -center.dy);

      canvas.drawArc(
        rect,
        0.0,
        2 * math.pi * progress,
        false,
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant GradientCircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.rotation != rotation ||
        oldDelegate.isDark != isDark;
  }
}


class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.entryRole,
    required this.language,
    required this.onLanguageChanged,
    required this.onSignedIn,
  });

  final UserRole entryRole;
  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final ValueChanged<UserRole> onSignedIn;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isRegister = false;
  bool _showOnboarding = true;
  bool _adminTyping = false;
  bool _adminPasswordVisible = false;
  String _adminPassword = '';

  @override
  Widget build(BuildContext context) {
    if (widget.entryRole == UserRole.student) {
      if (_showOnboarding) {
        return StudentOnboarding(
          language: widget.language,
          onLanguageChanged: widget.onLanguageChanged,
          onFinished: () => setState(() {
            _showOnboarding = false;
          }),
          onSignIn: () => setState(() {
            _showOnboarding = false;
            _isRegister = false;
          }),
          onCreateAccount: () => setState(() {
            _showOnboarding = false;
            _isRegister = true;
          }),
        );
      }

      return Scaffold(
        body: _StudentAuthBackdrop(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: _AuthCard(
                    isRegister: _isRegister,
                    role: widget.entryRole,
                    language: widget.language,
                    onModeChanged: (value) =>
                        setState(() => _isRegister = value),
                    onLanguageChanged: widget.onLanguageChanged,
                    onSubmit: () => widget.onSignedIn(widget.entryRole),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 860;
            final form = ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: widget.entryRole == UserRole.admin ? 420 : 450,
              ),
              child: _AuthCard(
                isRegister: _isRegister,
                role: widget.entryRole,
                language: widget.language,
                onModeChanged: (value) => setState(() => _isRegister = value),
                onLanguageChanged: widget.onLanguageChanged,
                onSubmit: () => widget.onSignedIn(widget.entryRole),
                onAdminTypingChanged: (value) =>
                    setState(() => _adminTyping = value),
                onAdminPasswordChanged: (value) =>
                    setState(() => _adminPassword = value),
                onAdminPasswordVisibleChanged: (value) =>
                    setState(() => _adminPasswordVisible = value),
              ),
            );

            if (!isWide) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.entryRole == UserRole.admin) ...[
                      const Center(child: _LoginBrandMark(dark: true)),
                      const SizedBox(height: 40),
                    ] else ...[
                      const AppLogo(),
                      const SizedBox(height: 28),
                    ],
                    form,
                  ],
                ),
              );
            }

            return Row(
              children: [
                Expanded(
                  child: widget.entryRole == UserRole.admin
                      ? _AnimatedAdminLoginHero(
                          isTyping: _adminTyping,
                          password: _adminPassword,
                          showPassword: _adminPasswordVisible,
                        )
                      : _AuthHeroPanel(role: widget.entryRole),
                ),
                Expanded(child: Center(child: form)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AnimatedAdminLoginHero extends StatefulWidget {
  const _AnimatedAdminLoginHero({
    required this.isTyping,
    required this.password,
    required this.showPassword,
  });

  final bool isTyping;
  final String password;
  final bool showPassword;

  @override
  State<_AnimatedAdminLoginHero> createState() =>
      _AnimatedAdminLoginHeroState();
}

class _AnimatedAdminLoginHeroState extends State<_AnimatedAdminLoginHero> {
  final _random = math.Random();
  Offset _pointer = const Offset(275, 230);
  bool _purpleBlink = false;
  bool _darkBlink = false;
  bool _lookingAtEachOther = false;
  bool _purplePeeking = false;
  Timer? _purpleBlinkTimer;
  Timer? _darkBlinkTimer;
  Timer? _typingTimer;
  Timer? _peekTimer;
  Timer? _peekResetTimer;

  @override
  void initState() {
    super.initState();
    _scheduleBlink(true);
    _scheduleBlink(false);
    _syncPeekTimer();
  }

  @override
  void didUpdateWidget(covariant _AnimatedAdminLoginHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTyping && !oldWidget.isTyping) {
      _startLookingAtEachOther();
    } else if (!widget.isTyping && oldWidget.isTyping) {
      _typingTimer?.cancel();
      if (_lookingAtEachOther) {
        setState(() => _lookingAtEachOther = false);
      }
    }

    final wasPasswordVisible =
        oldWidget.password.isNotEmpty && oldWidget.showPassword;
    if (_isPasswordVisible != wasPasswordVisible) {
      _syncPeekTimer();
    }
  }

  @override
  void dispose() {
    _purpleBlinkTimer?.cancel();
    _darkBlinkTimer?.cancel();
    _typingTimer?.cancel();
    _peekTimer?.cancel();
    _peekResetTimer?.cancel();
    super.dispose();
  }

  bool get _hasPassword => widget.password.isNotEmpty;
  bool get _isPasswordHidden => _hasPassword && !widget.showPassword;
  bool get _isPasswordVisible => _hasPassword && widget.showPassword;

  void _assignBlinkTimer(bool purple, Timer timer) {
    if (purple) {
      _purpleBlinkTimer = timer;
    } else {
      _darkBlinkTimer = timer;
    }
  }

  void _scheduleBlink(bool purple) {
    _assignBlinkTimer(
      purple,
      Timer(Duration(milliseconds: _random.nextInt(4000) + 3000), () {
        if (!mounted) return;
        setState(() {
          if (purple) {
            _purpleBlink = true;
          } else {
            _darkBlink = true;
          }
        });
        _assignBlinkTimer(
          purple,
          Timer(const Duration(milliseconds: 150), () {
            if (!mounted) return;
            setState(() {
              if (purple) {
                _purpleBlink = false;
              } else {
                _darkBlink = false;
              }
            });
            _scheduleBlink(purple);
          }),
        );
      }),
    );
  }

  void _startLookingAtEachOther() {
    _typingTimer?.cancel();
    setState(() => _lookingAtEachOther = true);
    _typingTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() => _lookingAtEachOther = false);
    });
  }

  void _syncPeekTimer() {
    _peekTimer?.cancel();
    _peekResetTimer?.cancel();
    if (!_isPasswordVisible) {
      if (_purplePeeking) {
        setState(() => _purplePeeking = false);
      }
      return;
    }
    _schedulePeek();
  }

  void _schedulePeek() {
    _peekTimer = Timer(
      Duration(milliseconds: _random.nextInt(3000) + 2000),
      () {
        if (!mounted || !_isPasswordVisible) return;
        setState(() => _purplePeeking = true);
        _peekResetTimer = Timer(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          setState(() => _purplePeeking = false);
          if (_isPasswordVisible) _schedulePeek();
        });
      },
    );
  }

  _FacePosition _position({
    required double left,
    required double width,
    required double height,
  }) {
    final center = Offset(left + width / 2, 440 - height + height / 3);
    final delta = _pointer - center;
    return _FacePosition(
      faceX: (delta.dx / 20).clamp(-15, 15).toDouble(),
      faceY: (delta.dy / 30).clamp(-10, 10).toDouble(),
      bodySkew: (-delta.dx / 120).clamp(-6, 6).toDouble(),
    );
  }

  Offset _pupilOffset(Offset center, double maxDistance) {
    final delta = _pointer - center;
    if (delta.distance == 0) return Offset.zero;
    return Offset.fromDirection(
      delta.direction,
      delta.distance.clamp(0, maxDistance).toDouble(),
    );
  }

  Matrix4 _characterTransform({required double skew, double translateX = 0}) {
    return Matrix4.identity()
      ..setEntry(0, 1, math.tan(skew * math.pi / 180))
      ..setTranslationRaw(translateX, 0, 0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFF6FF), Color(0xFF2563EB), Color(0xFF1D4ED8)],
          stops: [0.0, .42, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _LoginGridPainter())),
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _LoginBrandMark(),
                const Spacer(),
                Center(
                  child: SizedBox(
                    height: 560,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: MouseRegion(
                        onHover: (event) =>
                            setState(() => _pointer = event.localPosition),
                        child: _buildCharacters(),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacters() {
    const purpleLeft = 70.0;
    const purpleWidth = 180.0;
    final purpleHeight = (widget.isTyping || _isPasswordHidden) ? 440.0 : 400.0;
    const blackLeft = 240.0;
    const blackWidth = 120.0;
    const blackHeight = 310.0;
    const orangeLeft = 0.0;
    const yellowLeft = 310.0;

    final purple = _position(
      left: purpleLeft,
      width: purpleWidth,
      height: purpleHeight,
    );
    final black = _position(
      left: blackLeft,
      width: blackWidth,
      height: blackHeight,
    );
    final orange = _position(left: orangeLeft, width: 240, height: 200);
    final yellow = _position(left: yellowLeft, width: 140, height: 230);

    final purpleSkew = _isPasswordVisible
        ? 0.0
        : (widget.isTyping || _isPasswordHidden)
        ? purple.bodySkew - 12
        : purple.bodySkew;
    final blackSkew = _isPasswordVisible
        ? 0.0
        : _lookingAtEachOther
        ? black.bodySkew * 1.5 + 10
        : (widget.isTyping || _isPasswordHidden)
        ? black.bodySkew * 1.5
        : black.bodySkew;

    final purpleEyesLeft = _isPasswordVisible
        ? 20.0
        : _lookingAtEachOther
        ? 55.0
        : 45.0 + purple.faceX;
    final purpleEyesTop = _isPasswordVisible
        ? 35.0
        : _lookingAtEachOther
        ? 65.0
        : 40.0 + purple.faceY;
    final blackEyesLeft = _isPasswordVisible
        ? 10.0
        : _lookingAtEachOther
        ? 32.0
        : 26.0 + black.faceX;
    final blackEyesTop = _isPasswordVisible
        ? 28.0
        : _lookingAtEachOther
        ? 12.0
        : 32.0 + black.faceY;
    final orangeEyesLeft = _isPasswordVisible ? 50.0 : 82.0 + orange.faceX;
    final orangeEyesTop = _isPasswordVisible ? 85.0 : 90.0 + orange.faceY;
    final yellowEyesLeft = _isPasswordVisible ? 20.0 : 52.0 + yellow.faceX;
    final yellowEyesTop = _isPasswordVisible ? 35.0 : 40.0 + yellow.faceY;
    final yellowMouthLeft = _isPasswordVisible ? 10.0 : 40.0 + yellow.faceX;
    final yellowMouthTop = _isPasswordVisible ? 88.0 : 88.0 + yellow.faceY;

    return SizedBox(
      width: 550,
      height: 440,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: purpleLeft,
            bottom: 0,
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: _characterTransform(
                skew: purpleSkew,
                translateX:
                    (widget.isTyping || _isPasswordHidden) &&
                        !_isPasswordVisible
                    ? 40
                    : 0,
              ),
              child: _LoginCharacterBody(
                width: purpleWidth,
                height: purpleHeight,
                color: const Color(0xFF6C3FF5),
                radius: const BorderRadius.vertical(top: Radius.circular(10)),
                children: [
                  Positioned(
                    left: purpleEyesLeft,
                    top: purpleEyesTop,
                    child: Row(
                      children: [
                        _LoginEye(
                          size: 18,
                          pupilSize: 7,
                          offset: _isPasswordVisible
                              ? Offset(
                                  _purplePeeking ? 4 : -4,
                                  _purplePeeking ? 5 : -4,
                                )
                              : _lookingAtEachOther
                              ? const Offset(3, 4)
                              : _pupilOffset(
                                  Offset(
                                    purpleLeft + purpleEyesLeft + 9,
                                    440 - purpleHeight + purpleEyesTop + 9,
                                  ),
                                  5,
                                ),
                          blink: _purpleBlink,
                        ),
                        const SizedBox(width: 32),
                        _LoginEye(
                          size: 18,
                          pupilSize: 7,
                          offset: _isPasswordVisible
                              ? Offset(
                                  _purplePeeking ? 4 : -4,
                                  _purplePeeking ? 5 : -4,
                                )
                              : _lookingAtEachOther
                              ? const Offset(3, 4)
                              : _pupilOffset(
                                  Offset(
                                    purpleLeft + purpleEyesLeft + 59,
                                    440 - purpleHeight + purpleEyesTop + 9,
                                  ),
                                  5,
                                ),
                          blink: _purpleBlink,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: blackLeft,
            bottom: 0,
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: _characterTransform(
                skew: blackSkew,
                translateX: _lookingAtEachOther && !_isPasswordVisible ? 20 : 0,
              ),
              child: _LoginCharacterBody(
                width: blackWidth,
                height: blackHeight,
                color: const Color(0xFF2D2D2D),
                radius: const BorderRadius.vertical(top: Radius.circular(8)),
                children: [
                  Positioned(
                    left: blackEyesLeft,
                    top: blackEyesTop,
                    child: Row(
                      children: [
                        _LoginEye(
                          size: 16,
                          pupilSize: 6,
                          offset: _isPasswordVisible
                              ? const Offset(-4, -4)
                              : _lookingAtEachOther
                              ? const Offset(0, -4)
                              : _pupilOffset(
                                  Offset(
                                    blackLeft + blackEyesLeft + 8,
                                    440 - blackHeight + blackEyesTop + 8,
                                  ),
                                  4,
                                ),
                          blink: _darkBlink,
                        ),
                        const SizedBox(width: 24),
                        _LoginEye(
                          size: 16,
                          pupilSize: 6,
                          offset: _isPasswordVisible
                              ? const Offset(-4, -4)
                              : _lookingAtEachOther
                              ? const Offset(0, -4)
                              : _pupilOffset(
                                  Offset(
                                    blackLeft + blackEyesLeft + 48,
                                    440 - blackHeight + blackEyesTop + 8,
                                  ),
                                  4,
                                ),
                          blink: _darkBlink,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: orangeLeft,
            bottom: 0,
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: _characterTransform(
                skew: _isPasswordVisible ? 0 : orange.bodySkew,
              ),
              child: _LoginCharacterBody(
                width: 240,
                height: 200,
                color: const Color(0xFFFF9B6B),
                radius: const BorderRadius.vertical(top: Radius.circular(120)),
                children: [
                  Positioned(
                    left: orangeEyesLeft,
                    top: orangeEyesTop,
                    child: Row(
                      children: [
                        _LoginPupil(
                          offset: _isPasswordVisible
                              ? const Offset(-5, -4)
                              : _pupilOffset(
                                  Offset(
                                    orangeLeft + orangeEyesLeft + 6,
                                    440 - 200 + orangeEyesTop + 6,
                                  ),
                                  5,
                                ),
                        ),
                        const SizedBox(width: 32),
                        _LoginPupil(
                          offset: _isPasswordVisible
                              ? const Offset(-5, -4)
                              : _pupilOffset(
                                  Offset(
                                    orangeLeft + orangeEyesLeft + 50,
                                    440 - 200 + orangeEyesTop + 6,
                                  ),
                                  5,
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: yellowLeft,
            bottom: 0,
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: _characterTransform(
                skew: _isPasswordVisible ? 0 : yellow.bodySkew,
              ),
              child: _LoginCharacterBody(
                width: 140,
                height: 230,
                color: const Color(0xFFE8D754),
                radius: const BorderRadius.vertical(top: Radius.circular(70)),
                children: [
                  Positioned(
                    left: yellowEyesLeft,
                    top: yellowEyesTop,
                    child: Row(
                      children: [
                        _LoginPupil(
                          offset: _isPasswordVisible
                              ? const Offset(-5, -4)
                              : _pupilOffset(
                                  Offset(
                                    yellowLeft + yellowEyesLeft + 6,
                                    440 - 230 + yellowEyesTop + 6,
                                  ),
                                  5,
                                ),
                        ),
                        const SizedBox(width: 24),
                        _LoginPupil(
                          offset: _isPasswordVisible
                              ? const Offset(-5, -4)
                              : _pupilOffset(
                                  Offset(
                                    yellowLeft + yellowEyesLeft + 42,
                                    440 - 230 + yellowEyesTop + 6,
                                  ),
                                  5,
                                ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: yellowMouthLeft,
                    top: yellowMouthTop,
                    child: Container(
                      width: 80,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D2D2D),
                        borderRadius: BorderRadius.circular(99),
                      ),
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

class _FacePosition {
  const _FacePosition({
    required this.faceX,
    required this.faceY,
    required this.bodySkew,
  });

  final double faceX;
  final double faceY;
  final double bodySkew;
}

class _LoginGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .08)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LoginBrandMark extends StatelessWidget {
  const _LoginBrandMark({this.dark = false});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final foreground = dark ? AppColors.navy : Colors.white;
    final muted = dark ? AppColors.muted : Colors.white.withValues(alpha: .78);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: dark
                ? AppColors.primaryBlue.withValues(alpha: .10)
                : Colors.white.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.auto_awesome_rounded,
            color: dark ? AppColors.primaryBlue : Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LabProof Academy',
              style: TextStyle(
                color: foreground,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Admin panel',
              style: TextStyle(
                color: muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LoginCharacterBody extends StatelessWidget {
  const _LoginCharacterBody({
    required this.width,
    required this.height,
    required this.color,
    required this.radius,
    required this.children,
  });

  final double width;
  final double height;
  final Color color;
  final BorderRadius radius;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOut,
      width: width,
      height: height,
      decoration: BoxDecoration(color: color, borderRadius: radius),
      clipBehavior: Clip.hardEdge,
      child: Stack(children: children),
    );
  }
}

class _LoginEye extends StatelessWidget {
  const _LoginEye({
    required this.size,
    required this.pupilSize,
    required this.offset,
    required this.blink,
  });

  final double size;
  final double pupilSize;
  final Offset offset;
  final bool blink;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: size,
      height: blink ? 2 : size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size),
      ),
      alignment: Alignment.center,
      child: blink
          ? null
          : Transform.translate(
              offset: offset,
              child: Container(
                width: pupilSize,
                height: pupilSize,
                decoration: const BoxDecoration(
                  color: Color(0xFF2D2D2D),
                  shape: BoxShape.circle,
                ),
              ),
            ),
    );
  }
}

class _LoginPupil extends StatelessWidget {
  const _LoginPupil({required this.offset});

  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: Color(0xFF2D2D2D),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _AuthHeroPanel extends StatelessWidget {
  const _AuthHeroPanel({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == UserRole.admin;

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppLogo(
            titleColor: Colors.white,
            subtitleColor: Color(0xFF94A3B8),
          ),
          const Spacer(),
          Text(
            isAdmin
                ? 'LabProof Academy boshqaruvi bitta professional panelda.'
                : 'Laboratoriya ta’limi darsdan isbotgacha tartibli oqimda.',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontSize: 42,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isAdmin
                ? 'Modullar, mavzular, PDF, video, testlar, yakuniy imtihonlar va natijalar alohida admin muhitida boshqariladi.'
                : 'Studentlar PDF/Matn, video dars, mavzu testi va yakuniy imtihondan bosqichma-bosqich o‘tadi. Yakuniy o‘tish sharti: 70%.',
            style: TextStyle(
              color: Color(0xFFCBD5E1),
              height: 1.55,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              _HeroPill(icon: Icons.picture_as_pdf_rounded, label: 'PDF/Text'),
              _HeroPill(icon: Icons.play_circle_rounded, label: 'Video'),
              _HeroPill(icon: Icons.quiz_rounded, label: 'Test'),
              _HeroPill(icon: Icons.lock_open_rounded, label: 'Ochilish'),
            ],
          ),
          const Spacer(),
          AppCard(
            color: Colors.white.withValues(alpha: .08),
            borderColor: Colors.white.withValues(alpha: .12),
            child: Row(
              children: [
                const IconBadge(
                  icon: Icons.verified_user_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    isAdmin
                        ? 'Admin kirish sahifasi student APK oqimidan ajratilgan.'
                        : 'Student APK’da faqat o‘quvchi uchun kerakli dars oqimi ko‘rinadi.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFE2E8F0),
                    ),
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

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentAuthBackdrop extends StatelessWidget {
  const _StudentAuthBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.2 : 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.2 : 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _StudentAuthLogo extends StatelessWidget {
  const _StudentAuthLogo({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logoSize = compact ? 48.0 : 58.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6D28D9).withValues(alpha: .45),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Icon(
            Icons.biotech_rounded,
            color: Colors.white,
            size: compact ? 28 : 34,
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'LABPROOF',
              style: TextStyle(
                fontFamily: 'Barabara',
                color: const Color(0xFF9B6BFF),
                fontSize: compact ? 25 : 31,
                height: 1,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'ACADEMY',
              style: TextStyle(
                fontFamily: 'Barabara',
                color: const Color(0xFF9B6BFF),
                fontSize: 14,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StudentLanguageButton extends StatelessWidget {
  const _StudentLanguageButton({
    required this.language,
    required this.onChanged,
  });

  final AppLanguage language;
  final ValueChanged<AppLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final picked = await showModalBottomSheet<AppLanguage>(
            context: context,
            showDragHandle: true,
            builder: (context) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentText(language, 'language'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 14),
                    ...AppLanguage.values.map(
                      (item) => ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        leading: CircleAvatar(child: Text(item.shortLabel)),
                        title: Text(item.label),
                        trailing: item == language
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primaryBlue,
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(item),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          if (picked != null) onChanged(picked);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: .05)
                  : const Color(0xFFF1F5F9),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                language.shortLabel,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: isDark ? const Color(0xFFB7C0D6) : const Color(0xFF64748B),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentBackButton extends StatelessWidget {
  const _StudentBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: .05)
                  : const Color(0xFFF1F5F9),
            ),
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _StudentGlassPanel extends StatelessWidget {
  const _StudentGlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: .3)
                : const Color(0xFF64748B).withValues(alpha: .08),
            blurRadius: 34,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: .05)
              : const Color(0xFFF1F5F9),
        ),
      ),
      child: child,
    );
  }
}

class _StudentSectionTitle extends StatelessWidget {
  const _StudentSectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withValues(alpha: .18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFA855F7).withValues(alpha: .30),
            ),
          ),
          child: Icon(icon, color: const Color(0xFFA855F7), size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _StudentAuthInput extends StatelessWidget {
  const _StudentAuthInput({
    required this.label,
    required this.hintText,
    required this.icon,
    required this.controller,
    this.obscureText = false,
    this.suffix,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final String hintText;
  final IconData icon;
  final TextEditingController controller;
  final bool obscureText;
  final Widget? suffix;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
          cursorColor: const Color(0xFFA855F7),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: isDark ? const Color(0xFF8994AA) : const Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
            ),
            prefixIcon: Icon(icon, color: isDark ? const Color(0xFFB7C0D6) : const Color(0xFF64748B)),
            suffixIcon: suffix,
            filled: true,
            fillColor: isDark ? const Color(0xFF081426).withValues(alpha: .92) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 17,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: .09) : const Color(0xFFE2E8F0),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: .09) : const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF8B5CF6),
                width: 1.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StudentPhoneInput extends StatelessWidget {
  const _StudentPhoneInput({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 58,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF081426).withValues(alpha: .92) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: .09) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(
                Icons.phone_rounded,
                color: isDark ? const Color(0xFFB7C0D6) : const Color(0xFF64748B),
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                '+998',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              Container(
                width: 1,
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: isDark ? Colors.white.withValues(alpha: .09) : const Color(0xFFE2E8F0),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                  cursorColor: const Color(0xFFA855F7),
                  decoration: InputDecoration(
                    hintText: '90 123 45 67',
                    hintStyle: TextStyle(
                      color: isDark ? const Color(0xFF8994AA) : const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ],
    );
  }
}



class _StudentGradientButton extends StatelessWidget {
  const _StudentGradientButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.prefixIcon,
  });

  final String label;
  final VoidCallback onPressed;
  final bool loading;
  final Widget? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: loading ? null : onPressed,
        child: Ink(
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFF2B49FF), Color(0xFF8B2BEA)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: .36),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (prefixIcon != null) ...[
                        prefixIcon!,
                        const SizedBox(width: 12),
                      ],
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _StudentOutlineButton extends StatelessWidget {
  const _StudentOutlineButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        foregroundColor: const Color(0xFFA855F7),
        side: BorderSide(color: const Color(0xFFA855F7).withValues(alpha: .45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.telegram_rounded),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _StudentAuthModeSwitch extends StatelessWidget {
  const _StudentAuthModeSwitch({
    required this.leading,
    required this.action,
    required this.onTap,
  });

  final String leading;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white.withValues(alpha: .10) : const Color(0xFFE2E8F0);
    return Row(
      children: [
        Expanded(child: Divider(color: dividerColor)),
        const SizedBox(width: 12),
        Flexible(
          flex: 0,
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                leading,
                style: TextStyle(
                  color: isDark ? const Color(0xFFB7C0D6) : const Color(0xFF64748B),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFA855F7),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 36),
                ),
                child: Text(
                  action,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: dividerColor)),
      ],
    );
  }
}

class _StudentSecureCard extends StatelessWidget {
  const _StudentSecureCard({required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _StudentGlassPanel(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: .12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Color(0xFFA855F7),
              size: 36,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studentText(language, 'secure_title'),
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  studentText(language, 'secure_desc'),
                  style: TextStyle(
                    color: isDark ? const Color(0xFFB7C0D6) : const Color(0xFF475569),
                    height: 1.45,
                    fontSize: 14,
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

// ----------------------------------------------------
// Custom Registration Wizard Helper Widgets
// ----------------------------------------------------

class _StudentStepper extends StatelessWidget {
  const _StudentStepper({required this.step, required this.language});

  final int step;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildStep(context, 1, studentText(language, 'step_info'), step >= 1, step > 1),
        _buildConnector(step > 1),
        _buildStep(context, 2, studentText(language, 'step_verify'), step >= 2, step > 2),
        _buildConnector(step > 2),
        _buildStep(context, 3, studentText(language, 'step_complete'), step >= 3, false),
      ],
    );
  }

  Widget _buildStep(
    BuildContext context,
    int index,
    String label,
    bool active,
    bool completed,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF8B5CF6);

    return Expanded(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: completed
                  ? primaryColor
                  : active
                      ? primaryColor.withValues(alpha: 0.15)
                      : isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : const Color(0xFFF1F5F9),
              border: Border.all(
                color: completed || active
                    ? primaryColor
                    : isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : const Color(0xFFE2E8F0),
                width: 2,
              ),
              boxShadow: active && !completed
                  ? [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: Center(
              child: completed
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    )
                  : Text(
                      '$index',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: completed
                            ? Colors.white
                            : active
                                ? primaryColor
                                : isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF94A3B8),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active
                  ? primaryColor
                  : isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnector(bool completed) {
    return Container(
      width: 24,
      height: 2,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: completed
            ? const Color(0xFF8B5CF6)
            : const Color(0xFFE2E8F0).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

class _VerificationRequiredIllustration extends StatefulWidget {
  const _VerificationRequiredIllustration();

  @override
  State<_VerificationRequiredIllustration> createState() =>
      _VerificationRequiredIllustrationState();
}

class _VerificationRequiredIllustrationState
    extends State<_VerificationRequiredIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculate perfect responsive sizing
    final double illustrationSize;

    if (screenHeight < 680) {
      illustrationSize = 110.0;
    } else if (screenHeight < 800) {
      illustrationSize = 130.0;
    } else if (screenHeight < 860) {
      illustrationSize = 148.0; // Sweet spot size for iPhone 14 Pro (852px screen height)
    } else {
      illustrationSize = 165.0;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: AnimatedBuilder(
        animation: _floatAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _floatAnimation.value),
            child: child,
          );
        },
        child: SizedBox(
          height: illustrationSize + 30,
          width: illustrationSize + 30,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow background
              Container(
                width: illustrationSize - 10,
                height: illustrationSize - 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0088CC).withValues(alpha: isDark ? 0.08 : 0.05),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0088CC).withValues(alpha: isDark ? 0.15 : 0.1),
                      blurRadius: 32,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
              // Premium glassmorphic background ring
              Container(
                width: illustrationSize + 16,
                height: illustrationSize + 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.4),
                    width: 1.5,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: isDark ? 0.03 : 0.25),
                      Colors.white.withValues(alpha: isDark ? 0.005 : 0.05),
                    ],
                  ),
                ),
              ),
              // Main Illustration Image
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/telegram_verification_illustration.png',
                  width: illustrationSize,
                  height: illustrationSize,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerificationBulletItem extends StatelessWidget {
  const _VerificationBulletItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
            ),
            child: const Icon(
              Icons.check,
              size: 14,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFB7C0D6) : const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifyTelegramIllustration extends StatefulWidget {
  const _VerifyTelegramIllustration();

  @override
  State<_VerifyTelegramIllustration> createState() =>
      _VerifyTelegramIllustrationState();
}

class _VerifyTelegramIllustrationState
    extends State<_VerifyTelegramIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculate perfect responsive sizing
    final double illustrationSize;

    if (screenHeight < 680) {
      illustrationSize = 110.0;
    } else if (screenHeight < 800) {
      illustrationSize = 130.0;
    } else if (screenHeight < 860) {
      illustrationSize = 148.0; // Sweet spot size for iPhone 14 Pro (852px screen height)
    } else {
      illustrationSize = 165.0;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: AnimatedBuilder(
        animation: _floatAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _floatAnimation.value),
            child: child,
          );
        },
        child: SizedBox(
          height: illustrationSize + 30,
          width: illustrationSize + 30,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow background
              Container(
                width: illustrationSize - 10,
                height: illustrationSize - 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0088CC).withValues(alpha: isDark ? 0.08 : 0.05),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0088CC).withValues(alpha: isDark ? 0.15 : 0.1),
                      blurRadius: 32,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
              // Premium glassmorphic background ring
              Container(
                width: illustrationSize + 16,
                height: illustrationSize + 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.4),
                    width: 1.5,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: isDark ? 0.03 : 0.25),
                      Colors.white.withValues(alpha: isDark ? 0.005 : 0.05),
                    ],
                  ),
                ),
              ),
              // Main Illustration Image
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/telegram_verification_illustration.png',
                  width: illustrationSize,
                  height: illustrationSize,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _StudentOtpInput extends StatefulWidget {
  const _StudentOtpInput({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  State<_StudentOtpInput> createState() => _StudentOtpInputState();
}

class _StudentOtpInputState extends State<_StudentOtpInput> {
  String _code = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onCodeChanged);
    super.dispose();
  }

  void _onCodeChanged() {
    setState(() {
      _code = widget.controller.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Hidden TextField to receive key inputs
        Opacity(
          opacity: 0.0,
          child: SizedBox(
            height: 48,
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: 4,
              onChanged: widget.onChanged,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                counterText: '',
              ),
            ),
          ),
        ),
        // Display custom glassmorphic digit boxes
        GestureDetector(
          onTap: () {
            widget.focusNode.requestFocus();
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final isFocused = widget.focusNode.hasFocus && _code.length == index;
              final char = _code.length > index ? _code[index] : '';

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 56,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isFocused
                        ? const Color(0xFF8B5CF6)
                        : isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFCBD5E1),
                    width: isFocused ? 2 : 1,
                  ),
                  boxShadow: isFocused
                      ? [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
                child: Text(
                  char,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _SuccessShieldIllustration extends StatefulWidget {
  const _SuccessShieldIllustration();

  @override
  State<_SuccessShieldIllustration> createState() =>
      _SuccessShieldIllustrationState();
}

class _SuccessShieldIllustrationState extends State<_SuccessShieldIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF10B981).withValues(alpha: 0.12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.verified_user_rounded,
              size: 48,
              color: Color(0xFF10B981),
            ),
          ),
        ),
      ),
    );
  }
}

class _VerifiedDetailsCard extends StatelessWidget {
  const _VerifiedDetailsCard({
    required this.phone,
    required this.language,
  });

  final String phone;
  final AppLanguage language;

  String _getText(String key) {
    final uz = {
      'acc_status': 'Hisob holati',
      'active_status': 'Faol / Tasdiqlangan',
      'phone_num': 'Telefon raqam',
      'verified_at': 'Tasdiqlangan vaqt',
    };

    final ru = {
      'acc_status': 'Статус аккаунта',
      'active_status': 'Активен / Подтвержден',
      'phone_num': 'Номер телефона',
      'verified_at': 'Время подтверждения',
    };

    final cyr = {
      'acc_status': 'Ҳисоб ҳолати',
      'active_status': 'Фаол / Тасдиқланган',
      'phone_num': 'Телефон рақам',
      'verified_at': 'Тасдиқланган вақт',
    };

    if (language == AppLanguage.ru) return ru[key] ?? key;
    if (language == AppLanguage.uzCyrillic) return cyr[key] ?? key;
    return uz[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildRow(
            context,
            Icons.check_circle_outline_rounded,
            _getText('acc_status'),
            _getText('active_status'),
            const Color(0xFF10B981),
          ),
          const SizedBox(height: 12),
          _buildRow(
            context,
            Icons.phone_iphone_rounded,
            _getText('phone_num'),
            phone,
            const Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 12),
          _buildRow(
            context,
            Icons.access_time_rounded,
            _getText('verified_at'),
            _formattedNow(),
            const Color(0xFF3B82F6),
          ),
        ],
      ),
    );
  }

  String _formattedNow() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color accentColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentColor.withValues(alpha: 0.12),
          ),
          child: Icon(
            icon,
            size: 16,
            color: accentColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuthCard extends StatefulWidget {
  const _AuthCard({
    required this.isRegister,
    required this.role,
    required this.language,
    required this.onModeChanged,
    required this.onLanguageChanged,
    required this.onSubmit,
    this.onAdminTypingChanged,
    this.onAdminPasswordChanged,
    this.onAdminPasswordVisibleChanged,
  });

  final bool isRegister;
  final UserRole role;
  final AppLanguage language;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final VoidCallback onSubmit;
  final ValueChanged<bool>? onAdminTypingChanged;
  final ValueChanged<String>? onAdminPasswordChanged;
  final ValueChanged<bool>? onAdminPasswordVisibleChanged;

  @override
  State<_AuthCard> createState() => _AuthCardState();
}

class _AuthCardState extends State<_AuthCard> {
  static const _telegramVerificationService = TelegramVerificationService();
  static const _appVersionName = String.fromEnvironment(
    'APP_VERSION_NAME',
    defaultValue: 'dev',
  );

  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _adminLoginController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _codeController = TextEditingController();
  final _otpFocusNode = FocusNode();

  String? _sessionId;
  bool _registrationPrepared = false;
  bool _telegramOpened = false;
  bool _verifyingCode = false;
  bool _registrationCompleted = false;
  bool _passwordVisible = false;
  bool _registerPasswordConfirmVisible = false;
  bool _rememberStudent = true;
  bool _submitting = false;
  Uri? _botLink;

  Timer? _countdownTimer;
  int _secondsRemaining = 180;

  @override
  void didUpdateWidget(covariant _AuthCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRegister != widget.isRegister ||
        oldWidget.role != widget.role) {
      _sessionId = null;
      _registrationPrepared = false;
      _telegramOpened = false;
      _registrationCompleted = false;
      _botLink = null;
      _countdownTimer?.cancel();
      _codeController.clear();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _adminLoginController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _codeController.dispose();
    _otpFocusNode.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  String get _phoneNumber => '+998${_phoneController.text.trim()}';
  String get _studentFullName {
    return [
      _nameController.text.trim(),
      _lastNameController.text.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
  }

  String _t(String key) => studentText(widget.language, key);

  String _getStepText(String key) {
    final uz = {
      'step_info': 'Ma’lumotlar',
      'step_verify': 'Tasdiqlash',
      'step_complete': 'Tugatish',
      'verification_required': 'Telegram orqali hisobni tasdiqlang',
      'telegram_secures': 'Telegram bot orqali akkauntingizni xavfsiz tasdiqlang va aktivlashtiring.',
      'bullet_secure': 'Rasmiy Telegram Bot orqali xavfsiz tasdiqlash',
      'bullet_instant': 'Lahzali tasdiqlash kodi',
      'bullet_support': 'Shaxsiy yordam kanaliga ulanish',
      'continue_to_verify': 'Telegram botni ochish',
      'secure_data_note': 'Sizning ma\'lumotlaringiz xavfsiz va himoyalangan',
      'verify_your_account': 'Hisobni tasdiqlash',
      'send_code_note': 'Biz sizning Telegram botingizga tasdiqlash kodini yuboramiz.',
      'what_happens_next': 'Qanday ishlaydi?',
      'step_open_bot': 'Telegram bot\nochiladi',
      'step_press_start': 'Start tugmasini\nbosing',
      'step_confirm_phone': 'Telefon raqamini\ntasdiqlang',
      'step_enter_code': 'Kodni ilovaga\nkiriting',
      'step1_desc': 'Telegram botimizni ochish tugmasini bosing',
      'step2_desc': 'Bot sizga 4 xonali tasdiqlash kodini yuboradi',
      'step3_desc': 'Kod hisobingizni tasdiqlash uchun shu yerga kiritiladi',
      'open_telegram_bot': 'Telegram botni ochish',
      'enter_code': 'Tasdiqlash kodini kiriting',
      'enter_code_sent': 'Telegram botimiz yuborgan tasdiqlash kodini kiriting.',
      'code_expires': 'Kodning amal qilish vaqti',
      'not_received': 'Kodni olmadingizmi? Botni ishga tushirganingizga ishonch hosil qiling.',
      'resend_code': 'Kodni qayta yuborish',
      'verify_continue': 'Tasdiqlash va davom etish',
      'all_set': 'Hammasi tayyor! 🎉',
      'success_verified': 'Hisobingiz muvaffaqiyatli tasdiqlandi va faollashtirildi.',
      'acc_status': 'Hisob holati',
      'phone_num': 'Telefon raqam',
      'verified_at': 'Tasdiqlangan vaqt',
      'active_status': 'Faol / Tasdiqlangan',
      'continue_to_app': 'Ilovaga o‘tish',
    };

    final ru = {
      'step_info': 'Данные',
      'step_verify': 'Проверка',
      'step_complete': 'Готово',
      'verification_required': 'Подтвердите аккаунт через Telegram',
      'telegram_secures': 'Безопасно подтвердите и активируйте свой аккаунт с помощью Telegram-бота.',
      'bullet_secure': 'Безопасная проверка через официальный Telegram-бот',
      'bullet_instant': 'Мгновенный код подтверждения',
      'bullet_support': 'Доступ к каналу персональной поддержки',
      'continue_to_verify': 'Открыть Telegram-бот',
      'secure_data_note': 'Ваши данные в безопасности и защищены',
      'verify_your_account': 'Подтвердите свой аккаунт',
      'send_code_note': 'Мы отправим код подтверждения в ваш Telegram-бот.',
      'what_happens_next': 'Как это работает?',
      'step_open_bot': 'Запуск\nбота',
      'step_press_start': 'Нажмите\nStart',
      'step_confirm_phone': 'Подтвердите\nтелефон',
      'step_enter_code': 'Введите код\nв приложении',
      'step1_desc': 'Нажмите кнопку, чтобы открыть нашего Telegram-бота',
      'step2_desc': 'Бот отправит вам 4-значный код подтверждения',
      'step3_desc': 'Введите полученный код здесь для подтверждения',
      'open_telegram_bot': 'Открыть Telegram-бот',
      'enter_code': 'Введите код подтверждения',
      'enter_code_sent': 'Введите код подтверждения, отправленный нашим Telegram-ботом.',
      'code_expires': 'Код истекает через',
      'not_received': 'Не получили код? Убедитесь, что запустили бота.',
      'resend_code': 'Отправить код повторно',
      'verify_continue': 'Подтвердить и продолжить',
      'all_set': 'Все готово! 🎉',
      'success_verified': 'Ваш аккаунт успешно подтвержден и активирован.',
      'acc_status': 'Статус аккаунта',
      'phone_num': 'Номер телефона',
      'verified_at': 'Время подтверждения',
      'active_status': 'Активен / Подтвержден',
      'continue_to_app': 'Войти в приложение',
    };

    final cyr = {
      'step_info': 'Маълумотлар',
      'step_verify': 'Тасдиқлаш',
      'step_complete': 'Тугатиш',
      'verification_required': 'Телеграм орқали ҳисобни тасдиқланг',
      'telegram_secures': 'Телеграм бот орқали аккаунтингизни хавфсиз тасдиқланг va aktivlashtiring.',
      'bullet_secure': 'Расмий Телеграм Бот орқали хавфсиз тасдиқлаш',
      'bullet_instant': 'Лаҳзали тасдиқлаш коди',
      'bullet_support': 'Шахсий ёрдам каналига уланиш',
      'continue_to_verify': 'Телеграм ботни очиш',
      'secure_data_note': 'Сизнинг маълумотларингиз хавфсиз ва ҳимояланган',
      'verify_your_account': 'Ҳисобни тасдиқлаш',
      'send_code_note': 'Биз сизнинг Телеграм ботингизга тасдиқлаш кодини юборамиз.',
      'what_happens_next': 'Қандай ишлайди?',
      'step_open_bot': 'Телеграм бот\nочилади',
      'step_press_start': 'Старт тугмасини\nбосинг',
      'step_confirm_phone': 'Телефон рақамини\nтасдиқланг',
      'step_enter_code': 'Кодни иловага\nкиритинг',
      'step1_desc': 'Телеграм ботимизни очиш тугмасини босинг',
      'step2_desc': 'Бот сизга 4 хонали тасдиқлаш кодини юборади',
      'step3_desc': 'Код ҳисобингизни тасдиқлаш uchun shu yerga kiritiladi',
      'open_telegram_bot': 'Телеграм ботни очиш',
      'enter_code': 'Тасдиқлаш кодини киритинг',
      'enter_code_sent': 'Телеграм ботимиз юборган тасдиqlash кодини киритинг.',
      'code_expires': 'Коднинг амал қилиш вақти',
      'not_received': 'Кодни олмадингизми? Ботни ишга туширганингизга ишонч ҳосил қилинг.',
      'resend_code': 'Кодни qayta yuborish',
      'verify_continue': 'Тасдиқлаш ва давом этиш',
      'all_set': 'Ҳаммаси тайёр! 🎉',
      'success_verified': 'Ҳисобингиз муваффақиятли тасдиқланди ва фаоллаштирилди.',
      'acc_status': 'Ҳисоб ҳолати',
      'phone_num': 'Телефон рақам',
      'verified_at': 'Тасдиқланган вақт',
      'active_status': 'Фаол / Тасдиқланган',
      'continue_to_app': 'Иловага ўтиш',
    };

    if (widget.language == AppLanguage.ru) return ru[key] ?? key;
    if (widget.language == AppLanguage.uzCyrillic) return cyr[key] ?? key;
    return uz[key] ?? key;
  }

  Widget _buildStepCircle({
    required int number,
    required Widget content,
    required String label,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF2E243F) : const Color(0xFFF3E8FF),
                  border: Border.all(
                    color: isDark ? const Color(0xFF3B2E58) : const Color(0xFFE9D5FF),
                    width: 1,
                  ),
                ),
                child: Center(child: content),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF7C3AED),
                  ),
                  child: Center(
                    child: Text(
                      '$number',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.5,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedConnector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
    return Expanded(
      child: Container(
        height: 44,
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (index) => Container(
            width: 4,
            height: 2,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1),
            ),
          )),
        ),
      ),
    );
  }

  int get _currentStep {
    if (_registrationCompleted) return 5;
    if (_sessionId != null && _telegramOpened) return 4;
    if (_sessionId != null && !_telegramOpened) return 3;
    if (_registrationPrepared) return 2;
    return 1;
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    setState(() {
      _secondsRemaining = 180;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  String get _formattedTime {
    final minutes = (_secondsRemaining / 60).floor().toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _handleBackPress() {
    final step = _currentStep;
    if (step == 5) return;
    setState(() {
      if (step == 4) {
        _telegramOpened = false;
      } else if (step == 3) {
        _sessionId = null;
        _countdownTimer?.cancel();
      } else if (step == 2) {
        _registrationPrepared = false;
      } else if (step == 1) {
        widget.onModeChanged(false);
      }
    });
  }

  bool _validateRegistrationForm() {
    if (_studentFullName.length < 3) {
      _showError(_t('full_name_required'));
      return false;
    }

    if (!RegExp(r'^\d{9}$').hasMatch(_phoneController.text.trim())) {
      _showError(_t('phone_invalid'));
      return false;
    }

    if (_passwordController.text.isEmpty) {
      _showError(_t('password_required'));
      return false;
    }

    if (_passwordController.text.length < 6) {
      _showError(_t('password_min'));
      return false;
    }

    if (_confirmPasswordController.text != _passwordController.text) {
      _showError(_t('passwords_not_match'));
      return false;
    }

    return true;
  }

  Future<void> _requestTelegramCode() async {
    if (_submitting) return;
    if (!_validateRegistrationForm()) return;

    setState(() => _submitting = true);
    try {
      final request = await _telegramVerificationService.requestCode(
        fullName: _studentFullName,
        phone: _phoneNumber,
        password: _passwordController.text,
      );

      setState(() {
        _sessionId = request.sessionId;
        _telegramOpened = true; // Transition directly to Step 4 (OTP input)
        _registrationCompleted = false;
        _botLink = request.botLink;
        _codeController.clear();
      });

      _startTimer();

      _openTelegramBot(request.botLink);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(studentText(widget.language, 'telegram_opened')),
          ),
        );
      }
    } on Object catch (error) {
      _showError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openTelegramBot(Uri link) async {
    final opened = await launchUrl(link, mode: LaunchMode.externalApplication);
    if (!opened) {
      await launchUrl(link, mode: LaunchMode.platformDefault);
    }
  }

  void _prepareRegistration() {
    if (!_validateRegistrationForm()) return;

    setState(() {
      _registrationPrepared = true;
    });
  }

  Future<void> _verifyCode(String value) async {
    if (value.trim().length != 4 ||
        _sessionId == null ||
        _verifyingCode ||
        _registrationCompleted) {
      return;
    }
    if (!_validateRegistrationForm()) return;

    setState(() => _verifyingCode = true);
    final result = await _telegramVerificationService.verifyCode(
      sessionId: _sessionId!,
      code: value,
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _verifyingCode = false);

    if (result.verified) {
      setState(() {
        _registrationCompleted = true;
      });
    } else {
      _showError(
        result.error ?? 'Kod tasdiqlanmadi. Botdan olingan kodni tekshiring.',
      );
    }
  }

  Future<void> _completeRegistration() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await _signIn();
      widget.onSubmit();
    } on Object catch (error) {
      _showError(
        _friendlyAuthMessage(
          error
              .toString()
              .replaceFirst('AuthException(message: ', '')
              .replaceFirst(')', ''),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _signIn() async {
    await AuthService.signInWithPhone(
      phone: _phoneNumber,
      password: _passwordController.text,
    );
  }

  Future<void> _signInAdmin() async {
    final login = _adminLoginController.text.trim();
    if (login.isEmpty) {
      throw Exception('Admin loginni kiriting.');
    }
    if (_passwordController.text.isEmpty) {
      throw Exception(_t('password_required'));
    }
    await AuthService.signInAdmin(
      login: login,
      password: _passwordController.text,
    );
  }

  Future<void> _submitLogin() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      if (widget.role == UserRole.admin) {
        await _signInAdmin();
      } else {
        if (!_validateLoginForm()) return;
        await _signIn();
      }
      widget.onSubmit();
    } on Object catch (error) {
      if (widget.role == UserRole.student) {
        await _handleStudentLoginError(error);
      } else {
        _showError(_friendlyAuthMessage(_cleanAuthError(error)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool _validateLoginForm() {
    if (!RegExp(r'^\d{9}$').hasMatch(_phoneController.text.trim())) {
      _showError(_t('phone_invalid'));
      return false;
    }
    if (_passwordController.text.isEmpty) {
      _showError(_t('password_required'));
      return false;
    }
    return true;
  }

  Future<void> _handleStudentLoginError(Object error) async {
    final message = _cleanAuthError(error);
    final lower = message.toLowerCase();

    if (lower.contains('invalid login credentials')) {
      final exists = await AuthService.isPhoneRegistered(_phoneNumber);
      if (!mounted) return;

      if (exists == true) {
        _showActionError(
          'Parol noto‘g‘ri. Parolni tiklash orqali yangisini o‘rnating.',
          _t('forgot'),
          () => unawaited(_openForgotPasswordSheet()),
        );
        return;
      }

      if (exists == false) {
        _showActionError(
          'Bu telefon raqam bilan akkaunt topilmadi. Ro‘yxatdan o‘ting.',
          _t('register'),
          () => widget.onModeChanged(true),
        );
        return;
      }
    }

    _showError(_friendlyAuthMessage(message));
  }

  String _cleanAuthError(Object error) {
    return error
        .toString()
        .replaceFirst('AuthException(message: ', '')
        .replaceFirst(')', '');
  }

  Future<void> _openForgotPasswordSheet() async {
    final result = await showModalBottomSheet<_PasswordResetResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _PasswordResetSheet(language: widget.language),
    );

    if (!mounted || result == null) return;

    _phoneController.text = result.phoneDigits;
    _passwordController.text = result.password;
    _showInfo(_t('reset_success'));
    await _submitLogin();
  }

  String _friendlyAuthMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('password should be at least') ||
        (lower.contains('password') && lower.contains('6'))) {
      return _t('password_min');
    }
    if (lower.contains('phone logins are disabled') ||
        lower.contains('phone_provider_disabled')) {
      return 'Telefon orqali kirish sozlamasi yangilandi. Ilovani yangilab qayta ro‘yxatdan o‘ting.';
    }
    if (lower.contains('invalid login credentials')) {
      return 'Telefon raqam yoki parol noto‘g‘ri.';
    }
    return message;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.errorRed),
    );
  }

  void _showActionError(
    String message,
    String actionLabel,
    VoidCallback onAction,
  ) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorRed,
        action: SnackBarAction(
          label: actionLabel,
          textColor: Colors.white,
          onPressed: onAction,
        ),
      ),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildStudentAuth(BuildContext context, String Function(String) t) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRegister = widget.isRegister;
    final step = _currentStep;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isRegister) ...[
              _StudentBackButton(onTap: _handleBackPress),
              const SizedBox(width: 12),
            ],
            Expanded(child: _StudentAuthLogo(compact: isRegister)),
            const SizedBox(width: 12),
            _StudentLanguageButton(
              language: widget.language,
              onChanged: widget.onLanguageChanged,
            ),
          ],
        ),
        SizedBox(height: isRegister ? 10 : 20),
        if (isRegister) ...[
          _StudentStepper(
            step: step == 5 ? 3 : (step >= 2 ? 2 : 1),
            language: widget.language,
          ),
          const SizedBox(height: 10),
        ],
        Text(
          !isRegister
              ? t('welcome')
              : (step == 1
                  ? t('create_account')
                  : (step == 2
                      ? _getStepText('verification_required')
                      : (step == 3
                          ? _getStepText('verify_your_account')
                          : (step == 4
                              ? _getStepText('enter_code')
                              : _getStepText('all_set'))))),
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 23,
            fontWeight: FontWeight.w900,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          !isRegister
              ? t('login_subtitle')
              : (step == 1
                  ? t('register_subtitle')
                  : (step == 2
                      ? _getStepText('telegram_secures')
                      : (step == 3
                          ? _getStepText('send_code_note')
                          : (step == 4
                              ? _getStepText('enter_code_sent')
                              : _getStepText('success_verified'))))),
          style: TextStyle(
            color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF475569),
            fontSize: 13.5,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        if (isRegister && (step == 2 || step == 3)) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: .3)
                      : const Color(0xFF64748B).withValues(alpha: .08),
                  blurRadius: 34,
                  offset: const Offset(0, 12),
                ),
              ],
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: .05)
                    : const Color(0xFFF1F5F9),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Transform.scale(
                  scale: 2.0,
                  child: Image.asset(
                    'assets/images/telegram_verification_illustration.png',
                    width: double.infinity,
                    height: 155,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 38),
                _VerificationBulletItem(text: _getStepText('bullet_secure')),
                _VerificationBulletItem(text: _getStepText('bullet_instant')),
                _VerificationBulletItem(text: _getStepText('bullet_support')),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _getStepText('what_happens_next'),
            style: TextStyle(
              color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStepCircle(
                number: 1,
                content: Icon(
                  Icons.telegram_rounded,
                  color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9),
                  size: 24,
                ),
                label: _getStepText('step_open_bot'),
              ),
              _buildDashedConnector(),
              _buildStepCircle(
                number: 2,
                content: Text(
                  '/start',
                  style: TextStyle(
                    color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                  ),
                ),
                label: _getStepText('step_press_start'),
              ),
              _buildDashedConnector(),
              _buildStepCircle(
                number: 3,
                content: Icon(
                  Icons.phone_iphone_rounded,
                  color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9),
                  size: 20,
                ),
                label: _getStepText('step_confirm_phone'),
              ),
              _buildDashedConnector(),
              _buildStepCircle(
                number: 4,
                content: Icon(
                  Icons.lock_outline_rounded,
                  color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9),
                  size: 20,
                ),
                label: _getStepText('step_enter_code'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (step == 2) ...[
            _StudentGradientButton(
              label: _getStepText('continue_to_verify'),
              loading: _submitting,
              onPressed: _requestTelegramCode,
              prefixIcon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Color(0xFF2B49FF),
                  size: 12,
                ),
              ),
            ),
          ] else if (step == 3) ...[
            _StudentGradientButton(
              label: _getStepText('open_telegram_bot'),
              onPressed: () {
                if (_botLink != null) {
                  _openTelegramBot(_botLink!);
                  setState(() => _telegramOpened = true);
                }
              },
              prefixIcon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Color(0xFF2B49FF),
                  size: 12,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _StudentOutlineButton(
              label: _getStepText('verify_continue'),
              onPressed: () {
                setState(() => _telegramOpened = true);
              },
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                size: 14,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _getStepText('secure_data_note'),
                  style: TextStyle(
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          _StudentGlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isRegister) ...[
                  _StudentSectionTitle(
                    icon: Icons.person_outline_rounded,
                    title: t('login_title'),
                  ),
                  const SizedBox(height: 18),
                  _StudentPhoneInput(
                    label: t('phone'),
                    controller: _phoneController,
                  ),
                  const SizedBox(height: 14),
                  _StudentAuthInput(
                    label: t('password'),
                    hintText: t('enter_password'),
                    icon: Icons.lock_outline_rounded,
                    controller: _passwordController,
                    obscureText: !_passwordVisible,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submitLogin(),
                    suffix: IconButton(
                      tooltip: _passwordVisible ? t('hide_password') : t('show_password'),
                      onPressed: () {
                        setState(() => _passwordVisible = !_passwordVisible);
                      },
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFFB7C0D6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberStudent,
                        onChanged: (value) =>
                            setState(() => _rememberStudent = value ?? true),
                        activeColor: const Color(0xFF7C3AED),
                        checkColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF7B879F)),
                      ),
                      Expanded(
                        child: Text(
                          t('remember_me'),
                          style: TextStyle(
                            color: isDark ? const Color(0xFFB7C0D6) : const Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _openForgotPasswordSheet,
                        child: Text(
                          t('forgot'),
                          style: const TextStyle(
                            color: Color(0xFFA855F7),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _StudentGradientButton(
                    label: t('login'),
                    loading: _submitting,
                    onPressed: _submitLogin,
                  ),
                  const SizedBox(height: 22),
                  _StudentAuthModeSwitch(
                    leading: t('no_account'),
                    action: t('create_account'),
                    onTap: () => widget.onModeChanged(true),
                  ),
                ],
                if (isRegister) ...[
                  if (step == 1) ...[
                    _StudentSectionTitle(
                      icon: Icons.account_circle_outlined,
                      title: t('your_info'),
                    ),
                    const SizedBox(height: 18),
                    _StudentAuthInput(
                      label: t('first_name'),
                      hintText: t('first_name'),
                      icon: Icons.person_outline_rounded,
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    _StudentAuthInput(
                      label: t('last_name'),
                      hintText: t('last_name'),
                      icon: Icons.person_outline_rounded,
                      controller: _lastNameController,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    _StudentPhoneInput(
                      label: t('phone'),
                      controller: _phoneController,
                    ),
                    const SizedBox(height: 14),
                    _StudentSectionTitle(
                      icon: Icons.lock_outline_rounded,
                      title: t('security'),
                    ),
                    const SizedBox(height: 14),
                    _StudentAuthInput(
                      label: t('password'),
                      hintText: t('create_password'),
                      icon: Icons.lock_outline_rounded,
                      controller: _passwordController,
                      obscureText: !_passwordVisible,
                      textInputAction: TextInputAction.next,
                      suffix: IconButton(
                        tooltip: _passwordVisible ? t('hide_password') : t('show_password'),
                        onPressed: () {
                          setState(() => _passwordVisible = !_passwordVisible);
                        },
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: const Color(0xFFB7C0D6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _StudentAuthInput(
                      label: t('confirm_password'),
                      hintText: t('reenter_password'),
                      icon: Icons.lock_outline_rounded,
                      controller: _confirmPasswordController,
                      obscureText: !_registerPasswordConfirmVisible,
                      textInputAction: TextInputAction.done,
                      suffix: IconButton(
                        tooltip: _registerPasswordConfirmVisible ? t('hide_password') : t('show_password'),
                        onPressed: () {
                          setState(() => _registerPasswordConfirmVisible = !_registerPasswordConfirmVisible);
                        },
                        icon: Icon(
                          _registerPasswordConfirmVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: const Color(0xFFB7C0D6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _StudentGradientButton(
                      label: t('create_account'),
                      loading: _submitting,
                      onPressed: _prepareRegistration,
                    ),
                  ],
                  if (step == 4) ...[
                    _StudentSectionTitle(
                      icon: Icons.verified_user_rounded,
                      title: _getStepText('enter_code'),
                    ),
                    const SizedBox(height: 18),
                    _StudentOtpInput(
                      controller: _codeController,
                      focusNode: _otpFocusNode,
                      onChanged: _verifyCode,
                    ),
                    const SizedBox(height: 20),
                    if (_verifyingCode)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(
                            color: Color(0xFF8B5CF6),
                          ),
                        ),
                      )
                    else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 16,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_getStepText('code_expires')}: $_formattedTime',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            if (_botLink != null) {
                              _openTelegramBot(_botLink!);
                            }
                          },
                          icon: const Icon(
                            Icons.telegram_rounded,
                            color: Color(0xFF2B49FF),
                            size: 20,
                          ),
                          label: Text(
                            _getStepText('open_telegram_bot'),
                            style: const TextStyle(
                              color: Color(0xFF2B49FF),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      if (_secondsRemaining == 0) ...[
                        const SizedBox(height: 14),
                        _StudentOutlineButton(
                          label: _getStepText('resend_code'),
                          onPressed: _requestTelegramCode,
                        ),
                      ],
                    ],
                  ],
                  if (step == 5) ...[
                    const _SuccessShieldIllustration(),
                    const SizedBox(height: 20),
                    _VerifiedDetailsCard(
                      phone: _phoneNumber,
                      language: widget.language,
                    ),
                    const SizedBox(height: 24),
                    _StudentGradientButton(
                      label: _getStepText('continue_to_app'),
                      loading: _submitting,
                      onPressed: _completeRegistration,
                    ),
                  ],
                  if (step == 1) ...[
                    const SizedBox(height: 22),
                    _StudentAuthModeSwitch(
                      leading: t('have_account'),
                      action: t('login'),
                      onTap: () => widget.onModeChanged(false),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
        if (!isRegister) ...[
          const SizedBox(height: 24),
          _StudentSecureCard(language: widget.language),
          const SizedBox(height: 26),
          Text(
            t('terms_agreement'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAdminLogin(BuildContext context, String Function(String) t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t('welcome'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 32,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t('admin_login_subtitle'),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 34),
            Text(
              t('admin_login_label'),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Focus(
              onFocusChange: widget.onAdminTypingChanged,
              child: TextField(
                controller: _adminLoginController,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.text,
                autofillHints: const [AutofillHints.username],
                decoration: const InputDecoration(hintText: 'admin231'),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              t('password'),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: !_passwordVisible,
              textInputAction: TextInputAction.done,
              onChanged: widget.onAdminPasswordChanged,
              onSubmitted: (_) => _submitLogin(),
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                hintText: '••••••••',
                suffixIcon: IconButton(
                  tooltip: _passwordVisible
                      ? t('hide_password')
                      : t('show_password'),
                  onPressed: () {
                    final nextValue = !_passwordVisible;
                    setState(() => _passwordVisible = nextValue);
                    widget.onAdminPasswordVisibleChanged?.call(nextValue);
                  },
                  icon: Icon(
                    _passwordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _openForgotPasswordSheet,
                child: Text(t('forgot')),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _submitting ? null : _submitLogin,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(_submitting ? 'Kirilmoqda...' : t('login')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => studentText(widget.language, key);
    final isAdminLogin = widget.role == UserRole.admin && !widget.isRegister;
    final isStudentEntry = widget.role == UserRole.student;

    if (isAdminLogin) {
      return _buildAdminLogin(context, t);
    }

    if (isStudentEntry) {
      return _buildStudentAuth(context, t);
    }

    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  isAdminLogin
                      ? 'Admin kirish'
                      : widget.isRegister
                      ? t('create_account')
                      : t('welcome'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              if (isStudentEntry) ...[
                const SizedBox(width: 12),
                _LanguageSelector(
                  language: widget.language,
                  onChanged: widget.onLanguageChanged,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.isRegister
                ? t('register_hint')
                : isAdminLogin
                ? t('admin_login_hint')
                : t('signin_hint'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          if (isAdminLogin) ...[
            TextField(
              controller: _adminLoginController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: t('admin_login_label'),
                prefixIcon: const Icon(Icons.admin_panel_settings_rounded),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (widget.isRegister) ...[
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: t('full_name'),
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (!isAdminLogin) ...[
            _PhoneNumberField(controller: _phoneController, label: t('phone')),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _passwordController,
            obscureText: !_passwordVisible,
            decoration: InputDecoration(
              labelText: t('password'),
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: _passwordVisible
                    ? t('hide_password')
                    : t('show_password'),
                onPressed: () {
                  setState(() => _passwordVisible = !_passwordVisible);
                },
                icon: Icon(
                  _passwordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!widget.isRegister)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _openForgotPasswordSheet,
                child: Text(t('forgot')),
              ),
            ),
          if (widget.isRegister &&
              _registrationPrepared &&
              !_telegramOpened) ...[
            AppCard(
              padding: const EdgeInsets.all(12),
              color: AppColors.successGreen.withValues(alpha: .06),
              borderColor: AppColors.successGreen.withValues(alpha: .2),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_user_rounded,
                    color: AppColors.successGreen,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t('telegram_hint'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (widget.isRegister && _sessionId != null && _telegramOpened) ...[
            AppCard(
              padding: const EdgeInsets.all(12),
              color: AppColors.primaryBlue.withValues(alpha: .06),
              borderColor: AppColors.primaryBlue.withValues(alpha: .2),
              child: Row(
                children: [
                  const Icon(Icons.send_rounded, color: AppColors.primaryBlue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t('telegram_opened'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              onChanged: _verifyCode,
              decoration: InputDecoration(
                labelText: t('code'),
                hintText: t('code_hint'),
                prefixIcon: const Icon(Icons.verified_user_rounded),
                suffixIcon: _verifyingCode
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (!(widget.isRegister && _telegramOpened))
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.isRegister
                    ? (_registrationPrepared
                          ? _requestTelegramCode
                          : _prepareRegistration)
                    : _submitLogin,
                icon: Icon(
                  _submitting
                      ? Icons.hourglass_top_rounded
                      : widget.isRegister
                      ? (_registrationPrepared
                            ? Icons.send_rounded
                            : Icons.person_add_alt_1_rounded)
                      : Icons.login,
                ),
                label: Text(
                  widget.isRegister
                      ? (_registrationPrepared ? t('get_code') : t('register'))
                      : t('login'),
                ),
              ),
            )
          else if (_botLink != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openTelegramBot(_botLink!),
                icon: const Icon(Icons.send_rounded),
                label: Text(t('open_bot_again')),
              ),
            ),
          const SizedBox(height: 16),
          if (isStudentEntry)
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  widget.isRegister ? t('already') : t('new'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                TextButton(
                  onPressed: () => widget.onModeChanged(!widget.isRegister),
                  child: Text(widget.isRegister ? t('login') : t('register')),
                ),
              ],
            ),
          if (isStudentEntry) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                'v$_appVersionName',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PasswordResetResult {
  const _PasswordResetResult({
    required this.phoneDigits,
    required this.password,
  });

  final String phoneDigits;
  final String password;
}

class _PasswordResetSheet extends StatefulWidget {
  const _PasswordResetSheet({required this.language});

  final AppLanguage language;

  @override
  State<_PasswordResetSheet> createState() => _PasswordResetSheetState();
}

class _PasswordResetSheetState extends State<_PasswordResetSheet> {
  static const _telegramVerificationService = TelegramVerificationService();

  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _codeController = TextEditingController();

  String? _sessionId;
  Uri? _botLink;
  bool _telegramOpened = false;
  bool _submitting = false;
  bool _verifying = false;
  bool _passwordVisible = false;
  bool _confirmVisible = false;

  String _t(String key) => studentText(widget.language, key);
  String get _phoneNumber => '+998${_phoneController.text.trim()}';

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    if (!RegExp(r'^\d{9}$').hasMatch(_phoneController.text.trim())) {
      _showError(_t('phone_invalid'));
      return false;
    }
    if (_passwordController.text.isEmpty) {
      _showError(_t('password_required'));
      return false;
    }
    if (_passwordController.text.length < 6) {
      _showError(_t('password_min'));
      return false;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError(_t('passwords_not_match'));
      return false;
    }
    return true;
  }

  Future<void> _requestResetCode() async {
    if (_submitting || !_validateForm()) return;

    setState(() => _submitting = true);
    try {
      final request = await _telegramVerificationService.requestPasswordReset(
        phone: _phoneNumber,
      );
      setState(() {
        _sessionId = request.sessionId;
        _botLink = request.botLink;
        _telegramOpened = true;
        _codeController.clear();
      });

      await _openTelegramBot(request.botLink);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_t('telegram_opened'))));
    } on Object catch (error) {
      _showError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openTelegramBot(Uri link) async {
    final opened = await launchUrl(link, mode: LaunchMode.externalApplication);
    if (!opened) {
      await launchUrl(link, mode: LaunchMode.platformDefault);
    }
  }

  Future<void> _verifyCode(String value) async {
    if (value.trim().length != 4 ||
        _sessionId == null ||
        _verifying ||
        !_validateForm()) {
      return;
    }

    setState(() => _verifying = true);
    final result = await _telegramVerificationService.verifyCode(
      sessionId: _sessionId!,
      code: value.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _verifying = false);

    if (!result.verified) {
      _showError(result.error ?? 'Kod tasdiqlanmadi.');
      return;
    }

    Navigator.of(context).pop(
      _PasswordResetResult(
        phoneDigits: _phoneController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.errorRed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t('reset_password'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                t('reset_password_hint'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              _PhoneNumberField(
                controller: _phoneController,
                label: t('phone'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: !_passwordVisible,
                decoration: InputDecoration(
                  labelText: t('new_password'),
                  prefixIcon: const Icon(Icons.lock_reset_rounded),
                  suffixIcon: IconButton(
                    tooltip: _passwordVisible
                        ? t('hide_password')
                        : t('show_password'),
                    onPressed: () {
                      setState(() => _passwordVisible = !_passwordVisible);
                    },
                    icon: Icon(
                      _passwordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPasswordController,
                obscureText: !_confirmVisible,
                decoration: InputDecoration(
                  labelText: t('confirm_password'),
                  prefixIcon: const Icon(Icons.verified_user_outlined),
                  suffixIcon: IconButton(
                    tooltip: _confirmVisible
                        ? t('hide_password')
                        : t('show_password'),
                    onPressed: () {
                      setState(() => _confirmVisible = !_confirmVisible);
                    },
                    icon: Icon(
                      _confirmVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.all(12),
                color: AppColors.primaryBlue.withValues(alpha: .06),
                borderColor: AppColors.primaryBlue.withValues(alpha: .18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.security_update_good_rounded,
                      color: AppColors.primaryBlue,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t('forgot_hint'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              if (_telegramOpened) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  onChanged: _verifyCode,
                  decoration: InputDecoration(
                    labelText: t('code'),
                    hintText: t('code_hint'),
                    prefixIcon: const Icon(Icons.mark_email_read_rounded),
                    suffixIcon: _verifying
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _telegramOpened ? null : _requestResetCode,
                  icon: Icon(
                    _submitting
                        ? Icons.hourglass_top_rounded
                        : Icons.send_rounded,
                  ),
                  label: Text(t('get_code')),
                ),
              ),
              if (_telegramOpened && _botLink != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openTelegramBot(_botLink!),
                    icon: const Icon(Icons.telegram_rounded),
                    label: Text(t('open_bot_again')),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneNumberField extends StatelessWidget {
  const _PhoneNumberField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(
            Icons.phone_rounded,
            size: 20,
            color: isDark ? const Color(0xFFCBD5E1) : AppColors.muted,
          ),
          const SizedBox(width: 10),
          const Text(
            '+998',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          Container(
            width: 1,
            height: 26,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: isDark ? const Color(0xFF334155) : AppColors.border,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              decoration: InputDecoration(
                hintText: label,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({required this.language, required this.onChanged});

  final AppLanguage language;
  final ValueChanged<AppLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final picked = await showModalBottomSheet<AppLanguage>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    studentText(language, 'language'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    studentText(language, 'language_picker_hint'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ...AppLanguage.values.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => Navigator.of(context).pop(item),
                          child: Ink(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: item == language
                                  ? AppColors.primaryBlue.withValues(alpha: .08)
                                  : null,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: item == language
                                    ? AppColors.primaryBlue.withValues(
                                        alpha: .28,
                                      )
                                    : (isDark
                                          ? const Color(0xFF334155)
                                          : AppColors.border),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: item == language
                                        ? AppColors.primaryBlue.withValues(
                                            alpha: .12,
                                          )
                                        : AppColors.background,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Text(
                                      item.shortLabel,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.label,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        languageOptionDescription(
                                          language,
                                          item,
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: AppColors.muted),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  item == language
                                      ? Icons.check_circle_rounded
                                      : Icons.chevron_right_rounded,
                                  color: item == language
                                      ? AppColors.primaryBlue
                                      : AppColors.muted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : AppColors.border,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: AppColors.navy.withValues(alpha: .05),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded, size: 18),
            const SizedBox(width: 8),
            Text(
              language.shortLabel,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}
