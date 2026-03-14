import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // ✅ NEW: Markdown Package

import '../theme/app_colors.dart';
import '../widgets/custom_widgets.dart';
import '../services/ai_logic.dart';

class PDFScreen extends StatefulWidget {
  const PDFScreen({super.key});
  @override
  State<PDFScreen> createState() => _PDFScreenState();
}

class _PDFScreenState extends State<PDFScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final AIBrain _brain = AIBrain();

  String _pdfText = "";
  String _fileName = "";
  bool _isLoading = false;
  List<String> _suggestedChips = [];
  final List<Map<String, String>> _messages = [
    {
      "role": "ai",
      "msg":
          "Select a PDF document. I will analyze it and give you quick suggestions."
    }
  ];

  @override
  void initState() {
    super.initState();
    _brain.initBrain();
  }

  Future<void> _pickPDF() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
      if (result != null) {
        setState(() {
          _isLoading = true;
          _fileName = result.files.single.name;
          _messages.add({"role": "user", "msg": "📂 Uploaded: $_fileName"});
          _suggestedChips = [];
        });
        
        List<int> bytes;
        if (kIsWeb) {
          if (result.files.single.bytes != null) {
            bytes = result.files.single.bytes!;
          } else {
            throw Exception("Web File bytes are null");
          }
        } else {
          if (result.files.single.path != null) {
            File file = File(result.files.single.path!);
            bytes = file.readAsBytesSync();
          } else {
            throw Exception("Mobile File path is null");
          }
        }
        
        final PdfDocument document = PdfDocument(inputBytes: bytes);
        String text = PdfTextExtractor(document).extractText();
        document.dispose();
        
        if (text.trim().isEmpty) {
          setState(() {
            _isLoading = false;
            _messages.add({
              "role": "ai",
              "msg":
                  "⚠️ This PDF seems to be an image (Scanned). Please upload a text-based PDF."
            });
          });
          return;
        }
        
        setState(() {
          _pdfText = text;
          _isLoading = false;
          _suggestedChips = [
            "📝 Summarize this",
            "🔑 List Key Points",
            "❓ What is the conclusion?",
            "📅 Find all dates",
            "📧 Extract Emails"
          ];
        });
        _askAI("Summarize this document in 3 bullet points.");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _messages.add({
          "role": "ai",
          "msg": "Error reading PDF. Please ensure it's a valid file."
        });
      });
    }
  }

  void _askAI(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _messages.add({"role": "user", "msg": query});
      _isLoading = true;
      _ctrl.clear();
    });
    _scrollToBottom();
    
    String lowerQuery = query.toLowerCase();
    bool isHindi = lowerQuery.contains("kisne") ||
        lowerQuery.contains("kya") ||
        lowerQuery.contains("banaya") ||
        lowerQuery.contains("kaise") ||
        lowerQuery.contains("sakte") ||
        lowerQuery.contains("tum") ||
        lowerQuery.contains("namaste");

    if (lowerQuery.contains("who made you") ||
        lowerQuery.contains("kisne banaya")) {
      await Future.delayed(const Duration(seconds: 1));
      String reply = isHindi
          ? """मैं **CodeNetra AI** हूँ, एक एडवांस इंटेलिजेंस सिस्टम जिसे **रोशन चौरसिया** ने बनाया है।"""
          : """I am **CodeNetra AI**, an advanced intelligence system engineered by **Roshan Chaurasiya**.""";
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _messages.add({"role": "ai", "msg": reply});
      });
      _scrollToBottom();
      return;
    }
    
    if (lowerQuery.contains("what can you do") ||
        lowerQuery.contains("kya kar sakte ho")) {
      await Future.delayed(const Duration(seconds: 1));
      String reply = isHindi
          ? """मैं **CodeNetra AI** हूँ। मेरी मुख्य शक्तियां ये हैं:\n1. **📄 DocuMind (PDF मास्टर)**\n2. **👁️ नेत्रा विजन**\n3. **🗣️ वॉइस असिस्टेंट**\n4. **💻 कोड एक्सपर्ट**"""
          : """I am **CodeNetra AI**. Here is my capability suite:\n1. **📄 DocuMind**\n2. **👁️ Netra Vision**\n3. **🗣️ Voice Commander**\n4. **💻 Code Expert**""";
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _messages.add({"role": "ai", "msg": reply});
      });
      _scrollToBottom();
      return;
    }
    
    if (_pdfText.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _messages.add({
          "role": "ai",
          "msg": isHindi
              ? "कृपया पहले कोई PDF अपलोड करें! 📂"
              : "Please upload a PDF first! 📂"
        });
      });
      return;
    }
    
    String prompt =
        "CONTEXT FROM PDF: $_pdfText \n USER QUESTION: \"$query\" \n INSTRUCTIONS: 1. Answer ONLY based on the PDF context. 2. Detect user language ($query). If Hindi, answer in Hindi.";
    
    String? res = await _brain.askLaravel(prompt);
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        _messages.add({"role": "ai", "msg": res ?? "Connection Error."});
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ProPageLayout(
      title: "DocuMind PDF",
      icon: Icons.picture_as_pdf_rounded,
      child: Column(children: [
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle)),
            child: Row(children: [
              Icon(Icons.description,
                  color: _fileName.isEmpty ? Colors.grey : Colors.redAccent),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                      _fileName.isEmpty ? "No PDF Selected" : _fileName,
                      style: TextStyle(
                          color: _fileName.isEmpty
                              ? Colors.grey
                              : Colors.white,
                          fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis)),
              ElevatedButton.icon(
                  onPressed: _pickPDF,
                  icon: const Icon(Icons.upload_file,
                      size: 18, color: Colors.black),
                  label: const Text("Upload",
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryAccent))
            ])),
        const SizedBox(height: 10),
        Expanded(
            child: Container(
                decoration: BoxDecoration(
                    color: const Color(0xFF0D0D0D),
                    borderRadius: BorderRadius.circular(16)),
                child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      bool isAi = msg['role'] == 'ai';
                      
                      return Align(
                          alignment: isAi
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context)
                                          .size
                                          .width *
                                      0.85), // Thoda choda kiya text padhne ke liye
                              decoration: BoxDecoration(
                                  color: isAi
                                      ? AppColors.cardSurface
                                      : AppColors.primaryAccent
                                          .withAlpha(51),
                                  borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(12),
                                      topRight: const Radius.circular(12),
                                      bottomLeft: isAi
                                          ? Radius.zero
                                          : const Radius.circular(12),
                                      bottomRight: isAi
                                          ? const Radius.circular(12)
                                          : Radius.zero),
                                  border: Border.all(
                                      color: isAi
                                          ? Colors.white10
                                          : AppColors.primaryAccent
                                              .withAlpha(128))),
                              child: isAi 
                                  // ✅ AI ke Message ke liye Premium Markdown
                                  ? MarkdownBody(
                                      data: msg['msg']!,
                                      selectable: true,
                                      styleSheet: MarkdownStyleSheet(
                                        p: GoogleFonts.outfit(
                                            color: Colors.white70,
                                            fontSize: 15,
                                            height: 1.5),
                                        h1: GoogleFonts.outfit(
                                            color: Colors.cyanAccent,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold),
                                        h2: GoogleFonts.outfit(
                                            color: Colors.cyanAccent,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold),
                                        strong: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                        listBullet: const TextStyle(
                                            color: Colors.cyanAccent, fontSize: 16),
                                      ),
                                    )
                                  // 👤 User ke Message ke liye Normal Text
                                  : SelectableText(msg['msg']!,
                                      style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 15,
                                          height: 1.5))));
                    }))),
        if (_isLoading)
          const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(
                  color: AppColors.primaryAccent, minHeight: 2)),
        if (_suggestedChips.isNotEmpty && !_isLoading)
          Container(
              height: 50,
              margin: const EdgeInsets.symmetric(vertical: 5),
              child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: _suggestedChips.length,
                  itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ActionChip(
                          label: Text(_suggestedChips[index]),
                          labelStyle: const TextStyle(
                              color: Colors.white, fontSize: 12),
                          backgroundColor: AppColors.cardSurface,
                          side: BorderSide(
                              color: AppColors.primaryAccent
                                  .withAlpha(128)),
                          shape: const StadiumBorder(),
                          onPressed: () =>
                              _askAI(_suggestedChips[index]))))),
        Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.borderSubtle)),
            child: Row(children: [
              Expanded(
                  child: TextField(
                      controller: _ctrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          hintText: "Ask something about this PDF...",
                          hintStyle: TextStyle(color: Colors.white24),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16)),
                      onSubmitted: (val) => _askAI(val))),
              IconButton(
                  icon: const Icon(Icons.send,
                      color: AppColors.primaryAccent),
                  onPressed: () => _askAI(_ctrl.text))
            ]))
      ]),
    );
  }
}
