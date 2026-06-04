import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

class AiRoutingService {
  static final AiRoutingService _instance = AiRoutingService._internal();
  factory AiRoutingService() => _instance;
  AiRoutingService._internal();

  /// 6-Dimensional Latent Semantic Space corresponding to:
  /// Dim 0: Idea / Sparks / Creativity
  /// Dim 1: Study / Learning / Education
  /// Dim 2: Personal / Feelings / Food / Travel
  /// Dim 3: Work / Office / Projects / Professional
  /// Dim 4: Shopping / Tasks / Purchase
  /// Dim 5: Content / Media / Writing / Creation
  static const Map<String, List<double>> _semanticVocabulary = {
    // Idea & Creative Concepts
    'idea': [1.0, 0.1, 0.0, 0.2, 0.0, 0.4],
    'ideas': [1.0, 0.1, 0.0, 0.2, 0.0, 0.4],
    'spark': [1.0, 0.0, 0.2, 0.0, 0.0, 0.5],
    'sparks': [1.0, 0.0, 0.2, 0.0, 0.0, 0.5],
    'think': [0.8, 0.3, 0.3, 0.2, 0.0, 0.2],
    'thought': [0.8, 0.3, 0.4, 0.1, 0.0, 0.2],
    'thoughts': [0.8, 0.3, 0.4, 0.1, 0.0, 0.2],
    'brainstorm': [1.0, 0.2, 0.0, 0.5, 0.0, 0.4],
    'brainstorming': [1.0, 0.2, 0.0, 0.5, 0.0, 0.4],
    'startup': [0.9, 0.1, 0.1, 0.8, 0.1, 0.3],
    'business': [0.6, 0.1, 0.1, 0.9, 0.2, 0.2],
    'app': [0.8, 0.2, 0.1, 0.6, 0.1, 0.4],
    'software': [0.7, 0.3, 0.0, 0.7, 0.1, 0.3],
    'create': [0.9, 0.2, 0.1, 0.4, 0.0, 0.8],
    'creating': [0.9, 0.2, 0.1, 0.4, 0.0, 0.8],
    'creative': [1.0, 0.2, 0.2, 0.3, 0.0, 0.8],
    'concept': [1.0, 0.4, 0.0, 0.3, 0.0, 0.4],
    'innovation': [1.0, 0.2, 0.0, 0.6, 0.0, 0.3],
    'innovative': [1.0, 0.2, 0.0, 0.6, 0.0, 0.3],
    'dream': [0.9, 0.1, 0.5, 0.0, 0.0, 0.4],
    'dreams': [0.9, 0.1, 0.5, 0.0, 0.0, 0.4],
    'future': [0.8, 0.3, 0.3, 0.4, 0.0, 0.3],
    'imagine': [1.0, 0.2, 0.3, 0.1, 0.0, 0.6],
    
    // Study & Learning
    'study': [0.1, 1.0, 0.0, 0.2, 0.0, 0.1],
    'studying': [0.1, 1.0, 0.0, 0.2, 0.0, 0.1],
    'learn': [0.2, 1.0, 0.1, 0.3, 0.0, 0.2],
    'learning': [0.2, 1.0, 0.1, 0.3, 0.0, 0.2],
    'read': [0.2, 0.9, 0.2, 0.2, 0.0, 0.4],
    'reading': [0.2, 0.9, 0.2, 0.2, 0.0, 0.4],
    'exam': [0.0, 1.0, 0.1, 0.4, 0.0, 0.0],
    'exams': [0.0, 1.0, 0.1, 0.4, 0.0, 0.0],
    'test': [0.1, 0.9, 0.1, 0.5, 0.0, 0.1],
    'book': [0.1, 1.0, 0.2, 0.1, 0.0, 0.3],
    'books': [0.1, 1.0, 0.2, 0.1, 0.0, 0.3],
    'subject': [0.1, 1.0, 0.0, 0.2, 0.0, 0.1],
    'revision': [0.0, 1.0, 0.0, 0.3, 0.0, 0.1],
    'revised': [0.0, 1.0, 0.0, 0.3, 0.0, 0.1],
    'course': [0.1, 1.0, 0.0, 0.4, 0.0, 0.2],
    'class': [0.0, 1.0, 0.2, 0.3, 0.0, 0.1],
    'classes': [0.0, 1.0, 0.2, 0.3, 0.0, 0.1],
    'lecture': [0.0, 1.0, 0.0, 0.4, 0.0, 0.2],
    'school': [0.0, 1.0, 0.4, 0.1, 0.0, 0.0],
    'college': [0.1, 1.0, 0.3, 0.2, 0.0, 0.1],
    'university': [0.1, 1.0, 0.2, 0.3, 0.0, 0.1],
    'research': [0.5, 0.9, 0.0, 0.6, 0.0, 0.5],
    'science': [0.3, 1.0, 0.0, 0.3, 0.0, 0.2],
    'math': [0.0, 1.0, 0.0, 0.2, 0.0, 0.0],
    'history': [0.0, 1.0, 0.3, 0.1, 0.0, 0.3],
    'assignment': [0.1, 0.9, 0.0, 0.6, 0.0, 0.2],
    'homework': [0.0, 1.0, 0.2, 0.2, 0.0, 0.0],
    'notes': [0.3, 0.8, 0.2, 0.5, 0.1, 0.4],
    'note': [0.3, 0.8, 0.2, 0.5, 0.1, 0.4],
    
    // Personal, Experiences & Food
    'family': [0.0, 0.1, 1.0, 0.0, 0.1, 0.0],
    'restaurant': [0.0, 0.0, 1.0, 0.1, 0.4, 0.0],
    'feel': [0.3, 0.2, 1.0, 0.1, 0.0, 0.4],
    'feeling': [0.3, 0.2, 1.0, 0.1, 0.0, 0.4],
    'feelings': [0.3, 0.2, 1.0, 0.1, 0.0, 0.4],
    'experience': [0.4, 0.3, 0.9, 0.3, 0.0, 0.3],
    'heart': [0.2, 0.0, 1.0, 0.0, 0.0, 0.3],
    'memory': [0.3, 0.3, 1.0, 0.1, 0.0, 0.2],
    'memories': [0.3, 0.3, 1.0, 0.1, 0.0, 0.2],
    'home': [0.1, 0.1, 1.0, 0.0, 0.1, 0.0],
    'friend': [0.0, 0.1, 1.0, 0.1, 0.1, 0.1],
    'friends': [0.0, 0.1, 1.0, 0.1, 0.1, 0.1],
    'dinner': [0.0, 0.0, 1.0, 0.1, 0.4, 0.0],
    'lunch': [0.0, 0.0, 1.0, 0.1, 0.4, 0.0],
    'breakfast': [0.0, 0.0, 1.0, 0.1, 0.4, 0.0],
    'food': [0.0, 0.0, 1.0, 0.0, 0.5, 0.0],
    'eat': [0.0, 0.0, 1.0, 0.0, 0.3, 0.0],
    'love': [0.4, 0.0, 1.0, 0.0, 0.0, 0.3],
    'sad': [0.0, 0.0, 1.0, 0.0, 0.0, 0.2],
    'happy': [0.2, 0.1, 1.0, 0.1, 0.0, 0.2],
    'life': [0.5, 0.3, 0.9, 0.3, 0.0, 0.3],
    'travel': [0.3, 0.2, 0.9, 0.1, 0.3, 0.3],
    'trip': [0.2, 0.1, 0.9, 0.0, 0.3, 0.2],
    'vacation': [0.1, 0.0, 1.0, 0.0, 0.2, 0.1],
    'belonging': [0.0, 0.0, 1.0, 0.1, 0.2, 0.0],
    'belongings': [0.0, 0.0, 1.0, 0.1, 0.2, 0.0],
    'personal': [0.1, 0.1, 1.0, 0.1, 0.0, 0.2],
    'myself': [0.1, 0.1, 1.0, 0.0, 0.0, 0.1],
    'daily': [0.1, 0.2, 0.8, 0.3, 0.1, 0.2],
    'log': [0.2, 0.2, 0.6, 0.5, 0.1, 0.4],
    
    // Work & Professional
    'meeting': [0.1, 0.1, 0.0, 1.0, 0.0, 0.2],
    'meetings': [0.1, 0.1, 0.0, 1.0, 0.0, 0.2],
    'call': [0.0, 0.0, 0.2, 0.9, 0.1, 0.2],
    'calls': [0.0, 0.0, 0.2, 0.9, 0.1, 0.2],
    'boss': [0.0, 0.0, 0.1, 1.0, 0.0, 0.0],
    'office': [0.0, 0.1, 0.2, 1.0, 0.0, 0.1],
    'project': [0.5, 0.3, 0.0, 1.0, 0.0, 0.4],
    'projects': [0.5, 0.3, 0.0, 1.0, 0.0, 0.4],
    'deadline': [0.1, 0.3, 0.0, 1.0, 0.0, 0.1],
    'work': [0.1, 0.2, 0.1, 1.0, 0.1, 0.2],
    'job': [0.0, 0.1, 0.2, 1.0, 0.1, 0.1],
    'company': [0.3, 0.1, 0.1, 1.0, 0.0, 0.1],
    'manager': [0.0, 0.1, 0.1, 1.0, 0.0, 0.1],
    'client': [0.1, 0.0, 0.1, 1.0, 0.2, 0.1],
    'team': [0.2, 0.2, 0.3, 1.0, 0.0, 0.1],
    'task': [0.1, 0.2, 0.0, 1.0, 0.3, 0.1],
    'tasks': [0.1, 0.2, 0.0, 1.0, 0.3, 0.1],
    'email': [0.0, 0.1, 0.1, 0.9, 0.0, 0.3],
    'emails': [0.0, 0.1, 0.1, 0.9, 0.0, 0.3],
    'presentation': [0.3, 0.3, 0.0, 0.9, 0.0, 0.5],
    'marketing': [0.4, 0.1, 0.0, 0.8, 0.2, 0.6],
    'sales': [0.1, 0.1, 0.0, 0.8, 0.4, 0.2],
    'urgent': [0.1, 0.2, 0.2, 0.8, 0.1, 0.2],
    'important': [0.3, 0.3, 0.3, 0.7, 0.1, 0.3],
    
    // Shopping & Tasks
    'buy': [0.0, 0.0, 0.2, 0.1, 1.0, 0.0],
    'grocery': [0.0, 0.0, 0.3, 0.0, 1.0, 0.0],
    'groceries': [0.0, 0.0, 0.3, 0.0, 1.0, 0.0],
    'shopping': [0.0, 0.0, 0.3, 0.0, 1.0, 0.0],
    'store': [0.0, 0.0, 0.2, 0.1, 1.0, 0.0],
    'market': [0.0, 0.1, 0.2, 0.2, 1.0, 0.0],
    'price': [0.0, 0.1, 0.0, 0.2, 1.0, 0.0],
    'cost': [0.0, 0.1, 0.0, 0.3, 1.0, 0.0],
    'purchase': [0.0, 0.0, 0.1, 0.2, 1.0, 0.0],
    'item': [0.0, 0.0, 0.1, 0.2, 0.9, 0.1],
    'items': [0.0, 0.0, 0.1, 0.2, 0.9, 0.1],
    'list': [0.1, 0.2, 0.1, 0.4, 0.8, 0.2],
    'sell': [0.1, 0.0, 0.1, 0.4, 0.9, 0.1],
    'product': [0.3, 0.1, 0.1, 0.5, 0.8, 0.2],
    'products': [0.3, 0.1, 0.1, 0.5, 0.8, 0.2],
    'pay': [0.0, 0.0, 0.1, 0.3, 1.0, 0.0],
    'cash': [0.0, 0.0, 0.1, 0.2, 1.0, 0.0],
    'card': [0.0, 0.0, 0.2, 0.2, 0.9, 0.0],
    'mall': [0.0, 0.0, 0.4, 0.0, 1.0, 0.1],
    
    // Content & Media Creation
    'script': [0.4, 0.1, 0.0, 0.1, 0.0, 1.0],
    'scripts': [0.4, 0.1, 0.0, 0.1, 0.0, 1.0],
    'video': [0.3, 0.1, 0.1, 0.2, 0.0, 1.0],
    'videos': [0.3, 0.1, 0.1, 0.2, 0.0, 1.0],
    'post': [0.2, 0.1, 0.2, 0.3, 0.1, 1.0],
    'posts': [0.2, 0.1, 0.2, 0.3, 0.1, 1.0],
    'blog': [0.3, 0.1, 0.1, 0.2, 0.0, 1.0],
    'blogs': [0.3, 0.1, 0.1, 0.2, 0.0, 1.0],
    'content': [0.4, 0.2, 0.1, 0.4, 0.1, 1.0],
    'draft': [0.4, 0.2, 0.0, 0.3, 0.0, 1.0],
    'drafts': [0.4, 0.2, 0.0, 0.3, 0.0, 1.0],
    'write': [0.4, 0.4, 0.1, 0.3, 0.0, 0.9],
    'writing': [0.4, 0.4, 0.1, 0.3, 0.0, 0.9],
    'writer': [0.3, 0.3, 0.1, 0.2, 0.0, 1.0],
    'edit': [0.2, 0.2, 0.0, 0.4, 0.0, 0.9],
    'editing': [0.2, 0.2, 0.0, 0.4, 0.0, 0.9],
    'youtube': [0.3, 0.1, 0.2, 0.3, 0.0, 1.0],
    'channel': [0.2, 0.1, 0.1, 0.4, 0.0, 0.9],
    'social': [0.1, 0.1, 0.5, 0.4, 0.1, 0.8],
    'media': [0.2, 0.2, 0.3, 0.5, 0.1, 0.9],
    'publish': [0.3, 0.2, 0.0, 0.5, 0.0, 0.8],
    'podcast': [0.3, 0.2, 0.2, 0.2, 0.0, 1.0],
    'episode': [0.2, 0.1, 0.2, 0.1, 0.0, 1.0],
  };

