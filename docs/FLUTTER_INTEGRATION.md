# Denizen AI — Offline Flutter Implementation 🚀

> **Complete Technical Reference & Plain-English Architecture Breakdown**

---

## 🎯 What This Application Accomplishes

This code runs an Artificial Intelligence model **100% locally on the user's mobile device** without sending any data to cloud servers. It provides:
- 🛡️ **Complete Data Privacy**: No telemetry, prompt data, or personal information leaves the handset.
- ⚡ **Zero Cloud Fees & Instant Response**: Zero API fees, low latency streaming inference.
- 📶 **100% Offline Usability**: Works seamlessly in airplane mode or remote areas with no network connectivity.

---

## 📦 Installation & Setup

Add `denizen_ai` directly from GitHub to your Flutter app's `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Pull Denizen AI SDK directly from GitHub
  denizen_ai:
    git:
      url: https://github.com/Ubuntu-Edge/denizen-ai-sdk.git
      ref: main
```

Run in your terminal:
```bash
flutter pub get
```

---

## 💻 Source Code (`lib/screens/offline_ai_chat_screen.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:denizen_ai/denizen_ai.dart';

void main() {
  runApp(MaterialApp(
    home: OfflineAIChatScreen(),
    theme: ThemeData.dark(),
  ));
}

class OfflineAIChatScreen extends StatefulWidget {
  @override
  State<OfflineAIChatScreen> createState() => _OfflineAIChatScreenState();
}

class _OfflineAIChatScreenState extends State<OfflineAIChatScreen> {
  final sdk = DenizenAI();
  late DenizenSession session;

  bool isDownloading = false;
  double downloadProgress = 0.0;
  bool isReady = false;

  String currentResponse = '';
  final TextEditingController inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    initializeAI();
  }

  Future<void> initializeAI() async {
    setState(() => isDownloading = true);

    // 1. Storage check -> Download (if missing) -> Native C++ load
    await sdk.models.load(
      'qwen2.5-0.5b',
      onProgress: (p) {
        setState(() => downloadProgress = p.percent);
      },
    );

    // 2. Initialize stateful Q&A session
    session = sdk.createSession(
      systemPrompt: 'You are a helpful offline assistant.',
      maxTokens: 512,
    );

    setState(() {
      isDownloading = false;
      isReady = true;
    });
  }

  void askQuestion() async {
    final prompt = inputController.text.trim();
    if (prompt.isEmpty) return;

    inputController.clear();
    setState(() => currentResponse = '');

    // 3. Stream generated tokens in real time directly to UI
    final stream = session.sendMessageStream(prompt);

    await for (final token in stream) {
      setState(() {
        currentResponse += token;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isDownloading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(value: downloadProgress / 100),
              SizedBox(height: 16),
              Text(
                'Downloading Model: ${downloadProgress.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Denizen AI — 100% Offline Chat'),
        actions: [
          IconButton(
            icon: Icon(Icons.cleaning_services),
            onPressed: () {
              setState(() => currentResponse = '');
            },
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Text(
                currentResponse.isEmpty
                    ? 'Ask any question to test offline AI...'
                    : currentResponse,
                style: TextStyle(fontSize: 16, height: 1.4),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(12),
            color: Colors.grey[900],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: inputController,
                    decoration: InputDecoration(
                      hintText: 'Ask a question offline...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send),
                  color: Colors.blueAccent,
                  onPressed: isReady ? askQuestion : null,
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
```

---

## 🔍 Step-by-Step Code Breakdown

### STEP 1: Model Download & Initialization

```dart
await sdk.models.load('qwen2.5-0.5b', onProgress: (p) => setState(() => downloadProgress = p.percent));
```

- **NON-TECHNICAL**: The app checks if the ~398 MB AI model is already saved on your phone. If missing, it downloads it once and loads it directly into the device's chip to run without internet.
- **DEVELOPER**: Asynchronous call checking local storage, executing resumable chunked HTTP downloader with progress callbacks, checking LRU disk eviction, and loading model weights into native ARM64/x64 C++ runtime context (`libllama.so`).

---

### STEP 2: Stateful Session Allocation

```dart
session = sdk.createSession(systemPrompt: 'You are a helpful offline assistant.', maxTokens: 512);
```

- **NON-TECHNICAL**: Configures the AI's persona/behavior and sets upper safety boundaries so responses remain concise without eating up device memory.
- **DEVELOPER**: Instantiates a stateful session manager handling context window buffer allocation, system prompt injection, and response token capping (512 max) with sliding context window eviction.

---

### STEP 3: Real-Time Token Streaming

```dart
final stream = session.sendMessageStream(prompt);
await for (final token in stream) { setState(() => currentResponse += token); }
```

- **NON-TECHNICAL**: As the local AI calculates each word, it displays it on the screen immediately in real time, creating an instant typewriter effect.
- **DEVELOPER**: Consumes an async Dart `Stream<String>` emitted token-by-token during C++ model inference. Re-renders UI reactively for low perceived latency (~15–40 tokens/sec).

---

### STEP 4: Reactive UI Render Pipeline

```dart
if (isDownloading) { return Scaffold(body: CircularProgressIndicator(...)); }
```

- **NON-TECHNICAL**: The user interface automatically switches between a progress download bar on first launch and the full chat screen once the AI model is ready.
- **DEVELOPER**: Conditional widget tree evaluation using Flutter state flags (`isDownloading`, `isReady`) to swap reactively between progress loader and chat view.
