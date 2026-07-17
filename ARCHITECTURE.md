# Offline AI Architecture — Technical Deep-Dive

This document explains the internal workings of the offline AI architecture so developers can understand, extend, and integrate it.

## Data Flow

The complete lifecycle of an offline AI interaction follows this pipeline:

```
 User Query
     │
     ▼
┌─────────────────┐     ┌─────────────────────────────────┐
│  ChatProvider    │────▶│ Smart Routing Decision           │
│  (Orchestrator)  │     │ 1. Is mode == offline?           │
└─────────────────┘     │ 2. Is offline model loaded?      │
                         │ 3. Is internet available?         │
                         │ 4. Can we fall back?             │
                         └───────────┬─────────────────────┘
                                     │
                    ┌────────────────┼────────────────┐
                    ▼                                 ▼
           ┌──────────────┐                  ┌──────────────┐
           │ Online Path   │                  │ Offline Path  │
           │ (AIService)   │                  │(OfflineAI)    │
           └───────┬──────┘                  └───────┬──────┘
                   │                                 │
                   ▼                                 ▼
           ┌──────────────┐                  ┌──────────────┐
           │ HuggingFace  │                  │ llama.cpp    │
           │ API Call      │                  │ Inference     │
           │ (medgemma-4b) │                  │ (local GGUF)  │
           └───────┬──────┘                  └───────┬──────┘
                   │                                 │
                   ▼                                 ▼
           ┌──────────────┐                  ┌──────────────┐
           │ _cleanResponse│                  │ Raw token     │
           │ _reformatTo   │                  │ stream to UI  │
           │   Sections    │                  └───────┬──────┘
           │ _applySafety  │                          │
           │   Filter      │                          ▼
           └───────┬──────┘                  ┌──────────────┐
                   │                          │ processOffline│
                   │                          │   Response    │
                   │                          │ (same safety  │
                   │                          │  pipeline)    │
                   ▼                          └───────┬──────┘
           ┌──────────────┐                          │
           │ Final Safe    │◀─────────────────────────┘
           │ Response      │
           └──────────────┘
```

## Smart Routing Logic

The `ChatProvider.sendMessage()` method implements intelligent routing:

```
if mode == ONLINE:
    if internet available:
        try online API
        on failure (network error) AND offline model loaded:
            fall back to offline  ← Smart fallback
        on failure (other error):
            show error
    else if offline model loaded:
        use offline  ← Auto-switch
    else:
        show "no internet, no model" error

if mode == OFFLINE:
    if offline model loaded:
        use offline
    else:
        show "download a model" guidance
```

Key design decisions:
- **User controls the mode** — no auto-switching from offline→online
- **Smart fallback only** — online→offline fallback is automatic when network fails
- **Mode persisted** — user's choice survives app restart via SharedPreferences

## Model Download Pipeline

```
downloadModel(url, modelId, fileName)
     │
     ▼
 Check for compressed version (.gguf.gz)
     │
     ├── Found → download compressed
     └── Not found → download original
     │
     ▼
 Check for partial download (resume support)
     │
     ├── Partial exists → add Range header
     └── No partial → start from 0
     │
     ▼
 Stream download with progress tracking
     │
     ▼
 If compressed → extract gzip with progress
     │
     ▼
 Verify file integrity (size check)
     │
     ▼
 Report completion with local path
```

### Storage Strategy

```dart
// Android: External storage (survives app updates)
getExternalStorageDirectory()
  → /storage/emulated/0/Android/data/com.app/files/models/

// Fallback: Internal storage
getApplicationDocumentsDirectory()
  → /data/data/com.app/app_flutter/models/
```

Why external storage? Large GGUF models (1-3 GB) shouldn't need re-downloading when the app updates. External storage persists across updates while internal storage may be cleared.

## Safety Filter Pipeline

The `AIService` implements a 3-stage safety pipeline that processes both online and offline responses:

### Stage 1: `_cleanResponse(raw)`
- Strips markdown formatting (asterisks, hashtags, brackets)
- Normalizes whitespace
- Converts bullet points to dashes

