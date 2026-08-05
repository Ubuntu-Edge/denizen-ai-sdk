import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:denizen_ai/denizen_ai.dart';
import 'package:denizen_ai/src/models/default_offline_models.dart';
import 'package:denizen_ai/src/rag/tflite_embedding_provider.dart';
import 'package:denizen_ai/src/rag/vector_storage_service.dart';
import 'package:denizen_ai/src/rag/document_ingestion_service.dart';

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
// TAB 3: RAG & TOOLS
// ============================================================================
// ============================================================================
// TAB 3: CHATGPT-STYLE DOCUMENT CHAT (RAG)
// ============================================================================

class IngestedDocumentInfo {
  final int docId;
  final String title;
  final int chunkCount;
  final DateTime ingestedAt;

  IngestedDocumentInfo({
    required this.docId,
    required this.title,
    required this.chunkCount,
    required this.ingestedAt,
  });
}

class RagChatMessage {
  final String sender; // "user", "assistant", or "system"
  String text;
  final List<String> retrievedSnippets;

  RagChatMessage({
    required this.sender,
    required this.text,
    this.retrievedSnippets = const [],
  });
}

class RagTab extends StatefulWidget {
  const RagTab({super.key});

  @override
  State<RagTab> createState() => _RagTabState();
}

class _RagTabState extends State<RagTab> {
  final DenizenAI _denizen = DenizenAI();
  DenizenRagSession? _ragSession;
  EmbeddingProvider? _embeddingProvider;
  VectorStorageService? _storageService;
  DocumentIngestionService? _ingestionService;

  bool _isInitializing = true;
  bool _isIngesting = false;
  bool _isGenerating = false;
  String _statusMessage = "Initializing RAG Vector Engine...";

  final List<IngestedDocumentInfo> _ingestedDocs = [];
  final List<RagChatMessage> _messages = [];
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _nextDocId = 1;

  @override
  void initState() {
    super.initState();
    _initRagEngine();
  }

  Future<void> _initRagEngine() async {
    try {
      _embeddingProvider = TFLiteEmbeddingProvider();
      await _embeddingProvider!.initialize();

      _storageService = VectorStorageService();
      if (!_storageService!.isInitialized) {
        await _storageService!.initialize();
      }

      _ingestionService = DocumentIngestionService(_embeddingProvider!, _storageService!);

      _ragSession = _denizen.createRagSession(
        embeddingProvider: _embeddingProvider!,
        storageService: _storageService!,
        baseSystemPrompt: "You are a helpful AI assistant. Answer user questions accurately based on the provided document context.",
      );

      setState(() {
        _isInitializing = false;
        _statusMessage = "RAG Vector DB ready. Add a document from your phone to get started.";
      });
    } catch (e) {
      debugPrint("RAG init error: $e");
      setState(() {
        _isInitializing = false;
        _statusMessage = "RAG Engine Init Warning: $e";
      });
    }
  }

  /// Pick file natively from phone storage
  Future<void> _pickAndIngestFile() async {
    if (_ingestionService == null || _storageService == null || !_storageService!.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vector database is not ready yet.')),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final path = result.files.first.path;
      final name = result.files.first.name;
      if (path == null) return;

      setState(() {
        _isIngesting = true;
        _statusMessage = "Ingesting $name from phone storage...";
      });

      final file = File(path);
      final docId = _nextDocId++;

      await _ingestionService!.ingestFile(docId, file);

      final chunkCount = _storageService!.search(List.filled(384, 0.1), limit: 100).length;

      setState(() {
        _ingestedDocs.add(IngestedDocumentInfo(
          docId: docId,
          title: name,
          chunkCount: chunkCount > 0 ? chunkCount : 1,
          ingestedAt: DateTime.now(),
        ));
        _statusMessage = "Successfully ingested '$name' into local Vector DB!";
        _messages.add(RagChatMessage(
          sender: "system",
          text: "📁 Document added: '$name' (Ingested into local Vector DB). You can now ask questions about it!",
        ));
      });
    } catch (e) {
      setState(() {
        _statusMessage = "File ingestion error: $e";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to ingest file: $e')),
      );
    } finally {
      setState(() {
        _isIngesting = false;
      });
    }
  }

  /// Paste text modal fallback
  void _showPasteTextDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.edit_note, color: Colors.cyanAccent),
              SizedBox(width: 8),
              Text('Paste Custom Document'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Document Title (e.g. Secret Password Guide)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Document Content / Notes',
                    hintText: 'Paste any text, notes, guidelines, or confidential information here...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final content = contentController.text.trim();
                if (title.isEmpty || content.isEmpty) return;

                Navigator.pop(context);
                await _ingestRawText(title, content);
              },
              child: const Text('Ingest Text'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _ingestRawText(String title, String content) async {
    if (_ingestionService == null || _storageService == null) return;

    setState(() {
      _isIngesting = true;
      _statusMessage = "Ingesting '$title'...";
    });

    try {
      final docId = _nextDocId++;
      await _ingestionService!.ingestText(docId, content);

      setState(() {
        _ingestedDocs.add(IngestedDocumentInfo(
          docId: docId,
          title: title,
          chunkCount: (content.length / 200).ceil(),
          ingestedAt: DateTime.now(),
        ));
        _statusMessage = "Successfully ingested '$title' into Vector DB!";
        _messages.add(RagChatMessage(
          sender: "system",
          text: "📝 Document added: '$title'. You can now ask questions about this document!",
        ));
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Ingestion error: $e";
      });
    } finally {
      setState(() {
        _isIngesting = false;
      });
    }
  }

  /// Send prompt and stream answer
  Future<void> _sendMessage() async {
    final text = _promptController.text.trim();
    if (text.isEmpty) return;

    if (!_denizen.isModelLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please load an offline model first in the Models tab.')),
      );
      return;
    }

    _promptController.clear();
    setState(() {
      _messages.add(RagChatMessage(sender: "user", text: text));
      _isGenerating = true;
    });

    _scrollToBottom();

    try {
      // Perform vector search manually to capture exact snippets for citations
      List<String> snippets = [];
      if (_embeddingProvider != null && _storageService != null && _storageService!.isInitialized) {
        try {
          final queryVec = await _embeddingProvider!.embed(text);
          final searchResults = _storageService!.search(queryVec, limit: 2);
          snippets = searchResults.map((r) => r['text_content'].toString()).toList();
        } catch (_) {}
      }

      final aiMsg = RagChatMessage(sender: "assistant", text: "", retrievedSnippets: snippets);
      setState(() {
        _messages.add(aiMsg);
      });

      final stream = _ragSession != null
          ? _ragSession!.streamChat(text)
          : _denizen.engine.generateResponseStream(prompt: text);

      await for (final token in stream) {
        setState(() {
          aiMsg.text += token;
        });
        _scrollToBottom();
      }
    } catch (e) {
      setState(() {
        _messages.add(RagChatMessage(sender: "assistant", text: "Error during generation: $e"));
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing RAG Vector Engine...'),
          ],
        ),
      );
    }

