import 'package:flutter/material.dart';

class TriggerOverlay extends StatefulWidget {
  const TriggerOverlay({super.key});

  @override
  State<TriggerOverlay> createState() => _TriggerOverlayState();
}

class _TriggerOverlayState extends State<TriggerOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 50,
      left: 0,
      right: 0,
      child: Center(
        child: FadeTransition(
          opacity: Tween(begin: 0.4, end: 1.0).animate(_controller),
          child: ScaleTransition(
            scale: Tween(begin: 1.0, end: 1.2).animate(_controller),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.7),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.4),
                    blurRadius: 15,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 30),
            ),
          ),
        ),
      ),
    );
  }
}
