import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:denizen_ai/denizen_ai.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DenizenShowcaseApp());
}

class DenizenShowcaseApp extends StatelessWidget {
  const DenizenShowcaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Denizen AI Showcase',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainDashboard(),
    );
  }
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  bool _isInitializing = true;
  
  @override
  void initState() {
    super.initState();
    _initDenizen();
  }

  Future<void> _initDenizen() async {
    final orchestrator = DenizenOrchestrator();
    try {
      await orchestrator.initialize();
    } catch (e) {
      debugPrint("Orchestrator init failed: $e");
    }
    setState(() {
      _isInitializing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Denizen AI Showcase'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.download), text: 'Models'),
              Tab(icon: Icon(Icons.chat), text: 'Chat'),
              Tab(icon: Icon(Icons.auto_stories), text: 'RAG Chat'),
              Tab(icon: Icon(Icons.mic), text: 'Voice'),
              Tab(icon: Icon(Icons.visibility), text: 'Vision'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ModelsTab(),
            ChatTab(),
            RagTab(),
            VoiceTab(),
            VisionTab(),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TAB 1: MODELS
// ============================================================================
class ModelsTab extends StatefulWidget {
  const ModelsTab({super.key});

  @override
  State<ModelsTab> createState() => _ModelsTabState();
}

class _ModelsTabState extends State<ModelsTab> {
  final DenizenAI _denizen = DenizenAI();
  double _progress = 0;
  bool _isDownloading = false;
  String _status = "Ready to load model.";

  Future<void> _loadModel() async {
    setState(() {
      _isDownloading = true;
      _progress = 0;
      _status = "Downloading/Loading model...";
    });

    try {
      final models = DefaultOfflineModels.getMedicalModels();
      final targetModelId = models.first.id;

      await _denizen.models.load(
        targetModelId,
        requireWifi: false,
        onProgress: (progress) {
          setState(() {
            _progress = progress.progress;
            _status = "Downloading: ${(progress.percent).toStringAsFixed(1)}%";
          });
        },
      );
      
      setState(() {
        _status = "Model Loaded Successfully!";
      });
    } catch (e) {
      setState(() {
        _status = "Error: $e";
      });
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoaded = _denizen.isModelLoaded;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.memory, size: 80, color: Colors.deepPurpleAccent),
          const SizedBox(height: 20),
          Text(
            isLoaded ? "Model is loaded and ready!" : "No model loaded.",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          if (_isDownloading) ...[
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 10),
          ],
          Text(_status, textAlign: TextAlign.center),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: _isDownloading ? null : _loadModel,
            icon: const Icon(Icons.cloud_download),
            label: const Text('Load Recommended Model'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB 2: CHAT
// ============================================================================
class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final DenizenAI _denizen = DenizenAI();
  DenizenSession? _session;
  final TextEditingController _controller = TextEditingController();
  final List<String> _messages = [];
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    try {
      final embeddingProvider = TFLiteEmbeddingProvider();
      await embeddingProvider.initialize();

      final storageService = VectorStorageService();
      if (!storageService.isInitialized) {
        await storageService.initialize();
      }

      setState(() {
        _session = _denizen.createRagSession(
          embeddingProvider: embeddingProvider,
          storageService: storageService,
          baseSystemPrompt: "You are a helpful assistant.",
        );
      });
    } catch (e) {
      debugPrint("RAG session init failed, falling back to standard session: $e");
      setState(() {
        _session = _denizen.createSession(systemPrompt: "You are a helpful assistant.");
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return;
    if (!_denizen.isModelLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please load a model first in the Models tab.')),
      );
      return;
    }
    if (_session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session is still initializing, please wait...')),
      );
      return;
    }

    final userText = _controller.text;
    _controller.clear();
    setState(() {
      _messages.add("You: $userText");
      _isGenerating = true;
    });

    try {
      final response = await _session!.chat(userText);
      setState(() {
        _messages.add("AI: $response");
      });
    } catch (e) {
      setState(() {
        _messages.add("Error: $e");
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              final isUser = msg.startsWith("You:");
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.deepPurple : Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(msg),
                ),
              );
            },
          ),
        ),
        if (_isGenerating) const LinearProgressIndicator(),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _isGenerating ? null : _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// TAB 3: DOCUMENT WORKSPACE & RAG CHAT  (Ubuntu-Elimu style — pure Dart)
// ============================================================================
//
// How this works (identical to Ubuntu Elimu):
//  1. User picks a file or pastes text.
//  2. We read the bytes, extract printable text, split into 500-word chunks.
//  3. Chunks are stored in memory (List<_DocEntry>). No sqlite-vec needed.
//  4. On each question, top-3 chunks are picked by keyword-score (same as UE).
//  5. Those chunks are joined and injected directly into the system prompt.
//  6. If a GGUF model is loaded, the LLM answers. Otherwise we show the raw
//     context so the user can see the retrieval working immediately.
// ============================================================================

enum DocCategory { all, pdf, docx, txt, custom }

/// One ingested document held entirely in memory — same as Ubuntu Elimu Document model.
class _DocEntry {
  final String id;
  final String title;
  final DocCategory category;
  final int sizeBytes;
  final DateTime addedAt;
  final List<String> chunks;

  _DocEntry({
    required this.id,
    required this.title,
    required this.category,
    required this.sizeBytes,
    required this.addedAt,
    required this.chunks,
  });

  String get sizeLabel {
    if (sizeBytes < 1024) return '${sizeBytes} B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData get icon {
    switch (category) {
      case DocCategory.pdf:    return Icons.picture_as_pdf;
      case DocCategory.docx:   return Icons.description;
      case DocCategory.txt:    return Icons.article;
      case DocCategory.custom: return Icons.sticky_note_2;
      default:                 return Icons.insert_drive_file;
    }
  }

  Color get color {
    switch (category) {
      case DocCategory.pdf:    return Colors.redAccent;
      case DocCategory.docx:  return Colors.blueAccent;
      case DocCategory.txt:   return Colors.greenAccent;
      case DocCategory.custom: return Colors.purpleAccent;
      default:                 return Colors.cyanAccent;
    }
  }
}

class _ChatMsg {
  final bool isUser;
  final bool isSystem;
  String text;
  _ChatMsg({required this.isUser, this.isSystem = false, required this.text});
}

class RagTab extends StatefulWidget {
  const RagTab({super.key});
  @override
  State<RagTab> createState() => _RagTabState();
}

class _RagTabState extends State<RagTab> {
  final DenizenAI _denizen = DenizenAI();
  DenizenSession? _session;

  // In-memory document store — same concept as Ubuntu Elimu's _documents list
  final List<_DocEntry> _docs = [];
  String? _activDocId;

  final List<_ChatMsg> _messages = [];
  final TextEditingController _promptCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  bool _isIngesting = false;
  bool _isGenerating = false;

  // ── Text extraction (same as Ubuntu Elimu's _extractText) ─────────────────

  String _extractText(List<int> bytes, String ext) {
    if (ext == 'pdf') return _extractPdfText(bytes);
    try {
      return String.fromCharCodes(bytes).trim();
    } catch (_) {
      return _extractPrintable(bytes);
    }
  }

  String _extractPdfText(List<int> bytes) {
    final raw = String.fromCharCodes(bytes);
    final sb = StringBuffer();
    for (final m in RegExp(r'\(([^)]+)\)\s*Tj', multiLine: true).allMatches(raw)) {
      final g = m.group(1);
      if (g != null && g.trim().length > 1) sb.writeln(g.trim());
    }
    for (final m in RegExp(r'\[(((?:\([^)]+\)\s*|-?\d+\s*))+)\]\s*TJ', multiLine: true).allMatches(raw)) {
      for (final inner in RegExp(r'\(([^)]+)\)').allMatches(m.group(1) ?? '')) {
        final t = inner.group(1);
        if (t != null && t.trim().isNotEmpty) { sb.write(t.trim()); sb.write(' '); }
      }
      sb.writeln();
    }
    if (sb.length < 50) return _extractPrintable(bytes);
    return sb.toString();
  }

  String _extractPrintable(List<int> bytes) {
    final raw = String.fromCharCodes(bytes);
    final sb = StringBuffer();
    for (final m in RegExp(r'[A-Za-z0-9\s.,!?:;()\-]{4,}').allMatches(raw)) {
      final s = m.group(0)!.trim();
      if (s.length >= 4 && !s.startsWith('/Font') && !s.startsWith('/Type') &&
          !s.startsWith('/Catalog') && !s.startsWith('/Pages')) {
        sb.writeln(s);
      }
    }
    return sb.toString();
  }

  // ── Chunking (500-word sliding window, same as Ubuntu Elimu) ──────────────

  List<String> _chunk(String text, {int size = 500, int overlap = 50}) {
    final words = text.split(RegExp(r'\s+'));
    final chunks = <String>[];
    int start = 0;
    while (start < words.length) {
      final end = (start + size).clamp(0, words.length);
      chunks.add(words.sublist(start, end).join(' '));
      if (end == words.length) break;
      start += size - overlap;
    }
    return chunks;
  }

  // ── Retrieval (keyword-score, same as Ubuntu Elimu's getRelevantChunks) ───

  List<String> _getRelevantChunks(String docId, String query, {int topK = 3}) {
    final doc = _docs.where((d) => d.id == docId).firstOrNull;
    if (doc == null || doc.chunks.isEmpty) return [];
    final qWords = query.toLowerCase().split(RegExp(r'\s+'));
    final scored = doc.chunks.map((c) {
      final lower = c.toLowerCase();
      return MapEntry(c, qWords.where((w) => lower.contains(w)).length);
    }).toList()..sort((a, b) => b.value.compareTo(a.value));
    return scored.take(topK).map((e) => e.key).toList();
  }

  List<String> _getChunksAllDocs(String query, {int topK = 3}) {
    if (_docs.isEmpty) return [];
    final all = <MapEntry<String, int>>[];
    for (final doc in _docs) {
      final qWords = query.toLowerCase().split(RegExp(r'\s+'));
      for (final c in doc.chunks) {
        all.add(MapEntry(c, qWords.where((w) => c.toLowerCase().contains(w)).length));
      }
    }
    all.sort((a, b) => b.value.compareTo(a.value));
    return all.take(topK).map((e) => e.key).toList();
  }

  // ── File picker ──────────────────────────────────────────────────────────────

  Future<void> _pickAndIngest() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.first;
      final name = picked.name;
      final ext = (picked.extension ?? '').toLowerCase();

      setState(() { _isIngesting = true; });

      List<int> bytes;
      if (picked.bytes != null && picked.bytes!.isNotEmpty) {
        bytes = picked.bytes!;
      } else if (picked.path != null) {
        bytes = await File(picked.path!).readAsBytes();
      } else {
        throw Exception("Could not read file.");
      }

      final rawText = _extractText(bytes, ext);
      if (rawText.trim().isEmpty) throw Exception("No readable text found in '$name'.");

      final chunks = _chunk(rawText);
      DocCategory cat = DocCategory.txt;
      if (ext == 'pdf') cat = DocCategory.pdf;
      if (ext == 'docx' || ext == 'doc') cat = DocCategory.docx;

      final doc = _DocEntry(
        id: 'doc_${DateTime.now().millisecondsSinceEpoch}',
        title: name, category: cat,
        sizeBytes: picked.size, addedAt: DateTime.now(), chunks: chunks,
      );
      setState(() {
        _docs.add(doc);
        _activDocId = doc.id;
        _messages.add(_ChatMsg(isUser: false, isSystem: true,
          text: "Loaded '$name' — ${chunks.length} chunks ready. Chat scoped to this document."));
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      setState(() { _isIngesting = false; });
    }
  }

  // ── Paste custom text ────────────────────────────────────────────────────────

  void _showPasteDialog() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Add Text Note', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: titleCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Title', labelStyle: TextStyle(color: Colors.cyanAccent),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: contentCtrl, maxLines: 8,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Content', labelStyle: TextStyle(color: Colors.cyanAccent),
              hintText: 'Paste or type your notes here...',
              hintStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(),
            ),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
            onPressed: () {
              final t = titleCtrl.text.trim();
              final c = contentCtrl.text.trim();
              if (t.isEmpty || c.isEmpty) return;
              Navigator.pop(context);
              _ingestCustomText(t, c);
            },
            child: const Text('Save Note', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _ingestCustomText(String title, String content) {
    final chunks = _chunk(content);
    final doc = _DocEntry(
      id: 'doc_${DateTime.now().millisecondsSinceEpoch}',
      title: title, category: DocCategory.custom,
      sizeBytes: content.length, addedAt: DateTime.now(), chunks: chunks,
    );
    setState(() {
      _docs.add(doc);
      _activDocId = doc.id;
      _messages.add(_ChatMsg(isUser: false, isSystem: true,
        text: "Note '$title' saved — ${chunks.length} chunks. Chat scoped to this note."));
    });
  }

  // ── Send message ─────────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _promptCtrl.text.trim();
    if (text.isEmpty) return;
    _promptCtrl.clear();

    // Retrieve context — Ubuntu Elimu-style keyword scoring
    final chunks = _activDocId != null
        ? _getRelevantChunks(_activDocId!, text)
        : _getChunksAllDocs(text);

    setState(() {
      _messages.add(_ChatMsg(isUser: true, text: text));
      _isGenerating = true;
    });
    _scrollToBottom();

    // If no model loaded → show raw context immediately (still useful for testing!)
    if (!_denizen.isModelLoaded) {
      final answer = chunks.isNotEmpty
          ? "Document context for your query:\n\n${chunks.join('\n\n---\n\n')}\n\n"
            "(Load a GGUF model in the 'Models' tab for full AI synthesis.)"
          : "No documents uploaded yet. Add a file or paste text first.";
      setState(() {
        _messages.add(_ChatMsg(isUser: false, text: answer));
        _isGenerating = false;
      });
      _scrollToBottom();
      return;
    }

    // Inject context into system prompt — identical to Ubuntu Elimu's tutorStream approach
    final contextStr = chunks.isEmpty ? '' : chunks.join('\n\n---\n\n');
    final systemPrompt = chunks.isEmpty
        ? "You are a helpful assistant."
        : "You are a helpful document assistant. Use the following document content as your knowledge base:\n\n$contextStr\n\nAnswer based ONLY on the above content.";

    try {
      _session = _denizen.createSession(systemPrompt: systemPrompt);
    } catch (e) {
      setState(() {
        _messages.add(_ChatMsg(isUser: false, text: "Session error: $e"));
        _isGenerating = false;
      });
      return;
    }

    final aiMsg = _ChatMsg(isUser: false, text: "");
    setState(() { _messages.add(aiMsg); });

    try {
      await for (final token in _session!.streamChat(text)) {
        setState(() { aiMsg.text += token; });
        _scrollToBottom();
      }
    } catch (e) {
      setState(() { aiMsg.text = "Error: $e"; });
    } finally {
      setState(() { _isGenerating = false; });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  // ── UI ────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Status bar
      Container(
        color: Colors.grey[900],
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          Expanded(child: Text(
            _docs.isEmpty
                ? "No documents — upload a file or paste text."
                : _activDocId != null
                    ? "Scoped: ${_docs.firstWhere((d) => d.id == _activDocId).title}"
                    : "All ${_docs.length} document(s)",
            style: const TextStyle(color: Colors.cyanAccent, fontSize: 12),
          )),
          if (_isIngesting)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ]),
      ),

      // Toolbar
      Container(
        color: Colors.grey[850],
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: [
          ElevatedButton.icon(
            onPressed: _isIngesting ? null : _pickAndIngest,
            icon: const Icon(Icons.upload_file, size: 16),
            label: const Text('Upload File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton.icon(
            onPressed: _isIngesting ? null : _showPasteDialog,
            icon: const Icon(Icons.note_add, size: 16),
            label: const Text('Paste Text'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
          const SizedBox(width: 6),
          if (_activDocId != null)
            TextButton(
              onPressed: () => setState(() => _activDocId = null),
              child: const Text('All Docs', style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
            ),
        ]),
      ),

      // Document chips
      if (_docs.isNotEmpty)
        Container(
          height: 90,
          color: Colors.grey[900],
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            itemCount: _docs.length,
            itemBuilder: (_, i) {
              final doc = _docs[i];
              final isActive = doc.id == _activDocId;
              return GestureDetector(
                onTap: () => setState(() => _activDocId = doc.id),
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isActive ? doc.color.withOpacity(0.2) : Colors.grey[800],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isActive ? doc.color : Colors.transparent, width: 1.5),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(doc.icon, size: 14, color: doc.color),
                      const SizedBox(width: 4),
                      Expanded(child: Text(doc.title,
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                    const SizedBox(height: 4),
                    Text('${doc.chunks.length} chunks · ${doc.sizeLabel}',
                        style: TextStyle(fontSize: 9, color: Colors.grey[400])),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() {
                        _docs.removeWhere((d) => d.id == doc.id);
                        if (_activDocId == doc.id) _activDocId = null;
                      }),
                      child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontSize: 9)),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),

      // Chat
      Expanded(
        child: ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(12),
          itemCount: _messages.length,
          itemBuilder: (_, i) {
            final msg = _messages[i];
            if (msg.isSystem) {
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(8)),
                child: Text(msg.text, style: const TextStyle(color: Colors.cyanAccent, fontSize: 12)),
              );
            }
            return Align(
              alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(12),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                decoration: BoxDecoration(
                  color: msg.isUser ? Colors.deepPurple[700] : Colors.grey[800],
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  msg.text.isEmpty && _isGenerating ? '...' : msg.text,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            );
          },
        ),
      ),

      if (_isGenerating) const LinearProgressIndicator(),

      // Input
      Container(
        color: Colors.grey[900],
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _promptCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: _docs.isEmpty ? 'Upload a document first...' : 'Ask about your document...',
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) { if (!_isGenerating) _sendMessage(); },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            style: IconButton.styleFrom(backgroundColor: Colors.deepPurple),
            icon: const Icon(Icons.send, color: Colors.white),
            onPressed: _isGenerating ? null : _sendMessage,
          ),
        ]),
      ),
    ]);
  }
}


