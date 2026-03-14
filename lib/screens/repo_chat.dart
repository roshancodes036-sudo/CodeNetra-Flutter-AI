import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // ✅ NEW: Markdown Package

import '../theme/app_colors.dart';
import '../widgets/custom_widgets.dart';
import '../services/ai_logic.dart';

class RepoChatScreen extends StatefulWidget {
  const RepoChatScreen({super.key});
  @override
  State<RepoChatScreen> createState() => _RepoChatScreenState();
}

class _RepoChatScreenState extends State<RepoChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _msgs = [];
  bool _isLoading = false;
  String? _activeFileName;
  final Map<String, String> _fileContentMap = {};
  final List<String> _allFilePaths = [];
  String _criticalContext = "";
  bool _isContextLoaded = false;
  final AIBrain _brain = AIBrain();

  final List<String> _suggestions = [
    "📂 Show Project Structure",
    "📝 List All Features",
    "🐞 Find Bugs in main.dart",
    "💻 Give full main.dart code"
  ];

  @override
  void initState() {
    super.initState();
    _brain.initBrain();
    _addMessage("ai",
        "Hello Developer! Upload a ZIP. I will auto-analyze the core files instantly.");
  }

  Future<void> _processZipFile(List<int> bytes, String filename) async {
    setState(() {
      _isLoading = true;
      _activeFileName = filename;
      _fileContentMap.clear();
      _allFilePaths.clear();
      _criticalContext = "";
    });
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final List<String> priorityFiles = [
        'pubspec.yaml',
        'main.dart',
        'AndroidManifest.xml',
        'Info.plist',
        'package.json',
        'index.js',
        'app.py',
        'requirements.txt',
        'firebase_options.dart',
        'routes.dart'
      ];
      StringBuffer criticalBuffer = StringBuffer();
      int totalFiles = 0;

      for (final file in archive) {
        if (file.isFile) {
          String path = file.name;
          if (path.contains('node_modules') ||
              path.contains('.git/') ||
              path.contains('build/') ||
              path.contains('.idea/') ||
              path.endsWith('.png') ||
              path.endsWith('.jpg') ||
              path.endsWith('.ttf')) {
            continue;
          }
          _allFilePaths.add(path);
          totalFiles++;
          try {
            String content = String.fromCharCodes(file.content as List<int>);
            _fileContentMap[path] = content;
            bool isPriority = priorityFiles.any((p) => path.endsWith(p));
            if (isPriority && criticalBuffer.length < 20000) {
              criticalBuffer.writeln("\n--- FILE: $path ---\n$content\n");
            }
          } catch (e) {}
        }
      }
      _criticalContext = criticalBuffer.toString();
      _isContextLoaded = true;
      String summaryPrompt = """
ACT AS A SENIOR DEVELOPER. I have uploaded a project ZIP.
STATS: - Total Files Scanned: $totalFiles - Key Files Content Provided Below: $_criticalContext
TASK: 1. Identify the Tech Stack (Flutter/React/Python). 2. Analyze the 'pubspec.yaml' or dependency file to list Key Features. 3. Tell me the folder structure briefly.
Reply in short bullet points. Start with "🚀 Project Loaded Successfully!".
""";
      String? res = await _brain.askLaravel(summaryPrompt);
      setState(() => _isLoading = false);
      _addMessage("ai", res ?? "Project Loaded. Ready to answer questions!");
    } catch (e) {
      setState(() => _isLoading = false);
      _addMessage("system", "Error reading ZIP: $e");
    }
  }

  Future<void> _pickZipFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['zip'], withData: true);
    if (result != null) {
      List<int> bytes = kIsWeb
          ? result.files.single.bytes!
          : await File(result.files.single.path!).readAsBytes();
      _processZipFile(bytes, result.files.single.name);
    }
  }

  void _send(String text) async {
    if (text.isEmpty) return;
    _ctrl.clear();
    _addMessage("user", text);
    setState(() => _isLoading = true);
    String fullPrompt = "";
    if (text.toLowerCase().contains("structure") ||
        text.toLowerCase().contains("folder")) {
      String structureList = _allFilePaths.take(50).join("\n");
      fullPrompt =
          "The user is asking about the file structure. Here is the list of files in the project: $structureList. Summarize the architecture.";
    } else if (text.toLowerCase().contains("code") ||
        text.toLowerCase().contains("file")) {
      String? foundFile;
      String? foundContent;
      for (var path in _fileContentMap.keys) {
        if (text.toLowerCase().contains(path.split('/').last.toLowerCase())) {
          foundFile = path;
          foundContent = _fileContentMap[path];
          break;
        }
      }
      if (foundContent != null) {
        fullPrompt =
            "The user wants the code for file: $foundFile. Here is the FULL CONTENT of that file: $foundContent. Task: Output the code cleanly in markdown format. Add brief comments explaining what it does.";
      } else {
        fullPrompt =
            "User asked: \"$text\". I could not find a specific file match in the ZIP map. Answer based on this Critical Context: $_criticalContext";
      }
    } else {
      fullPrompt =
          "CONTEXT (Key Project Files): $_criticalContext. USER QUESTION: $text. Answer based on the code provided above.";
    }
    String? res = await _brain.askLaravel(fullPrompt);
    setState(() => _isLoading = false);
    _addMessage("ai", res ?? "Error processing request.");
  }

  void _addMessage(String role, String text) {
    setState(() => _msgs.add({"role": role, "text": text, "animated": false}));
    Future.delayed(
        const Duration(milliseconds: 100),
        () => _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut));
  }

  @override
  Widget build(BuildContext context) {
    return ProPageLayout(
      title: "Repo Chat",
      icon: Icons.code,
      child: Column(children: [
        if (_activeFileName != null)
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.check_circle, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                    "Analyzing: $_activeFileName (${_allFilePaths.length} files)",
                    style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 14))
              ])),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _msgs.length,
            itemBuilder: (c, i) {
              final msg = _msgs[i];
              final isUser = msg['role'] == 'user';

              // ✅ NEW: User ke liye ModernChatBubble, AI ke liye Premium Markdown
              if (isUser) {
                return ModernChatBubble(
                    isUser: true,
                    text: msg['text'],
                    isAnimated: msg['animated'],
                    onAnimationEnd: () =>
                        setState(() => _msgs[i]['animated'] = true));
              } else {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16, right: 30),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface, // Premium Dark Background
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: MarkdownBody(
                    data: msg['text'],
                    selectable: true, // ✅ जजों को कोड कॉपी करने में आसानी होगी
                    styleSheet: MarkdownStyleSheet(
                      p: GoogleFonts.outfit(
                          color: Colors.white70, fontSize: 15),
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
                          color: Colors.white, fontWeight: FontWeight.bold),
                      listBullet: const TextStyle(
                          color: Colors.cyanAccent, fontSize: 18),
                      code: GoogleFonts.firaCode(
                          color: Colors.greenAccent,
                          backgroundColor: Colors.transparent),
                      codeblockDecoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                    ),
                  ),
                );
              }
            },
          ),
        ),
        if (_isLoading)
          const LinearProgressIndicator(color: AppColors.primaryAccent),
        Container(
            height: 50,
            margin: const EdgeInsets.only(bottom: 10),
            child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) => ActionChip(
                    backgroundColor: AppColors.cardSurface,
                    side: const BorderSide(color: AppColors.borderSubtle),
                    label: Text(_suggestions[index],
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13)),
                    onPressed: () => _send(_suggestions[index])))),
        Padding(
            padding: const EdgeInsets.all(16.0),
            child: NeonInputWrapper(
                child: Row(children: [
              IconButton(
                  icon: const Icon(Icons.add_circle,
                      color: AppColors.primaryAccent),
                  onPressed: _pickZipFile),
              Expanded(
                  child: TextField(
                      controller: _ctrl,
                      style:
                          GoogleFonts.outfit(color: Colors.white, fontSize: 16),
                      decoration: const InputDecoration(
                          hintText:
                              "Ask: 'Show structure' or 'Give main.dart'...",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                      onSubmitted: _send)),
              IconButton(
                  icon: const Icon(Icons.send_rounded,
                      color: AppColors.primaryAccent),
                  onPressed: () => _send(_ctrl.text))
            ])))
      ]),
    );
  }
}