  /// Computes a semantic vector for any given text (phrase or paragraph)
  /// by averaging individual word embedding vectors from the Latent Space.
  List<double> getEmbedding(String text) {
    // Tokenization and normalization
    final words = text.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
        
    final List<double> docVector = List.filled(6, 0.0);
    if (words.isEmpty) {
      // Regularization baseline
      return List.filled(6, 0.01);
    }
    
    int activeWords = 0;
    
    for (final word in words) {
      if (_semanticVocabulary.containsKey(word)) {
        final vector = _semanticVocabulary[word]!;
        for (int i = 0; i < 6; i++) {
          docVector[i] += vector[i];
        }
        activeWords++;
      } else {
        // Semantic Stemming
        String singular = word;
        if (word.endsWith('s') && word.length > 2) {
          singular = word.substring(0, word.length - 1);
        } else if (word.endsWith('ing') && word.length > 4) {
          singular = word.substring(0, word.length - 3);
        }
        
        if (_semanticVocabulary.containsKey(singular)) {
          final vector = _semanticVocabulary[singular]!;
          for (int i = 0; i < 6; i++) {
            docVector[i] += vector[i];
          }
          activeWords++;
        }
      }
    }
    
    if (activeWords > 0) {
      for (int i = 0; i < 6; i++) {
        docVector[i] /= activeWords;
      }
    }
    
    // Add small epsilon for numerical stability and zero-vector regularization
    for (int i = 0; i < 6; i++) {
      docVector[i] += 0.01;
    }
    
    return docVector;
  }

