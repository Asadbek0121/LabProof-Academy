import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_language.dart';

class StudentOnboarding extends StatefulWidget {
  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final VoidCallback onFinished;
  final VoidCallback onSignIn;
  final VoidCallback onCreateAccount;

  const StudentOnboarding({
    super.key,
    required this.language,
    required this.onLanguageChanged,
    required this.onFinished,
    required this.onSignIn,
    required this.onCreateAccount,
  });

  @override
  State<StudentOnboarding> createState() => _StudentOnboardingState();
}

class _StudentOnboardingState extends State<StudentOnboarding> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  String _t(String key) => studentText(widget.language, key);

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onFinished();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            if (_currentPage < 4)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: SizedBox(
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Right: Skip button
                      Align(
                        alignment: Alignment.centerRight,
                        child: AnimatedOpacity(
                          opacity: _currentPage < 3 ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: IgnorePointer(
                            ignoring: _currentPage >= 3,
                            child: TextButton(
                              onPressed: widget.onFinished,
                              child: Text(
                                _t('onboarding_skip'),
                                style: const TextStyle(
                                  color: Color(0xFF7C3AED),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Center: Page count + Dots
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_currentPage + 1} of 4',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (index) => _buildDot(index, isDark)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // PageView (Expanded to take available space)
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _OnboardingSlide(
                    imagePath: 'assets/images/onboarding_1.png',
                    title: _t('onboarding_slide1_title'),
                    subtitle: _t('onboarding_slide1_subtitle'),
                    isDark: isDark,
                  ),
                  _OnboardingSlide(
                    imagePath: 'assets/images/onboarding_2.png',
                    title: _t('onboarding_slide2_title'),
                    subtitle: _t('onboarding_slide2_subtitle'),
                    isDark: isDark,
                  ),
                  _OnboardingSlide(
                    imagePath: 'assets/images/onboarding_3.png',
                    title: _t('onboarding_slide3_title'),
                    subtitle: _t('onboarding_slide3_subtitle'),
                    isDark: isDark,
                  ),
                  _AuthChoiceSlide(
                    isDark: isDark,
                    language: widget.language,
                    onSignIn: widget.onSignIn,
                    onCreateAccount: widget.onCreateAccount,
                    onBack: _prevPage,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Bottom Navigation Bar
            if (_currentPage < 4)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back Button (Circular)
                    AnimatedOpacity(
                      opacity: _currentPage > 0 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: _currentPage == 0,
                        child: InkWell(
                          onTap: _prevPage,
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Next / Get Started Button (Pill or Circle shape based on page index)
                    AnimatedOpacity(
                      opacity: _currentPage < 3 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: _currentPage >= 3,
                        child: InkWell(
                          onTap: _nextPage,
                          borderRadius: BorderRadius.circular(28),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            height: 56,
                            padding: EdgeInsets.symmetric(
                              horizontal: _currentPage == 2 ? 32 : 16,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_currentPage == 2) ...[
                                  Text(
                                    _t('onboarding_get_started'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
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
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index, bool isDark) {
    if (_currentPage > 3) return const SizedBox();
    final isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive 
            ? const Color(0xFF7C3AED) 
            : (isDark ? Colors.white24 : const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _AuthChoiceSlide extends StatelessWidget {
  final bool isDark;
  final AppLanguage language;
  final VoidCallback onSignIn;
  final VoidCallback onCreateAccount;
  final VoidCallback onBack;

  const _AuthChoiceSlide({
    required this.isDark,
    required this.language,
    required this.onSignIn,
    required this.onCreateAccount,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isUz = language == AppLanguage.uzLatin || language == AppLanguage.uzCyrillic;
    final double screenHeight = MediaQuery.of(context).size.height;
    
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Text Header (with horizontal padding)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: screenHeight < 750 ? 4 : (screenHeight < 880 ? 10 : 16)),
                SizedBox(height: screenHeight < 750 ? 6 : (screenHeight < 880 ? 12 : 20)),
                RichText(
                  text: TextSpan(
                    children: _parseTitleMarkup(
                      studentText(language, 'onboarding_welcome'),
                      TextStyle(
                        fontSize: screenHeight < 750 ? 22 : (screenHeight < 880 ? 25 : 30),
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        height: 1.2,
                      ),
                      TextStyle(
                        fontSize: screenHeight < 750 ? 22 : (screenHeight < 880 ? 25 : 30),
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF7C3AED),
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: screenHeight < 750 ? 4 : 8),
                // Short purple line indicator
                Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                SizedBox(height: screenHeight < 750 ? 6 : (screenHeight < 880 ? 8 : 12)),
                Text(
                  studentText(language, 'onboarding_journey'),
                  style: TextStyle(
                    fontSize: screenHeight < 750 ? 12 : (screenHeight < 880 ? 13.5 : 15),
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: screenHeight < 600 ? 12 : (screenHeight < 780 ? 20 : 28)),
          
          // 2. 3D Welcome Illustration - NO horizontal padding (spans full width of the screen)
          SizedBox(
            height: screenHeight < 600 
                ? 110 
                : (screenHeight < 780 
                    ? 135 
                    : 170),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ScientificDecorationPainter(isDark: isDark),
                    ),
                  ),
                  Transform.scale(
                    scale: screenHeight < 600 ? 1.4 : (screenHeight < 780 ? 1.6 : 1.65), // Perfect sweet spot
                    child: Image.asset(
                      'assets/images/onboarding_welcome.png',
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        final double fallbackSize = screenHeight < 600 
                            ? 110 
                            : (screenHeight < 780 
                                ? 135 
                                : 170);
                        return Container(
                          width: fallbackSize,
                          height: fallbackSize,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF162440) : Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.biotech_rounded,
                            size: fallbackSize * 0.55,
                            color: const Color(0xFF7C3AED),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: screenHeight < 600 ? 16 : (screenHeight < 780 ? 24 : 32)),
          
          // 3. Action Buttons & Telegram Banner (with horizontal padding)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kirish (Sign In) Button with subtext
                InkWell(
                  onTap: onSignIn,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: screenHeight < 750 ? 10 : (screenHeight < 880 ? 12 : 16),
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED), // Beautiful luxury violet theme color
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                studentText(language, 'login'),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: screenHeight < 750 ? 14 : 16,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                studentText(language, 'sign_in_desc'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontWeight: FontWeight.w500,
                                  fontSize: screenHeight < 750 ? 10.5 : 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: screenHeight < 750 ? 6 : (screenHeight < 880 ? 8 : 12)),
                
                // Ro'yxatdan o'tish Outline Button with subtext
                InkWell(
                  onTap: onCreateAccount,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: screenHeight < 750 ? 10 : (screenHeight < 880 ? 12 : 16),
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
                      border: Border.all(
                        color: isDark ? const Color(0xFF5B21B6) : const Color(0xFFDDD6FE), // Lavender border
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                studentText(language, 'create_account'),
                                style: TextStyle(
                                  color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF6D28D9),
                                  fontWeight: FontWeight.w800,
                                  fontSize: screenHeight < 750 ? 14 : 16,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                studentText(language, 'create_account_desc'),
                                style: TextStyle(
                                  color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                                  fontWeight: FontWeight.w500,
                                  fontSize: screenHeight < 750 ? 10.5 : 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF6D28D9),
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: screenHeight < 750 ? 8 : (screenHeight < 880 ? 12 : 16)),
                
                // Telegram banner note
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(screenHeight < 750 ? 10 : (screenHeight < 880 ? 12 : 16)),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.4) : const Color(0xFFF5F3FF), // Soft lavender bg
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFEDE9FE),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Original Telegram logo natively drawn via CustomPaint
                      SizedBox(
                        width: screenHeight < 750 ? 24 : 32,
                        height: screenHeight < 750 ? 24 : 32,
                        child: CustomPaint(
                          painter: _TelegramIconPainter(
                            color: const Color(0xFF229ED9), // Official Telegram Blue
                          ),
                        ),
                      ),
                      SizedBox(width: screenHeight < 750 ? 8 : 12),
                      Expanded(
                        child: Text(
                          studentText(language, 'telegram_onboarding_note'),
                          style: TextStyle(
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                            fontSize: screenHeight < 750 ? 10.5 : 12.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: screenHeight < 750 ? 12 : 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  final String imagePath;
  final String title;
  final String subtitle;
  final bool isDark;

  const _OnboardingSlide({
    required this.imagePath,
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Illustration area with scientific particles ──
        Expanded(
          flex: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Beautiful scientific molecules background decoration
              Positioned.fill(
                child: CustomPaint(
                  painter: _ScientificDecorationPainter(isDark: isDark),
                ),
              ),
              // 3D illustration on top (Responsive scale, fits container perfectly, zoomed 1.25x)
              Transform.scale(
                scale: 1.25,
                child: Image.asset(
                  imagePath,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.biotech_rounded,
                    size: 140,
                    color: const Color(0xFF7C3AED),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Text content ──
        Expanded(
          flex: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // Title parsed dynamically with <purple>...</purple> markup support
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: _parseTitleMarkup(
                        title,
                        TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                        const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? Colors.white60
                          : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

List<InlineSpan> _parseTitleMarkup(String text, TextStyle baseStyle, TextStyle purpleStyle) {
  final List<InlineSpan> spans = [];
  final cleanText = text.replaceAll('\\n', '\n');
  
  final RegExp regExp = RegExp(r'<purple>(.*?)</purple>');
  int lastMatchEnd = 0;
  
  for (final Match match in regExp.allMatches(cleanText)) {
    if (match.start > lastMatchEnd) {
      spans.add(TextSpan(
        text: cleanText.substring(lastMatchEnd, match.start),
        style: baseStyle,
      ));
    }
    spans.add(TextSpan(
      text: match.group(1),
      style: purpleStyle,
    ));
    lastMatchEnd = match.end;
  }
  
  if (lastMatchEnd < cleanText.length) {
    spans.add(TextSpan(
      text: cleanText.substring(lastMatchEnd),
      style: baseStyle,
    ));
  }
  
  return spans;
}

class _ScientificDecorationPainter extends CustomPainter {
  final bool isDark;
  const _ScientificDecorationPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = (isDark ? const Color(0xFF7C3AED).withValues(alpha: 0.15) : const Color(0xFFC084FC).withValues(alpha: 0.25))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final dotPaint = Paint()
      ..color = (isDark ? const Color(0xFFC084FC).withValues(alpha: 0.2) : const Color(0xFF7C3AED).withValues(alpha: 0.3))
      ..style = PaintingStyle.fill;

    // Molecular hexagons & connections
    // Hexagon 1: Top Left
    _drawHexagon(canvas, const Offset(60, 80), 25, strokePaint);
    canvas.drawLine(const Offset(85, 80), const Offset(110, 80), strokePaint);
    _drawHexagon(canvas, const Offset(135, 80), 25, strokePaint);
    
    // Hexagon 2: Bottom Right
    _drawHexagon(canvas, Offset(size.width - 70, size.height - 90), 22, strokePaint);
    canvas.drawLine(
      Offset(size.width - 92, size.height - 90),
      Offset(size.width - 115, size.height - 90),
      strokePaint,
    );

    // Floaties: tiny glowing circles/atoms
    canvas.drawCircle(const Offset(35, 180), 4, dotPaint);
    canvas.drawCircle(Offset(size.width - 45, 110), 5, dotPaint);
    canvas.drawCircle(Offset(75, size.height - 70), 3, dotPaint);
    canvas.drawCircle(Offset(size.width / 2 - 80, size.height / 2 + 60), 3.5, dotPaint);
    canvas.drawCircle(Offset(size.width / 2 + 90, size.height / 2 - 50), 4.5, dotPaint);

    // Plus signs for visual complexity
    _drawPlus(canvas, Offset(size.width - 75, 160), 10, strokePaint);
    _drawPlus(canvas, Offset(100, size.height - 140), 8, strokePaint);
  }

  void _drawHexagon(Canvas canvas, Offset center, double radius, Paint paint) {
    final Path path = Path();
    for (int i = 0; i < 6; i++) {
      double angle = i * 60 * math.pi / 180;
      double x = center.dx + radius * math.cos(angle);
      double y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawPlus(Canvas canvas, Offset center, double size, Paint paint) {
    canvas.drawLine(
      Offset(center.dx - size / 2, center.dy),
      Offset(center.dx + size / 2, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - size / 2),
      Offset(center.dx, center.dy + size / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Native CustomPainter for the official Telegram paper airplane ──
class _TelegramIconPainter extends CustomPainter {
  final Color color;
  _TelegramIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    // Symmetrical scale to fit the box
    final double scaleX = w;
    final double scaleY = h;

    // Define coordinates based on the exact 240x240 grid of the official Telegram logo
    final p1 = Offset(0.8375 * scaleX, 0.1542 * scaleY); // Top right tip
    final p2 = Offset(0.1583 * scaleX, 0.4792 * scaleY); // Left tip
    final p3 = Offset(0.4375 * scaleX, 0.6000 * scaleY); // Middle fold
    final p4 = Offset(0.7083 * scaleX, 0.8000 * scaleY); // Right bottom tip
    final p5 = Offset(0.4375 * scaleX, 0.8000 * scaleY); // Bottom fold tip
    final p6 = Offset(0.5542 * scaleX, 0.6833 * scaleY); // Inner fold third point

    // Path 1: Left Wing
    final path1 = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..close();

    // Path 2: Right Wing
    final path2 = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy)
      ..close();

    // Path 3: Middle Fold (the little bottom attachment)
    final path3 = Path()
      ..moveTo(p3.dx, p3.dy)
      ..lineTo(p5.dx, p5.dy)
      ..lineTo(p6.dx, p6.dy)
      ..close();

    canvas.drawPath(path1, paint);
    canvas.drawPath(path2, paint);
    canvas.drawPath(path3, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

