# Denizen AI Engine 🚀

> **Privacy-first, On-device Multimodal AI Engine & Orchestrator for Flutter**  
> Run local LLMs, Vector RAG search, Structured Tool Calling, Conversational Voice, and Vision analysis 100% offline with zero cloud API fees.

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
│ │  • Offline TTS   │  │  • Visual Projector│  │  • sqlite-vec DB      │ │
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

## 🌟 Key Features

- **⚡ 100% Offline & Private**: Complete on-device processing. No telemetry, no cloud API dependencies, and zero data leaving the user's device.
- **🧠 Local LLM Execution**: Accelerated GGUF inference powered by pre-compiled C++ backends (`Llama 3`, `Phi-3.5`, `Qwen 2.5`, `Mistral`).
- **🔍 Vector RAG (Retrieval-Augmented Generation)**: On-device TF-Lite embedding extraction combined with local vector storage for instant document Q&A.
- **🛠️ Parallel Tool Calling & GBNF Grammar Constraints**: Multi-turn tool execution with dynamic GBNF grammar compiling to guarantee strict JSON output schemas.
- **🎙️ Conversational Voice Sessions**: Real-time offline Speech-to-Text (STT) and Text-to-Speech (TTS) integration.
- **👁️ Multimodal Vision Processing**: On-device image analysis and visual projector simulation.

---

## 📦 Installation

Add `denizen_ai` to your Flutter project's `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter

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

## 🚀 Quickstart

### 1. Initialize Denizen Engine & Generate Text Stream

```dart
import 'package:denizen_ai/denizen_ai.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final engine = DenizenEngine();
  await engine.initialize(
    modelPath: '/path/to/local/model.gguf',
    contextSize: 2048,
    gpuLayers: 0,
  );

  final stream = engine.generateStream(
    prompt: 'Explain quantum computing in 2 short sentences.',
  );

  await for (final token in stream) {
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
offline_ai_architecture/
├── lib/                               ← Core Denizen AI SDK
│   ├── denizen_ai.dart                ← Main entry export
│   └── src/
│       ├── audio/                     ← Offline STT / TTS Voice Sessions
│       ├── benchmark/                 ← On-device benchmark performance suite
│       ├── engine/                    ← GGUF LLM Engine & Parameters
│       ├── grammar/                   ← GBNF Schema Compiler
│       ├── orchestrator/              ← Denizen Orchestrator
│       ├── rag/                       ← TF-Lite Embeddings & Vector Storage
│       ├── tools/                     ← Parallel Tool Calling & Sessions
│       └── vision/                    ← Multimodal Vision Analysis
├── packages/
│   └── llama_flutter_android/         ← Native Android C++ / JNI Plugin
├── tool/
│   └── release.dart                   ← Automated Closed-Source Packager
└── example/                           ← Interactive Showcase Dashboard
```

---

## 💻 Platform Support & Native Binaries

| Platform | Status | Architecture | Binary Module |
|---|---|---|---|
| **Android** | ✅ Production Ready | `ARM64-v8a` | Pre-compiled `libllama.so` |
| **Windows** | ✅ Production Ready | `x64` | `example.exe` & `vec0.dll` |
| **iOS** | 🚧 Roadmap | `Metal` | Metal Shaders |
| **macOS** | 🚧 Roadmap | `Apple Silicon` | Metal Shaders |

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
