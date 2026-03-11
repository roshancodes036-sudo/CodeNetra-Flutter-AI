import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // HapticFeedback ke liye
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';

// Tumhare purane imports
import '../theme/app_colors.dart';
import '../services/ai_logic.dart';

class FaceEmotionScreen extends StatefulWidget {
  const FaceEmotionScreen({super.key});
  @override
  State<FaceEmotionScreen> createState() => _FaceEmotionScreenState();
}

class _FaceEmotionScreenState extends State<FaceEmotionScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _selectedCameraIdx = 0; // Default Back Camera
  
  final AIBrain _brain = AIBrain();
  final FlutterTts _tts = FlutterTts();
  
  bool _isProcessing = false;
  String _result = "Initializing Social Coach...";
  Timer? _timer;

  // ✅ NEW: Language State
  bool _isHindi = false; 

  // Animation Variables
  late AnimationController _animController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _brain.initBrain();
    _setupVoice();
    _initCamera();
    _setupAnimation();
  }

  void _setupAnimation() {
    _animController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_animController);
  }

  // ✅ NEW: Smart Voice Setup
  Future<void> _setupVoice() async {
    await _tts.setLanguage(_isHindi ? "hi-IN" : "en-US");
    await _tts.setSpeechRate(0.5); // Clear instruction speed
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
  }

  // ✅ NEW: Language Toggle
  void _toggleLanguage() {
    setState(() {
      _isHindi = !_isHindi;
      AIBrain.isHindi = _isHindi; 
      _result = _isHindi ? "सोशल कोच तैयार है..." : "Social Coach Active...";
    });
    _setupVoice();
    HapticFeedback.lightImpact();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      int frontIndex = _cameras!.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
      _selectedCameraIdx = (frontIndex != -1) ? frontIndex : 0;
      _setCamera(_cameras![_selectedCameraIdx]);
    }
  }

  Future<void> _setCamera(CameraDescription cameraDescription) async {
    if (_controller != null) {
      await _controller!.dispose();
    }
    // Resolution 'medium' rakha hai taki 1.5s me fast upload ho
    _controller = CameraController(
      cameraDescription, 
      ResolutionPreset.medium, 
      enableAudio: false
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {});
        _startAutoPilot();
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  void _switchCamera() {
    if (_cameras == null || _cameras!.length < 2) return;
    setState(() {
      _selectedCameraIdx = (_selectedCameraIdx == 0) ? 1 : 0;
      _result = _isHindi ? "कैमरा बदल रहा है..." : "Switching Camera...";
    });
    _setCamera(_cameras![_selectedCameraIdx]);
  }

  // ✅ FASTER AUTO-PILOT (1.5 Seconds)
  void _startAutoPilot() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (!_isProcessing && mounted && _controller!.value.isInitialized) {
        _scanFaceAndEmotion();
      }
    });
  }

  Future<void> _scanFaceAndEmotion() async {
    try {
      setState(() => _isProcessing = true);
      final image = await _controller!.takePicture();

      // 🔥 THE STRICT "SOCIAL COACH" PROMPT 🔥
      String prompt = """
      You are 'Netra', a Social Intelligence Coach for a blind person.
      Analyze the face in the image INSTANTLY. Identify the exact emotion or social cue.
      
      INSTRUCTIONS:
      1. Give a DIRECT, REAL-WORLD conversational tip to the blind user.
      2. Language: Reply STRICTLY in ${_isHindi ? "HINDI" : "ENGLISH"}.
      
      EXAMPLES:
      - "He looks stressed. Keep your tone calm." / "वह तनाव में है, शांत स्वर में बात करें।"
      - "She is smiling warmly. You can match her energy." / "वह मुस्कुरा रही है, आप भी गर्मजोशी दिखाएं।"
      - "He looks bored or distracted. Try changing the topic." / "वह बोर लग रहा है, विषय बदलें।"
      - "No face detected." / "कोई चेहरा नहीं दिखा।"
      
      OUTPUT FORMAT: Plain ${_isHindi ? "Hindi" : "English"} text. STRICTLY UNDER 12 WORDS. No extra symbols.
      """;

      String? res = await _brain.askWithImage(prompt, File(image.path));

      if (mounted && res != null) {
        // Haptic feedback if someone is angry/aggressive
        String upperRes = res.toUpperCase();
        if (upperRes.contains("ANGRY") || upperRes.contains("STRESSED") || upperRes.contains("गुस्से") || upperRes.contains("तनाव")) {
          HapticFeedback.mediumImpact();
        }

        setState(() {
          _result = res;
          _isProcessing = false;
        });
        await _tts.speak(res);
      }
    } catch (e) {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    _animController.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryAccent)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. FULL SCREEN CAMERA
          SizedBox(
            height: double.infinity,
            width: double.infinity,
            child: CameraPreview(_controller!),
          ),

          // 2. LASER SCAN ANIMATION
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Positioned(
                top: MediaQuery.of(context).size.height * _animation.value,
                left: 0,
                right: 0,
                child: Container(
                  height: 2,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.greenAccent.withOpacity(0.8),
                        blurRadius: 15,
                        spreadRadius: 2
                      )
                    ]
                  ),
                ),
              );
            },
          ),

          // 3. UI OVERLAY (Bottom Text Panel)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 30, left: 20, right: 20, bottom: 30),
              decoration: const BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _result,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_isProcessing)
                    const LinearProgressIndicator(color: AppColors.primaryAccent),
                  if (!_isProcessing)
                    Text(
                      _isHindi ? "सोशल कोच सक्रिय • स्कैन कर रहा है..." : "Social Coach Active • Scanning...",
                      style: GoogleFonts.outfit(color: Colors.greenAccent, fontSize: 12),
                    )
                ],
              ),
            ),
          ),

          // 4. FLOATING CAMERA SWITCH BUTTON (Bottom Right)
          Positioned(
            bottom: 160, 
            right: 20,
            child: FloatingActionButton(
              heroTag: "switch_cam",
              backgroundColor: Colors.black.withOpacity(0.6), 
              onPressed: _switchCamera,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
                side: const BorderSide(color: Colors.white38, width: 1)
              ),
              child: const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 28),
            ),
          ),

          // 5. BACK BUTTON (Top Left)
          Positioned(
            top: 50, 
            left: 20,
            child: SafeArea(
              child: CircleAvatar(
                backgroundColor: Colors.black45,
                radius: 22,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),

          // ✅ 6. NEW: LANGUAGE TOGGLE BUTTON (Top Right)
          Positioned(
            top: 50,
            right: 20,
            child: SafeArea(
              child: GestureDetector(
                onTap: _toggleLanguage,
                child: CircleAvatar(
                  backgroundColor: _isHindi ? Colors.greenAccent.withOpacity(0.8) : Colors.black45,
                  radius: 22,
                  child: Text(
                    _isHindi ? "हिं" : "EN",
                    style: GoogleFonts.outfit(
                      color: Colors.white, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 16
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}