import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:voice_to_text/screens/home_screen.dart';
import 'package:voice_to_text/utils/app_styles.dart';
import 'package:voice_to_text/services/voice_trigger_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Screen 2 Data
  final Map<String, String> _intentLabels = {
    'curious': 'Just curious',
    'study': 'Learning & study',
    'personal': 'Personal thoughts & feelings',
    'startup': 'Startup & business ideas',
    'content': 'Content creation',
    'daily_ideas': 'Daily idea logging',
    'movement_log': 'Log personal movements & memories',
  };
  final Set<String> _selectedIntents = {};
  final List<String> _customIntents = [];

  bool _isListening = false;

  // Screen 3 Data
  List<String> _folders = [];
  final TextEditingController _newFolderController = TextEditingController();

  final Map<String, List<String>> _intentFolderMap = {
    'curious': ['Raw Thoughts', 'Rabbit Holes'],
    'study': ['Study Notes', 'Subjects', 'Revision'],
    'personal': ['Heart Captures', 'Feelings', 'Personal'],
    'startup': ['Startup Ideas', 'Validation', 'Market Research'],
    'content': ['Content Ideas', 'Scripts', 'Drafts'],
    'daily_ideas': ['Daily Sparks', 'Raw Thoughts'],
    'movement_log': ['Daily Log', 'Memories', 'Where I Was'],
  };

  void _nextPage() {
    if (_currentPage == 1) {
      _generateFolders();
    }
    if (_currentPage == 3) {
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutExpo,
    );
  }

  void _generateFolders() {
    Set<String> folderSet = {};
    for (String intent in _selectedIntents) {
      if (_intentFolderMap.containsKey(intent)) {
        folderSet.addAll(_intentFolderMap[intent]!);
      }
    }
    for (String customIntent in _customIntents) {
      folderSet.add(customIntent);
    }
    if (folderSet.isEmpty) {
      folderSet.addAll(['My Notes', 'Ideas']);
    }
    setState(() {
      _folders = folderSet.toList();
    });
  }

  Future<void> _startListening() async {
    if (Platform.isWindows) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech to text not fully supported on Windows simulator.')),
        );
      }
      return;
    }
    
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required.')),
        );
      }
      return;
    }

    
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech to text not available on this device.')),
        );
      }
  }

  Future<void> _completeSetup() async {
    try {
      final box = Hive.box('user_prefs');
      final allIntents = _selectedIntents.toList()..addAll(_customIntents);
      await box.put('selected_intents', allIntents);
      await box.put('folders', _folders);
      await box.put('onboarding_done', true);

      final docDir = await getApplicationDocumentsDirectory();
      for (String folder in _folders) {
        final dir = Directory('${docDir.path}/vichaar/$folder');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      }
    } catch (e) {
      debugPrint("Error creating folders or saving to Hive: $e");
    }

    final triggerService = VoiceTriggerService();
    await triggerService.requestPermissionsAndEnable();

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (idx) {
            setState(() {
              _currentPage = idx;
            });
          },
          children: [
            _buildScreen1(),
            _buildScreen2(),
            _buildScreen3(),
            _buildScreen4(),
          ],
        ),
      ),
    );
  }

  // --- SCREEN 1 ---
  Widget _buildScreen1() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryPurple.withOpacity(0.1),
            ),
            child: const Icon(
              Icons.graphic_eq_rounded,
              size: 80,
              color: AppColors.primaryPurple,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'VICHAAR',
            style: AppStyles.brandName.copyWith(fontSize: 40),
          ),
          const SizedBox(height: 16),
          Text(
            'Your voice. Your thoughts.\nCompletely safe.',
            textAlign: TextAlign.center,
            style: AppStyles.heading.copyWith(fontSize: 22, height: 1.3),
          ),
          const SizedBox(height: 48),
          _buildFeatureRow(Icons.lock_outline_rounded, 'Your voice never leaves your device'),
          const SizedBox(height: 20),
          _buildFeatureRow(Icons.person_off_outlined, 'No account required'),
          const SizedBox(height: 20),
          _buildFeatureRow(Icons.wifi_off_outlined, 'Works offline, always'),
          const Spacer(),
          _buildCTA('Get Started →', _nextPage),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryPurple, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: AppStyles.body.copyWith(color: AppColors.textBlack, fontSize: 16),
          ),
        ),
      ],
    );
  }

  // --- SCREEN 2 ---
  Widget _buildScreen2() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Text('What brings you here?', style: AppStyles.heading.copyWith(fontSize: 28)),
          const SizedBox(height: 12),
          Text('Select all that apply. We\'ll set things up for you.', style: AppStyles.body),
          const SizedBox(height: 40),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 16,
                children: [
                  ..._intentLabels.entries.map((e) => _buildChoiceChip(e.key, e.value)),
                  ..._customIntents.map((custom) => _buildCustomChip(custom)),
                  _buildOtherChip(),
                ],
              ),
            ),
          ),
          _buildCTA('Next →', _nextPage),
        ],
      ),
    );
  }

  Widget _buildChoiceChip(String key, String label) {
    final isSelected = _selectedIntents.contains(key);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {
          setState(() {
            if (val) _selectedIntents.add(key);
            else _selectedIntents.remove(key);
          });
        },
        selectedColor: AppColors.primaryPurple,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.textBlack,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          fontSize: 15,
        ),
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isSelected ? AppColors.primaryPurple : Colors.grey.shade300,
            width: isSelected ? 0 : 1,
          ),
        ),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildCustomChip(String label) {
    return Chip(
      label: Text(label),
      backgroundColor: AppColors.primaryPurple,
      labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
      deleteIcon: const Icon(Icons.close, color: Colors.white, size: 18),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      onDeleted: () {
        setState(() {
          _customIntents.remove(label);
        });
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.primaryPurple, width: 0),
      ),
    );
  }

  Widget _buildOtherChip() {
    return ActionChip(
      avatar: _isListening 
          ? const SizedBox(
              width: 16, height: 16, 
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryPurple)
            )
          : const Icon(Icons.mic, size: 18, color: AppColors.primaryPurple),
      label: Text(
        _isListening ? 'Listening...' : 'Other (voice input)',
        style: const TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.w600, fontSize: 15),
      ),
      backgroundColor: AppColors.accentLavender,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.primaryPurple, width: 1.5),
      ),
      onPressed: _isListening ? () {
        setState(() => _isListening = false);
      } : _startListening,
    );
  }

  // --- SCREEN 3 ---
  Widget _buildScreen3() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Text('Here\'s your personal space', style: AppStyles.heading.copyWith(fontSize: 28)),
          const SizedBox(height: 12),
          Text('You can always change this later.', style: AppStyles.body),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.builder(
              itemCount: _folders.length,
              itemBuilder: (context, index) {
                final folder = _folders[index];
                return Dismissible(
                  key: Key('$folder-$index'),
                  direction: DismissDirection.endToStart,
                  onDismissed: (dir) {
                    setState(() {
                      _folders.removeAt(index);
                    });
                  },
                  background: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      leading: const Icon(Icons.folder_outlined, color: AppColors.primaryPurple),
                      title: Text(folder, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      trailing: IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
                        onPressed: () {
                          setState(() {
                            _folders.removeAt(index);
                          });
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: _showAddFolderDialog,
              icon: const Icon(Icons.add, color: AppColors.primaryPurple),
              label: const Text('Add folder', style: TextStyle(color: AppColors.primaryPurple, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 16),
          _buildCTA('Looks good →', _nextPage),
        ],
      ),
    );
  }

  void _showAddFolderDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('New Folder', style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: _newFolderController,
            decoration: InputDecoration(
              hintText: 'Folder Name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2),
              ),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final text = _newFolderController.text.trim();
                if (text.isNotEmpty && !_folders.contains(text)) {
                  setState(() => _folders.add(text));
                }
                _newFolderController.clear();
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        );
      }
    );
  }

  // --- SCREEN 4 ---
  Widget _buildScreen4() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.elasticOut,
            builder: (context, val, child) {
              return Transform.scale(
                scale: val,
                child: child,
              );
            },
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryPurple,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 50),
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
          Text(
            'Your Vichaar is ready',
            style: AppStyles.heading.copyWith(fontSize: 28),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Folders created locally.\nYour data stays with you.',
            style: AppStyles.body.copyWith(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FutureBuilder<Directory>(
            future: getApplicationDocumentsDirectory(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Text(
                  'Location:\n${snapshot.data!.path}\\vichaar',
                  style: AppStyles.body.copyWith(fontSize: 13, color: AppColors.textGrey),
                  textAlign: TextAlign.center,
                );
              }
              return const SizedBox();
            },
          ),
          const Spacer(),
          _buildCTA('Start capturing →', () {
            _completeSetup();
          }),
        ],
      ),
    );
  }

  Widget _buildCTA(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 64),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
