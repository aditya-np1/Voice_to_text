import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:voice_to_text/services/ai_routing_service.dart';
import 'package:voice_to_text/utils/app_styles.dart';

class NotesScreen extends StatefulWidget {
  final String folderName;
  const NotesScreen({super.key, required this.folderName});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Map<String, dynamic>> _notes = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingPath;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() {
        _currentlyPlayingPath = null;
      });
    });
  }

  @override
  void didUpdateWidget(NotesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folderName != widget.folderName) {
      _loadNotes();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final List<Map<String, dynamic>> loadedNotes = [];
      
      if (widget.folderName == 'All Notes') {
        // Read all JSONs from all vichaar folders
        final vichaarDir = Directory('${directory.path}/vichaar');
        if (await vichaarDir.exists()) {
          await for (var entity in vichaarDir.list(recursive: true)) {
            if (entity is File && entity.path.endsWith('.json')) {
              try {
                loadedNotes.add(jsonDecode(await entity.readAsString()));
              } catch (e) {}
            }
          }
        }
      } else {
        // Read from specific folder
        final specificDir = Directory('${directory.path}/vichaar/${widget.folderName}');
        if (await specificDir.exists()) {
          await for (var entity in specificDir.list()) {
            if (entity is File && entity.path.endsWith('.json')) {
              try {
                loadedNotes.add(jsonDecode(await entity.readAsString()));
              } catch (e) {}
            }
          }
        }
      }
      
      // Sort by timestamp
      loadedNotes.sort((a, b) {
        final ta = a['timestamp'] ?? '';
        final tb = b['timestamp'] ?? '';
        return tb.compareTo(ta); // descending
      });

      setState(() {
        _notes = loadedNotes;
      });
    } catch (e) {
      debugPrint('Error loading notes: $e');
    }
  }

  Future<void> _togglePlay(String audioPath) async {
    if (_currentlyPlayingPath == audioPath) {
      await _audioPlayer.pause();
      setState(() {
        _currentlyPlayingPath = null;
      });
    } else {
      if (!File(audioPath).existsSync()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio file not found')),
        );
        return;
      }
      await _audioPlayer.play(DeviceFileSource(audioPath));
      setState(() {
        _currentlyPlayingPath = audioPath;
      });
    }
  }
  
  List<String> _generateTags(String text) {
    // Genuine offline AI Auto-Tagging using Latent Semantic Embedding space similarity
    final aiService = AiRoutingService();
    final textEmbedding = aiService.getEmbedding(text);
    final List<String> tags = [];

    // Predefined tag semantic vectors
    final Map<String, String> tagProfiles = {
      '💡 Idea': 'idea brainstorm spark create dream concept innovation future thoughts imagine startup',
      '📚 Learning': 'study learn read exam book subject revision course lecture assignment homework university science math research',
      '🍔 Personal': 'family restaurant feel heart memory memories home friend friends lunch dinner breakfast food eat love happy sad life travel trip vacation',
      '💼 Work': 'meeting meetings call calls office project projects deadline work job manager client team task tasks email emails urgent important',
      '🛒 Shopping': 'buy grocery groceries shopping store market price cost purchase item items list cash card pay product mall',
      '🎬 Creative': 'script scripts video videos post posts blog blogs content draft drafts write writing editor edit podcast youtube channel',
      '🗓️ Schedule': 'schedule calendar tomorrow today yesterday next week monday tuesday wednesday thursday friday saturday sunday',
      '⏰ Time': 'time clock hour minute morning afternoon evening night early late deadline',
      '⚠️ Urgent': 'urgent important asap priority critical attention crucial',
    };

    // Calculate semantic similarity to each tag profile
    tagProfiles.forEach((tagName, profileText) {
      final profileEmbedding = aiService.getEmbedding(profileText);
      final similarity = aiService.calculateCosineSimilarity(textEmbedding, profileEmbedding);
      
      // Assign tag if it satisfies the semantic proximity threshold (0.50)
      if (similarity >= 0.50) {
        tags.add(tagName);
      }
    });

    if (tags.isEmpty) {
      tags.add('📝 Note');
    }
    return tags;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.folderName,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: const Color(0xFF1F1F1F),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadNotes,
              )
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "All your transcribed voice notes will appear here.",
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF757575),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _notes.isEmpty ? _buildEmptyState() : _buildNotesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesList() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;
        if (constraints.maxWidth > 1200) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth > 900) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 2;
        }

        return MasonryGridView.count(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          itemCount: _notes.length,
          itemBuilder: (context, index) {
            final note = _notes[index];
            final String text = note['text'] ?? '';
            final String timestamp = note['timestamp'] ?? '';
            final String audioPath = note['audio_file'] ?? '';
            final bool isPlaying = _currentlyPlayingPath == audioPath;
            final tags = _generateTags(text);

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x05000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        timestamp,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFFA0A0A0),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _togglePlay(audioPath),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPlaying ? Colors.red.withValues(alpha: 0.1) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isPlaying ? Colors.red.withValues(alpha: 0.2) : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                color: isPlaying ? Colors.red : const Color(0xFF4B5563),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isPlaying ? 'Playing...' : 'Audio',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isPlaying ? Colors.red : const Color(0xFF4B5563),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    text,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      height: 1.6,
                      color: const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tag,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    )).toList(),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      decoration: AppStyles.modernCard,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.note_add_rounded,
              size: 48,
              color: AppColors.primaryPurple,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "No notes yet",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textBlack,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Start recording to create a new note",
            style: AppStyles.body.copyWith(color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }
}
