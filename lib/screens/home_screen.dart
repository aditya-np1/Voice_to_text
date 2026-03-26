import 'package:flutter/material.dart';
import '../services/voice_service.dart';
import '../widgets/mic_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final VoiceService _voiceService = VoiceService();
  String _statusText = "Press and Hold to Speak";
  bool _isRecording = false;

  void _handleVoiceAction() async {
    if (!_isRecording) {
      // START RECORDING
      await _voiceService.startRecording();
      setState(() {
        _isRecording = true;
        _statusText = "Recording... Release to stop";
      });
    } else {
      // STOP RECORDING
      String? path = await _voiceService.stopRecording();
      setState(() {
        _isRecording = false;
        _statusText = "Recording saved to $path";
      });
      
      // For now, we simulate a transcription and save it to a file
      if (path != null) {
         await _voiceService.saveToTextFile("Recorded audio at: $path");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice To Text'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isRecording ? Icons.graphic_eq : Icons.mic_none,
              size: 100,
              color: _isRecording ? Colors.red : Colors.grey,
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: MicButton(
        onPressed: _handleVoiceAction,
      ),
    );
  }
}
