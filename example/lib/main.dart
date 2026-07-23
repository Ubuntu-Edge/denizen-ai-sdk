import 'package:flutter/material.dart';
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
  final DenizenAI _denizen = DenizenAI();
  
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
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Denizen AI Showcase'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.download), text: 'Models'),
              Tab(icon: Icon(Icons.chat), text: 'Chat'),
              Tab(icon: Icon(Icons.manage_search), text: 'RAG & Tools'),
              Tab(icon: Icon(Icons.mic), text: 'Voice'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ModelsTab(),
            ChatTab(),
            RagTab(),
            VoiceTab(),
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
    _session = _denizen.createSession(systemPrompt: "You are a helpful assistant.");
  }

  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return;
    if (!_denizen.isModelLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please load a model first in the Models tab.')),
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
class RagTab extends StatefulWidget {
  const RagTab({super.key});

  @override
  State<RagTab> createState() => _RagTabState();
}

class _RagTabState extends State<RagTab> {
  bool _isIngesting = false;
  String _status = "RAG Database ready.";

  Future<void> _ingestDummyDocument() async {
    setState(() {
      _isIngesting = true;
      _status = "Ingesting document...";
    });

    try {
      final embeddingProvider = TFLiteEmbeddingProvider();
      await embeddingProvider.initialize();
      
      final storageService = VectorStorageService();
      if (!storageService.isInitialized) {
        await storageService.initialize();
      }
      
      final ingestionService = DocumentIngestionService(embeddingProvider, storageService);
      
      await ingestionService.ingestText(
        1, // docId
        "The secret password to access the mainframe is 'Antigravity'. It was set by Ibrahim on Tuesday.",
      );
      setState(() {
        _status = "Document ingested successfully! Try asking the AI about the password.";
      });
    } catch (e) {
      setState(() {
        _status = "Error: $e";
      });
    } finally {
      setState(() {
        _isIngesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.manage_search, size: 80, color: Colors.blueAccent),
          const SizedBox(height: 20),
          const Text(
            "RAG (Retrieval-Augmented Generation)",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            "Insert a secret document into the local Vector DB so the AI can read it.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _isIngesting ? null : _ingestDummyDocument,
            icon: const Icon(Icons.upload_file),
            label: const Text('Ingest Secret Document'),
          ),
          const SizedBox(height: 20),
          if (_isIngesting) const CircularProgressIndicator(),
          Text(_status, textAlign: TextAlign.center),
          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 20),
          const Text(
            "To test this, go to the Chat tab and ask: 'What is the secret password?'\n(Note: In a full app, you would use DenizenRagSession for the chat.)",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
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
