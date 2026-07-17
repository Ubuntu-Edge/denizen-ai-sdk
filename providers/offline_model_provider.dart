import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

import '../models/offline_model.dart';
import '../models/offline_context_params.dart';
import '../models/default_offline_models.dart';
import '../services/model_download_service.dart';
import '../services/offline_ai_service.dart';

/// Provider for managing offline AI models (GGUF models for llama.cpp)
/// Does NOT interfere with online AIService operations
class OfflineModelProvider extends ChangeNotifier {
  List<OfflineModel> _models = [];
  OfflineModel? _activeModel;
  bool _isContextLoading = false;
  bool _isInferencing = false;
  bool _isStreaming = false;
  
  OfflineContextParams _contextParams = const OfflineContextParams();
  
  static const String _modelsKey = 'offline_models';
  static const String _activeModelKey = 'active_offline_model_id';
  static const String _contextParamsKey = 'offline_context_params';

  // Getters
  List<OfflineModel> get models => _models;
  OfflineModel? get activeModel => _activeModel;
  bool get isContextLoading => _isContextLoading;
  bool get isInferencing => _isInferencing;
  bool get isStreaming => _isStreaming;
  OfflineContextParams get contextParams => _contextParams;
  bool get hasActiveModel => _activeModel != null;

  /// Request necessary permissions for offline model loading
  /// Returns true if permissions granted, false otherwise
  Future<bool> _requestModelLoadingPermissions() async {
    debugPrint('🔐 Requesting permissions for offline model loading...');
    
    // Check and request POST_NOTIFICATIONS permission (Android 13+)
    // Required for foreground service notification
    if (await Permission.notification.isDenied) {
      debugPrint('  📢 Requesting POST_NOTIFICATIONS permission');
      final notificationStatus = await Permission.notification.request();
      if (notificationStatus.isDenied || notificationStatus.isPermanentlyDenied) {
        debugPrint('  ❌ POST_NOTIFICATIONS permission denied');
        return false;
      }
    }
    
    debugPrint('  ✅ All permissions granted');
    return true;
  }

  /// Initialize - load models from storage
  Future<void> initialize() async {
    try {
      debugPrint('🚀 Initializing OfflineModelProvider...');
      final prefs = await SharedPreferences.getInstance();

      // Load models from storage
      final modelsJson = prefs.getStringList(_modelsKey) ?? [];
    
    if (modelsJson.isEmpty) {
      // First run: Load default medical models
      _models = DefaultOfflineModels.getMedicalModels();
      debugPrint('✅ First run - Loaded ${_models.length} default medical models');
    } else {
      // Load saved models
      _models = modelsJson.map((json) => OfflineModel.fromJson(jsonDecode(json))).toList();
      debugPrint('✅ Loaded ${_models.length} models from SharedPreferences');
    }

    // Auto-detect downloaded models from disk (even after reinstall/update)
    await _autoDetectDownloadedModels();

    // Load context params
    final contextParamsJson = prefs.getString(_contextParamsKey);
    if (contextParamsJson != null) {
      _contextParams = OfflineContextParams.fromJson(jsonDecode(contextParamsJson));
    }

    // Auto-detect downloaded models from disk (even after reinstall/update)
    await _autoDetectDownloadedModels();

    // Load active model
    final activeModelId = prefs.getString(_activeModelKey);
    if (activeModelId != null) {
      _activeModel = _models.where((m) => m.id == activeModelId).firstOrNull;
      
      // Check if user has chosen to use offline mode
      // Only auto-load if user's preference is offline or not set (first time)
      final savedAiMode = prefs.getString('chat_ai_mode');
      final shouldAutoLoad = savedAiMode == null || savedAiMode == 'offline';
      
      // Auto-load active model into OfflineAIService (with permission check)
      // Only if user prefers offline mode
      if (_activeModel != null && _activeModel!.isDownloaded && shouldAutoLoad) {
        final modelPath = await getModelFullPath(_activeModel!);
        if (modelPath != null) {
          debugPrint('🔄 Auto-loading active model: ${_activeModel!.name}');
          debugPrint('   User AI mode preference: ${savedAiMode ?? "not set (defaulting to load)"}');
          
          // Request permissions before loading
          final hasPermissions = await _requestModelLoadingPermissions();
          if (!hasPermissions) {
            debugPrint('⚠️ Permissions denied - skipping auto-load. User can manually load model.');
          } else {
            final loaded = await OfflineAIService.instance.loadModel(
              modelPath: modelPath,
              model: _activeModel!,
              contextParams: _contextParams,
            );
            if (loaded) {
              debugPrint('✅ Active model loaded into OfflineAIService');
            } else {
              debugPrint('❌ Failed to load active model into OfflineAIService');
            }
          }
        }
      } else if (_activeModel != null && !shouldAutoLoad) {
        debugPrint('ℹ️ User prefers online mode - skipping auto-load of model');
        debugPrint('   Model "${_activeModel!.name}" is downloaded but not loaded');
      }
    }

    // Check which models are actually downloaded
    await _refreshDownloadStatuses();

    notifyListeners();
    } catch (e) {
      debugPrint('❌ OfflineModelProvider initialization failed: $e');
      // Load default models anyway so the UI can still function
      _models = DefaultOfflineModels.getMedicalModels();
      notifyListeners();
    }
  }