  /// Calculates cosine similarity between two vectors: Cos(A, B) = (A . B) / (||A|| * ||B||)
  double calculateCosineSimilarity(List<double> vecA, List<double> vecB) {
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    for (int i = 0; i < vecA.length; i++) {
      dotProduct += vecA[i] * vecB[i];
      normA += vecA[i] * vecA[i];
      normB += vecB[i] * vecB[i];
    }
    
    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dotProduct / (math.sqrt(normA) * math.sqrt(normB));
  }

  Future<void> processInbox() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final inboxFile = File('${docDir.path}/Media/transcriptions.jsonl');
      
      if (!await inboxFile.exists()) return;

      final lines = await inboxFile.readAsLines();
      if (lines.isEmpty) return;

      // Get user's folders from Hive
      final box = Hive.box('user_prefs');
      final List<dynamic> rawFolders = box.get('folders', defaultValue: ['My Notes', 'Raw Thoughts']);
      final List<String> userFolders = rawFolders.map((e) => e.toString()).toList();

      for (var line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final noteData = jsonDecode(line);
          final String text = noteData['text'] ?? '';
          
          // Genuine AI Semantic Routing
          final String matchedFolder = _determineFolder(text, userFolders);
          
          // Save note to specific folder
          final String timestampStr = noteData['timestamp']?.replaceAll(':', '-') ?? DateTime.now().millisecondsSinceEpoch.toString();
          final folderDir = Directory('${docDir.path}/vichaar/$matchedFolder');
          if (!await folderDir.exists()) {
            await folderDir.create(recursive: true);
          }
          
          final noteFile = File('${folderDir.path}/note_$timestampStr.json');
          await noteFile.writeAsString(jsonEncode(noteData));
          
          debugPrint("AI Routed note to folder: $matchedFolder");
        } catch (e) {
          debugPrint('Error routing note: $e');
        }
      }

      // Clear the inbox after successful processing
      await inboxFile.writeAsString('');
    } catch (e) {
      debugPrint("Error in processInbox: $e");
    }
  }

  String _determineFolder(String text, List<String> folders) {
    if (folders.isEmpty) return 'My Notes';
    
    // Get text embedding vector
    final textEmbedding = getEmbedding(text);
    
    // Score each folder by computing cosine similarity dynamically
    Map<String, double> folderScores = {};
    for (var folder in folders) {
      final folderEmbedding = getEmbedding(folder);
      final similarity = calculateCosineSimilarity(textEmbedding, folderEmbedding);
      folderScores[folder] = similarity;
    }

    // Find the folder with the highest similarity score
    String bestFolder = folders.first;
    double maxScore = -1.0;
    
    for (var entry in folderScores.entries) {
      if (entry.value > maxScore) {
        maxScore = entry.value;
        bestFolder = entry.key;
      }
    }
    
    debugPrint("AI Semantic Router: $folderScores (Selected '$bestFolder' with similarity: $maxScore)");
    
    return bestFolder;
  }
}
