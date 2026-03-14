import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // ✅ NEW: Markdown Package

import '../theme/app_colors.dart';
import '../widgets/custom_widgets.dart';
import '../services/ai_logic.dart';

class ErrorFixerScreen extends StatefulWidget {
  const ErrorFixerScreen({super.key});
  @override
  State<ErrorFixerScreen> createState() => _ErrorFixerScreenState();
}

class _ErrorFixerScreenState extends State<ErrorFixerScreen> {
  final TextEditingController _ctrl = TextEditingController();
  String _solution = "";
  bool _loading = false;
  File? _errorImage;
  final AIBrain _brain = AIBrain();

  @override
  void initState() {
    super.initState();
    _brain.initBrain();
  }

  Future<void> _scanErrorImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _errorImage = File(pickedFile.path);
        _loading = true;
        _solution = "🔍 Scanning Error Log from Image...";
      });
      String prompt =
          "Extract the error message from this screenshot and FIX IT. Explain the root cause briefly.";
          
      String? res = await _brain.askWithImage(prompt, _errorImage!);
      
      if (!mounted) return; // ✅ Safety Check Added

      setState(() {
        _loading = false;
        _solution = res ?? "Could not read error from image.";
      });
    }
  }

  Future<void> _searchOnGoogle() async {
    if (_ctrl.text.isEmpty) return;
    String query = _ctrl.text.split('\n').first;
    final url = Uri.parse(
        "https://www.google.com/search?q=${Uri.encodeComponent(query)}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _fixError() async {
    if (_ctrl.text.isEmpty && _errorImage == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _solution = "🔍 Analyzing Stack Trace & Logic...";
    });
    
    String prompt = """
I have a bug. Here is the ERROR LOG:
${_ctrl.text}

TASK:
1. Identify the root cause.
2. Provide the corrected code snippet.
3. Explain briefly why this happened.
""";

    String? res = await _brain.askLaravel(prompt);
    
    if (!mounted) return; // ✅ Safety Check Added

    setState(() {
      _loading = false;
      _solution = res ?? "Could not solve this error.";
    });
  }

  @override
  Widget build(BuildContext context) {
    return ProPageLayout(
      title: "Error Debugger Pro",
      icon: Icons.bug_report_rounded,
      child: Column(children: [
        Expanded(
            flex: 1,
            child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.redAccent.withAlpha(128))),
                child: Column(children: [
                  Expanded(
                      child: TextField(
                          controller: _ctrl,
                          maxLines: null,
                          expands: true,
                          style: GoogleFonts.firaCode(
                              color: Colors.redAccent, fontSize: 13),
                          decoration: const InputDecoration(
                              hintText:
                                  "Paste Stack Trace OR Scan Screenshot...",
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none))),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text("Scan Error:",
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 12)),
                    IconButton(
                        icon: const Icon(Icons.camera_alt,
                            color: AppColors.primaryAccent),
                        onPressed: () =>
                            _scanErrorImage(ImageSource.camera),
                        tooltip: "Scan from Camera"),
                    IconButton(
                        icon: const Icon(Icons.image,
                            color: AppColors.primaryAccent),
                        onPressed: () =>
                            _scanErrorImage(ImageSource.gallery),
                        tooltip: "Upload Screenshot")
                  ])
                ]))),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: ElevatedButton.icon(
                  onPressed: _loading ? null : _fixError,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_fix_high,
                          color: Colors.black),
                  label: Text(_loading ? " DEBUGGING..." : "FIX ERROR",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16)))),
          const SizedBox(width: 10),
          InkWell(
              onTap: _searchOnGoogle,
              child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppColors.borderSubtle)),
                  child: const Icon(Icons.search, color: Colors.white)))
        ]),
        const SizedBox(height: 16),
        Expanded(
            flex: 2,
            child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(16)),
                child: SingleChildScrollView(
                    child: _solution.isEmpty
                        ? Center(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.health_and_safety,
                                      size: 50, color: Colors.grey[800]),
                                  const SizedBox(height: 10),
                                  Text(
                                      "Paste error or scan screenshot to debug",
                                      style: TextStyle(
                                          color: Colors.grey[700]))
                                ]))
                        : 
                        // ✅ CHANGED: Premium Markdown Theme for Error Debugger
                        MarkdownBody(
                            data: _solution,
                            selectable: true,
                            styleSheet: MarkdownStyleSheet(
                              p: GoogleFonts.outfit(
                                  color: Colors.white70,
                                  fontSize: 15,
                                  height: 1.5),
                              // 🔥 Error screen ke hisaab se headings RedAccent me
                              h1: GoogleFonts.outfit(
                                  color: Colors.redAccent,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold),
                              h2: GoogleFonts.outfit(
                                  color: Colors.redAccent,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold),
                              h3: GoogleFonts.outfit(
                                  color: Colors.redAccent,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                              strong: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                              listBullet: const TextStyle(
                                  color: Colors.redAccent, fontSize: 18),
                              code: GoogleFonts.firaCode(
                                  color: Colors.greenAccent, // Code hara dikhega
                                  backgroundColor: Colors.transparent),
                              codeblockDecoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: AppColors.borderSubtle),
                              ),
                            ),
                          ))))
      ]),
    );
  }
}
