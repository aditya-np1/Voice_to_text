import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
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

  final List<_AudioJob> _audioQueue = [];
  final ValueNotifier<bool> isProcessing = ValueNotifier<bool>(false);
  DateTime? _recordingStartTime;
  
  final StreamController<String> _transcriptionController = StreamController<String>.broadcast();
  Stream<String> get transcriptions => _transcriptionController.stream;

  Future<void> startRecording() async {
    if (await _recorder.hasPermission()) {
      final directory = await getApplicationDocumentsDirectory();
      final String vichaarPath = '${directory.path}/Vichaar';
      
      final Directory vichaarDir = Directory(vichaarPath);
      if (!await vichaarDir.exists()) {
        await vichaarDir.create(recursive: true);
      }

      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String path = '$vichaarPath/recording_$timestamp.wav';

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
      _audioQueue.add(_AudioJob(path, duration));
      _processQueue();
    }
    _recordingStartTime = null;
  }

  Future<void> _processQueue() async {
    if (isProcessing.value || _audioQueue.isEmpty) return;

    isProcessing.value = true;

    while (_audioQueue.isNotEmpty) {
      final job = _audioQueue.removeAt(0);
      final String? result = await _sendToSarvam(job.path, job.duration);
      
      if (result != null && result.isNotEmpty) {
        _transcriptionController.add(result);
        await saveToTextFile(result);
      }
    }

    isProcessing.value = false;
  }

  Future<String?> _sendToSarvam(String filePath, Duration audioDuration) async {
    final url = Uri.parse('https://api.sarvam.ai/speech-to-text');
    try {
      var request = http.MultipartRequest('POST', url);
      request.headers['api-subscription-key'] = _apiKey;
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      request.fields['model'] = 'saaras:v3';
      request.fields['mode'] = 'translate';

      // Dynamic timeout: 2x the audio length, with a minimum of 30s and max of 5 mins
      final timeoutSeconds = math.max(30, math.min(300, audioDuration.inSeconds * 2));
      
      var streamedResponse = await request.send().timeout(
          Duration(seconds: timeoutSeconds));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['transcript'];
      }
    } on TimeoutException catch (_) {
      debugPrint("Transcription Error: Upload timed out after ${audioDuration.inSeconds * 2}s. Check your internet.");
    } catch (e) {
      debugPrint("Transcription Error: $e");
    }
    return null;
  }

  Future<void> saveToTextFile(String content) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/transcriptions.txt');
    await file.writeAsString("${DateTime.now()}: $content\n", mode: FileMode.append);
  }

  void dispose() {
    _transcriptionController.close();
    isProcessing.dispose();
  }
}
