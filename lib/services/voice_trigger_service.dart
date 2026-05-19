import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/trigger_overlay.dart';
import 'voice_service.dart';
import '../main.dart'; 
import 'dart:convert';

class VoiceTriggerService {
  static final VoiceTriggerService _instance = VoiceTriggerService._internal();
  factory VoiceTriggerService() => _instance;
  VoiceTriggerService._internal();

  final SpeechToText _speech = SpeechToText();
  final VoiceService _voiceService = VoiceService();
  final MethodChannel _platform = const MethodChannel('com.yourapp/trigger');
  
  OverlayEntry? _overlayEntry;
  Function(String)? _onCaptured;
  bool _isTriggerActive = false;
  String _currentMode = 'two_finger_long';
  bool _sttInitialized = false;

  final Set<int> _activePointers = {};
  Timer? _twoFingerTimer;

  Future<void> init({required Function(String) onTextCaptured}) async {
    _onCaptured = onTextCaptured;
    
    if (kIsWeb) return;

    if (Platform.isAndroid) {
      await _initAndroidTriggers();
    }
  }



  Future<void> _initAndroidTriggers() async {
    try {
      _sttInitialized = await _speech.initialize(
        onError: (error) => debugPrint('Speech Error: $error'),
        onStatus: (status) => debugPrint('Speech Status: $status'),
      );
    } catch (e) {
      debugPrint('Speech-to-Text initialization failed: $e');
    }
    
    final prefs = await SharedPreferences.getInstance();
    _currentMode = prefs.getString('trigger_mode') ?? 'two_finger_long';
    bool backgroundEnabled = prefs.getBool('background_trigger_enabled') ?? false;

    if (_currentMode == 'power_triple' && backgroundEnabled) {
      _startNativeService();
    }

    _platform.setMethodCallHandler((call) async {
      if (call.method == "onPowerButtonTrigger") {
        if (!_isTriggerActive) _handleTriggerFired();
      }
      return null;
    });
  }

  Future<bool> requestPermissionsAndEnable() async {
    if (kIsWeb) return true;
    if (Platform.isWindows) return true;

    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.microphone,
        Permission.notification,
      ].request();

      if (statuses[Permission.microphone]!.isGranted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('background_trigger_enabled', true);
        
        if (_currentMode == 'power_triple') {
          _startNativeService();
        }
        return true;
      }
    }
    return false;
  }

  void _startNativeService() async {
    if (!Platform.isAndroid) return;
    try {
      await _platform.invokeMethod('startPowerService');
    } catch (e) {
      debugPrint('Failed to start Power Service: $e');
    }
  }

  Widget wrapWithTrigger({required Widget child}) {
    if (kIsWeb || !Platform.isAndroid) return child;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (_currentMode != 'two_finger_long') return;
        _activePointers.add(event.pointer);
        if (_activePointers.length == 2) _startTwoFingerTimer();
      },
      onPointerUp: (event) {
        _activePointers.remove(event.pointer);
        if (_activePointers.length < 2) _cancelTwoFingerTimer();
      },
      onPointerCancel: (event) {
        _activePointers.remove(event.pointer);
        _cancelTwoFingerTimer();
      },
      child: child,
    );
  }

  void _startTwoFingerTimer() {
    _twoFingerTimer?.cancel();
    _twoFingerTimer = Timer(const Duration(milliseconds: 1500), () {
      if (_activePointers.length == 2 && !_isTriggerActive) {
        _handleTriggerFired();
      }
    });
  }

  void _cancelTwoFingerTimer() {
    _twoFingerTimer?.cancel();
    _twoFingerTimer = null;
  }

  void _handleTriggerFired() async {
    if (_isTriggerActive) return;
    _isTriggerActive = true;
    
    // Haptic only for mobile
    if (!kIsWeb && Platform.isAndroid) {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(pattern: [0, 80, 100, 80]);
      }
    }

    _showOverlay();
    
    // Core voice capture (Media/Vichaar folder)
    await _voiceService.startRecording();
    
    if (Platform.isAndroid && _sttInitialized) {
      // Use STT for automatic silence detection on Android
      _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            _finishTrigger(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 2),
        listenOptions: SpeechListenOptions(listenMode: ListenMode.dictation),
      );
    } else {
      // On Windows or if STT is not available, we wait for a manual stop or a fixed time
      // For now, let's implement a 10s auto-stop or provide a way to stop it.
      // Since it's a trigger, maybe 15 seconds of capture is a good default for "Ideas".
      Timer(const Duration(seconds: 15), () {
        _finishTrigger("Thought captured (Windows/No-STT)");
      });
    }
  }

  void _finishTrigger(String text) async {
    if (!_isTriggerActive) return;
    _isTriggerActive = false;

    if (Platform.isAndroid) await _speech.stop();
    await _voiceService.stopAndQueue();
    _hideOverlay();

    if (text.isNotEmpty && _onCaptured != null) {
      _onCaptured!(text);
    }
  }

  void _showOverlay() {
    final overlayState = navigatorKey.currentState?.overlay;
    if (overlayState == null) return;
    _overlayEntry = OverlayEntry(builder: (context) => const TriggerOverlay());
    overlayState.insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}
