library denizen_ai;

import 'src/services/offline_ai_service.dart';
import 'src/services/model_download_service.dart';

/// The core entry point for the Denizen AI SDK.
/// Abstracts away complex offline AI tasks like model management, 
/// text generation, and context management.
/// 
/// Note: This is designed as a Singleton. On-device resource limits 
/// (specifically RAM and CPU) prevent multiple offline LLMs from running 
/// concurrently without crashing the host application. Enforcing a single 
/// instance ensures clean lifecycle and resource management.
class DenizenAI {
  static final DenizenAI _instance = DenizenAI._internal();
  
  /// Get the singleton instance of DenizenAI.
  factory DenizenAI() => _instance;

  final OfflineAIService _aiService;
  final ModelDownloadService _downloadService;
  
  /// Access the model manager to download, load, and manage GGUF models.
  final DenizenModelManager models;

  DenizenAI._internal() 
      : _aiService = OfflineAIService.instance,
        _downloadService = ModelDownloadService.instance,
        models = DenizenModelManager(
          ModelDownloadService.instance, 
          OfflineAIService.instance,
        );

  /// Returns true if a model is currently loaded in memory.
  bool get isModelLoaded => _aiService.isModelLoaded;

  /// **UNSTABLE / ADVANCED API**
  /// 
  /// Exposes the underlying [OfflineAIService] for lower-level operations. 
  /// Directly interacting with this service bypasses the safety guarantees 
  /// and orchestrations (such as automated context management) provided by the SDK.
  /// Use with caution.
  OfflineAIService get engine => _aiService;

  // TODO: Add chat(), streamChat(), createSession(), etc.
}

/// Progress data representing an ongoing model download.
class DenizenDownloadProgress {
  /// The fractional progress from `0.0` (start) to `1.0` (complete).
  final double progress;

  /// Number of bytes downloaded so far.
  final int bytesDownloaded;

  /// Total size of the model file in bytes.
  final int totalBytes;

  /// Returns the percentage of download completed (0.0 to 100.0).
  double get percent => progress * 100.0;

  DenizenDownloadProgress({
    required this.progress,
    required this.bytesDownloaded,
    required this.totalBytes,
  });
}

/// Facade for managing models (Downloading, Loading, Eviction)
class DenizenModelManager {
  final ModelDownloadService _downloadService;
  final OfflineAIService _aiService;

  DenizenModelManager(this._downloadService, this._aiService);

  /// Load a model by ID. If it is not present on the device, 
  /// it will automatically download it.
  Future<void> load(String modelId, {
    bool requireWifi = false, 
    void Function(DenizenDownloadProgress progress)? onProgress,
  }) async {
    // TODO: Implement the actual load logic tying download service to AI service
    // 1. Check if model exists locally
    // 2. Download if it doesn't (with progress and wifi checks)
    // 3. Ensure LRU storage eviction happens if quota is exceeded
    // 4. Load the file into the OfflineAIService
  }
}