    return Column(
      children: [
        // ================= KNOWLEDGE BASE BAR =================
        Container(
          color: Colors.grey[900],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_stories, color: Colors.cyanAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Knowledge Base (${_ingestedDocs.length} Docs)",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.upload_file, color: Colors.cyanAccent),
                    tooltip: "Pick File from Phone",
                    onPressed: _isIngesting ? null : _pickAndIngestFile,
                  ),
                  IconButton(
                    icon: const Icon(Icons.note_add, color: Colors.purpleAccent),
                    tooltip: "Paste Custom Text",
                    onPressed: _isIngesting ? null : _showPasteTextDialog,
                  ),
                ],
              ),
              if (_isIngesting) ...[
                const SizedBox(height: 4),
                const LinearProgressIndicator(),
              ],
              if (_ingestedDocs.isNotEmpty) ...[
                const SizedBox(height: 6),
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _ingestedDocs.length,
                    itemBuilder: (context, index) {
                      final doc = _ingestedDocs[index];
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.cyan.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.cyanAccent.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.description, size: 14, color: Colors.cyanAccent),
                            const SizedBox(width: 6),
                            Text(
                              doc.title,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "(${doc.chunkCount} chunks)",
                              style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ] else ...[
                const SizedBox(height: 4),
                Text(
                  "No bespoke documents uploaded yet. Tap 📁 icon to pick a file from your phone!",
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
              ]
            ],
          ),
        ),

        const Divider(height: 1),

        // ================= CHAT MESSAGES CANVAS =================
        Expanded(
          child: _messages.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return _buildMessageItem(msg);
                  },
                ),
        ),

        if (_isGenerating) const LinearProgressIndicator(minHeight: 2),

        // ================= INPUT & ATTACHMENT BAR =================
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            border: Border(top: BorderSide(color: Colors.grey[800]!)),
          ),
          child: Row(
            children: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.add_circle_outline, color: Colors.cyanAccent, size: 28),
                onSelected: (value) {
                  if (value == 'phone') {
                    _pickAndIngestFile();
                  } else if (value == 'text') {
                    _showPasteTextDialog();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'phone',
                    child: Row(
                      children: [
                        Icon(Icons.smartphone, color: Colors.cyanAccent),
                        SizedBox(width: 8),
                        Text('Pick File from Phone'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'text',
                    child: Row(
                      children: [
                        Icon(Icons.edit_note, color: Colors.purpleAccent),
                        SizedBox(width: 8),
                        Text('Paste Custom Text'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _promptController,
                  maxLines: 4,
                  minLines: 1,
                  decoration: const InputDecoration(
                    hintText: 'Ask questions about your uploaded documents...',
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.deepPurpleAccent),
                onPressed: _isGenerating ? null : _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_stories, size: 64, color: Colors.cyanAccent),
            ),
            const SizedBox(height: 16),
            const Text(
              "Document RAG Chat",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Pick custom files from your phone storage or paste bespoke notes. AI will answer questions directly using your uploaded documents!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _pickAndIngestFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Pick File from Phone'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(RagChatMessage msg) {
    if (msg.sender == "system") {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blueGrey.withOpacity(0.4)),
        ),
        child: Text(
          msg.text,
          style: const TextStyle(fontSize: 12, color: Colors.cyanAccent),
        ),
      );
    }

    final isUser = msg.sender == "user";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.cyan,
                  child: Icon(Icons.smart_toy, size: 16, color: Colors.black),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.deepPurple : Colors.grey[850],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    msg.text.isEmpty ? "..." : msg.text,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.purpleAccent,
                  child: Icon(Icons.person, size: 16, color: Colors.white),
                ),
              ],
            ],
          ),
          if (!isUser && msg.retrievedSnippets.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  "🔍 Used ${msg.retrievedSnippets.length} retrieved context snippets from DB",
                  style: const TextStyle(fontSize: 11, color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                ),
                children: msg.retrievedSnippets.map((snippet) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                    ),
                    child: Text(
                      snippet,
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.grey),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
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

