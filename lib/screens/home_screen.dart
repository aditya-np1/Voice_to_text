import 'package:flutter/material.dart';
import 'package:voice_to_text/screens/notes_screen.dart';
import 'package:voice_to_text/screens/voice_recording_screen.dart';
import 'package:voice_to_text/services/ai_routing_service.dart';
import 'package:voice_to_text/utils/app_styles.dart';
import 'package:voice_to_text/widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedFolder = 'All Notes';
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initRouting();
  }
  
  Future<void> _initRouting() async {
    await AiRoutingService().processInbox();
    setState((){}); // Refresh notes after processing
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _currentIndex == 0 ? 'VICHAR CAPTURE' : '${_selectedFolder.toUpperCase()} WORKSPACE', 
          style: AppStyles.brandName.copyWith(fontSize: 14)
        ),
        centerTitle: true,
      ),
      drawer: AppDrawer(
        currentFolder: _selectedFolder,
        onFolderSelected: (folder) {
          setState(() { 
            _selectedFolder = folder; 
            _currentIndex = 1; // Auto switch to Notes tab to see folder contents
          });
          Navigator.pop(context); // close drawer
        },
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            const VoiceRecordingScreen(),
            NotesScreen(folderName: _selectedFolder),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          elevation: 0,
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          selectedItemColor: AppColors.primaryPurple,
          unselectedItemColor: AppColors.textGrey,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.mic_rounded),
              label: 'Capture',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notes_rounded),
              label: 'Workspace',
            ),
          ],
        ),
      ),
    );
  }
}