### Stage 2: `_reformatToSections(cleaned)`
Enforces a strict 3-section format:
```
Assessment: [1-2 sentences, no diagnosis]
Action:
- [first action]
- [second action]
Important: [when to seek professional care]
```

Parsing logic:
1. Skip intro fluff ("Okay, I understand...", "Here's what...")
2. Extract bullet points as Action items
3. Detect closing "seek doctor" sentences as Important
4. Provide safe defaults if sections are missing

### Stage 3: `_applySafetyFilter(structured)`
Scans for blocked medical terms:
- Drug names: `amoxicillin`, `ibuprofen`, `paracetamol`
- Diagnostic terms: `cancer`, `HIV`, `tuberculosis`
- Dangerous advice: `rush to hospital`, `emergency`

If any trigger is found, replaces entire response with a safe fallback message.

## Device-Adaptive Configuration

The `OfflineContextParams` class provides presets for different device capabilities:

| Parameter | Low-End (<4GB) | Mid-Range (4-8GB) | High-End (8GB+) |
|-----------|---------------|-------------------|-----------------|
| Context | 1024 tokens | 2048 tokens | 4096 tokens |
| Threads | 2 | 4 | 6 |
| Batch Size | 128 | 256 | 512 |
| GPU Layers | 0 | 20 | 99 |

## Model Auto-Detection

When `OfflineModelProvider.initialize()` runs, it performs filesystem scanning:

1. Get storage directory (external → internal fallback)
2. Recursively list all `.gguf` files
3. Match filenames against known models in `DefaultOfflineModels`
4. Update model state (`isDownloaded`, `localPath`)
5. Persist updated state to SharedPreferences

This means models survive:
- App updates (external storage)
- SharedPreferences wipe (re-detected from disk)
- App reinstall (if external storage not cleared)

## Extension Points

### Adding New Models

Edit `default_offline_models.dart`:

```dart
OfflineModel(
  id: 'your-model-id',
  name: 'Your Model Name',
  author: 'Author',
  size: 2000000000, // bytes
  downloadUrl: 'https://huggingface.co/.../resolve/main/model.gguf',
  filename: 'model.gguf',
  quantization: 'Q4_K_M',
  description: 'What this model is good at',
  tags: ['medical', 'your-tag'],
  contextSize: 4096,
),
```

### Custom Prompt Templates

The `OfflineAIService.formatChatPrompt()` method generates ChatML format:

```
<|im_start|>system
Your system prompt here
<|im_end|>
<|im_start|>user
User message
<|im_end|>
<|im_start|>assistant
```

Override this for models that use different chat templates (e.g., Llama uses `[INST]...[/INST]`).

### Custom Safety Rules

Modify `_applySafetyFilter()` in `ai_service.dart` to add/remove blocked terms.
Modify `_reformatToSections()` to change the output structure.

### Adding Persistence

The `ChatProvider` has `// TODO:` comments where database calls should go. Plug in your own:
- SQLite via `drift` or `sqflite`
- Hive for key-value storage
- Firebase for cloud sync

### Adding New Languages

The `AIService._detectLanguage()` method currently supports English and Kiswahili. Add new languages by:
1. Adding word lists to the detection method
2. Adding system prompt translations in `_buildMessages()`
3. Adding safety filter fallback messages

## Dependencies Graph

```
llama_flutter_android (native plugin)
  └── OfflineAIService
        └── OfflineModelProvider
              └── ChatProvider → UI

connectivity_plus (platform plugin)
  └── ConnectivityService
        └── ChatProvider → UI

http (Dart package)
  ├── AIService (online API)
  └── ModelDownloadService (downloads)

shared_preferences (platform plugin)
  ├── OfflineModelProvider (model state)
  ├── ChatProvider (mode persistence)
  └── ModelDownloadService (download state)

provider (Dart package)
  └── All UI screens

path_provider (platform plugin)
  ├── OfflineModelProvider (model paths)
  └── ModelDownloadService (storage dir)
```

## Performance Notes

- **Model loading**: 5-30 seconds depending on model size and device
- **Token generation**: 4-15 tokens/second on mid-range Android
- **Memory usage**: Model size + ~500MB overhead
- **Download**: Support for resume, but no parallel downloads
- **Storage**: External storage preferred (survives updates)
