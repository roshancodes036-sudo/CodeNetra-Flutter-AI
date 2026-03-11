import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // HapticFeedback ke liye
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

// Tumhare project ke imports
import '../theme/app_colors.dart';
import '../widgets/custom_widgets.dart';
import '../services/ai_logic.dart';

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});
  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen>
    with SingleTickerProviderStateMixin {
  // Services
  late stt.SpeechToText _speech;
  final FlutterTts _tts = FlutterTts();
  final AIBrain _brain = AIBrain();

  // Variables
  bool _isListening = false;
  bool _isThinking = false;
  String _status = "INITIALIZING...";
  String _aiResponse = "";

  // ✅ NEW: Language State
  bool _isHindi = false; 

  // Safety Timer
  Timer? _silenceTimer;

  // Animation
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _brain.initBrain();

    // Orb Pulse Animation
    _animController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1000),
        lowerBound: 0.95,
        upperBound: 1.05);

    _initSystem();
  }

  // 1. SETUP SYSTEM (✅ Hindi/English Auto-Loop Logic)
  void _initSystem() async {
    await _setupVoice();

    // ✅ MAGIC LOOP: Jawab khatam hote hi screen saaf aur sunna shuru
    _tts.setCompletionHandler(() async {
      await Future.delayed(const Duration(milliseconds: 200));

      if (mounted && !_isListening && !_isThinking) {
        setState(() {
          _aiResponse = ""; // Screen Clear
          _status = _isHindi ? "सुन रहा हूँ..." : "LISTENING...";
        });
        _startListening(); // Auto Listen Start
      }
    });

    await Future.delayed(const Duration(milliseconds: 500));
    await _tts.speak(_isHindi ? "कोडनेत्रा ऑनलाइन है। मैं सुन रहा हूँ, सर।" : "CodeNetra online. I'm listening, Sir.");
  }

  // ✅ NEW: Voice Setup Function
  Future<void> _setupVoice() async {
    await _tts.setLanguage(_isHindi ? "hi-IN" : "en-US");
    await _tts.setPitch(0.9); // Deep & Professional
    await _tts.setSpeechRate(0.5); // Clear Speed
  }

  // ✅ NEW: Language Toggle Function
  void _toggleLanguage() {
    _speech.stop(); // Turaant sunna band karo
    setState(() {
      _isHindi = !_isHindi;
      AIBrain.isHindi = _isHindi; // Update global AI brain state
      _status = _isHindi ? "हिंदी मोड सक्रिय" : "ENGLISH MODE";
    });
    _setupVoice(); 
    HapticFeedback.lightImpact();
    _tts.speak(_isHindi ? "हिंदी मोड चालू हो गया है, सर।" : "English mode activated, Sir.").then((_) {
      _startListening(); // Awaz badalne ke baad wapas sunna shuru
    });
  }

  // 2. SMART LISTENING (✅ FAST & OPTIMIZED)
  void _startListening() async {
    if (_isListening || _isThinking) return;

    bool available = await _speech.initialize(
      onError: (val) {
        if (val.errorMsg != "error_busy") _resetSilenceTimer();
      },
      onStatus: (val) {
        if (val == 'done' || val == 'notListening') {
          if (mounted && !_isThinking) {
            setState(() {
              _isListening = false;
              if (_aiResponse.isEmpty) _status = _isHindi ? "प्रोसेसिंग..." : "PROCESSING...";
            });
            _animController.stop();
            _animController.value = 1.0;
          }
        }
      },
    );

    if (available) {
      setState(() {
        _isListening = true;
        _status = _isHindi ? "सुन रहा हूँ..." : "LISTENING...";
      });
      _animController.repeat(reverse: true);
      _resetSilenceTimer();

      _speech.listen(
        onResult: (val) {
          _silenceTimer?.cancel();
          if (val.finalResult) {
            _processVoice(val.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 20),
        // ✅ 2 SECONDS PAUSE: User ko sochne ka thoda time dega, par rukte hi turant catch karega
        pauseFor: const Duration(seconds: 2),
        // 🔥 FAST RECOGNITION MAGIC: en-IN (Indian English) ya hi-IN
        localeId: _isHindi ? "hi-IN" : "en-IN", 
        // ⚠️ ListenMode hata diya taki delay na ho (Default is fast)
        partialResults: false, // Partial results ko false kiya taki sirf final text hi process ho
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    _silenceTimer?.cancel();
    if (mounted) {
      setState(() {
        _isListening = false;
        _animController.stop();
        _status = _isHindi ? "बोलने के लिए टैप करें" : "TAP TO ACTIVATE";
      });
    }
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 60), () {
      _stopListening();
      _tts.speak(_isHindi ? "मैं स्लीप मोड में जा रहा हूँ, सर।" : "Going to sleep mode, Sir.");
    });
  }

  // 3. INTELLIGENT PROCESSING (✅ Hindi Prompt Support Added)
  void _processVoice(String query) async {
    if (query.trim().isEmpty) {
      _startListening();
      return;
    }

    _speech.stop();
    _silenceTimer?.cancel();

    setState(() {
      _isListening = false;
      _isThinking = true;
      _animController.stop();
      _status = _isHindi ? "सोच रहा हूँ..." : "ANALYZING...";
    });

    String lowerQuery = query.toLowerCase();

    // 🔥🔥🔥 THE AURA RESPONSE (HINDI & ENGLISH) 🔥🔥🔥
    if (lowerQuery.contains("who made you") ||
        lowerQuery.contains("created by") ||
        lowerQuery.contains("tumhe kisne banaya") ||
        lowerQuery.contains("tumhara malik kaun hai")) {
      _finalizeResponse(_isHindi 
          ? "मैं रोशन चौरसिया के विज़न की डिजिटल धड़कन हूँ। मैं अंधेरे और उजाले के बीच का पुल हूँ। मैं कोडनेत्रा हूँ, सर।" 
          : "I am the digital heartbeat of Roshan Chaurasiya's vision. I exist to bridge the gap between darkness and light. I am CodeNetra, Sir.");
      return;
    }

    // Standard Identity
    if (lowerQuery.contains("who are you") || lowerQuery.contains("tum kaun ho")) {
      _finalizeResponse(_isHindi
          ? "मैं कोडनेत्रा एआई हूँ, आपका इंटेलिजेंट असिस्टेंट, सर।"
          : "I am CodeNetra AI, your intelligent assistant, Sir.");
      return;
    }

    // Prompt for Gemini
    String prompt = """
    You are CodeNetra-AI. 
    User said: "$query"
    INSTRUCTIONS:
    1. Reply STRICTLY in ${_isHindi ? "HINDI" : "ENGLISH"}. Tone: Smart, Professional, Concise.
    2. Length: 2 to 3 sentences (Approx 60 words).
    3. Be direct and helpful.
    """;

    String? res = await _brain.askLaravel(prompt);

    _finalizeResponse(res ?? (_isHindi ? "मुझे वह समझ नहीं आया, सर।" : "I didn't catch that, Sir."));
  }

  void _finalizeResponse(String response) async {
    if (mounted) {
      setState(() {
        _isThinking = false;
        _aiResponse = response;
        _status = "ONLINE";
      });
    }
    await _tts.speak(response);
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _silenceTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  // 4. HOLOGRAPHIC UI (✅ Wrapped in Stack for Language Toggle)
  @override
  Widget build(BuildContext context) {
    return ProPageLayout(
      title: "CODE NETRA",
      icon: Icons.graphic_eq,
      child: Stack(
        children: [
          // MAIN CONTENT
          Container(
            color: Colors.black,
            width: double.infinity,
            height: double.infinity,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              // STATUS TEXT (HUD)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    border: Border.all(
                        color: _isListening ? Colors.red : Colors.cyan, width: 1),
                    borderRadius: BorderRadius.circular(4)),
                child: Text(
                  _status,
                  style: GoogleFonts.shareTechMono(
                    color: _isListening ? Colors.redAccent : Colors.cyanAccent,
                    fontSize: 16,
                    letterSpacing: 2.0,
                  ),
                ),
              ),

              const SizedBox(height: 50),

              // THE ORB (550 Size - NO BACKGROUND GLOW)
              GestureDetector(
                  onTap: () {
                    if (_isListening) {
                      _stopListening();
                    } else {
                      _tts.speak(_isHindi ? "मैं यहाँ हूँ, सर।" : "I'm here, Sir.");
                      _startListening();
                    }
                  },
                  child: ScaleTransition(
                      scale: _animController,
                      child: Container(
                          height: 550,
                          width: 550,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.transparent // Pure Transparent
                              ),
                          child: ClipOval(
                              child: Stack(alignment: Alignment.center, children: [
                            Image.asset("assets/orb.gif",
                                fit: BoxFit.cover, height: 550, width: 550),

                            // Thinking Indicator
                            if (_isThinking)
                              const SizedBox(
                                height: 550,
                                width: 550,
                                child: CircularProgressIndicator(
                                    color: Colors.cyanAccent, strokeWidth: 2),
                              ),
                          ]))))),

              const SizedBox(height: 50),

              // HOLOGRAPHIC ANSWER DISPLAY
              if (_aiResponse.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Text(
                    _aiResponse.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.shareTechMono(
                        color: Colors.cyanAccent,
                        fontSize: 18,
                        height: 1.4,
                        shadows: [
                          const Shadow(
                            blurRadius: 8.0,
                            color: Colors.cyan,
                            offset: Offset(0, 0),
                          ),
                        ]),
                  ),
                ),

              if (_aiResponse.isEmpty) const Spacer(),
              const SizedBox(height: 30),
            ]),
          ),

          // ✅ LANGUAGE TOGGLE BUTTON (Top Right Corner)
          Positioned(
            top: 20,
            right: 20,
            child: GestureDetector(
              onTap: _toggleLanguage,
              child: CircleAvatar(
                backgroundColor: _isHindi ? Colors.cyan.withOpacity(0.8) : Colors.white24,
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
            ),
          ),
        ],
      ),
    );
  }
}