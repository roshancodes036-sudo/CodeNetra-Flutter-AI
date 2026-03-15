import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/foundation.dart'; 

import '../theme/app_colors.dart';
import '../widgets/custom_widgets.dart';
import '../services/ai_logic.dart';

class PDFScreen extends StatefulWidget {
  const PDFScreen({super.key});

  @override
  State<PDFScreen> createState() => _PDFScreenState();
}

class _PDFScreenState extends State<PDFScreen> with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  final FlutterTts _tts = FlutterTts();
  final AIBrain _brain = AIBrain();

  bool _isProcessing = false;
  String _aiResultText = "";
  bool _isHindi = AIBrain.isHindi; 
  Timer? _timer; 

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _brain.initBrain();
    _initAnimation();
    _initTTSAndCamera();
  }

  void _initAnimation() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  Future<void> _setupVoice() async {
    await _tts.setLanguage(_isHindi ? "hi-IN" : "en-US");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  void _toggleLanguage() async {
    await _tts.stop();
    setState(() {
      _isHindi = !_isHindi;
      AIBrain.isHindi = _isHindi; 
      _aiResultText = ""; 
    });
    
    await _setupVoice();
    HapticFeedback.lightImpact();
    
    String speech = _isHindi ? "हिंदी भाषा सक्रिय।" : "English language active.";
    await _tts.speak(speech);
    _startFastAutoPilot(); 
  }

  Future<void> _initTTSAndCamera() async {
    await _setupVoice();
    
    String initialGreeting = _isHindi 
        ? "लाइव पीडीएफ एनालिसिस एक्टिव सर।"
        : "Live PDF analysis active sir.";
    await _tts.speak(initialGreeting);

    if (kIsWeb) return;

    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium, 
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {});
      _startFastAutoPilot(); 
    }
  }

  void _startFastAutoPilot() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (!_isProcessing && mounted && _cameraController!.value.isInitialized && _aiResultText.isEmpty) {
        _scanDocumentInstantly();
      }
    });
  }

  Future<void> _scanDocumentInstantly() async {
    setState(() => _isProcessing = true);

    try {
      final XFile file = await _cameraController!.takePicture();
      String? result = await _brain.analyzeDocumentLive(File(file.path));

      // AI check karega ki document hai ya nahi
      if (result != null && result.trim() == "NO_DOC") {
        if (mounted) setState(() => _isProcessing = false);
        return; 
      }

      // Document mil gaya!
      _timer?.cancel(); 
      HapticFeedback.heavyImpact(); 

      setState(() {
        _aiResultText = result ?? (_isHindi ? "माफ़ करें, समझ नहीं पाया।" : "Sorry, couldn't understand.");
        _isProcessing = false;
      });

      await _tts.speak(_aiResultText);
    } catch (e) {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ✅ DOUBLE TAP LOGIC (Reset & Speak)
  void _resetScanner() async {
    if (kIsWeb) return; 
    await _tts.stop();
    HapticFeedback.mediumImpact();

    setState(() {
      _aiResultText = ""; // Text khali hote hi panel niche slide ho jayega
      _isProcessing = false;
    });
    
    // Exactly wahi awaz jo tumne boli thi
    String restartMsg = _isHindi ? "लाइव पीडीएफ एनालिसिस एक्टिव सर।" : "Live PDF analysis active sir.";
    await _tts.speak(restartMsg);
    
    _startFastAutoPilot(); // Wapas scan shuru
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController?.dispose();
    _tts.stop();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Screen height nikal rahe hain animation ke liye
    final screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onDoubleTap: _resetScanner, // ✅ Double tap par reset
      child: ProPageLayout(
        title: "Live DocuMind",
        icon: Icons.document_scanner,
        child: Stack(
          children: [
            // 1. Camera Preview
            if (_cameraController != null && _cameraController!.value.isInitialized)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CameraPreview(_cameraController!),
                ),
              )
            else
              const Center(child: CircularProgressIndicator(color: AppColors.primaryAccent)),

            // 2. Green Scanner Line
            if (_aiResultText.isEmpty && !kIsWeb)
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Positioned(
                    top: _animationController.value * screenHeight * 0.6,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 10, spreadRadius: 5)],
                        color: Colors.greenAccent,
                      ),
                    ),
                  );
                },
              ),

            // 3. Status Text (Top)
            Positioned(
              top: 15, left: 20, right: 80, 
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black87, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _aiResultText.isNotEmpty ? Colors.green : Colors.cyanAccent),
                ),
                child: Text(
                  _aiResultText.isNotEmpty 
                      ? (_isHindi ? "✅ स्कैन पूरा हुआ (डबल-टैप)" : "✅ Scan Complete (Double-Tap)")
                      : (_isHindi ? "🔍 कागज़ ढूंढ रहा है..." : "🔍 Looking for document..."),
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            // 4. Language Button (Top Right)
            Positioned(
              top: 15, right: 15,
              child: GestureDetector(
                onTap: _toggleLanguage,
                child: CircleAvatar(
                  backgroundColor: _isHindi ? Colors.greenAccent.withOpacity(0.8) : Colors.black87,
                  radius: 22,
                  child: Text(_isHindi ? "हिं" : "EN", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),

            // 5. ✅ THE SLIDE-UP PANEL (Niche se upar aayega)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 600), // 0.6 second ka smooth slide
              curve: Curves.easeOutExpo, // Ekdam smooth premium feel
              bottom: _aiResultText.isNotEmpty ? 0 : -screenHeight, // Agar text nahi hai to screen ke niche chhupa rahega
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                height: screenHeight * 0.45,
                decoration: const BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  border: Border(top: BorderSide(color: Colors.cyanAccent, width: 2)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Chhota sa drag handle design (Premium look ke liye)
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          margin: const EdgeInsets.only(bottom: 15),
                          decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      // AI ka Markdown Text
                      MarkdownBody(
                        data: _aiResultText,
                        selectable: true, // User copy kar sakega
                        styleSheet: MarkdownStyleSheet(
                          p: GoogleFonts.outfit(color: Colors.white, fontSize: 16, height: 1.5),
                          strong: GoogleFonts.outfit(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}