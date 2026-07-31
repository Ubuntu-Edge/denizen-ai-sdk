# Denizen AI Engine 🚀

> **Privacy-first, On-Device Multimodal AI Engine & Orchestrator for Flutter (v1.0 Developer Preview)**  
> Run local LLMs, Vector RAG search, Structured Tool Calling, Conversational Voice, and Vision analysis 100% offline with zero cloud API fees.

---

## 📊 Feature Matrix & Release Roadmap

| Feature | Release | Status | Details |
|---|---|---|---|
| 🧠 **Model Download & Lifecycle Management** | **v1.0 (Today)** | 🟢 **Production Ready** | Resumable chunked GGUF downloading, pre-pushed import, LRU storage eviction, and memory management. |
| 💬 **Basic Prompting & Streaming Q&A** | **v1.0 (Today)** | 🟢 **Production Ready** | Stateful chat sessions (`DenizenSession`), token streaming, sliding context window eviction, and rollback safety. |
| 🔍 **Offline Vector RAG Engine** | **v2.0 (Next Week)** | 🟡 **Targeting v2.0** | TF-Lite embedding extraction + `sqlite-vec` local vector database for PDF document reasoning. |
| 🛠️ **Structured Tool Calling** | **v2.0 (Next Week)** | 🟡 **Targeting v2.0** | GBNF context grammar constraints for guaranteed JSON function calling. |
| 🎙️ **Conversational Voice** | **v2.0 (Next Week)** | 🟡 **Targeting v2.0** | Real-time offline Speech-to-Text (Whisper) + Text-to-Speech (TTS) loop. |
| 👁️ **Multimodal Vision** | **v2.0 (Next Week)** | 🟡 **Targeting v2.0** | LLaVA / MobileVLM local image analysis. |

---

## 🏗️ Denizen AI System Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Denizen Orchestrator                            │
│ ┌──────────────────┐  ┌───────────────────┐  ┌───────────────────────┐ │
│ │  DenizenEngine   │  │ DocumentIngestion │  │   DenizenToolSession  │ │
│ │  (Local LLM GGUF)│  │   Service (RAG)   │  │ (Tool Calling & GBNF) │ │
│ └────────┬─────────┘  └─────────┬─────────┘  └───────────┬───────────┘ │
├──────────┼──────────────────────┼────────────────────────┼─────────────┤
│          ▼                      ▼                        ▼             │
│                 Multimodal & Native Hardware Layer                     │
│ ┌──────────────────┐  ┌───────────────────┐  ┌───────────────────────┐ │
│ │DenizenVoiceSess. │  │DenizenVisionSess. │  │  VectorStorageService │ │
│ │  • Offline STT   │  │  • Image Analysis │  │  • TFLite Embeddings  │ │
│ │  • Offline TTS   │  │  • Early Access   │  │  • sqlite-vec DB      │ │
│ └────────┬─────────┘  └─────────┬─────────┘  └───────────┬───────────┘ │
└──────────┼──────────────────────┼────────────────────────┼─────────────┘
           │                      │                        │
           ▼                      ▼                        ▼
┌────────────────────────────────────────────────────────────────────────┐
│                    Pre-Compiled Native C++ Binaries                    │
│    • libllama.so (Android ARM64 NEON)    • vec0.dll (Windows x64)     │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 📦 Installation for App Developers

Downstream developers can install `denizen_ai` directly in their Flutter project:

```yaml
dependencies:
  flutter:
    sdk: flutter

  denizen_ai:
    git:
      url: https://github.com/Ubuntu-Edge/denizen-ai-sdk.git
      ref: main

  path_provider: ^2.1.1
```

Run in your terminal:
```bash
flutter pub get
```

