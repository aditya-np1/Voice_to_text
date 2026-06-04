import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:permission_handler/permission_handler.dart';
import 'voice_service.dart';

class VoiceTriggerService {
  static final VoiceTriggerService _instance = VoiceTriggerService._internal();
  factory VoiceTriggerService() => _instance;
  VoiceTriggerService._internal();

  final VoiceService _voiceService = VoiceService();
  final MethodChannel _platform = const MethodChannel('com.yourapp/trigger');
  
  Function(String)? _onCaptured;
  bool _isTriggerActive = false;
  String _currentMode = 'two_finger_long';

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
    final prefs = await SharedPreferences.getInstance();
    _currentMode = prefs.getString('trigger_mode') ?? 'power_triple';
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

    // Check if the app was launched by a background hardware button trigger
    try {
      final bool initialTrigger = await _platform.invokeMethod('checkInitialTrigger');
      if (initialTrigger && !_isTriggerActive) {
        _handleTriggerFired();
      }
    } catch (e) {
      debugPrint("Failed to check initial trigger: $e");
    }
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
        await prefs.setString('trigger_mode', 'power_triple');
        _currentMode = 'power_triple';
        
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
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(duration: 100);
      }
    }

    // Core voice capture (Media/Vichaar folder)
    await _voiceService.startRecording();
    
    Timer(const Duration(seconds: 15), () {
      _finishTrigger("Thought captured (Windows/No-STT)");
    });
  }

  void _finishTrigger(String text) async {
    if (!_isTriggerActive) return;
    _isTriggerActive = false;

    if (!kIsWeb && Platform.isAndroid) {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(duration: 100);
      }
    }

    await _voiceService.stopAndQueue();

    if (text.isNotEmpty && _onCaptured != null) {
      _onCaptured!(text);
    }
  }
}
