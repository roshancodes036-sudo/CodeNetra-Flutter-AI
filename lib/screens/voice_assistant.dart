import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // ✅ NEW: User jo bol raha hai wo live dikhane ke liye
  String _liveSpokenText = "";

  bool _isHindi = false;
  Timer? _silenceTimer;
  late AnimationController _animController;

  // Speech initialization flag
  bool _isSpeechReady = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _brain.initBrain();

    _animController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1000),
        lowerBound: 0.95,
        upperBound: 1.05);

    _initSystem();
  }

  // 1. SETUP SYSTEM & MIC ONCE
  void _initSystem() async {
    await _setupVoice();

    // ✅ FIX: MIC ko sirf ek baar initialize karo
    _isSpeechReady = await _speech.initialize(
      onError: (val) => debugPrint("Speech Error: ${val.errorMsg}"),
      onStatus: (val) {
        debugPrint("Speech Status: $val");
        if (val == 'done' || val == 'notListening') {
          if (mounted && _isListening) {
            // Agar user bolna band karde, to process karo
            _stopListeningAndProcess();
          }
        }
      },
    );

    _tts.setCompletionHandler(() async {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted && !_isListening && !_isThinking) {
        setState(() {
          _aiResponse = "";
          _liveSpokenText = ""; // Purana text clear karo
          _status = _isHindi ? "सुन रहा हूँ..." : "LISTENING...";
        });
        _startListening();
      }
    });

    await Future.delayed(const Duration(milliseconds: 500));
    await _tts.speak(_isHindi
        ? "कोडनेत्रा ऑनलाइन है। मैं सुन रहा हूँ, सर।"
        : "CodeNetra online. I'm listening, Sir.");
  }

  Future<void> _setupVoice() async {
    await _tts.setLanguage(_isHindi ? "hi-IN" : "en-US");
    await _tts.setPitch(0.9);
    await _tts.setSpeechRate(0.5);
  }

  void _toggleLanguage() {
    _speech.stop();
    setState(() {
      _isHindi = !_isHindi;
      AIBrain.isHindi = _isHindi;
      _status = _isHindi ? "हिंदी मोड सक्रिय" : "ENGLISH MODE";
      _liveSpokenText = "";
    });
    _setupVoice();
    HapticFeedback.lightImpact();
    _tts
        .speak(_isHindi
            ? "हिंदी मोड चालू हो गया है, सर।"
            : "English mode activated, Sir.")
        .then((_) {
      _startListening();
    });
  }

  // 2. SMART LISTENING (✅ BUG FIXED)
  void _startListening() {
    if (_isListening || _isThinking || !_isSpeechReady) return;

    setState(() {
      _isListening = true;
      _status = _isHindi ? "सुन रहा हूँ..." : "LISTENING...";
      _liveSpokenText = ""; // Naya session, text clear karo
    });

    _animController.repeat(reverse: true);
    _resetSilenceTimer();

    // ✅ FIX: partialResults TRUE rakha hai taki Android hang na ho
    _speech.listen(
      onResult: (val) {
        _silenceTimer?.cancel();
        if (mounted) {
          setState(() {
            _liveSpokenText = val.recognizedWords; // Live text update
          });
        }
        // Agar pause hone ke baad final result aaya to direct process
        if (val.finalResult) {
          _processVoice(val.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor:
          const Duration(seconds: 3), // 3 second chup rahne par process karega
      localeId: _isHindi ? "hi-IN" : "en-IN",
      partialResults: true, // Zaroori hai!
    );
  }

  // ✅ NEW: Custom stop & process function
  void _stopListeningAndProcess() {
    if (_liveSpokenText.isNotEmpty) {
      _processVoice(_liveSpokenText);
    } else {
      _stopListening();
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
    _silenceTimer = Timer(const Duration(seconds: 45), () {
      _stopListening();
      _tts.speak(_isHindi
          ? "मैं स्लीप मोड में जा रहा हूँ, सर।"
          : "Going to sleep mode, Sir.");
    });
  }

  // 3. INTELLIGENT PROCESSING
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

    // The Aura Response
    if (lowerQuery.contains("who made you") ||
        lowerQuery.contains("created by") ||
        lowerQuery.contains("tumhe kisne banaya") ||
        lowerQuery.contains("tumhara malik kaun hai")) {
      _finalizeResponse(_isHindi
          ? "मैं रोशन चौरसिया के विज़न की डिजिटल धड़कन हूँ। मैं अंधेरे और उजाले के बीच का पुल हूँ। मैं कोडनेत्रा हूँ, सर।"
          : "I am the digital heartbeat of Roshan Chaurasiya's vision. I exist to bridge the gap between darkness and light. I am CodeNetra, Sir.");
      return;
    }

    if (lowerQuery.contains("who are you") ||
        lowerQuery.contains("tum kaun ho")) {
      _finalizeResponse(_isHindi
          ? "मैं कोडनेत्रा एआई हूँ, आपका इंटेलिजेंट असिस्टेंट, सर।"
          : "I am CodeNetra AI, your intelligent assistant, Sir.");
      return;
    }

    String prompt = """
    You are CodeNetra-AI. 
    User said: "$query"
    INSTRUCTIONS:
    1. Reply STRICTLY in ${_isHindi ? "HINDI" : "ENGLISH"}. Tone: Smart, Professional, Concise.
    2. Length: 2 to 3 sentences.
    3. Be direct and helpful.
    """;

    String? res = await _brain.askLaravel(prompt);

    _finalizeResponse(res ??
        (_isHindi ? "मुझे वह समझ नहीं आया, सर।" : "I didn't catch that, Sir."));
  }

  void _finalizeResponse(String response) async {
    if (mounted) {
      setState(() {
        _isThinking = false;
        _aiResponse = response;
        _status = "ONLINE";
        _liveSpokenText = ""; // Jawab aate hi live text hata do
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

  // 4. HOLOGRAPHIC UI
  @override
  Widget build(BuildContext context) {
    return ProPageLayout(
      title: "CODE NETRA",
      icon: Icons.graphic_eq,
      child: Stack(
        children: [
          Container(
            color: Colors.black,
            width: double.infinity,
            height: double.infinity,
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              // STATUS TEXT
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    border: Border.all(
                        color: _isListening ? Colors.red : Colors.cyan,
                        width: 1),
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

              const SizedBox(height: 30),

              // ✅ NEW: LIVE SPOKEN TEXT (User ki aawaz text me)
              if (_liveSpokenText.isNotEmpty && !_isThinking)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Text(
                    '"$_liveSpokenText"',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // THE ORB
              GestureDetector(
                  onTap: () {
                    if (_isListening) {
                      _stopListening();
                    } else {
                      _tts.speak(
                          _isHindi ? "मैं यहाँ हूँ, सर।" : "I'm here, Sir.");
                      _startListening();
                    }
                  },
                  child: ScaleTransition(
                      scale: _animController,
                      child: Container(
                          height:
                              450, // Thoda chota kiya taki text ki jagah bache
                          width: 450,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.transparent),
                          child: ClipOval(
                              child:
                                  Stack(alignment: Alignment.center, children: [
                            Image.asset("assets/orb.gif",
                                fit: BoxFit.cover, height: 450, width: 450),
                            if (_isThinking)
                              const SizedBox(
                                height: 450,
                                width: 450,
                                child: CircularProgressIndicator(
                                    color: Colors.cyanAccent, strokeWidth: 2),
                              ),
                          ]))))),

              const SizedBox(height: 40),

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

          // LANGUAGE TOGGLE BUTTON
          Positioned(
            top: 20,
            right: 20,
            child: GestureDetector(
              onTap: _toggleLanguage,
              child: CircleAvatar(
                backgroundColor:
                    _isHindi ? Colors.cyan.withOpacity(0.8) : Colors.white24,
                radius: 24,
                child: Text(
                  _isHindi ? "हिं" : "EN",
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
