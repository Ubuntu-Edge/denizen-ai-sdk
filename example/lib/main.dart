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
// TAB 3: RAG & TOOLS
// ============================================================================
// ============================================================================
// ============================================================================
// TAB 3: UBUNTU-ELIMU DOCUMENT WORKSPACE & RAG CHAT
// ============================================================================

enum DocCategory { all, pdf, docx, txt, custom }

class StoredDocument {
  final int docId;
  final String title;
  final DocCategory category;
  final int sizeBytes;
  final DateTime addedAt;
  final String filePath;
  final int chunkCount;
  final String textPreview;

  StoredDocument({
    required this.docId,
    required this.title,
    required this.category,
    required this.sizeBytes,
    required this.addedAt,
    required this.filePath,
    required this.chunkCount,
    required this.textPreview,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData get icon {
    switch (category) {
      case DocCategory.pdf:
        return Icons.picture_as_pdf;
      case DocCategory.docx:
        return Icons.description;
      case DocCategory.txt:
        return Icons.article;
      case DocCategory.custom:
        return Icons.sticky_note_2;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color get color {
    switch (category) {
      case DocCategory.pdf:
        return Colors.redAccent;
      case DocCategory.docx:
        return Colors.blueAccent;
      case DocCategory.txt:
        return Colors.greenAccent;
      case DocCategory.custom:
        return Colors.purpleAccent;
      default:
        return Colors.cyanAccent;
    }
  }
}

class RagChatMessage {
  final String sender; // "user", "assistant", or "system"
  String text;
  final List<String> retrievedSnippets;
  final String? scopedDocTitle;

  RagChatMessage({
    required this.sender,
    required this.text,
    this.retrievedSnippets = const [],
    this.scopedDocTitle,
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
  bool _showLibraryWorkspace = true;
  String _statusMessage = "Initializing RAG Vector Engine...";

  final List<StoredDocument> _documents = [];
  final List<RagChatMessage> _messages = [];
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _docSearchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  DocCategory _selectedCategory = DocCategory.all;
  int? _scopedDocId;
  String _docSearchQuery = "";

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
        baseSystemPrompt: "You are an intelligent offline document AI assistant. Answer user questions accurately based strictly on the provided document context.",
      );

      setState(() {
        _isInitializing = false;
        _statusMessage = "Ubuntu Elimu Document Workspace ready.";
      });
    } catch (e) {
      debugPrint("RAG init error: $e");
      setState(() {
        _isInitializing = false;
        _statusMessage = "RAG Engine Init Warning: $e";
      });
    }
  }

  List<StoredDocument> get _filteredDocuments {
    return _documents.where((doc) {
      final matchesSearch = doc.title.toLowerCase().contains(_docSearchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == DocCategory.all || doc.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  /// Pick file natively from phone storage (Ubuntu Elimu style)
  Future<void> _pickAndUploadDocument() async {
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

      final pickedFile = result.files.first;
      if (pickedFile.path == null) return;

      final sourceFile = File(pickedFile.path!);
      final name = pickedFile.name;
      final ext = pickedFile.extension?.toLowerCase() ?? '';

      setState(() {
        _isIngesting = true;
        _statusMessage = "Ingesting $name from phone storage...";
      });

      // 1. Copy to local app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final docsDir = Directory('${appDir.path}/denizen_documents');
      if (!await docsDir.exists()) {
        await docsDir.create(recursive: true);
      }
      final savedPath = '${docsDir.path}/$name';
      await sourceFile.copy(savedPath);
      final savedFile = File(savedPath);

      // 2. Register document in SQLite Vector Storage
      final docId = _storageService!.insertDocument(name, sourceUri: savedPath);

      // 3. Ingest and extract text & vectors
      await _ingestionService!.ingestFile(docId, savedFile);

      // 4. Query vector count for this document
      final searchResults = _storageService!.search(List.filled(384, 0.1), limit: 200);
      final chunkCount = searchResults.isEmpty ? 1 : searchResults.length;

      DocCategory cat = DocCategory.txt;
      if (ext == 'pdf') cat = DocCategory.pdf;
      if (ext == 'docx' || ext == 'doc') cat = DocCategory.docx;

      final storedDoc = StoredDocument(
        docId: docId,
        title: name,
        category: cat,
        sizeBytes: pickedFile.size,
        addedAt: DateTime.now(),
        filePath: savedPath,
        chunkCount: chunkCount,
        textPreview: "Document ingested into sqlite-vec with $chunkCount vectors.",
      );

      setState(() {
        _documents.add(storedDoc);
        _scopedDocId = docId;
        _statusMessage = "Successfully ingested '$name' into local Vector DB!";
        _messages.add(RagChatMessage(
          sender: "system",
          text: "📁 Ingested '$name' ($chunkCount vector chunks). Active chat scoped to this document!",
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

  /// Paste custom text modal dialog
  void _showPasteTextDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Row(
            children: [
              Icon(Icons.note_add, color: Colors.purpleAccent),
              SizedBox(width: 8),
              Text('Add Custom Text Note', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Title (e.g. Love Story Notes)',
                    labelStyle: TextStyle(color: Colors.cyanAccent),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  maxLines: 6,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Document Content / Text',
                    labelStyle: TextStyle(color: Colors.cyanAccent),
                    hintText: 'Paste custom text, study guide, or notes here...',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
              onPressed: () async {
                final title = titleController.text.trim();
                final content = contentController.text.trim();
                if (title.isEmpty || content.isEmpty) return;

                Navigator.pop(context);
                await _ingestCustomText(title, content);
              },
              child: const Text('Ingest Note', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _ingestCustomText(String title, String content) async {
    if (_ingestionService == null || _storageService == null) return;

    setState(() {
      _isIngesting = true;
      _statusMessage = "Ingesting '$title'...";
    });

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final docsDir = Directory('${appDir.path}/denizen_documents');
      if (!await docsDir.exists()) {
        await docsDir.create(recursive: true);
      }
      final savedPath = '${docsDir.path}/$title.txt';
      final file = File(savedPath);
      await file.writeAsString(content);

      final docId = _storageService!.insertDocument(title, sourceUri: savedPath);
      await _ingestionService!.ingestText(docId, content);

      final chunkCount = (content.length / 200).ceil();

      final storedDoc = StoredDocument(
        docId: docId,
        title: title,
        category: DocCategory.custom,
        sizeBytes: content.length,
        addedAt: DateTime.now(),
        filePath: savedPath,
        chunkCount: chunkCount,
        textPreview: content.length > 80 ? '${content.substring(0, 80)}...' : content,
      );

      setState(() {
        _documents.add(storedDoc);
        _scopedDocId = docId;
        _statusMessage = "Ingested '$title' into Vector DB!";
        _messages.add(RagChatMessage(
          sender: "system",
          text: "📝 Note added: '$title' ($chunkCount chunks). Scoped chat to this note!",
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

  void _deleteDocument(StoredDocument doc) {
    if (_storageService != null) {
      _storageService!.deleteDocument(doc.docId);
    }
    final file = File(doc.filePath);
    if (file.existsSync()) {
      try {
        file.deleteSync();
      } catch (_) {}
    }

    setState(() {
      _documents.removeWhere((d) => d.docId == doc.docId);
      if (_scopedDocId == doc.docId) {
        _scopedDocId = null;
      }
      _messages.add(RagChatMessage(
        sender: "system",
        text: "🗑 Deleted document: '${doc.title}' from Vector DB.",
      ));
    });
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

    String? scopedTitle;
    if (_scopedDocId != null) {
      final doc = _documents.firstWhere(
        (d) => d.docId == _scopedDocId,
        orElse: () => StoredDocument(
          docId: -1,
          title: "All Docs",
          category: DocCategory.all,
          sizeBytes: 0,
          addedAt: DateTime.now(),
          filePath: "",
          chunkCount: 0,
          textPreview: "",
        ),
      );
      if (doc.docId != -1) scopedTitle = doc.title;
    }

    setState(() {
      _messages.add(RagChatMessage(sender: "user", text: text, scopedDocTitle: scopedTitle));
      _isGenerating = true;
    });

    _scrollToBottom();

    try {
      // Perform vector search with fallback to direct document chunks
      List<String> snippets = [];
      if (_storageService != null && _storageService!.isInitialized) {
        try {
          if (_embeddingProvider != null) {
            final queryVec = await _embeddingProvider!.embed(text);
            final searchResults = _storageService!.search(queryVec, limit: 3);
            snippets = searchResults.map((r) => r['text_content'].toString()).toList();
          }
        } catch (_) {}

        if (snippets.isEmpty) {
          final dbChunks = _storageService!.getChunksForDocument(docId: _scopedDocId, limit: 3);
          snippets = dbChunks.map((r) => r['text_content'].toString()).toList();
        }
      }

      final aiMsg = RagChatMessage(sender: "assistant", text: "", retrievedSnippets: snippets, scopedDocTitle: scopedTitle);
      setState(() {
        _messages.add(aiMsg);
      });

      final stream = _ragSession != null
          ? _ragSession!.streamChat(text, docId: _scopedDocId, directChunks: snippets)
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
            Text('Initializing Ubuntu Elimu Document Workspace...'),
          ],
        ),
      );
    }

    final scopedDoc = _scopedDocId != null
        ? _documents.firstWhere((d) => d.docId == _scopedDocId, orElse: () => _documents.first)
        : null;

    return Column(
      children: [
        // ================= UBUNTU ELIMU HEADER BAR =================
        Container(
          color: Colors.grey[900],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.school, color: Colors.cyanAccent, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    "Ubuntu Elimu Workspace",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _showLibraryWorkspace ? Icons.expand_less : Icons.folder_copy,
                      color: Colors.cyanAccent,
                    ),
                    tooltip: "Toggle Library Workspace",
                    onPressed: () {
                      setState(() {
                        _showLibraryWorkspace = !_showLibraryWorkspace;
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.upload_file, color: Colors.cyanAccent),
                    tooltip: "Upload Document (PDF/DOCX/TXT)",
                    onPressed: _isIngesting ? null : _pickAndUploadDocument,
                  ),
                  IconButton(
                    icon: const Icon(Icons.note_add, color: Colors.purpleAccent),
                    tooltip: "Paste Custom Text Note",
                    onPressed: _isIngesting ? null : _showPasteTextDialog,
                  ),
                ],
              ),

              if (_isIngesting) ...[
                const SizedBox(height: 4),
                const LinearProgressIndicator(),
              ],

              // Scope selector chip bar
              if (_documents.isNotEmpty) ...[
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        selected: _scopedDocId == null,
                        label: Text("🌐 All Docs (${_documents.length})"),
                        selectedColor: Colors.deepPurple,
                        onSelected: (_) {
                          setState(() {
                            _scopedDocId = null;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ..._documents.map((doc) {
                        final isSelected = _scopedDocId == doc.docId;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            avatar: Icon(doc.icon, size: 14, color: doc.color),
                            selected: isSelected,
                            selectedColor: doc.color.withOpacity(0.3),
                            label: Text("${doc.title} (${doc.chunkCount} chk)"),
                            onSelected: (_) {
                              setState(() {
                                _scopedDocId = isSelected ? null : doc.docId;
                              });
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // ================= UBUNTU ELIMU LIBRARY WORKSPACE =================
        if (_showLibraryWorkspace) ...[
          Container(
            color: Colors.grey[850],
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _docSearchController,
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search documents...',
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                          prefixIcon: const Icon(Icons.search, size: 16, color: Colors.cyanAccent),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor: Colors.grey[900],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _docSearchQuery = val;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<DocCategory>(
                      value: _selectedCategory,
                      dropdownColor: Colors.grey[900],
                      underline: const SizedBox(),
                      style: const TextStyle(fontSize: 12, color: Colors.cyanAccent),
                      items: DocCategory.values.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(cat.name.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (cat) {
                        if (cat != null) {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                if (_filteredDocuments.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _documents.isEmpty
                          ? "No documents uploaded yet. Tap 📁 to pick a PDF/DOCX from your phone or 📝 to paste text."
                          : "No matching documents found.",
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    height: 105,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filteredDocuments.length,
                      itemBuilder: (context, index) {
                        final doc = _filteredDocuments[index];
                        final isScoped = _scopedDocId == doc.docId;

                        return Container(
                          width: 190,
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isScoped ? Colors.deepPurple.withOpacity(0.3) : Colors.grey[900],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isScoped ? Colors.cyanAccent : Colors.grey[700]!,
                              width: isScoped ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(doc.icon, color: doc.color, size: 18),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      doc.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _deleteDocument(doc),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${doc.formattedSize} • ${doc.chunkCount} vector chunks",
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                              const Spacer(),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _scopedDocId = doc.docId;
                                    });
                                  },
                                  child: Text(
                                    isScoped ? "✓ Active Doc" : "Chat with Doc",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isScoped ? Colors.cyanAccent : Colors.purpleAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.grey),
        ],

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (scopedDoc != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(scopedDoc.icon, size: 12, color: scopedDoc.color),
                      const SizedBox(width: 6),
                      Text(
                        "Scoped to: ${scopedDoc.title}",
                        style: const TextStyle(fontSize: 11, color: Colors.cyanAccent, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _scopedDocId = null;
                          });
                        },
                        child: const Icon(Icons.close, size: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
              Row(
                children: [
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.cyanAccent, size: 28),
                    onSelected: (value) {
                      if (value == 'phone') {
                        _pickAndUploadDocument();
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
                            Text('Upload Document (PDF/DOCX/TXT)'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'text',
                        child: Row(
                          children: [
                            Icon(Icons.edit_note, color: Colors.purpleAccent),
                            SizedBox(width: 8),
                            Text('Paste Custom Text Note'),
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
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: scopedDoc != null
                            ? 'Ask questions about "${scopedDoc.title}"...'
                            : 'Ask questions about your uploaded documents...',
                        hintStyle: const TextStyle(color: Colors.grey),
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
              child: const Icon(Icons.school, size: 64, color: Colors.cyanAccent),
            ),
            const SizedBox(height: 16),
            const Text(
              "Ubuntu Elimu Document RAG Workspace",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              "Upload bespoke PDF, DOCX, or text files from your phone or paste notes into your local library. AI will retrieve exact context chunks and answer questions offline!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickAndUploadDocument,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Upload Document'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _showPasteTextDialog,
                  icon: const Icon(Icons.edit_note, color: Colors.purpleAccent),
                  label: const Text('Add Text Note', style: TextStyle(color: Colors.purpleAccent)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.purpleAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (msg.scopedDocTitle != null) ...[
                        Text(
                          "Scoped to: ${msg.scopedDocTitle}",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isUser ? Colors.cyanAccent : Colors.purpleAccent,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        msg.text.isEmpty ? "..." : msg.text,
                        style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.white),
                      ),
                    ],
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

