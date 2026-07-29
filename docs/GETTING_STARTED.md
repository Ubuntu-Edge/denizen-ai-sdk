# Denizen AI SDK — Getting Started Guide 🚀

Welcome to the **Denizen AI SDK** release! Denizen AI is a privacy-first, on-device multimodal AI engine for Flutter. It lets you run local LLMs, offline document RAG, structured tool calling (with guaranteed JSON schemas), voice consultation, and image analysis 100% offline with zero cloud API fees.

---

## 📋 Table of Contents

- [Key Capabilities](#-key-capabilities)
- [Installation & Setup](#-installation--setup)
- [Recommended Offline Models](#-recommended-offline-models)
- [5-Minute Quickstart](#-5-minute-quickstart)
  - [1. Download & Load a Local GGUF Model](#1-download--load-a-local-gguf-model)
  - [2. Stream LLM Responses with Context Memory](#2-stream-llm-responses-with-context-memory)
  - [3. Offline Document RAG (PDF Vector Search)](#3-offline-document-rag-pdf-vector-search)
  - [4. Guaranteed Structured JSON Output (Tool Calling)](#4-guaranteed-structured-json-output-tool-calling)
  - [5. Hands-Free Conversational Voice Loop](#5-hands-free-conversational-voice-loop)
  - [6. Multimodal Vision (Image Analysis)](#6-multimodal-vision-image-analysis)
- [Platform Configuration (Android / Windows)](#-platform-configuration)
- [Memory & Performance Best Practices](#-memory--performance-best-practices)

---

## ✨ Key Capabilities

| Feature | Description | On-Device Performance |
|---|---|---|
| 🧠 **Local LLM Engine** | Accelerated GGUF model execution (Qwen, Llama 3.2, SmolLM2, Phi-3.5) | ~15–40 tokens/sec on mobile CPUs |
| 🔍 **Vector RAG Engine** | Ingest PDFs & text docs into local SQLite vector storage with TF-Lite embeddings | Zero-latency cosine similarity |
| 🛠️ **Structured Tool Calling** | Forced JSON output parsing via GBNF context grammars | 100% schema validation accuracy |
| 🎙️ **Conversational Voice** | Offline STT (Whisper) + LLM inference + TTS (Piper/eSpeak) loop | Hands-free audio consultation |
| 👁️ **Multimodal Vision** | Analyze images on-device using quantized MobileVLM / LLaVA GGUF models | Instant local diagnosis |

---

## 📦 Installation & Setup

Add `denizen_ai` to your Flutter project's `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Denizen AI Offline SDK
  denizen_ai:
    git:
      url: https://github.com/Ubuntu-Edge/denizen-ai-sdk.git
      ref: main

  path_provider: ^2.1.1
  path: ^1.9.1
```

Run in your terminal:
```bash
flutter pub get
```

---

## 🎯 Recommended Offline Models

Denizen AI supports any standard `.gguf` quantized model (Q4_K_M recommended for mobile). Here are our pre-tested recommendations:

| Model Name | Size | RAM Required | Best Use Case | Direct Download Link |
|---|---|---|---|---|
| **SmolLM2 360M Instruct** | 228 MB | ~0.5 GB | Instant testing / Low-end phones | [Download GGUF](https://huggingface.co/bartowski/SmolLM2-360M-Instruct-GGUF/resolve/main/SmolLM2-360M-Instruct-Q4_K_M.gguf) |
| **Qwen2.5 0.5B Instruct** | 398 MB | ~0.8 GB | Ultra-fast mobile Q&A (Recommended) | [Download GGUF](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf) |
| **Llama 3.2 1B Instruct** | 758 MB | ~1.5 GB | Balanced general & instruction follow | [Download GGUF](https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf) |
| **Qwen2.5 1.5B Instruct** | 980 MB | ~1.8 GB | High reasoning power | [Download GGUF](https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf) |
| **Phi-3.5 Mini 3.8B** | 2.39 GB | ~4.5 GB | High-RAM Android / Windows Desktop | [Download GGUF](https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf) |

---

## ⚡ 5-Minute Quickstart

### 1. Download & Load a Local GGUF Model

Denizen includes a built-in chunked, resumable downloader with SHA-256 integrity verification:

```dart
import 'package:denizen_ai/denizen_ai.dart';

Future<void> prepareModel() async {
  final sdk = DenizenAI();

  // 1. Download model directly to mobile local storage
  final model = await sdk.models.downloadModel(
    url: 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
    modelId: 'qwen2.5-0.5b',
    fileName: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
    onProgress: (progress) {
      print('Download progress: ${(progress * 100).toStringAsFixed(1)}%');
    },
  );

  // 2. Load model into memory
  await sdk.models.loadModel(
    model,
    contextSize: 2048,
    gpuLayers: 0, // Set > 0 for GPU acceleration if available
  );

  print('✅ Denizen AI Engine loaded and ready offline!');
}
```

---

### 2. Stream LLM Responses with Context Memory

Manage conversation history and context windows automatically using `DenizenSession`:

```dart
import 'package:denizen_ai/denizen_ai.dart';

Future<void> runChat() async {
  final sdk = DenizenAI();

  // Create a stateful conversation session
  final session = sdk.createSession(
    systemPrompt: 'You are an offline assistant helping a health worker in a rural clinic.',
    maxTokens: 512,
  );

  // Stream token responses in real time
  final stream = session.sendMessageStream('What are the symptoms of severe malaria?');

  await for (final token in stream) {
    // Print each token as it is generated by the local engine
    stdout.write(token);
  }
}
```

---

### 3. Offline Document RAG (PDF Vector Search)

Index offline documents (medical guidelines, manuals, handbooks) into an on-device SQLite vector database:

```dart
import 'package:denizen_ai/denizen_ai.dart';

Future<void> runOfflineRAG(String pdfPath) async {
  final sdk = DenizenAI();

  // Initialize vector ingestion engine
  final ragService = DocumentIngestionService(
    embeddingProvider: TFLiteEmbeddingProvider(),
  );

  // Ingest document chunks into on-device vector DB
  await ragService.ingestDocument(filePath: pdfPath);

  // Create a RAG Session that automatically searches vector DB before answering
  final ragSession = sdk.createRagSession(
    embeddingProvider: TFLiteEmbeddingProvider(),
    storageService: VectorStorageService.instance,
    baseSystemPrompt: 'Answer strictly based on local clinical guidelines.',
  );

  final stream = ragSession.sendMessageStream('How do I treat dehydration in children?');
  
  await for (final token in stream) {
    stdout.write(token);
  }
}
```

---

### 4. Guaranteed Structured JSON Output (Tool Calling)

Guarantee strict JSON tool execution using GBNF grammar constraints:

```dart
import 'package:denizen_ai/denizen_ai.dart';

Future<void> runStructuredTriage() async {
  final sdk = DenizenAI();
  final registry = DenizenToolRegistry();

  // Register a tool with a strict JSON Schema
  registry.registerTool(
    name: 'submit_patient_triage',
    description: 'Submits structured emergency patient triage report',
    parameters: {
      'type': 'object',
      'properties': {
        'patient_id': {'type': 'string'},
        'urgency': {'type': 'string', 'enum': ['CRITICAL', 'URGENT', 'STABLE']},
        'primary_symptom': {'type': 'string'},
      },
      'required': ['patient_id', 'urgency', 'primary_symptom'],
    },
    handler: (args) async {
      print('Executing Triage Submission: $args');
      return 'Triage logged successfully for ${args['patient_id']}';
    },
  );

  final toolSession = DenizenToolSession(
    engine: sdk.engine,
    registry: registry,
  );

  // The engine automatically formats prompt, forces GBNF schema, calls function & returns response
  final response = await toolSession.chat(
    'Patient #409 presents with acute shortness of breath and high fever.',
  );
  print(response);
}
```

---

### 5. Hands-Free Conversational Voice Loop

Run an offline Speech-to-Text -> LLM -> Text-to-Speech loop:

```dart
import 'package:denizen_ai/denizen_ai.dart';

Future<void> startVoiceConsultation() async {
  final sdk = DenizenAI();

  final voiceSession = DenizenVoiceSession(
    engine: sdk.engine,
    sttService: OfflineAudioService(),
  );

  await voiceSession.startListening(
    onSpeechRecognized: (spokenText) {
      print('CHW Spoke: $spokenText');
    },
    onResponseGenerated: (aiReply) {
      print('AI Audio Reply: $aiReply');
    },
  );
}
```

---

### 6. Multimodal Vision (Image Analysis)

Analyze local medical photos (e.g. skin conditions, diagnostic cards):

```dart
import 'package:denizen_ai/denizen_ai.dart';

Future<void> analyzeDiagnosticImage(String imagePath) async {
  final sdk = DenizenAI();

  final visionSession = DenizenVisionSession(
    engine: sdk.engine,
  );

  final analysis = await visionSession.analyzeImage(
    imagePath: imagePath,
    prompt: 'Identify any abnormal rash or swelling shown in this photo.',
  );

  print('Vision Diagnosis: $analysis');
}
```

---

## 📱 Platform Configuration

### Android Setup (`android/app/build.gradle`)

Set `minSdkVersion` to **24** or higher:

```groovy
android {
    defaultConfig {
        minSdkVersion 24
        targetSdkVersion 34
    }
}
```

Add microphone & storage permissions to `AndroidManifest.xml` (for Voice & Model downloads):

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

---

## ⚡ Memory & Performance Best Practices

1. **Use `Q4_K_M` Quantization**: Quantized 4-bit models offer 95%+ of full model accuracy while reducing RAM consumption by 75%.
2. **Context Window Sizing**: Set `contextSize` to **2048** for low-end mobile devices (2GB–4GB RAM). Set to **4096** for modern flagship phones (6GB+ RAM).
3. **Single Engine Singleton**: Keep `DenizenAI()` as a singleton. Loading multiple GGUF models simultaneously into mobile RAM will trigger an Operating System OOM (Out Of Memory) kill.
4. **Resumable Downloads**: Use `ModelDownloadService` to handle spotty 3G/rural connectivity with partial range headers.

---

## 📄 License & Community Support

Denizen AI is open-source and built for privacy-first developers worldwide.

- 🐛 **Report Issues**: [GitHub Issues](https://github.com/Ubuntu-Edge/denizen-ai-sdk/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/Ubuntu-Edge/denizen-ai-sdk/discussions)
- 🌐 **Documentation**: [Ubuntu Edge Docs](https://github.com/Ubuntu-Edge/denizen-ai-sdk)
