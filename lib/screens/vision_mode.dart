import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // HapticFeedback (Vibration) ke liye
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';

// Tumhare purane imports (Inhe mat hatana)
import '../theme/app_colors.dart';
import '../services/ai_logic.dart';

class LiveCameraScreen extends StatefulWidget {
  const LiveCameraScreen({super.key});
  @override
  State<LiveCameraScreen> createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends State<LiveCameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  final FlutterTts _tts = FlutterTts();
  final AIBrain _brain = AIBrain(); // Tumhara AI Logic Class

  bool _isProcessing = false; // Check karega ki AI busy to nahi hai
  String _desc = "Initializing Netra Vision..."; // Screen par dikhne wala text
  Timer? _timer; // Auto-pilot timer

  // ✅ NEW: Language State
  bool _isHindi = false; 

  @override
  void initState() {
    super.initState();
    _brain.initBrain();
    _setupVoice(); // Default Voice set karega
    _initCamera(); // Camera chalu karega
  }

  // 1. VOICE SETUP (✅ Hindi/English Support Added)
  Future<void> _setupVoice() async {
    await _tts.setLanguage(_isHindi ? "hi-IN" : "en-US"); // Language Toggle
    await _tts.setPitch(1.0); // Normal Pitch
    await _tts.setSpeechRate(0.5); // Speed thodi dheemi taki saaf samajh aaye
    await _tts.awaitSpeakCompletion(true); // Pura bolne ke baad hi agla bole
  }

  // ✅ NEW: Language Toggle Function
  void _toggleLanguage() {
    setState(() {
      _isHindi = !_isHindi;
      AIBrain.isHindi = _isHindi; // Update global AI brain state
      _desc = _isHindi ? "नेत्रा विजन शुरू हो रहा है..." : "Initializing Netra Vision...";
    });
    _setupVoice(); // Aawaz badlo
    HapticFeedback.lightImpact(); // Button dabane par chota vibration
  }

