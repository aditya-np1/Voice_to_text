import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_to_text/services/storage_service.dart';
import 'package:voice_to_text/utils/app_styles.dart';

class AppDrawer extends StatefulWidget {
  final String currentFolder;
  final Function(String) onFolderSelected;

  const AppDrawer({
    super.key,
    required this.currentFolder,
    required this.onFolderSelected,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  List<String> _folders = [];

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  void _loadFolders() {
    final box = Hive.box('user_prefs');
    final List<dynamic> rawFolders = box.get('folders', defaultValue: ['My Notes', 'Raw Thoughts']);
    setState(() {
      _folders = ['All Notes'] + rawFolders.map((e) => e.toString()).toList();
    });
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return const SettingsDialog();
      }
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('How to Use Vichaar', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🎙️ Recording', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Press your chosen Hardware Trigger (e.g., Triple click Volume Up) to silently start recording in the background.'),
                SizedBox(height: 12),
                Text('🧠 Smart AI Folders', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('When you stop speaking, the app automatically transcribes and categorizes your note into one of your folders.'),
                SizedBox(height: 12),
                Text('🎵 Audio Playback', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Tap the "Play Audio" button next to any note to hear your original recording.'),
                SizedBox(height: 12),
                Text('🧹 Storage Management', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Go to Settings to automatically delete old audio files and save space.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it'),
            ),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic, color: AppColors.primaryPurple),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Vichaar',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textBlack,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _folders.length,
                itemBuilder: (context, index) {
                  final folder = _folders[index];
                  final isSelected = folder == widget.currentFolder;
                  return ListTile(
                    leading: Icon(
                      folder == 'All Notes' ? Icons.all_inbox : Icons.folder_outlined,
                      color: isSelected ? AppColors.primaryPurple : AppColors.textGrey,
                    ),
                    title: Text(
                      folder,
                      style: GoogleFonts.poppins(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? AppColors.primaryPurple : AppColors.textBlack,
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor: AppColors.primaryPurple.withOpacity(0.05),
                    onTap: () => widget.onFolderSelected(folder),
                  );
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_outlined, color: AppColors.textGrey),
              title: Text('Settings', style: GoogleFonts.poppins(color: AppColors.textBlack)),
              onTap: () {
                Navigator.pop(context);
                _showSettingsDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, color: AppColors.textGrey),
              title: Text('How to Use', style: GoogleFonts.poppins(color: AppColors.textBlack)),
              onTap: () {
                Navigator.pop(context);
                _showHelpDialog();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});
  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}
class _SettingsDialogState extends State<SettingsDialog> {
  final TextEditingController _apiUrlController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String _triggerOption = 'triple_power';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiUrlController.text = prefs.getString('api_url') ?? "http://10.0.2.2:8000/api/transcribe";
      _emailController.text = prefs.getString('support_email') ?? "support@vichaar.app";
      _triggerOption = prefs.getString('background_trigger') ?? "triple_power";
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_url', _apiUrlController.text);
    await prefs.setString('support_email', _emailController.text);
    await prefs.setString('background_trigger', _triggerOption);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Backend API URL'),
            TextField(controller: _apiUrlController),
            const SizedBox(height: 16),
            const Text('Hardware Trigger'),
            DropdownButton<String>(
              isExpanded: true,
              value: _triggerOption,
              items: const [
                DropdownMenuItem(value: 'triple_power', child: Text('Triple Press Power Button')),
                DropdownMenuItem(value: 'triple_volume_up', child: Text('Triple Press Volume Up')),
                DropdownMenuItem(value: 'triple_volume_down', child: Text('Triple Press Volume Down')),
              ],
              onChanged: (v) { if (v != null) setState(() => _triggerOption = v); },
            ),
            const SizedBox(height: 16),
            const Text('Support Email'),
            TextField(controller: _emailController),
            const SizedBox(height: 24),
            const Divider(),
            const Text('Storage Management', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Clear old audio files to free up space.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(
                  onPressed: () async {
                    int count = await StorageService().deleteOldRecordings(7);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted $count files older than 7 days')));
                    }
                  },
                  child: const Text('> 7 Days', style: TextStyle(fontSize: 12)),
                ),
                OutlinedButton(
                  onPressed: () async {
                    int count = await StorageService().deleteOldRecordings(30);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted $count files older than 30 days')));
                    }
                  },
                  child: const Text('> 30 Days', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _saveSettings, child: const Text('Save')),
      ],
    );
  }
}
