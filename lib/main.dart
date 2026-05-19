import 'package:flutter/material.dart';
import 'package:voice_to_text/screens/welcome_screen.dart';
import 'package:voice_to_text/utils/app_styles.dart';
import 'package:voice_to_text/services/voice_trigger_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:voice_to_text/screens/onboarding_screen.dart';
import 'package:voice_to_text/screens/home_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // HotKeyManager init (if needed in this version, handled natively)

  await Hive.initFlutter();
  await Hive.openBox('user_prefs');

  // Initialize the Voice Trigger Service
  final triggerService = VoiceTriggerService();
  await triggerService.init(onTextCaptured: (text) {
    debugPrint("Trigger Captured Text: $text");
  });

  runApp(VoiceToTextApp(triggerService: triggerService));
}

class VoiceToTextApp extends StatelessWidget {
  final VoiceTriggerService triggerService;
  const VoiceToTextApp({super.key, required this.triggerService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Vichar AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primaryPurple,
        useMaterial3: true,
      ),
      // Wrapper for Two-Finger Long Press (Android)
      builder: (context, child) {
        return triggerService.wrapWithTrigger(
          child: child ?? const SizedBox(),
        );
      },
      home: const SplashScreenLoader(),
    );
  }
}

class SplashScreenLoader extends StatefulWidget {
  const SplashScreenLoader({super.key});

  @override
  State<SplashScreenLoader> createState() => _SplashScreenLoaderState();
}

class _SplashScreenLoaderState extends State<SplashScreenLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 2), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);

    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        final prefsBox = Hive.box('user_prefs');
        final bool onboardingDone = prefsBox.get('onboarding_done', defaultValue: false);

        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => onboardingDone ? const HomeScreen() : const OnboardingScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: const Icon(Icons.psychology, size: 70, color: Colors.black),
              ),
              const SizedBox(height: 24),
              Text(
                "VICHAR AI",
                style: AppStyles.brandName.copyWith(color: Colors.black),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
