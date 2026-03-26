import 'package:flutter/material.dart';

class MicButton extends StatelessWidget {
  final VoidCallback onPressed;
  
  const MicButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      child: const Icon(Icons.mic),
    );
  }
}
