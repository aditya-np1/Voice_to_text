import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceService {
  final AudioRecorder _recorder = AudioRecorder();

  // This starts the recording
  Future<void> startRecording() async {
    // 1. Check if we have permission to record
    if (await _recorder.hasPermission()) {

      // 2. Get a directory to save the temporary audio file
      final directory = await getTemporaryDirectory();
      final String path = '${directory.path}/my_record.m4a';

      // 3. Start recording with default configuration
      const config = RecordConfig();
      await _recorder.start(config, path: path);

      print("Recording started at: $path");
    } else {
      print("Microphone permission denied");
    }
  }

  // This stops the recording and returns the path to the file
  Future<String?> stopRecording() async {
    final String? path = await _recorder.stop();
    print("Recording stopped. File saved at: $path");
    return path;
  }

  // This will save text to a file in the app's documents directory
  Future<void> saveToTextFile(String content) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/transcriptions.txt');
    
    // Append the new content to the file
    await file.writeAsString("$content\n", mode: FileMode.append);
    print("Saved text to: ${file.path}");
  }
}