  // 2. CAMERA SETUP
  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      // Resolution 'medium' rakho taki photo jaldi upload ho aur fast response aaye
      _controller = CameraController(cameras.first, ResolutionPreset.medium,
          enableAudio: false);
      _initializeControllerFuture = _controller!.initialize();
      if (mounted) {
        setState(() {});
        _startAutoPilotLoop(); // Camera khulte hi scanning shuru
      }
    }
  }

  // 3. AUTO-PILOT LOOP (Har 2 second me scan karega)
  void _startAutoPilotLoop() {
    _timer = Timer.periodic(const Duration(milliseconds: 2000), (timer) {
      // Agar pichla scan chal raha hai, to naya mat lo (Queue rokne ke liye)
      if (!_isProcessing && mounted && _controller!.value.isInitialized) {
        _captureAndAnalyze();
      }
    });
  }

  // 4. MAIN MAGIC FUNCTION (AI Logic)
  Future<void> _captureAndAnalyze() async {
    try {
      setState(() => _isProcessing = true); // Loading shuru
      final image = await _controller!.takePicture(); // Photo khincho
      
      // --- SUPER INTELLIGENT PROMPT (✅ Hindi/English Support Added) ---
      String prompt = """
      You are 'Netra', an advanced vision assistant for the blind. 
      Analyze the image strictly based on visual evidence.
      IMPORTANT: Reply strictly in ${_isHindi ? "HINDI" : "ENGLISH"} language.

      PRIORITY RULES:
      1. **DANGER (Safety First):** If you see an approaching Car, Bike, Fire, Deep Pit, or Edge, output MUST start with "STOP DANGER" (or "खतरा" in Hindi).
      
      2. **MEDICINE (Health):** If you see a Medicine Strip or Bottle:
         - Read the Name (e.g., Dolo 650, Vicks).
         - Explain usage briefly.
         - If text is unreadable, say "Medicine name unclear".

      3. **HARDWARE (Tech):** If you see a computer part (RAM, Mouse, Arduino, Keyboard):
         - Name it and its function.

      4. **GENERAL:** If none of above, describe the object in front in 5-10 words.

      OUTPUT FORMAT: Plain ${_isHindi ? "Hindi" : "English"} text only. Max 15 words.
      """;

      // AI ko bhejo (Gemini API)
      String? res = await _brain.askWithImage(prompt, File(image.path));

      if (mounted && res != null) {
        // --- DANGER VIBRATION LOGIC (✅ Hindi Support Added) ---
        String upperRes = res.toUpperCase();
        if (upperRes.contains("STOP") || 
            upperRes.contains("DANGER") || 
            upperRes.contains("WARNING") ||
            res.contains("खतरा") || 
            res.contains("सावधान")) {
          HapticFeedback.heavyImpact(); // Zordaar jhatka 1
          await Future.delayed(const Duration(milliseconds: 200));
          HapticFeedback.heavyImpact(); // Zordaar jhatka 2
        }

        setState(() {
          _desc = res;
          _isProcessing = false; // Loading band
        });
        
        // User ko bolkar batao
        await _tts.speak(res);
      }
    } catch (e) {
      debugPrint("Error in Vision: $e");
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel(); // Timer band karo varna battery khayega
    _controller?.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Jab tak camera nahi khulta, loading dikhao
    if (_controller == null || _initializeControllerFuture == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryAccent));
    }

    return FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return Stack(children: [
            // 1. CAMERA PREVIEW (Full Screen)
            SizedBox(
                height: double.infinity,
                width: double.infinity,
                child: CameraPreview(_controller!)),
            
            // 2. BLACK OVERLAY (Niche ka design)
            Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(30),
                            topRight: Radius.circular(30)),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black54,
                              blurRadius: 20,
                              spreadRadius: 5)
                        ]),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      
                      // AI TEXT OUTPUT
                      Text(_desc,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                              // ✅ Hindi danger color support added
                              color: _desc.toUpperCase().contains("DANGER") ||
                                      _desc.toUpperCase().contains("STOP") ||
                                      _desc.contains("खतरा")
                                  ? Colors.redAccent
                                  : Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      
                      // NETRA EYE ANIMATION (Orb)
                      Container(
                          height: 80, // ✅ Correct Size: 80
                          width: 80,  // ✅ Correct Size: 80
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black,
                              border: Border.all(
                                // ✅ Hindi danger border support added
                                color: _desc.toUpperCase().contains("DANGER") || _desc.contains("खतरा")
                                  ? Colors.red // Khatre me border LAL ho jayega
                                  : AppColors.primaryAccent,
                                width: 2
                              ),
                              boxShadow: [
                                BoxShadow(
                                    color: _desc.toUpperCase().contains("DANGER") || _desc.contains("खतरा")
                                        ? Colors.red.withOpacity(0.8)
                                        : (_isProcessing
                                            ? Colors.purpleAccent.withOpacity(0.6)
                                            : AppColors.primaryAccent.withOpacity(0.4)),
                                    blurRadius: 30,
                                    spreadRadius: 5)
                              ]),
                          child: ClipOval(
                              child: Stack(alignment: Alignment.center, children: [
                            // Tumhara GIF yahan hai
                            Image.asset("assets/orb.gif",
                                fit: BoxFit.cover, height: 80, width: 80),
                            // Jab scan ho raha ho, to gol loading ghumegi
                            if (_isProcessing)
                              const CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2)
                          ]))),
                      const SizedBox(height: 10),
                      
                      // STATUS TEXT
                      Text(_isProcessing ? (_isHindi ? "स्कैन कर रहा है..." : "Scanning...") : (_isHindi ? "ऑटो-पायलट सक्रिय" : "Auto-Pilot Active"),
                          style: const TextStyle(color: Colors.white54, fontSize: 12))
                    ]))),
            
            // 3. BACK BUTTON (Upar Left)
            Positioned(
                top: 40,
                left: 10,
                child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context)))),

            // ✅ 4. NEW: LANGUAGE TOGGLE BUTTON (Upar Right)
            Positioned(
                top: 40,
                right: 10,
                child: GestureDetector(
                  onTap: _toggleLanguage,
                  child: CircleAvatar(
                    backgroundColor: _isHindi ? AppColors.primaryAccent : Colors.black54,
                    radius: 24,
                    child: Text(
                      _isHindi ? "हिं" : "EN",
                      style: GoogleFonts.outfit(
                        color: Colors.white, 
                        fontWeight: FontWeight.bold, 
                        fontSize: 16
                      ),
                    ),
                  ),
                )),
          ]);
        } else {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryAccent));
        }
      },
    );
  }
}