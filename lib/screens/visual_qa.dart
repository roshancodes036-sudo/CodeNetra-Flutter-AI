import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // ✅ NEW: Markdown Package

import '../theme/app_colors.dart';
import '../widgets/custom_widgets.dart';
import '../services/ai_logic.dart';

class VisualQAScreen extends StatefulWidget {
  const VisualQAScreen({super.key});
  @override
  State<VisualQAScreen> createState() => _VisualQAScreenState();
}

class _VisualQAScreenState extends State<VisualQAScreen> {
  File? _image;
  final AIBrain _brain = AIBrain();
  final FlutterTts _tts = FlutterTts();
  late stt.SpeechToText _speech;

  String _question = "Tap mic to ask question...";
  String _answer = "";
  bool _isListening = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _brain.initBrain();
    _speech = stt.SpeechToText();
    _tts.setLanguage("hi-IN"); // Hindi for India
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _answer = "";
      });
      _tts.speak("Image captured. Now tap mic and ask your question.");
    }
  }

  void _listen() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(onResult: (val) {
        setState(() {
          _question = val.recognizedWords;
          if (val.finalResult) {
            _isListening = false;
            _askBrain();
          }
        });
      });
    }
  }

  void _askBrain() async {
    if (_image == null) {
      _tts.speak("Please capture an image first.");
      return;
    }
    setState(() => _isLoading = true);

    String prompt =
        "You are a visual assistant. User asks: '$_question'. Answer strictly based on the image. Keep it short. If user asks in Hindi, reply in Hindi.";
        
    String? res = await _brain.askWithImage(prompt, _image!);

    if (!mounted) return; // ✅ Safety Check Added for Crash Prevention

    setState(() {
      _isLoading = false;
      _answer = res ?? "Error";
    });
    _tts.speak(_answer);
  }

  @override
  Widget build(BuildContext context) {
    return ProPageLayout(
      title: "Visual Q&A",
      icon: Icons.help_outline,
      child: Column(children: [
        Expanded(
            flex: 2,
            child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.borderSubtle)),
                child: _image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.file(_image!, fit: BoxFit.contain))
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Icon(Icons.add_a_photo,
                                size: 50, color: Colors.grey),
                            Text("Capture Image First",
                                style: TextStyle(color: Colors.grey))
                          ]))),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          FloatingActionButton(
              heroTag: "cam",
              backgroundColor: AppColors.primaryAccent,
              onPressed: () => _pickImage(ImageSource.camera),
              child: const Icon(Icons.camera_alt, color: Colors.black)),
          FloatingActionButton(
              heroTag: "mic",
              backgroundColor:
                  _isListening ? Colors.red : AppColors.cardSurface,
              onPressed: _listen,
              child: Icon(_isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white)),
        ]),
        const SizedBox(height: 20),
        Text("Q: $_question",
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16)),
        const SizedBox(height: 10),
        if (_isLoading)
          const CircularProgressIndicator(color: AppColors.primaryAccent),
        if (_answer.isNotEmpty)
          Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green)),
              child: 
              // ✅ CHANGED: Normal Text converted to Premium MarkdownBody
              MarkdownBody(
                data: _answer,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600),
                  strong: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                  listBullet: const TextStyle(
                      color: Colors.greenAccent, fontSize: 20),
                ),
              ))
      ]),
    );
  }
}
