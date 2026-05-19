import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:voice_to_text/services/voice_service.dart';
import 'package:voice_to_text/utils/app_styles.dart';
import 'dart:math' as math;

class VoiceRecordingScreen extends StatefulWidget {
  const VoiceRecordingScreen({super.key});

  @override
  State<VoiceRecordingScreen> createState() => _VoiceRecordingScreenState();
}

class _VoiceRecordingScreenState extends State<VoiceRecordingScreen> with SingleTickerProviderStateMixin {
  final VoiceService _voiceService = VoiceService();
  final List<String> _transcriptions = []; 
  bool _isRecording = false;
  late AnimationController _waveController;
  StreamSubscription<String>? _subscription;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _isRecording = _voiceService.isRecording.value;
    _voiceService.isRecording.addListener(_onRecordingStateChanged);
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _subscription = _voiceService.transcriptions.listen((text) {
      setState(() {
        _transcriptions.add(text);
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    Timer(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onRecordingStateChanged() {
    if (mounted) {
      setState(() {
        _isRecording = _voiceService.isRecording.value;
      });
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _subscription?.cancel();
    _scrollController.dispose();
    _voiceService.isRecording.removeListener(_onRecordingStateChanged);
    super.dispose();
  }

  void _handleVoiceAction() async {
    if (!_voiceService.isRecording.value) {
      await _voiceService.startRecording();
    } else {
      await _voiceService.stopAndQueue();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: AppStyles.modernCard,
            child: Column(
              children: [
                Row(
                  children: [
                    _buildStatusIndicator(),
                    const SizedBox(width: 12),
                    ValueListenableBuilder<bool>(
                      valueListenable: _voiceService.isProcessing,
                      builder: (context, processing, _) {
                        String label = "IDLE";
                        if (_isRecording) label = "RECORDING";
                        else if (processing) label = "ANALYZING";
                        
                        return Text(
                          label,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.5,
                            color: AppColors.textGrey,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const Divider(height: 40),
                
                Expanded(
                  child: _transcriptions.isEmpty && !_isRecording
                      ? _buildPlaceholder()
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: _transcriptions.length,
                          itemBuilder: (context, index) {
                            return _buildTranscriptionBubble(_transcriptions[index]);
                          },
                        ),
                ),
                
                if (_isRecording) _buildModernVisualizer(),
              ],
            ),
          ),
        ),
        
        _buildBottomControls(),
      ],
    );
  }

  Widget _buildStatusIndicator() {
    return ValueListenableBuilder<bool>(
      valueListenable: _voiceService.isProcessing,
      builder: (context, processing, _) {
        Color color = Colors.green;
        if (_isRecording) color = const Color.fromARGB(255, 27, 185, 106);
        else if (processing) color = Colors.orange;
        
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mic_none, size: 48, color: AppColors.textGrey.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            "Your transcriptions will appear here",
            style: AppStyles.body.copyWith(color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptionBubble(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryPurple.withValues(alpha: 0.1)),
      ),
      child: Text(
        text,
        style: AppStyles.body.copyWith(color: AppColors.textBlack, fontSize: 17),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.only(bottom: 20, top: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Column(
        children: [
          Text(
            _isRecording ? "Listening..." : "Ready to capture",
            style: AppStyles.body.copyWith(fontWeight: FontWeight.bold, color: AppColors.textBlack),
          ),
          const SizedBox(height: 20),
          _buildMicButton(),
        ],
      ),
    );
  }

  Widget _buildMicButton() {
    return GestureDetector(
      onTap: _handleVoiceAction,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: _isRecording ? Colors.black : AppColors.primaryPurple,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (_isRecording ? Colors.black : AppColors.primaryPurple).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Icon(
          _isRecording ? Icons.stop_rounded : Icons.mic_none_rounded,
          color: Colors.white,
          size: 36,
        ),
      ),
    );
  }

  Widget _buildModernVisualizer() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(10, (index) {
          return AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              double animValue = math.sin((_waveController.value * 2 * math.pi) + (index * 0.6)).abs();
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 3,
                height: 15 + (animValue * 40),
                decoration: BoxDecoration(color: AppColors.primaryPurple, borderRadius: BorderRadius.circular(10)),
              );
            },
          );
        }),
      ),
    );
  }
}
