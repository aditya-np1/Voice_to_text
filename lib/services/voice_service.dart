import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class _AudioJob {
  final String path;
  final Duration duration;
  _AudioJob(this.path, this.duration);
}

class VoiceService {
  final AudioRecorder _recorder = AudioRecorder();
  
  final String _apiKey = 'sk_j1oxq2cy_PZrhAk5huGj39UnWQjY4Co3u';

  final ValueNotifier<bool> isProcessing = ValueNotifier<bool>(false);
  int _activeTranscriptionCount = 0;
  DateTime? _recordingStartTime;
  
  final StreamController<String> _transcriptionController = StreamController<String>.broadcast();
  Stream<String> get transcriptions => _transcriptionController.stream;

  Future<void> startRecording() async {
    if (await _recorder.hasPermission()) {
      final directory = await getApplicationDocumentsDirectory();
      // Everything stays inside the 'Media' folder
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
    }
  }

  Future<void> stopAndQueue() async {
    final String? path = await _recorder.stop();
    final endTime = DateTime.now();
    
    if (path != null && _recordingStartTime != null) {
      final duration = endTime.difference(_recordingStartTime!);
      // Start transcription immediately in parallel background
      _startTranscriptionTask(_AudioJob(path, duration));
    }
    _recordingStartTime = null;
  }

  /// background task that retries on failure
  Future<void> _startTranscriptionTask(_AudioJob job) async {
    _activeTranscriptionCount++;
    isProcessing.value = true;

    int retryCount = 0;
    const maxRetries = 3;
    bool success = false;

    while (retryCount < maxRetries && !success) {
      try {
        final String? result = await _sendToSarvam(job.path);
        
        if (result != null && result.isNotEmpty) {
          _transcriptionController.add(result);
          await saveToTextFile(result);
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
    if (_activeTranscriptionCount == 0) {
      isProcessing.value = false;
    }
  }

  Future<String?> _sendToSarvam(String filePath) async {
    final url = Uri.parse('https://api.sarvam.ai/speech-to-text');
    
    var request = http.MultipartRequest('POST', url);
    request.headers['api-subscription-key'] = _apiKey;
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    request.fields['model'] = 'saaras:v3';
    request.fields['mode'] = 'translate';
    // request.fields['language_code'] = 'hi-IN'; // Uncomment if you want to force Hindi

    // Removed tight dynamic timeout.
    // Using a very generous 10-minute timeout to allow for slow uploads and long server processing.
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
    
    // Append the text one by one with a timestamp for better idea management
    final String timestamp = DateTime.now().toLocal().toString().split('.')[0];
    await file.writeAsString(
      "[$timestamp]\n$content\n\n", 
      mode: FileMode.append,
      flush: true
    );
  }

  void dispose() {
    _transcriptionController.close();
    isProcessing.dispose();
  }
}
