import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ NEW: HapticFeedback ke liye
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
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

class _PDFScreenState extends State<PDFScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  final FlutterTts _tts = FlutterTts();
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.devanagiri);
  final AIBrain _brain = AIBrain();

  bool _isDetecting = false;
  bool _documentFound = false;
  String _aiResultText = "";
  bool _isLoadingAI = false;

  // 🌐 NEW: Language State (AIBrain se sync karega)
  bool _isHindi = AIBrain.isHindi;

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

  // 🌐 NEW: Smart Voice Setup
  Future<void> _setupVoice() async {
    await _tts.setLanguage(_isHindi ? "hi-IN" : "en-US");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  // 🌐 NEW: Language Toggle Function
  void _toggleLanguage() async {
    await _tts.stop();
    setState(() {
      _isHindi = !_isHindi;
      AIBrain.isHindi = _isHindi; // Sync with AI Brain
      _aiResultText = ""; // Clear old text
    });

    await _setupVoice();
    HapticFeedback.lightImpact();

    String speech = _isHindi
        ? "हिंदी भाषा सक्रिय। डॉक्यूमेंट स्कैन करें।"
        : "English language active. Scan a document.";
    await _tts.speak(speech);
  }

  Future<void> _initTTSAndCamera() async {
    await _setupVoice();

    String initialGreeting = _isHindi
        ? "लाइव पीडीएफ एनालिसिस एक्टिव सर। कृपया कोई कागज़ या डॉक्यूमेंट कैमरे के सामने लाएं।"
        : "Live PDF analysis active sir. Please place a document in front of the camera.";
    await _tts.speak(initialGreeting);

    if (kIsWeb) {
      setState(() {
        _aiResultText =
            "⚠️ चेतावनी: लाइव कैमरा और ML Kit वेब ब्राउज़र (Firebase Studio) पर काम नहीं करते। कृपया इसे अपने असली Android फोन में APK बनाकर टेस्ट करें।";
      });
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {});
      _startLocalDocumentDetection();
    }
  }

  void _startLocalDocumentDetection() {
    _cameraController?.startImageStream((CameraImage image) async {
      if (_isDetecting || _documentFound) return;
      _isDetecting = true;

      try {
        final WriteBuffer allBytes = WriteBuffer();
        for (final Plane plane in image.planes) {
          allBytes.putUint8List(plane.bytes);
        }
        final bytes = allBytes.done().buffer.asUint8List();

        final Size imageSize =
            Size(image.width.toDouble(), image.height.toDouble());
        final imageRotation = InputImageRotationValue.fromRawValue(
                _cameraController!.description.sensorOrientation) ??
            InputImageRotation.rotation0deg;
        final inputImageFormat =
            InputImageFormatValue.fromRawValue(image.format.raw) ??
                InputImageFormat.nv21;

        final inputImageData = InputImageMetadata(
          size: imageSize,
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: image.planes[0].bytesPerRow,
        );

        final inputImage =
            InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
        final RecognizedText recognizedText =
            await _textRecognizer.processImage(inputImage);

        if (recognizedText.text.length > 20) {
          _documentFound = true;
          _cameraController?.stopImageStream();
          _captureAndSendToGemini();
        }
      } catch (e) {
        // Ignore stream errors
      } finally {
        _isDetecting = false;
      }
    });
  }

  Future<void> _captureAndSendToGemini() async {
    String foundMsg = _isHindi
        ? "डॉक्यूमेंट मिल गया। स्कैनिंग हो रही है।"
        : "Document found. Scanning in progress.";
    await _tts.speak(foundMsg);

    setState(() {
      _isLoadingAI = true;
    });

    try {
      final XFile file = await _cameraController!.takePicture();
      String? result = await _brain.analyzeDocumentLive(File(file.path));

      setState(() {
        _aiResultText = result ??
            (_isHindi
                ? "माफ़ करें, मैं इस डॉक्यूमेंट को समझ नहीं पाया।"
                : "Sorry, I couldn't understand this document.");
        _isLoadingAI = false;
      });

      await _tts.speak(_aiResultText);
    } catch (e) {
      setState(() {
        _isLoadingAI = false;
        _aiResultText =
            _isHindi ? "एरर: स्कैन फेल हो गया।" : "Error: Scan failed.";
      });
    }
  }

  void _resetScanner() async {
    if (kIsWeb) return;
    await _tts.stop();
    setState(() {
      _documentFound = false;
      _aiResultText = "";
      _isLoadingAI = false;
    });

    String restartMsg = _isHindi
        ? "लाइव पीडीएफ एनालिसिस रीस्टार्ट हो गया है।"
        : "Live PDF analysis restarted.";
    await _tts.speak(restartMsg);
    _startLocalDocumentDetection();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    _tts.stop();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _resetScanner,
      child: ProPageLayout(
        title: "Live DocuMind",
        icon: Icons.document_scanner,
        child: Stack(
          children: [
            // 1. Live Camera
            if (_cameraController != null &&
                _cameraController!.value.isInitialized)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CameraPreview(_cameraController!),
                ),
              )
            else
              const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primaryAccent)),

            // 2. Scanner Animation
            if (!_documentFound && !kIsWeb)
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Positioned(
                    top: _animationController.value *
                        MediaQuery.of(context).size.height *
                        0.6,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                              color: Colors.greenAccent.withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 5)
                        ],
                        color: Colors.greenAccent,
                      ),
                    ),
                  );
                },
              ),

            // 3. Status Text (Top Center)
            Positioned(
              top: 15,
              left: 20,
              right: 80, // Made space for the button
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _documentFound ? Colors.green : Colors.redAccent),
                ),
                child: Text(
                  _documentFound
                      ? (_isHindi
                          ? "✅ स्कैन पूरा हुआ (डबल-टैप)"
                          : "✅ Scan Complete (Double-Tap)")
                      : (_isHindi
                          ? "🔍 कागज़ ढूंढ रहा है..."
                          : "🔍 Looking for document..."),
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            // 🌐 4. NEW: LANGUAGE TOGGLE BUTTON (Top Right)
            Positioned(
              top: 15,
              right: 15,
              child: GestureDetector(
                onTap: _toggleLanguage,
                child: CircleAvatar(
                  backgroundColor: _isHindi
                      ? Colors.greenAccent.withOpacity(0.8)
                      : Colors.black87,
                  radius: 22,
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

            // 5. AI Loading
            if (_isLoadingAI)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.cyanAccent),
                      const SizedBox(height: 15),
                      Text(
                          _isHindi
                              ? "AI डॉक्यूमेंट पढ़ रहा है..."
                              : "AI is reading the document...",
                          style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),

            // 6. AI Result Bottom Sheet
            if (_aiResultText.isNotEmpty)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  height: MediaQuery.of(context).size.height * 0.45,
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20)),
                    border: Border(
                        top: BorderSide(color: Colors.cyanAccent, width: 2)),
                  ),
                  child: SingleChildScrollView(
                    child: MarkdownBody(
                      data: _aiResultText,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: GoogleFonts.outfit(
                            color: Colors.white, fontSize: 16, height: 1.5),
                        strong: GoogleFonts.outfit(
                            color: Colors.cyanAccent,
                            fontWeight: FontWeight.bold),
                      ),
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