// ============================================================================
// ============================================================================
// TAB 4: VOICE
// ============================================================================
class VoiceTab extends StatefulWidget {
  const VoiceTab({super.key});

  @override
  State<VoiceTab> createState() => _VoiceTabState();
}

class _VoiceTabState extends State<VoiceTab> {
  final DenizenAI _denizen = DenizenAI();
  late DenizenVoiceSession _voiceSession;
  bool _isListening = false;
  bool _isSpeaking = false;
  String _recognizedText = "";
  String _aiResponse = "";

  @override
  void initState() {
    super.initState();
    _voiceSession = _denizen.createVoiceSession();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _voiceSession.stopListening();
      setState(() {
        _isListening = false;
      });
      if (_recognizedText.isNotEmpty && _denizen.isModelLoaded) {
        _processWithLLM(_recognizedText);
      }
    } else {
      setState(() {
        _recognizedText = "Listening...";
        _aiResponse = "";
        _isListening = true;
      });
      await _voiceSession.startListening(
        onResult: (text) {
          setState(() {
            _recognizedText = text;
          });
        },
      );
    }
  }

  Future<void> _processWithLLM(String prompt) async {
    try {
      final session = _denizen.createSession(
        systemPrompt: "You are a helpful offline voice assistant. Keep answers brief.",
      );
      String fullReply = "";
      await for (final chunk in session.streamChat(prompt)) {
        fullReply += chunk;
        setState(() {
          _aiResponse = fullReply;
        });
      }
      if (fullReply.isNotEmpty) {
        _speakResponse(fullReply);
      }
    } catch (e) {
      setState(() {
        _aiResponse = "Error: $e";
      });
    }
  }

  Future<void> _speakResponse(String text) async {
    setState(() {
      _isSpeaking = true;
    });
    await _voiceSession.speak(text);
    setState(() {
      _isSpeaking = false;
    });
  }

  Future<void> _stopSpeaking() async {
    await _voiceSession.stopSpeaking();
    setState(() {
      _isSpeaking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              size: 80,
              color: _isListening ? Colors.red : Colors.deepPurple,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _toggleListening,
              icon: Icon(_isListening ? Icons.stop : Icons.mic),
              label: Text(
                _isListening ? "Stop Listening" : "Start Listening",
                style: const TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isListening ? Colors.red : Colors.deepPurple,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),
            const SizedBox(height: 30),
            if (_recognizedText.isNotEmpty)
              Card(
                color: Colors.grey[900],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "🗣️ You said:",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent),
                      ),
                      const SizedBox(height: 8),
                      Text(_recognizedText, style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            if (_aiResponse.isNotEmpty)
              Card(
                color: Colors.grey[850],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "🤖 AI Assistant:",
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent),
                          ),
                          IconButton(
                            icon: Icon(_isSpeaking ? Icons.volume_off : Icons.volume_up),
                            onPressed: _isSpeaking ? _stopSpeaking : () => _speakResponse(_aiResponse),
                            color: Colors.greenAccent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_aiResponse, style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class BatteryTool extends DenizenTool {
  final int Function() getBatteryLevel;
  final void Function(String) logCallback;

  BatteryTool({
    required this.getBatteryLevel,
    required this.logCallback,
  }) : super(
          name: 'get_battery_status',
          description: 'Check the current device battery percentage and charging state.',
          parametersSchema: {
            'type': 'object',
            'properties': {},
          },
        );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    logCallback("Native Tool Executed: get_battery_status() called.");
    return {'battery_level': getBatteryLevel(), 'is_charging': false};
  }
}

class FlashlightTool extends DenizenTool {
  final void Function(bool) setFlashlight;
  final void Function(String) logCallback;

  FlashlightTool({
    required this.setFlashlight,
    required this.logCallback,
  }) : super(
          name: 'toggle_flashlight',
          description: 'Turns the device flashlight/torch on or off based on the enable argument.',
          parametersSchema: {
            'type': 'object',
            'properties': {
              'enable': {
                'type': 'boolean',
                'description': 'True to turn on, false to turn off.'
              }
            },
            'required': ['enable'],
          },
        );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    final enable = arguments['enable'] as bool? ?? false;
    setFlashlight(enable);
    logCallback("Native Tool Executed: toggle_flashlight(enable: $enable) called.");
    return {'success': true, 'flashlight_enabled': enable};
  }
}

class VisionTab extends StatefulWidget {
  const VisionTab({super.key});

  @override
  State<VisionTab> createState() => _VisionTabState();
}

class _VisionTabState extends State<VisionTab> {
  String _aiResponse = "";
  bool _isAnalyzing = false;
  final TextEditingController _promptController = TextEditingController(
    text: "What is in this image?",
  );

  final List<Map<String, String>> _mockImages = [
    {
      'name': 'Pressure Valve Error',
      'desc': 'A standard water pipe with a red pressure release valve pointing to the right showing critical leaks.',
      'icon': 'build'
    },
    {
      'name': 'Circuit Board Component',
      'desc': 'A green printed circuit board with dynamic capacitors, resistors, and a blue microcontroller chip in the center.',
      'icon': 'developer_board'
    },
    {
      'name': 'Receipt Scan',
      'desc': 'A printed scanner copy of a business receipt showing 1x local diagnostic tool kit total: \$85.00.',
      'icon': 'receipt_long'
    }
  ];
  
  int _selectedImageIndex = -1;



  Future<void> _analyzeSelectedImage() async {
    if (_selectedImageIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image from the mock list first.')),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _aiResponse = "Analyzing visual data...";
    });

    try {
      final mockImageText = _mockImages[_selectedImageIndex]['desc']!;
      final prompt = _promptController.text.trim();

      // Simulate on-device visual projector inference latency
      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _aiResponse = "Visual Analysis Results:\n\n"
            "Based on the image data ($mockImageText) and prompt request ($prompt):\n\n"
            "The offline vision model detects a ${_mockImages[_selectedImageIndex]['name']}. "
            "It matches the details: $mockImageText.";
      });
    } catch (e) {
      setState(() {
        _aiResponse = "Error: $e";
      });
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const Icon(Icons.visibility, size: 60, color: Colors.purpleAccent),
            const SizedBox(height: 10),
            const Text(
              "Multimodal Vision Analysis",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Process camera snapshots or photos offline using local visual projectors (LLaVA / CLIP).",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // Image Selector Carousel
            const Text(
              "Select a Mock Image to Analyze:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_mockImages.length, (index) {
                final isSelected = _selectedImageIndex == index;
                final img = _mockImages[index];
                
                IconData getIcon(String name) {
                  if (name == 'build') return Icons.build;
                  if (name == 'developer_board') return Icons.developer_board;
                  return Icons.receipt_long;
                }

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedImageIndex = index;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.purple.withOpacity(0.2) : Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.purpleAccent : Colors.grey[800]!,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(getIcon(img['icon']!), size: 40, color: isSelected ? Colors.purpleAccent : Colors.grey),
                        const SizedBox(height: 4),
                        Text(img['name']!, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            
            // Selected Image Preview
            if (_selectedImageIndex != -1)
              Card(
                color: Colors.grey[900],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.image, size: 48, color: Colors.grey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _mockImages[_selectedImageIndex]['name']!,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _mockImages[_selectedImageIndex]['desc']!,
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // Input Prompt
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    decoration: const InputDecoration(
                      hintText: "Enter visual prompt (e.g. 'Is it leaking?')",
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _analyzeSelectedImage(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isAnalyzing ? null : _analyzeSelectedImage,
                  icon: const Icon(Icons.search),
                  label: const Text("Analyze"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isAnalyzing) const LinearProgressIndicator(),
            const SizedBox(height: 10),

            // Output Card
            if (_aiResponse.isNotEmpty)
              Card(
                color: Colors.grey[850],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "👁️ Vision Analysis Output:",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent),
                      ),
                      const SizedBox(height: 8),
                      Text(_aiResponse, style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

