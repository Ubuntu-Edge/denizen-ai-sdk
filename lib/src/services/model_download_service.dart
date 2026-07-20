import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for downloading AI models with compression support and progress tracking
/// Handles multiple models, automatic extraction, and storage management
class ModelDownloadService {
  static final ModelDownloadService instance = ModelDownloadService._init();
  ModelDownloadService._init();

  // Active downloads tracking
  final Map<String, StreamController<ModelDownloadProgress>> _activeDownloads = {};
  final Map<String, http.Client> _downloadClients = {};
  static const String _activeDownloadsKey = 'active_downloads';

  /// Save active downloads to SharedPreferences for persistence
  Future<void> _saveActiveDownloads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeIds = _activeDownloads.keys.toList();
      await prefs.setStringList(_activeDownloadsKey, activeIds);
    } catch (e) {
      debugPrint('⚠️ Failed to save active downloads: $e');
    }
  }

  /// Get list of active downloads from SharedPreferences
  Future<List<String>> getActiveDownloads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_activeDownloadsKey) ?? [];
    } catch (e) {
      debugPrint('⚠️ Failed to load active downloads: $e');
      return [];
    }
  }

  /// Clear active download from SharedPreferences
  Future<void> _clearActiveDownload(String modelId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeIds = prefs.getStringList(_activeDownloadsKey) ?? [];
      activeIds.remove(modelId);
      await prefs.setStringList(_activeDownloadsKey, activeIds);
    } catch (e) {
      debugPrint('⚠️ Failed to clear active download: $e');
    }
  }

  /// Get the best storage directory for models
  /// Uses external storage on Android (persists across app updates)
  /// Falls back to internal storage if external is not available
  Future<Directory> getModelStorageDirectory() async {
    if (Platform.isAndroid) {
      try {
        // Try external storage first (persists across app updates)
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          debugPrint('📁 Using external storage: ${externalDir.path}');
          return externalDir;
        }
      } catch (e) {
        debugPrint('⚠️ External storage not available: $e');
      }
    }
    // Fall back to app documents directory
    final appDir = await getApplicationDocumentsDirectory();
    debugPrint('📁 Using internal storage: ${appDir.path}');
    return appDir;
  }

  /// Download a model from URL with progress tracking
  /// Supports both compressed (.gguf.gz) and uncompressed (.gguf) files
  /// Returns a stream of progress updates
  Stream<ModelDownloadProgress> downloadModel({
    required String url,
    required String modelId,
    required String fileName,
    required String author,
    bool useCompression = true,
  }) async* {
    // Create progress stream
    final progressController = StreamController<ModelDownloadProgress>();
    _activeDownloads[modelId] = progressController;    await _saveActiveDownloads(); // Persist download state
    try {
      // Get storage directory (external on Android for persistence across updates)
      final storageDir = await getModelStorageDirectory();
      final modelDir = Directory('${storageDir.path}/models/$author');
      await modelDir.create(recursive: true);
      
      debugPrint('📥 Starting download for $modelId');
      debugPrint('   URL: $url');
      debugPrint('   Author: $author');
      debugPrint('   Filename: $fileName');
      debugPrint('   Save dir: ${modelDir.path}');

      // Determine download URL (prefer compressed if available)
      String downloadUrl = url;
      String tempFileName = fileName;
      bool isCompressed = false;

      if (useCompression && !url.endsWith('.gz')) {
        // Try compressed version first (HuggingFace often has .gz versions)
        final compressedUrl = '$url.gz';
        try {
          final testResponse = await http.head(Uri.parse(compressedUrl));
          if (testResponse.statusCode == 200) {
            downloadUrl = compressedUrl;
            tempFileName = '$fileName.gz';
            isCompressed = true;
            debugPrint('✅ Found compressed version: $compressedUrl');
          }
        } catch (e) {
          debugPrint('⚠️ No compressed version available, using original');
        }
      } else if (url.endsWith('.gz')) {
        isCompressed = true;
        tempFileName = fileName;
      }

      final tempFile = File('${modelDir.path}/$tempFileName.tmp');
      final finalFile = File('${modelDir.path}/$fileName');

      // Check for partial download to resume
      int startByte = 0;
      if (await tempFile.exists()) {
        startByte = await tempFile.length();
        debugPrint('🔄 Resuming download from byte $startByte');
      }

      // Check if already downloaded
      if (await finalFile.exists()) {
        final fileSize = await finalFile.length();
        debugPrint('🔍 Found existing file: ${finalFile.path}');
        debugPrint('   Size: ${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB');
        
        if (fileSize > 1024 * 1024) {
          // File exists and is valid
          debugPrint('✅ File already downloaded, skipping download');
          yield ModelDownloadProgress(
            modelId: modelId,
            stage: ModelDownloadStage.completed,
            progress: 100,
            localPath: finalFile.path,
          );
          await progressController.close();
          _activeDownloads.remove(modelId);
          return;
        } else {
          debugPrint('⚠️ Existing file too small, will re-download');
          await finalFile.delete();
        }
      }

      // Start download
      final client = http.Client();
      _downloadClients[modelId] = client;

      final request = http.Request('GET', Uri.parse(downloadUrl));
      // Add Range header for resume support
      if (startByte > 0) {
        request.headers['Range'] = 'bytes=$startByte-';
      }
      final response = await client.send(request);

      if (response.statusCode != 200 && response.statusCode != 206) {
        debugPrint('❌ HTTP Error: ${response.statusCode}');
        throw Exception('Download failed with status ${response.statusCode}. Please check your internet connection and try again.');
      }

      final totalBytes = (response.contentLength ?? 0) + startByte;
      int receivedBytes = startByte;
      final sink = tempFile.openWrite(mode: FileMode.append);

      // Track download progress
      await for (final chunk in response.stream) {
        if (!_activeDownloads.containsKey(modelId)) {
          // Download was cancelled
          await sink.close();
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
          client.close();
          return;
        }

        sink.add(chunk);
        receivedBytes += chunk.length;

        final progress = totalBytes > 0 ? (receivedBytes / totalBytes) * 100 : 0;
        final progressData = ModelDownloadProgress(
          modelId: modelId,
          stage: ModelDownloadStage.downloading,
          progress: progress.toDouble(),
          downloadedBytes: receivedBytes,
          totalBytes: totalBytes,
        );
        
        progressController.add(progressData);
        yield progressData;
      }

      await sink.close();
      client.close();
      _downloadClients.remove(modelId);

      // Extract if compressed
      if (isCompressed) {
        final extractingProgress = ModelDownloadProgress(
          modelId: modelId,
          stage: ModelDownloadStage.extracting,
          progress: 0,
        );
        progressController.add(extractingProgress);
        yield extractingProgress;

        await _extractGzip(tempFile, finalFile, (progress) {
          final extractProgress = ModelDownloadProgress(
            modelId: modelId,
            stage: ModelDownloadStage.extracting,
            progress: progress,
          );
          progressController.add(extractProgress);
        });

        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } else {
        // Just rename temp file
        // On Windows, rename can fail if the file was just closed due to AV or OS locks.
        try {
          await tempFile.rename(finalFile.path);
        } catch (e) {
          debugPrint('Rename failed, attempting copy and delete: $e');
          await Future.delayed(const Duration(milliseconds: 500));
          await tempFile.copy(finalFile.path);
          await tempFile.delete();
        }
      }

      // Verify file
      final verifyingProgress = ModelDownloadProgress(
        modelId: modelId,
        stage: ModelDownloadStage.verifying,
        progress: 100,
      );
      progressController.add(verifyingProgress);
      yield verifyingProgress;

      final fileExists = await finalFile.exists();
      final fileSize = await finalFile.length();

      if (!fileExists || fileSize < 1024 * 1024) {
        throw Exception('Downloaded file is invalid or too small');
      }

      // Complete
      final completeProgress = ModelDownloadProgress(
        modelId: modelId,
        stage: ModelDownloadStage.completed,
        progress: 100,
        localPath: finalFile.path,
      );
      progressController.add(completeProgress);
      yield completeProgress;

      // Clear from active downloads
      await _clearActiveDownload(modelId);

      debugPrint('✅ Model downloaded: ${finalFile.path} (${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB)');
    } catch (e, stackTrace) {
      debugPrint('❌ Download failed: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Provide user-friendly error message
      String userMessage = 'Download failed';
      if (e.toString().contains('SocketException') || e.toString().contains('Connection')) {
        userMessage = 'Network error: Please check your internet connection';
      } else if (e.toString().contains('TimeoutException')) {
        userMessage = 'Download timeout: Please try again';
      } else if (e.toString().contains('Space') || e.toString().contains('storage')) {
        userMessage = 'Insufficient storage space';
      } else {
        userMessage = 'Download failed: ${e.toString()}';
      }
      
      final failedProgress = ModelDownloadProgress(
        modelId: modelId,
        stage: ModelDownloadStage.failed,
        progress: 0,
        error: userMessage,
      );
      progressController.add(failedProgress);
      yield failedProgress;
    } finally {
      await progressController.close();
      _activeDownloads.remove(modelId);
      await _clearActiveDownload(modelId); // Clean up persistent state
    }
  }

  /// Extract gzip compressed file with progress tracking
  Future<void> _extractGzip(
    File compressedFile,
    File outputFile,
    Function(double) onProgress,
  ) async {
    final inputStream = compressedFile.openRead();
    final decompressedStream = inputStream.transform(gzip.decoder);
    final outputSink = outputFile.openWrite();

    int processedBytes = 0;
    final totalBytes = await compressedFile.length();

    await for (final chunk in decompressedStream) {
      outputSink.add(chunk);
      processedBytes += chunk.length;
      
      final progress = (processedBytes / totalBytes) * 100;
      onProgress(progress.clamp(0, 100));
    }

    await outputSink.close();
    debugPrint('✅ Extraction complete: ${outputFile.path}');
  }

  /// Cancel an active download and delete all partial files immediately
  Future<void> cancelDownload(String modelId) async {
    final client = _downloadClients[modelId];
    if (client != null) {
      client.close();
      _downloadClients.remove(modelId);
    }

    final controller = _activeDownloads[modelId];
    if (controller != null) {
      await controller.close();
      _activeDownloads.remove(modelId);
      await _clearActiveDownload(modelId); // Remove from persistent storage
    }

    // Clean up ALL partial/incomplete files immediately
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${appDir.path}/models');
      
      if (await modelsDir.exists()) {
        // Delete temp files
        await for (final entity in modelsDir.list(recursive: true)) {
          if (entity is File && entity.path.endsWith('.tmp')) {
            await entity.delete();
            debugPrint('🗑️ Deleted temporary file: ${entity.path}');
          }
        }
        
        // Delete incomplete GGUF file for this specific model
        final ggufFile = File('${modelsDir.path}/$modelId.gguf');
        if (await ggufFile.exists()) {
          await ggufFile.delete();
          debugPrint('🗑️ Deleted incomplete model: ${ggufFile.path}');
        }
        
        // Delete compressed file if exists
        final gzFile = File('${modelsDir.path}/$modelId.gguf.gz');
        if (await gzFile.exists()) {
          await gzFile.delete();
          debugPrint('🗑️ Deleted compressed file: ${gzFile.path}');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error cleaning temp files: $e');
    }

    debugPrint('⚠️ Cancelled download: $modelId');
  }

  /// Delete a downloaded model file
  Future<bool> deleteModel(String localPath) async {
    try {
      final file = File(localPath);
      if (await file.exists()) {
        final sizeMB = (await file.length()) / (1024 * 1024);
        await file.delete();
        debugPrint('✅ Deleted model: $localPath (${sizeMB.toStringAsFixed(1)} MB freed)');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Failed to delete model: $e');
      return false;
    }
  }

  /// Get available storage space in bytes
  Future<int> getAvailableStorageBytes() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Note: This is an approximation. Real implementation would use platform channels
        // to get actual device storage via native APIs
        return 5 * 1024 * 1024 * 1024; // 5GB default assumption
      }
      return 10 * 1024 * 1024 * 1024; // 10GB for desktop
    } catch (e) {
      debugPrint('⚠️ Could not determine storage: $e');
      return 5 * 1024 * 1024 * 1024; // Default 5GB
    }
  }

  /// Check if enough storage is available for model
  Future<bool> hasEnoughStorage(int requiredBytes) async {
    final available = await getAvailableStorageBytes();
    final buffer = 500 * 1024 * 1024; // 500MB safety buffer
    return available > (requiredBytes + buffer);
  }

  /// Get total size of downloaded models directory in bytes
  Future<int> getModelsDirectorySize() async {
    try {
      final storageDir = await getModelStorageDirectory();
      final modelsDir = Directory('${storageDir.path}/models');
      
      if (!await modelsDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (final entity in modelsDir.list(recursive: true)) {
        if (entity is File && !entity.path.endsWith('.tmp')) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      debugPrint('⚠️ Could not calculate directory size: $e');
      return 0;
    }
  }

  /// Check if download is in progress
  bool isDownloading(String modelId) {
    return _activeDownloads.containsKey(modelId);
  }

  /// Get list of all downloaded model files
  Future<List<String>> getDownloadedModelPaths() async {
    try {
      final storageDir = await getModelStorageDirectory();
      final modelsDir = Directory('${storageDir.path}/models');
      
      if (!await modelsDir.exists()) {
        return [];
      }

      final List<String> modelPaths = [];
      await for (final entity in modelsDir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.gguf')) {
          modelPaths.add(entity.path);
        }
      }
      return modelPaths;
    } catch (e) {
      debugPrint('⚠️ Error listing models: $e');
      return [];
    }
  }

  // Custom model path management
  static const String _customModelPathKey = 'custom_model_path';

  /// Get the custom model path if set
  Future<String?> getCustomModelPath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_customModelPathKey);
      if (path != null && await File(path).exists()) {
        return path;
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Error getting custom model path: $e');
      return null;
    }
  }

  /// Set a custom model path
  Future<bool> setCustomModelPath(String filePath) async {
    try {
      // Validate the file exists and is a GGUF file
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('❌ Custom model file not found: $filePath');
        return false;
      }
      if (!filePath.toLowerCase().endsWith('.gguf')) {
        debugPrint('❌ File is not a GGUF model: $filePath');
        return false;
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_customModelPathKey, filePath);
      debugPrint('✅ Custom model path set: $filePath');
      return true;
    } catch (e) {
      debugPrint('⚠️ Error setting custom model path: $e');
      return false;
    }
  }

  /// Clear the custom model path
  Future<void> clearCustomModelPath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_customModelPathKey);
      debugPrint('✅ Custom model path cleared');
    } catch (e) {
      debugPrint('⚠️ Error clearing custom model path: $e');
    }
  }

  void dispose() {
    for (final controller in _activeDownloads.values) {
      controller.close();
    }
    _activeDownloads.clear();
    
    for (final client in _downloadClients.values) {
      client.close();
    }
    _downloadClients.clear();
  }
}

