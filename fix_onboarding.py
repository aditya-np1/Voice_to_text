with open('lib/screens/onboarding_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("import 'package:speech_to_text/speech_to_text.dart' as stt;\n", "")
text = text.replace("  final stt.SpeechToText _speechToText = stt.SpeechToText();\n", "")
text = text.replace("        _speechToText.stop();\n", "")

old_start_listening = """    bool available = await _speechToText.initialize(
      onError: (e) => debugPrint('STT Error: $e'),
      onStatus: (s) {
        if (s == 'notListening' || s == 'done') {
          setState(() => _isListening = false);
        }
      },
    );
    
    if (available) {
      setState(() => _isListening = true);
      _speechToText.listen(
        onResult: (result) {
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            setState(() {
              if (!_customIntents.contains(result.recognizedWords)) {
                _customIntents.add(result.recognizedWords);
              }
              _isListening = false;
            });
          }
        },
        listenMode: stt.ListenMode.dictation,
      );
    } else {"""

new_start_listening = """    bool available = false;
    
    if (available) {
      setState(() => _isListening = true);
    } else {"""

text = text.replace(old_start_listening, new_start_listening)

with open('lib/screens/onboarding_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)
