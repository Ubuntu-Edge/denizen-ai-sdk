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

import 'dart:io';
import 'src/models/offline_model.dart';
import 'src/models/default_offline_models.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Exception thrown when the device is out of storage space and eviction fails.
class StorageQuotaException implements Exception {
  final String message;
  StorageQuotaException(this.message);
  @override
  String toString() => 'StorageQuotaException: $message';
}

/// Exception thrown when network constraints are violated.
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  @override
  String toString() => 'NetworkException: $message';
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

  /// Look up model from recommendations
  OfflineModel? _lookUpModel(String modelId) {
    try {
      final recommended = DefaultOfflineModels.getMedicalModels();
      return recommended.firstWhere((m) => m.id == modelId);
    } catch (_) {
      return null;
    }
  }

  /// Perform LRU storage eviction to reclaim space.
  Future<void> _performLRUEviction(int requiredBytes, {required String excludingModelId}) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get all downloaded model paths
    final List<String> downloadedPaths = await _downloadService.getDownloadedModelPaths();
    if (downloadedPaths.isEmpty) return;

    final List<OfflineModel> recommendedModels = DefaultOfflineModels.getMedicalModels();
    final List<String> residentModels = prefs.getStringList('denizen_resident_models') ?? [];

    // Find models we can evict
    final List<Map<String, dynamic>> evictableCandidates = [];
    
    for (final path in downloadedPaths) {
      final file = File(path);
      final filename = file.uri.pathSegments.last;
      
      // Look up matching recommended model
      OfflineModel? matchingModel;
      try {
        matchingModel = recommendedModels.firstWhere((m) => m.filename == filename);
      } catch (_) {}
      
      final id = matchingModel?.id ?? filename;
      
      // Skip if this is the model we are trying to load right now
      if (id == excludingModelId) continue;
      
      // Skip if marked as resident
      if (residentModels.contains(id)) continue;
      
      // Skip if it is currently loaded/active in memory
      if (_aiService.isModelLoaded && _aiService.loadedModelPath == path) continue;
      
      // Get last accessed timestamp (default to 0 if not set)
      final lastAccessed = prefs.getInt('denizen_last_accessed_$id') ?? 0;
      
      evictableCandidates.add({
        'path': path,
        'id': id,
        'lastAccessed': lastAccessed,
        'size': await file.length(),
      });
    }

    // Sort by last accessed timestamp ascending (oldest first)
    evictableCandidates.sort((a, b) => (a['lastAccessed'] as int).compareTo(b['lastAccessed'] as int));

    // Evict models until we have enough space
    for (final candidate in evictableCandidates) {
      final available = await _downloadService.getAvailableStorageBytes();
      final buffer = 500 * 1024 * 1024; // 500MB safety buffer
      if (available > (requiredBytes + buffer)) {
        break; // We have enough space now!
      }
      
      final path = candidate['path'] as String;
      final id = candidate['id'] as String;
      final size = candidate['size'] as int;
      
      debugPrint('🗑️ Storage Eviction: Deleting model $id ($path) to free up ${(size / (1024 * 1024)).toStringAsFixed(1)} MB');
      await _downloadService.deleteModel(path);
      
      // Clean up pref timestamp
      await prefs.remove('denizen_last_accessed_$id');
    }
  }

  /// Load a model by ID. If it is not present on the device, 
  /// it will automatically download it.
  Future<void> load(String modelId, {
    bool requireWifi = false, 
    void Function(DenizenDownloadProgress progress)? onProgress,
    bool requireResidency = false,
  }) async {
    // 1. Look up the model definition
    final OfflineModel? model = _lookUpModel(modelId);
    if (model == null) {
      throw ArgumentError('Model not found in recommendations: $modelId');
    }

    final prefs = await SharedPreferences.getInstance();

    // Track residency configuration persistently
    final List<String> residentModels = prefs.getStringList('denizen_resident_models') ?? [];
    if (requireResidency) {
      if (!residentModels.contains(modelId)) {
        residentModels.add(modelId);
        await prefs.setStringList('denizen_resident_models', residentModels);
      }
    } else {
      if (residentModels.contains(modelId)) {
        residentModels.remove(modelId);
        await prefs.setStringList('denizen_resident_models', residentModels);
      }
    }

    // 2. Determine paths
    final storageDir = await _downloadService.getModelStorageDirectory();
    final modelDir = Directory('${storageDir.path}/models/${model.author}');
    final finalFile = File('${modelDir.path}/${model.filename}');

    // 3. Update last accessed timestamp
    await prefs.setInt('denizen_last_accessed_$modelId', DateTime.now().millisecondsSinceEpoch);

    // 4. Check if file already exists locally
    final bool exists = await finalFile.exists() && (await finalFile.length()) > 1024 * 1024;
    
    if (!exists) {
      // 5. Handle Storage/Eviction logic before download
      final int requiredBytes = model.size;
      final bool hasSpace = await _downloadService.hasEnoughStorage(requiredBytes);
      
      if (!hasSpace) {
        // Run LRU Eviction
        await _performLRUEviction(requiredBytes, excludingModelId: modelId);
      }

      // Check space again
      final bool hasSpacePostEviction = await _downloadService.hasEnoughStorage(requiredBytes);
      if (!hasSpacePostEviction) {
        throw StorageQuotaException('Insufficient storage space to download model $modelId (${model.sizeGB.toStringAsFixed(1)} GB required). Eviction could not reclaim enough space because other cached models are marked as resident.');
      }

      // 6. Gated Download based on wifi if required
      if (requireWifi) {
        final connectivityResult = await Connectivity().checkConnectivity();
        if (!connectivityResult.contains(ConnectivityResult.wifi)) {
          throw NetworkException('Wifi connection required to download model, but current connection is not Wifi.');
        }
      }

      // 7. Perform the download and map progress
      final downloadStream = _downloadService.downloadModel(
        url: model.downloadUrl ?? '',
        modelId: modelId,
        fileName: model.filename ?? '',
        author: model.author,
      );

      await for (final downloadProgress in downloadStream) {
        if (downloadProgress.stage == ModelDownloadStage.failed) {
          throw Exception('Download failed: ${downloadProgress.error}');
        }
        
        if (onProgress != null) {
          // Translate to DenizenDownloadProgress
          final progressPercent = downloadProgress.progress / 100.0;
          onProgress(DenizenDownloadProgress(
            progress: progressPercent,
            bytesDownloaded: downloadProgress.downloadedBytes ?? 0,
            totalBytes: downloadProgress.totalBytes ?? model.size,
          ));
        }
      }
    }

    // 8. Load the model into OfflineAIService
    final bool loadSuccess = await _aiService.loadModel(
      modelPath: finalFile.path,
      model: model,
    );

    if (!loadSuccess) {
      throw Exception('Failed to load model into inference engine.');
    }
  }
}