/// Model download progress data
class ModelDownloadProgress {
  final String modelId;
  final ModelDownloadStage stage;
  final double progress;
  final int? downloadedBytes;
  final int? totalBytes;
  final String? localPath;
  final String? error;

  ModelDownloadProgress({
    required this.modelId,
    required this.stage,
    required this.progress,
    this.downloadedBytes,
    this.totalBytes,
    this.localPath,
    this.error,
  });

  String get progressText {
    switch (stage) {
      case ModelDownloadStage.downloading:
        if (totalBytes != null && totalBytes! > 0) {
          final downloadedMB = (downloadedBytes ?? 0) / (1024 * 1024);
          final totalMB = totalBytes! / (1024 * 1024);
          return 'Downloading: ${downloadedMB.toStringAsFixed(1)} MB / ${totalMB.toStringAsFixed(1)} MB (${progress.toStringAsFixed(1)}%)';
        }
        return 'Downloading: ${progress.toStringAsFixed(1)}%';
      case ModelDownloadStage.extracting:
        return 'Extracting: ${progress.toStringAsFixed(1)}%';
      case ModelDownloadStage.verifying:
        return 'Verifying file integrity...';
      case ModelDownloadStage.completed:
        return 'Download complete!';
      case ModelDownloadStage.failed:
        return 'Failed: ${error ?? "Unknown error"}';
    }
  }

  String? get speedText {
    if (stage == ModelDownloadStage.downloading && 
        downloadedBytes != null && 
        totalBytes != null && 
        totalBytes! > 0) {
      final remainingBytes = totalBytes! - downloadedBytes!;
      final remainingMB = remainingBytes / (1024 * 1024);
      
      if (remainingMB < 100) {
        return 'Almost done...';
      } else if (remainingMB < 500) {
        return 'A few more minutes...';
      } else {
        return 'This may take 5-10 minutes';
      }
    }
    return null;
  }
}

/// Download stages
enum ModelDownloadStage {
  downloading,
  extracting,
  verifying,
  completed,
  failed,
}
