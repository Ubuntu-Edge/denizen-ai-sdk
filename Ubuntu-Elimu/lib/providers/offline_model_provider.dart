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
class OfflineModelProvider extends ChangeNotifier {
  List<OfflineModel> _models = [];
  OfflineModel? _activeModel;
  bool _isContextLoading = false;
  bool _isInferencing = false;
  bool _isStreaming = false;
  String? _error;

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
  String? get error => _error;
  OfflineContextParams get contextParams => _contextParams;
  bool get hasActiveModel => _activeModel != null;

  /// Request necessary permissions for offline model loading
  Future<bool> _requestModelLoadingPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.notification.isDenied) {
        final status = await Permission.notification.request();
        return status.isGranted;
      }
    }
    return true;
  }

  /// Initialize - load models from storage
  Future<void> initialize() async {
    try {
      debugPrint('🚀 Initializing OfflineModelProvider...');
      final prefs = await SharedPreferences.getInstance();

      // Load models from storage or defaults
      final modelsJson = prefs.getStringList(_modelsKey) ?? [];
      if (modelsJson.isEmpty) {
        _models = DefaultOfflineModels.getEducationModels();
        debugPrint('✅ Loaded default models');
      } else {
        _models = modelsJson.map((json) => OfflineModel.fromJson(jsonDecode(json))).toList();
        debugPrint('✅ Loaded ${_models.length} models from storage');
      }

      // Auto-detect downloaded models from disk
      await _autoDetectDownloadedModels();

      // Load active model
      final activeModelId = prefs.getString(_activeModelKey);
      if (activeModelId != null) {
        final model = _models.where((m) => m.id == activeModelId).firstOrNull;
        if (model != null && model.isDownloaded) {
          await setActiveModel(model);
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('❌ OfflineModelProvider initialization failed: $e');
      _models = DefaultOfflineModels.getEducationModels();
      notifyListeners();
    }
  }

  /// Set active model (will be loaded for inference)
  Future<void> setActiveModel(OfflineModel model) async {
    _error = null;

    if (!model.isDownloaded) {
      _error = 'Model must be downloaded first.';
      notifyListeners();
      return;
    }

    _activeModel = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeModelKey, model.id);

    _isContextLoading = true;
    notifyListeners();

    try {
      final modelPath = await getModelFullPath(model);
      if (modelPath != null) {
        await _requestModelLoadingPermissions();

        final loaded = await OfflineAIService.instance.loadModel(
          modelPath: modelPath,
          model: model,
        );

        if (!loaded) {
          _error = 'Failed to load model into memory.';
        } else {
          debugPrint('✅ Model loaded: ${model.name}');
        }
      }
    } catch (e) {
      _error = 'Error loading model: $e';
    } finally {
      _isContextLoading = false;
      notifyListeners();
    }
  }

  /// Download a model
  Future<void> downloadModel(OfflineModel model) async {
    _error = null;

    final service = ModelDownloadService.instance;
    final downloadStream = service.downloadModel(
      url: model.downloadUrl ?? '',
      modelId: model.id,
      fileName: model.filename,
      author: model.author,
    );

    downloadStream.listen(
          (progress) async {
        if (progress.error != null) {
          _error = progress.error;
          _updateModelProgress(model.id, 0, false);
        } else if (progress.isCompleted) {
          _updateModelProgress(model.id, 1.0, true, path: progress.filePath);
          await _saveModels();
          debugPrint('✅ Download complete: ${model.name}');
        } else {
          _updateModelProgress(model.id, progress.progress, false);
        }
      },
      onError: (e) {
        _error = 'Download error: $e';
        notifyListeners();
      },
    );
  }

  /// Cancel an in-progress download
  void cancelDownload(String modelId) {
    ModelDownloadService.instance.cancelDownload(modelId);
    _updateModelProgress(modelId, 0, false);
  }

  void _updateModelProgress(String id, double progress, bool downloaded, {String? path}) {
    final index = _models.indexWhere((m) => m.id == id);
    if (index != -1) {
      _models[index] = _models[index].copyWith(
        downloadProgress: progress,
        isDownloaded: downloaded,
        localPath: path,
      );
      notifyListeners();
    }
  }

  Future<String?> getModelFullPath(OfflineModel model) async {
    if (model.localPath != null && await File(model.localPath!).exists()) {
      return model.localPath;
    }

    final storageDir = await _getModelStorageDirectory();
    final path = '${storageDir.path}/models/${model.author}/${model.filename}';
    if (await File(path).exists()) return path;
    return null;
  }

  Future<Directory> _getModelStorageDirectory() async {
    if (Platform.isAndroid) {
      final dir = await getExternalStorageDirectory();
      if (dir != null) return dir;
    }
    return await getApplicationDocumentsDirectory();
  }

  Future<void> _autoDetectDownloadedModels() async {
    bool changed = false;
    for (int i = 0; i < _models.length; i++) {
      final path = await getModelFullPath(_models[i]);
      if (path != null && !_models[i].isDownloaded) {
        _models[i] = _models[i].copyWith(
          isDownloaded: true,
          downloadProgress: 1.0,
          localPath: path,
        );
        changed = true;
      }
    }
    if (changed) await _saveModels();
  }

  Future<void> _saveModels() async {
    final prefs = await SharedPreferences.getInstance();
    final modelsJson = _models.map((m) => jsonEncode(m.toJson())).toList();
    await prefs.setStringList(_modelsKey, modelsJson);
  }

  Future<void> deleteModel(OfflineModel model) async {
    final path = await getModelFullPath(model);
    if (path != null) {
      await ModelDownloadService.instance.deleteModel(path);
      _updateModelProgress(model.id, 0, false, path: null);

      if (_activeModel?.id == model.id) {
        _activeModel = null;
        await OfflineAIService.instance.unloadModel();
      }

      await _saveModels();
    }
  }

  /// Total disk space used by downloaded models, in bytes
  Future<int> getUsedStorageBytes() {
    return ModelDownloadService.instance.getModelsDirectorySize();
  }

  Future<void> clearActiveModel() async {
    await OfflineAIService.instance.unloadModel();
    _activeModel = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeModelKey);
    notifyListeners();
  }
}
