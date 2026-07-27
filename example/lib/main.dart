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
              Tab(icon: Icon(Icons.manage_search), text: 'RAG & Tools'),
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
class RagTab extends StatefulWidget {
  const RagTab({super.key});

  @override
  State<RagTab> createState() => _RagTabState();
}

class _RagTabState extends State<RagTab> {
  bool _isIngesting = false;
  String _status = "RAG Database ready.";

  // Tool demonstration state
  final DenizenToolRegistry _toolRegistry = DenizenToolRegistry();
  bool _flashlightEnabled = false;
  int _batteryLevel = 88;
  String _toolLog = "No tools triggered yet.";
  bool _isToolRunning = false;
  final TextEditingController _toolController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initTools();
  }

  void _initTools() {
    _toolRegistry.register(
      BatteryTool(
        getBatteryLevel: () => _batteryLevel,
        logCallback: (msg) {
          setState(() {
            _toolLog = msg;
          });
        },
      ),
    );

    _toolRegistry.register(
      FlashlightTool(
        setFlashlight: (enable) {
          setState(() {
            _flashlightEnabled = enable;
          });
        },
        logCallback: (msg) {
          setState(() {
            _toolLog = msg;
          });
        },
      ),
    );
  }

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

  Future<void> _runToolRequest() async {
    final prompt = _toolController.text.trim();
    if (prompt.isEmpty) return;
    final denizen = DenizenAI();
    if (!denizen.isModelLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please load a model first in the Models tab.')),
      );
      return;
    }

    setState(() {
      _isToolRunning = true;
      _toolLog = "Sending prompt to tool session...";
    });

    try {
      final session = denizen.createToolSession(
        registry: _toolRegistry,
        systemPrompt: "You are a helpful on-device assistant. Use tools when requested by the user.",
      );
      final response = await session.chat(prompt);
      setState(() {
        _toolLog = "AI Response: $response";
      });
    } catch (e) {
      setState(() {
        _toolLog = "Error: $e";
      });
    } finally {
      setState(() {
        _isToolRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ================= RAG SECTION =================
          const Icon(Icons.manage_search, size: 60, color: Colors.blueAccent),
          const SizedBox(height: 10),
          const Text(
            "RAG (Retrieval-Augmented Generation)",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Insert a secret document into the local Vector DB so the AI can read it.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isIngesting ? null : _ingestDummyDocument,
            icon: const Icon(Icons.upload_file),
            label: const Text('Ingest Secret Document'),
          ),
          const SizedBox(height: 10),
          if (_isIngesting) const CircularProgressIndicator(),
          Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          const Text(
            "To test this, go to the Chat tab and ask: 'What is the secret password?'\n(Chat tab is now configured with DenizenRagSession!)",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // ================= TOOLS SECTION =================
          const Icon(Icons.build_circle, size: 60, color: Colors.orangeAccent),
          const SizedBox(height: 10),
          const Text(
            "On-Device Tool Use & Function Calling",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "AI automatically detects tool calls (battery or flashlight) and runs local Dart code.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          
          // Simulated Device State Card
          Card(
            color: Colors.grey[900],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Icon(
                        _flashlightEnabled ? Icons.flash_on : Icons.flash_off,
                        color: _flashlightEnabled ? Colors.yellow : Colors.grey,
                        size: 32,
                      ),
                      const SizedBox(height: 4),
                      Text("Flashlight: ${_flashlightEnabled ? 'ON' : 'OFF'}"),
                    ],
                  ),
                  Column(
                    children: [
                      const Icon(Icons.battery_std, color: Colors.green, size: 32),
                      const SizedBox(height: 4),
                      Text("Battery: $_batteryLevel%"),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tool Prompt Input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _toolController,
                  decoration: const InputDecoration(
                    hintText: "Try: 'turn on the flashlight' or 'battery status'",
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _runToolRequest(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isToolRunning ? null : _runToolRequest,
                child: const Text("Run"),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isToolRunning) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          
          // Log output console
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: Text(
              _toolLog,
              style: const TextStyle(fontFamily: 'monospace', color: Colors.lightGreenAccent),
            ),
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

