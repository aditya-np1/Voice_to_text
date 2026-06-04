import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  /// Deletes notes and their associated audio files older than [days]
  Future<int> deleteOldRecordings(int days) async {
    int deletedCount = 0;
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final vichaarDir = Directory('${docDir.path}/vichaar');
      
      if (!await vichaarDir.exists()) return 0;

      final thresholdDate = DateTime.now().subtract(Duration(days: days));

      await for (var entity in vichaarDir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final content = await entity.readAsString();
            final data = jsonDecode(content);
            final String timestampStr = data['timestamp'] ?? ''; // e.g. "2026-05-29 16:54:08"
            
            if (timestampStr.isNotEmpty) {
              final noteDate = DateTime.parse(timestampStr);
              if (noteDate.isBefore(thresholdDate)) {
                // Delete associated audio file if it exists
                final audioPath = data['audio_file'] as String?;
                if (audioPath != null && audioPath.isNotEmpty) {
                  final audioFile = File(audioPath);
                  if (await audioFile.exists()) {
                    await audioFile.delete();
                  }
                }
                // Delete the JSON file
                await entity.delete();
                deletedCount++;
              }
            }
          } catch (e) {
            debugPrint('Error parsing or deleting file: ${entity.path}, Error: $e');
          }
        }
      }
    } catch (e) {
      debugPrint("Error in deleteOldRecordings: $e");
    }
    return deletedCount;
  }
}