  /// Add a new model to the list
  Future<void> addModel(OfflineModel model) async {
    _models.add(model);
    await _saveModels();
    notifyListeners();
  }

  /// Update an existing model
  Future<void> updateModel(OfflineModel model) async {
    final index = _models.indexWhere((m) => m.id == model.id);
    if (index != -1) {
      _models[index] = model;
      if (_activeModel?.id == model.id) {
        _activeModel = model;
      }
      await _saveModels();
      notifyListeners();
    }
  }

  /// Remove a model
  Future<void> removeModel(String modelId) async {
    _models.removeWhere((m) => m.id == modelId);
    if (_activeModel?.id == modelId) {
      _activeModel = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeModelKey);
    }
    await _saveModels();
    notifyListeners();
  }

  /// Set active model (will be loaded for inference)
  Future<void> setActiveModel(OfflineModel model) async {
    _activeModel = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeModelKey, model.id);
    
    // Load model into OfflineAIService for actual inference
    if (model.isDownloaded) {
      final modelPath = await getModelFullPath(model);
      if (modelPath != null) {
        // Verify file actually exists
        final file = File(modelPath);
        if (!await file.exists()) {
          debugPrint('❌ Model file not found: $modelPath');
          _isContextLoading = false;
          notifyListeners();
          return;
        }
        
        // Request permissions before loading model
        final hasPermissions = await _requestModelLoadingPermissions();
        if (!hasPermissions) {
          debugPrint('❌ Permissions denied - cannot load model');
          _isContextLoading = false;
          notifyListeners();
          throw Exception('Permission denied: POST_NOTIFICATIONS required for offline AI models');
        }
        
        // Verify file size (should be at least 100MB for valid GGUF model)
        final fileSize = await file.length();
        if (fileSize < 100 * 1024 * 1024) {
          debugPrint('❌ Model file too small ($fileSize bytes): $modelPath');
          debugPrint('   File may be corrupted. Please re-download.');
          _isContextLoading = false;
          notifyListeners();
          return;
        }
        
        debugPrint('🔄 Loading model into OfflineAIService: ${model.name}');
        debugPrint('   Path: $modelPath');
        debugPrint('   Size: ${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB');
        
        _isContextLoading = true;
        notifyListeners();
        
        try {
          final loaded = await OfflineAIService.instance.loadModel(
            modelPath: modelPath,
            model: model,
            contextParams: _contextParams,
          );
          
          _isContextLoading = false;
          
          if (loaded) {
            debugPrint('✅ Model loaded and ready for inference');
          } else {
            debugPrint('❌ Failed to load model into OfflineAIService');
            debugPrint('   Possible causes:');
            debugPrint('   - Corrupted model file (try re-downloading)');
            debugPrint('   - Insufficient device memory');
            debugPrint('   - Incompatible model format');
          }
        } catch (e, stackTrace) {
          debugPrint('❌ Exception loading model: $e');
          debugPrint('Stack trace: $stackTrace');
          _isContextLoading = false;
        }
      }
    }
    
    notifyListeners();
  }

  /// Update context parameters
  Future<void> updateContextParams(OfflineContextParams params) async {
    _contextParams = params;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_contextParamsKey, jsonEncode(params.toJson()));
    notifyListeners();
  }

  /// Get the best storage directory for models (external on Android)
  Future<Directory> _getModelStorageDirectory() async {
    if (Platform.isAndroid) {
      try {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          return externalDir;
        }
      } catch (e) {
        debugPrint('⚠️ External storage not available: $e');
      }
    }
    return await getApplicationDocumentsDirectory();
  }

  /// Get model file path
  Future<String?> getModelFullPath(OfflineModel model) async {
    // Check if model has a custom local path
    if (model.localPath != null && model.localPath!.isNotEmpty) {
      return model.localPath;
    }

    // Otherwise, use default path in storage directory
    if (model.filename == null) return null;
    
    final storageDir = await _getModelStorageDirectory();
    return '${storageDir.path}/models/${model.author}/${model.filename}';
  }

  /// Check if model file exists on disk
  Future<bool> isModelDownloaded(OfflineModel model) async {
    final filePath = await getModelFullPath(model);
    if (filePath == null) {
      debugPrint('  ⚠️ ${model.name}: No file path available');
      return false;
    }
    
    final file = File(filePath);
    final exists = await file.exists();
    if (exists) {
      final sizeBytes = await file.length();
      final sizeMB = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
      debugPrint('  📁 ${model.name}: Found at $filePath ($sizeMB MB)');
    } else {
      debugPrint('  ❌ ${model.name}: Not found at $filePath');
    }
    return exists;
  }

  /// Auto-detect downloaded models from filesystem (survives app updates/reinstalls)
  Future<void> _autoDetectDownloadedModels() async {
    debugPrint('🔍 Auto-detecting downloaded models from filesystem...');
    
    try {
      final storageDir = await _getModelStorageDirectory();
      final modelsDir = Directory('${storageDir.path}/models');
      
      if (!await modelsDir.exists()) {
        debugPrint('  📁 Models directory does not exist yet');
        return;
      }

      // Scan for .gguf files
      final ggufFiles = <File>[];
      await for (final entity in modelsDir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.gguf')) {
          ggufFiles.add(entity);
        }
      }

      debugPrint('  📦 Found ${ggufFiles.length} .gguf files on disk');

      // Match files to models
      for (final file in ggufFiles) {
        final fileName = file.path.split(Platform.pathSeparator).last;
        
        // Find matching model by filename
        for (int i = 0; i < _models.length; i++) {
          if (_models[i].filename == fileName) {
            final fileSize = await file.length();
            final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(1);
            
            debugPrint('  ✅ Matched: ${_models[i].name} ($fileSizeMB MB)');
            
            _models[i] = _models[i].copyWith(
              isDownloaded: true,
              downloadProgress: 100.0,
              localPath: file.path,
            );
            break;
          }
        }
      }

      // Save updated model states
      await _saveModels();
      debugPrint('💾 Auto-detection complete - saved updated model states');
    } catch (e) {
      debugPrint('❌ Error auto-detecting models: $e');
    }
  }

  /// Refresh download statuses for all models
  Future<void> _refreshDownloadStatuses() async {
    debugPrint('🔍 Checking actual download status for ${_models.length} models...');
    bool anyChanged = false;
    
    for (int i = 0; i < _models.length; i++) {
      final isDownloaded = await isModelDownloaded(_models[i]);
      if (_models[i].isDownloaded != isDownloaded) {
        debugPrint('  🔄 ${_models[i].name}: ${_models[i].isDownloaded} → $isDownloaded');
        _models[i] = _models[i].copyWith(isDownloaded: isDownloaded);
        anyChanged = true;
      } else {
        debugPrint('  ✅ ${_models[i].name}: downloaded=$isDownloaded');
      }
    }
    
    // Save updated statuses to SharedPreferences
    if (anyChanged) {
      debugPrint('💾 Saving updated model statuses to SharedPreferences');
      await _saveModels();
    }
  }

  /// Refresh download statuses (public method)
  Future<void> refreshDownloadStatuses() async {
    await _refreshDownloadStatuses();
    await _saveModels();
    notifyListeners();
  }

  /// Update model download progress
  void updateModelProgress(String modelId, double progress) {
    final index = _models.indexWhere((m) => m.id == modelId);
    if (index != -1) {
      _models[index] = _models[index].copyWith(downloadProgress: progress);
      notifyListeners();
    }
  }

  /// Mark model as downloaded
  Future<void> markModelAsDownloaded(String modelId, String localPath) async {
    debugPrint('🎯 Marking model as downloaded: $modelId at $localPath');
    final index = _models.indexWhere((m) => m.id == modelId);
    if (index != -1) {
      _models[index] = _models[index].copyWith(
        isDownloaded: true,
        downloadProgress: 100.0,
        localPath: localPath,
      );
      await _saveModels();
      debugPrint('✅ Model marked as downloaded and saved');
      notifyListeners();
    } else {
      debugPrint('❌ Model not found in list: $modelId');
    }
  }

  /// Set loading state
  void setIsContextLoading(bool value) {
    _isContextLoading = value;
    notifyListeners();
  }

  /// Set inferencing state
  void setIsInferencing(bool value) {
    _isInferencing = value;
    notifyListeners();
  }

  /// Set streaming state
  void setIsStreaming(bool value) {
    _isStreaming = value;
    notifyListeners();
  }

  /// Save models to storage
  Future<void> _saveModels() async {
    final prefs = await SharedPreferences.getInstance();
    final modelsJson = _models.map((m) => jsonEncode(m.toJson())).toList();
    await prefs.setStringList(_modelsKey, modelsJson);
    debugPrint('💾 Saved ${_models.length} models to SharedPreferences');
  }

  /// Clear active model (release from memory)
  Future<void> clearActiveModel() async {
    // Unload from OfflineAIService
    if (OfflineAIService.instance.isModelLoaded) {
      debugPrint('🔄 Unloading model from OfflineAIService');
      await OfflineAIService.instance.unloadModel();
    }
    
    _activeModel = null;
    _isContextLoading = false;
    _isInferencing = false;
    _isStreaming = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeModelKey);
    notifyListeners();
  }

  /// Download a model from HuggingFace
  Stream<ModelDownloadProgress> downloadModel(OfflineModel model) {
    final downloadService = ModelDownloadService.instance;
    return downloadService.downloadModel(
      url: model.downloadUrl ?? '',
      modelId: model.id,
      fileName: model.filename ?? '${model.name}.gguf',
      author: model.author,
      useCompression: true,
    );
  }

  /// Delete a downloaded model
  Future<bool> deleteModel(OfflineModel model) async {
    if (model.localPath == null) return false;
    
    final downloadService = ModelDownloadService.instance;
    final success = await downloadService.deleteModel(model.localPath!);
    
    if (success) {
      // Update model in list
      await updateModel(model.copyWith(
        isDownloaded: false,
        localPath: null,
        downloadProgress: 0,
      ));
      
      // Clear active model if it was the deleted one
      if (_activeModel?.id == model.id) {
        await clearActiveModel();
      }
    }
    
    return success;
  }

  /// Get available storage in bytes
  Future<int> getAvailableStorage() async {
    final downloadService = ModelDownloadService.instance;
    return await downloadService.getAvailableStorageBytes();
  }

  /// Get total size of downloaded models in bytes
  Future<int> getUsedStorage() async {
    final downloadService = ModelDownloadService.instance;
    return await downloadService.getModelsDirectorySize();
  }

  /// Check if enough storage is available for a model
  Future<bool> hasEnoughStorage(OfflineModel model) async {
    final downloadService = ModelDownloadService.instance;
    final requiredBytes = (model.sizeMB * 1024 * 1024).toInt();
    return await downloadService.hasEnoughStorage(requiredBytes);
  }
}
