import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_to_text/services/ai_routing_service.dart';


class _AudioJob {
  final String path;
  final Duration duration;
  _AudioJob(this.path, this.duration);
}

class VoiceService {
  // Singleton pattern to ensure global state consistency
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  
  // Secure: Removed hardcoded API key from client code. Managed on Django Proxy.
  final String _proxyUrl = kIsWeb 
      ? 'http://localhost:8000/api/transcribe' 
      : (Platform.isAndroid ? 'http://10.0.2.2:8000/api/transcribe' : 'http://localhost:8000/api/transcribe');

  final ValueNotifier<bool> isProcessing = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isRecording = ValueNotifier<bool>(false);
  int _activeTranscriptionCount = 0;
  DateTime? _recordingStartTime;
  
  final StreamController<String> _transcriptionController = StreamController<String>.broadcast();
  Stream<String> get transcriptions => _transcriptionController.stream;

  Future<void> startRecording() async {
    if (isRecording.value) return;

    if (await _recorder.hasPermission()) {
      final directory = await getApplicationDocumentsDirectory();
      // Strictly using 'Media' folder as requested for all project data
      final String mediaPath = '${directory.path}/Media';
      
      final Directory mediaDir = Directory(mediaPath);
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }

      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String path = '$mediaPath/recording_$timestamp.wav';

      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 24000,
        bitRate: 128000,
      );
      
