# Offline AI Architecture

A self-contained, on-device LLM inference architecture for Flutter Android apps. Built for Community Health Workers (CHWs) in low-connectivity environments — but designed to be reused by any developer who needs offline AI capabilities.

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                      UI Layer (Screens)                      │
│  ┌─────────────────┐ ┌─────────────┐ ┌───────────────────┐  │
│  │ Download Screen  │ │ Model Picker│ │ Inference Settings│  │
│  └────────┬────────┘ └──────┬──────┘ └────────┬──────────┘  │
│           │                 │                  │             │
├───────────┼─────────────────┼──────────────────┼─────────────┤
│           ▼                 ▼                  ▼             │
│                 State Management (Providers)                  │
│  ┌──────────────────────┐  ┌────────────────────────────┐   │
│  │ OfflineModelProvider │  │      ChatProvider           │   │
│  │  • Model lifecycle   │  │  • Online ↔ Offline routing │   │
│  │  • Download status   │  │  • Smart fallback           │   │
│  │  • Auto-detection    │  │  • Chat session management  │   │
│  └──────────┬───────────┘  └──────────┬─────────────────┘   │
│             │                         │                      │
├─────────────┼─────────────────────────┼──────────────────────┤
│             ▼                         ▼                      │
│                    Core Services                             │
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────┐  │
│  │ OfflineAIService │  │ ModelDownload     │  │Connectivity│ │
│  │  • llama.cpp      │  │  Service          │  │  Service   │ │
│  │  • GGUF loading   │  │  • HuggingFace DL │  │  • Real    │ │
│  │  • Streaming      │  │  • Resume support │  │    internet│ │
│  │  • Token gen      │  │  • Gzip extract   │  │    check   │ │
│  └──────────────────┘  └──────────────────┘  └───────────┘  │
│                                                              │
│  ┌──────────────────┐  ┌──────────────────┐                  │
│  │   AIService      │  │  SymptomParser   │                  │
│  │  • Online API    │  │  • NLP extraction │                  │
│  │  • Safety filter │  │  • Emergency      │                  │
│  │  • Post-process  │  │    detection      │                  │
│  └──────────────────┘  └──────────────────┘                  │
│                                                              │
├──────────────────────────────────────────────────────────────┤
│                    Data Models                               │
│  ┌────────────────┐ ┌──────────────────┐ ┌───────────────┐  │
│  │ OfflineModel   │ │ ContextParams    │ │ CompletionPrms│  │
│  │ DefaultModels  │ │ LoadingProgress  │ │ ChatMessage   │  │
│  └────────────────┘ └──────────────────┘ └───────────────┘  │
└──────────────────────────────────────────────────────────────┘
         │
         ▼
  ┌──────────────────┐
  │ llama_flutter_    │
  │ android (plugin)  │
  │  • llama.cpp JNI  │
  │  • ARM64 NEON     │
  └──────────────────┘
```

## Quick Start

### 1. Add Dependencies

Add these to your `pubspec.yaml`:

```yaml
dependencies:
  # Core: On-device LLM inference
  llama_flutter_android: ^0.1.1

  # Network & Downloads
  http: ^1.1.0
  connectivity_plus: ^6.1.0

  # State Management
  provider: ^6.1.1
  shared_preferences: ^2.2.3

  # Storage
  path_provider: ^2.1.1

  # File Picker (for custom models)
  file_picker: ^10.3.7

  # Permissions
  permission_handler: ^12.0.1

  # UUID (for chat sessions)
  uuid: ^4.2.1

  # Environment variables (for API token)
  flutter_dotenv: ^6.0.0
```

### 2. Initialize Services

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await AIService.instance.initialize();
  await OfflineAIService.instance.initialize();
  await ConnectivityService.instance.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OfflineModelProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider.value(value: ConnectivityService.instance),
      ],
      child: MyApp(),
    ),
  );
}
```

### 3. Use in Your App

```dart
// Send a message (auto-routes between online/offline)
final chatProvider = context.read<ChatProvider>();
await chatProvider.sendMessage('Patient has fever for 3 days', patientId);

// Or use OfflineAIService directly
final response = await OfflineAIService.instance.generateResponse(
  prompt: 'What should I check for a child with fever?',
  systemPrompt: 'You are a medical assistant.',
);
```

## Folder Structure

```
offline_ai_architecture/
├── README.md                          ← You are here
├── ARCHITECTURE.md                    ← Technical deep-dive
├── models/                            ← Data classes
│   ├── offline_model.dart             ← GGUF model metadata
│   ├── offline_context_params.dart    ← llama.cpp init parameters
│   ├── offline_completion_params.dart ← Generation parameters
│   ├── model_loading_progress.dart    ← Loading state tracking
│   ├── default_offline_models.dart    ← Pre-configured model registry
│   └── chat_message.dart              ← Chat message data class
├── services/                          ← Core business logic
│   ├── offline_ai_service.dart        ← llama.cpp inference engine
│   ├── model_download_service.dart    ← HuggingFace download manager
│   ├── ai_service.dart                ← Online API + safety filters
│   ├── connectivity_service.dart      ← Real internet verification
│   └── symptom_parser.dart            ← Medical symptom NLP
├── providers/                         ← State management
│   ├── offline_model_provider.dart    ← Model lifecycle management
│   └── chat_provider.dart             ← Online↔offline routing
├── screens/                           ← UI components
│   ├── offline_model_download_screen.dart  ← Download management
│   ├── custom_model_picker_dialog.dart     ← GGUF file picker
│   ├── inference_settings_bottom_sheet.dart ← Parameter tuning
│   └── offline_ai_example.dart             ← Integration demo
└── docs/                              ← Documentation & tools
    ├── models_guide.md                ← Model selection guide
    └── download_model_simple.ps1      ← PowerShell download helper
```

## Supported Models

| Model | Size | Quantization | Best For |
|-------|------|-------------|----------|
| **Phi-3.5 Mini** ⭐ | 2.39 GB | Q4_K_M | Medical reasoning, multilingual |
| **MedGemma 4B** | 2.49 GB | Q4_K | Medical QA, high quality |
| **Qwen2.5-1.5B** | 1.89 GB | Q8_0 | Fast inference, low RAM |
| **Llama 3.2 3B** | 2.64 GB | Q6_K | Instructions, reports |
| **SmolLM2-1.7B** | 1.82 GB | Q8_0 | Testing, lightweight |

## Key Features

- **On-device inference** — No internet required after model download
- **Smart routing** — Auto-falls back from online to offline when internet drops
- **Resume downloads** — Partial downloads resume automatically
- **External storage** — Models persist across app updates (Android)
- **Safety filters** — Built-in medical guardrails (never diagnoses, never prescribes)
- **Streaming** — Token-by-token streaming for real-time UI updates
- **Multi-model** — Download and switch between multiple models
- **Custom models** — Load any GGUF file from device storage

## License

This architecture was extracted from the [Augment-CHWs](https://github.com/ogemboeugene/Augment-CHWs) project.