📖 **Complete Release Guide**: Check out our [Getting Started Guide](file:///c:/Users/ibrahim.fadhili/OneDrive%20-%20Agile%20Business%20Solutions/Desktop/offline_ai_architecture/docs/GETTING_STARTED.md) for full step-by-step documentation, recommended GGUF model links, and platform setup.

---

## 🚀 Quickstart

### 1. Initialize Engine & Stream Local LLM Responses

```dart
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:denizen_ai/denizen_ai.dart';
import 'package:path/path.dart' as p;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Resolve portable app documents directory (Android Scoped Storage compatible)
  final docsDir = await getApplicationDocumentsDirectory();
  final modelPath = p.join(docsDir.path, 'models', 'qwen2.5-1.5b-instruct-q4_k_m.gguf');

  final engine = DenizenEngine();
  await engine.initialize(
    modelPath: modelPath,
    contextSize: 2048,
    gpuLayers: 0,
  );

  final tokenStream = engine.generateStream(
    prompt: 'Explain quantum computing in 2 short sentences.',
  );

  await for (final token in tokenStream) {
    print(token);
  }
}
```

---

### 2. Offline Vector RAG (Document Ingestion & Query)

```dart
final ragService = DocumentIngestionService(
  embeddingProvider: TFLiteEmbeddingProvider(),
);

// Ingest local document into vector store
await ragService.ingestDocument(
  filePath: '/path/to/handbook.pdf',
);

// Query vector database
final matches = await ragService.queryVectorStore(
  query: 'What is our emergency response protocol?',
  topK: 3,
);

for (final match in matches) {
  print('Match snippet: ${match.content} (Score: ${match.score})');
}
```

---

### 3. Parallel Tool Calling with GBNF Constraints

```dart
final registry = DenizenToolRegistry();

// Register a custom function with JSON Schema validation
registry.registerTool(
  name: 'get_weather',
  description: 'Fetches current weather for a city',
  parameters: {
    'type': 'object',
    'properties': {
      'city': {'type': 'string'},
    },
    'required': ['city'],
  },
  handler: (args) async => 'Weather in ${args['city']} is 24°C, Sunny',
);

final toolSession = DenizenToolSession(
  engine: engine,
  registry: registry,
);

// Engine executes function loop & returns final synthesized response
final result = await toolSession.chat('What is the weather in Nairobi?');
print(result);
```

---

### 4. Conversational Voice Session

```dart
final voiceSession = DenizenVoiceSession(
  engine: engine,
  sttService: OfflineAudioService(),
);

await voiceSession.startListening(
  onSpeechRecognized: (userText) => print('User said: $userText'),
  onResponseGenerated: (aiReply) => print('AI replied: $aiReply'),
);
```

---

## 📂 Repository Structure

```
offline_ai_architecture/               ← Main Development Source Repository
├── lib/                               ← Core Denizen AI SDK Source
│   ├── denizen_ai.dart                ← Main entry export
│   └── src/
│       ├── audio/                     ← Offline STT / TTS Voice Sessions
│       ├── benchmark/                 ← On-device benchmark performance suite
│       ├── engine/                    ← GGUF LLM Engine & Parameters
│       ├── grammar/                   ← GBNF Schema Compiler
│       ├── orchestrator/              ← Denizen Orchestrator
│       ├── rag/                       ← TF-Lite Embeddings & Vector Storage
│       ├── tools/                     ← Parallel Tool Calling & Sessions
│       └── vision/                    ← Multimodal Vision Analysis (Early Access)
├── packages/
│   └── llama_flutter_android/         ← Native Android C++ / JNI Plugin
├── tool/
│   └── release.dart                   ← Automated Closed-Source Packager
└── example/                           ← Interactive Showcase Dashboard
```

---

## 🔒 Closed-Source Binary Packaging

To generate a secure distribution package with raw C++ source files stripped:

```bash
dart tool/release.dart
```

This compiles release binaries, strips all C++ source code (`.cpp`, `.h`), and generates a clean distribution package in `release_bundle/`.

---

## 📄 License

Copyright © 2026 Denizen AI / Ubuntu Edge. All rights reserved.
