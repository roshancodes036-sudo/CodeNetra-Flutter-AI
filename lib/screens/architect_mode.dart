import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // ✅ NEW: Markdown Package

import '../theme/app_colors.dart';
import '../widgets/custom_widgets.dart';
import '../services/ai_logic.dart';

class ArchitectScreen extends StatefulWidget {
  const ArchitectScreen({super.key});
  @override
  State<ArchitectScreen> createState() => _ArchitectScreenState();
}

class _ArchitectScreenState extends State<ArchitectScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final AIBrain _brain = AIBrain();
  String _blueprint = "";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _brain.initBrain();
  }

  void _generateBlueprint() async {
    if (_ctrl.text.isEmpty) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _blueprint = "";
    });

    String prompt = """
ACT AS A SENIOR SOFTWARE ARCHITECT (CTO Level).
User wants to build: "${_ctrl.text}".
Create a complete SYSTEM DESIGN BLUEPRINT.

OUTPUT FORMAT (Use Markdown):
## 🛠️ 1. Recommended Tech Stack
- Frontend: (e.g. Flutter)
- Backend: (e.g. Serverpod / Node.js)
- Database: (e.g. PostgreSQL / Firebase)

## 🗄️ 2. Database Schema (Tables & Fields)
- **Users**: id, name, email...

## 🔌 3. Key API Endpoints
- `POST /auth/login`

## 🚀 4. Development Steps (MVP)
1. Setup project...
""";

    String? res = await _brain.askLaravel(prompt);
    
    if (!mounted) return; // ✅ Safety check added to prevent crashes

    setState(() {
      _isLoading = false;
      _blueprint = res ?? "Failed to generate blueprint. Try again.";
    });
  }

  @override
  Widget build(BuildContext context) {
    return ProPageLayout(
      title: "System Architect",
      icon: Icons.architecture,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtle)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("What do you want to build?",
                    style:
                        GoogleFonts.outfit(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: _ctrl,
                          style: GoogleFonts.outfit(
                              color: Colors.white, fontSize: 18),
                          decoration: const InputDecoration(
                              hintText: "e.g. Airbnb Clone, Crypto Wallet...",
                              hintStyle: TextStyle(color: Colors.white24),
                              border: InputBorder.none))),
                  IconButton(
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryAccent))
                          : const Icon(Icons.send_rounded,
                              color: AppColors.primaryAccent, size: 30),
                      onPressed: _isLoading ? null : _generateBlueprint)
                ])
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_blueprint.isEmpty)
            SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                    children: [
                  "Social Media App",
                  "E-commerce Store",
                  "Chat Application",
                  "Task Manager"
                ]
                        .map((idea) => Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: ActionChip(
                                label: Text(idea),
                                backgroundColor: AppColors.backgroundDark,
                                side: BorderSide(
                                    color: AppColors.primaryAccent
                                        .withAlpha(128)),
                                labelStyle:
                                    const TextStyle(color: Colors.white),
                                onPressed: () {
                                  _ctrl.text = idea;
                                  _generateBlueprint();
                                })))
                        .toList())),
          if (_blueprint.isNotEmpty)
            Expanded(
                child: Container(
                    margin: const EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                        color: const Color(0xFF0D0D0D),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderSubtle)),
                    child: Column(children: [
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: const BoxDecoration(
                              color: AppColors.cardSurface,
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16))),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(children: [
                                  const Icon(Icons.wb_sunny,
                                      color: Colors.amber, size: 18),
                                  const SizedBox(width: 8),
                                  Text("Project Blueprint",
                                      style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold))
                                ]),
                                InkWell(
                                    onTap: () {
                                      Clipboard.setData(
                                          ClipboardData(text: _blueprint));
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content:
                                                  Text("Blueprint Copied!")));
                                    },
                                    child: const Icon(Icons.copy,
                                        color: Colors.white70, size: 18))
                              ])),
                      Expanded(
                          child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              // ✅ CHANGED: SelectableText to Premium MarkdownBody
                              child: MarkdownBody(
                                data: _blueprint,
                                selectable: true, // Judges can still copy text!
                                styleSheet: MarkdownStyleSheet(
                                  p: GoogleFonts.outfit(
                                      color: Colors.white70,
                                      fontSize: 15,
                                      height: 1.5),
                                  h1: GoogleFonts.outfit(
                                      color: Colors.cyanAccent,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold),
                                  h2: GoogleFonts.outfit(
                                      color: Colors.cyanAccent,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                  h3: GoogleFonts.outfit(
                                      color: Colors.cyanAccent,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                  strong: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                  listBullet: const TextStyle(
                                      color: Colors.cyanAccent, fontSize: 18),
                                  code: GoogleFonts.firaCode(
                                      color: Colors.greenAccent,
                                      backgroundColor: Colors.transparent),
                                  codeblockDecoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: AppColors.borderSubtle),
                                  ),
                                ),
                              )))
                    ])))
        ],
      ),
    );
  }
}
