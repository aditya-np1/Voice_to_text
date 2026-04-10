import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:voice_to_text/screens/home_screen.dart';
import 'package:voice_to_text/utils/app_styles.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late PageController _pageController;

  final List<String> _quotes = [
    "The only place you outgrow yourself is inside your own thoughts.",
    "Dreams are not what you see in your sleep, but what doesn't let you sleep.",
    "An egg broken from outside ends a life. Broken from within, it begins one.",
    "We hesitate to spend three years building our dream, yet we give forty years to someone else’s."
  ];

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(duration: const Duration(seconds: 4), vsync: this)..repeat();
    _pageController = PageController();

    Future.delayed(const Duration(seconds: 3), _autoScroll);
  }

  void _autoScroll() {
    if (!mounted) return;
    int next = ((_pageController.page ?? 0).toInt() + 1) % _quotes.length;
    _pageController.animateToPage(
      next, 
      duration: const Duration(milliseconds: 1000), 
      curve: Curves.easeInOutExpo
    );
    Future.delayed(const Duration(seconds: 5), _autoScroll);
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            
            // LOGO: Modern Brain Network (as per provided image)
            Center(
              child: SizedBox(
                width: 180,
                height: 140,
                child: CustomPaint(
                  painter: NetworkBrainLogoPainter(animationValue: _mainController.value),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            Text(
              'VICHAR AI',
              style: AppStyles.brandName.copyWith(
                fontSize: 28,
                color: Colors.black,
                letterSpacing: 4,
                fontWeight: FontWeight.w900,
              ),
            ),
            
            const Spacer(),
            
            // Modern Flat Vector Illustration
            SizedBox(
              height: 280,
              width: double.infinity,
              child: AnimatedBuilder(
                animation: _mainController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: ModernFlatVectorPainter(_mainController.value),
                  );
                },
              ),
            ),

            const Spacer(),
            
            // Quote Slider
            SizedBox(
              height: 80,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _quotes.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      _quotes[index],
                      textAlign: TextAlign.center,
                      style: AppStyles.quoteStyle.copyWith(
                        fontSize: 16,
                        color: AppColors.textGrey,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 40),

            // Modern Action Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => const HomeScreen())
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 65),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: Text(
                  "GET STARTED", 
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, letterSpacing: 2)
                ),
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

class NetworkBrainLogoPainter extends CustomPainter {
  final double animationValue;
  NetworkBrainLogoPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final nodePaint = Paint()..style = PaintingStyle.fill;

    // Define more points to create a detailed brain network
    final List<Offset> points = [
      Offset(0.5, 0.1), Offset(0.4, 0.15), Offset(0.6, 0.15),
      Offset(0.3, 0.25), Offset(0.5, 0.3), Offset(0.7, 0.25),
      Offset(0.2, 0.4), Offset(0.4, 0.45), Offset(0.6, 0.45), Offset(0.8, 0.4),
      Offset(0.25, 0.6), Offset(0.45, 0.6), Offset(0.55, 0.6), Offset(0.75, 0.6),
      Offset(0.35, 0.75), Offset(0.5, 0.8), Offset(0.65, 0.75),
      Offset(0.45, 0.9), Offset(0.55, 0.9),
    ];

    final scaledPoints = points.map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList();

    // Complex connectivity
    final List<List<int>> connections = [
      [0, 1], [0, 2], [1, 2], [1, 3], [1, 4], [2, 4], [2, 5],
      [3, 6], [3, 4], [4, 7], [4, 8], [5, 9], [5, 4],
      [6, 10], [7, 10], [7, 11], [8, 12], [9, 13], [8, 13],
      [10, 14], [11, 14], [11, 15], [12, 15], [12, 16], [13, 16],
      [14, 17], [15, 17], [15, 18], [16, 18], [17, 18]
    ];

    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final Gradient gradient = LinearGradient(
      colors: [const Color(0xFF33CCFF), const Color(0xFF928DFF), const Color(0xFFFF33CC)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    paint.shader = gradient.createShader(rect);

    for (final conn in connections) {
      canvas.drawLine(scaledPoints[conn[0]], scaledPoints[conn[1]], paint);
    }

    for (int i = 0; i < scaledPoints.length; i++) {
      final p = scaledPoints[i];
      double pulse = math.sin(animationValue * 2 * math.pi + i) * 0.5 + 0.5;
      double radius = 2.0 + (pulse * 1.5);
      
      nodePaint.color = Color.lerp(const Color(0xFF33CCFF), const Color(0xFFFF33CC), i / scaledPoints.length)!;
      canvas.drawCircle(p, radius, nodePaint);
      
      if (i % 5 == 0) {
        final ringPaint = Paint()
          ..color = nodePaint.color.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5;
        canvas.drawCircle(p, radius + 3, ringPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ModernFlatVectorPainter extends CustomPainter {
  final double animation;
  ModernFlatVectorPainter(this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint();

    // Soft background accent
    paint.color = const Color(0xFFF9FAFF);
    canvas.drawCircle(center, size.width * 0.3, paint);

    // AI Core (Animated)
    final coreY = center.dy - 40 + (math.sin(animation * 2 * math.pi) * 12);
    final corePos = Offset(center.dx + 60, coreY);
    
    // Core Glow
    paint.color = AppColors.primaryPurple.withValues(alpha: 0.08);
    canvas.drawCircle(corePos, 55, paint);
    
    paint.color = AppColors.primaryPurple;
    canvas.drawCircle(corePos, 22, paint);

    // Person (Modern Minimalist)
    final personColor = const Color(0xFF3F3D56);
    paint.color = personColor;
    
    // Head
    canvas.drawCircle(Offset(center.dx - 50, center.dy + 10), 22, paint);
    
    // Body (Shoulder/Chest)
    final bodyPath = Path();
    bodyPath.moveTo(center.dx - 85, center.dy + 45);
    bodyPath.quadraticBezierTo(center.dx - 50, center.dy + 35, center.dx - 15, center.dy + 45);
    bodyPath.lineTo(center.dx - 15, center.dy + 130);
    bodyPath.lineTo(center.dx - 85, center.dy + 130);
    bodyPath.close();
    canvas.drawPath(bodyPath, paint);

    // Dynamic Connection Lines
    final linePaint = Paint()
      ..color = AppColors.primaryPurple.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(center.dx - 15, center.dy + 40);
    path.quadraticBezierTo(center.dx + 25, center.dy - 10, corePos.dx - 30, corePos.dy);
    canvas.drawPath(path, linePaint);

    // Floating particles around AI
    for (int i = 0; i < 5; i++) {
      double t = (animation + i * 0.2) % 1.0;
      double angle = i * 72 * math.pi / 180 + (animation * 0.5);
      double dist = 45 + (t * 25);
      double px = corePos.dx + math.cos(angle) * dist;
      double py = corePos.dy + math.sin(angle) * dist;
      
      paint.color = AppColors.primaryPurple.withValues(alpha: 1.0 - t);
      canvas.drawCircle(Offset(px, py), 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