      await _recorder.start(config, path: path);
      _recordingStartTime = DateTime.now();
      isRecording.value = true;
      debugPrint("Recording started: $path");
    }
  }

  Future<void> stopAndQueue() async {
    if (!isRecording.value) return;

    final String? path = await _recorder.stop();
    final endTime = DateTime.now();
    isRecording.value = false;
    
    if (path != null && _recordingStartTime != null) {
      final duration = endTime.difference(_recordingStartTime!);
      // Launch transcription in parallel background task
      _startTranscriptionTask(_AudioJob(path, duration));
    }
    _recordingStartTime = null;
  }

  Future<void> _neutralizeWavFile(String inputPath, String outputPath) async {
    try {
      final file = File(inputPath);
      final bytes = await file.readAsBytes();
      
      if (bytes.length < 44) return;
      
      final header = bytes.sublist(0, 44);
      final pcmBytes = bytes.sublist(44);
      final pcmData = ByteData.sublistView(pcmBytes);
      
      final int numSamples = pcmBytes.length ~/ 2;
      final double sampleRate = 24000.0;
      final double carrierFreq = 80.0; // 80Hz carrier frequency for ring modulation voice scramble
      
      final list16 = Int16List(numSamples);
      for (int i = 0; i < numSamples; i++) {
        int sample = pcmData.getInt16(i * 2, Endian.little);
        double t = i / sampleRate;
        double modulation = math.sin(2 * math.pi * carrierFreq * t);
        int scrambledSample = (sample * modulation).round();
        
        if (scrambledSample > 32767) scrambledSample = 32767;
        if (scrambledSample < -32768) scrambledSample = -32768;
        
        list16[i] = scrambledSample;
      }
      
      final outBytes = BytesBuilder();
      outBytes.add(header);
      
      final buffer = Uint8List(numSamples * 2);
      final outData = ByteData.sublistView(buffer);
      for (int i = 0; i < numSamples; i++) {
        outData.setInt16(i * 2, list16[i], Endian.little);
      }
      outBytes.add(buffer);
      
      await File(outputPath).writeAsBytes(outBytes.toBytes());
      debugPrint("Client-side voice neutralization complete: $outputPath");
    } catch (e) {
      debugPrint("Failed to scramble voice: $e");
      rethrow;
    }
  }

  /// Background worker that retries on failure and supports parallel tasks
  Future<void> _startTranscriptionTask(_AudioJob job) async {
    _activeTranscriptionCount++;
    isProcessing.value = true;

    // Neutralize voice locally on the phone before sending
    final String neutralizedPath = job.path.replaceAll('.wav', '_anon.wav');
    try {
      await _neutralizeWavFile(job.path, neutralizedPath);
    } catch (e) {
      debugPrint("Failed to neutralize voice locally, falling back to raw recording: $e");
    }
    final String fileToUpload = File(neutralizedPath).existsSync() ? neutralizedPath : job.path;

    int retryCount = 0;
    const maxRetries = 3;
    bool success = false;

    while (retryCount < maxRetries && !success) {
      try {
        final String? result = await _sendToSarvam(fileToUpload);
        
        if (result != null && result.isNotEmpty) {
          _transcriptionController.add(result);
          await saveToInbox(result, job.path);
          success = true;
        } else {
          throw Exception("Empty result or API error");
        }
      } catch (e) {
        retryCount++;
        debugPrint("Transcription attempt $retryCount failed for ${job.path}: $e");
        if (retryCount < maxRetries) {
          // Wait longer between each retry (Backoff)
          await Future.delayed(Duration(seconds: 5 * retryCount));
        }
      }
    }

    _activeTranscriptionCount--;
    // Only set processing to false if no other tasks are running
    if (_activeTranscriptionCount == 0) {
      isProcessing.value = false;
    }
    
    // Clean up local neutralized file from disk
    try {
      final anonFile = File(neutralizedPath);
      if (await anonFile.exists()) {
        await anonFile.delete();
        debugPrint("Deleted local neutralized audio: $neutralizedPath");
      }
    } catch (e) {
      debugPrint("Failed to clean up neutralized file: $e");
    }
  }

  Future<String?> _sendToSarvam(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    final dynamicUrl = prefs.getString('api_url') ?? _proxyUrl;
    final url = Uri.parse(dynamicUrl);
    
    var request = http.MultipartRequest('POST', url);
    // Secure: API key is now securely handled on the backend proxy server
    request.files.add(await http.MultipartFile.fromPath('audio', filePath));
    request.fields['model'] = 'saaras:v3';
    request.fields['mode'] = 'translate';

    // Generous 10-minute timeout for slow connections
    var streamedResponse = await request.send().timeout(const Duration(minutes: 10));
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['transcript'];
    } else {
      throw Exception("Sarvam API returned ${response.statusCode}: ${response.body}");
    }
  }

  Future<void> saveToTextFile(String content) async {
    final directory = await getApplicationDocumentsDirectory();
    // Strictly saved inside Project/Media folder
    final file = File('${directory.path}/Media/transcriptions.txt');
    
    final String timestamp = DateTime.now().toLocal().toString().split('.')[0];
    // Use append mode to keep all responses one after another
    await file.writeAsString(
      "[$timestamp]\n$content\n\n", 
      mode: FileMode.append,
      flush: true
    );
  }

  Future<void> saveToInbox(String content, String audioPath) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      
      // Ensure Media folder exists
      final mediaDir = Directory('${directory.path}/Media');
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }
      
      final file = File('${directory.path}/Media/transcriptions.jsonl');
      
      final String timestamp = DateTime.now().toLocal().toString().split('.')[0];
      final noteData = {
        'text': content,
        'timestamp': timestamp,
        'audio_file': audioPath,
      };
      
      // Save in .jsonl (JSON Lines) format
      await file.writeAsString(
        '${jsonEncode(noteData)}\n',
        mode: FileMode.append,
        flush: true,
      );
      
      debugPrint("Saved note to transcriptions.jsonl. Triggering AI Routing...");
      
      // Run AI Routing Service to automatically organize notes into dynamic folders
      await AiRoutingService().processInbox();
      
      // Save standard raw txt backup as well
      await saveToTextFile(content);
    } catch (e) {
      debugPrint("Error in saveToInbox: $e");
    }
  }

  void dispose() {
    _transcriptionController.close();
    isProcessing.dispose();
    isRecording.dispose();
  }
}
