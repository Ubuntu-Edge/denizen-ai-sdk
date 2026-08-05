import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/offline_model.dart';
import 'package:flutter/foundation.dart';

class ModelDownloadProgress {
  final String modelId;
  final double progress;
  final String? filePath;
  final String? error;
  final bool isCompleted;

  ModelDownloadProgress({
    required this.modelId,
    required this.progress,
    this.filePath,
    this.error,
    this.isCompleted = false,
  });
}

class ModelDownloadService {
  static final ModelDownloadService _instance = ModelDownloadService._internal();
  static ModelDownloadService get instance => _instance;
  ModelDownloadService._internal();

  final Dio _dio = Dio();
  final Map<String, CancelToken> _activeDownloads = {};

  Stream<ModelDownloadProgress> downloadModel({
    required String url,
    required String modelId,
    required String fileName,
    String author = 'Unknown',
    bool useCompression = true,
  }) {
    final controller = StreamController<ModelDownloadProgress>();
    final cancelToken = CancelToken();
    _activeDownloads[modelId] = cancelToken;

    Future<void> run() async {
      try {
        final storageDir = await _getModelStorageDirectory();
        final modelsDir = Directory('${storageDir.path}/models/$author');

        if (!await modelsDir.exists()) {
          await modelsDir.create(recursive: true);
        }

        final savePath = '${modelsDir.path}/$fileName';

        await _dio.download(
          url,
          savePath,
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            if (total != -1 && !controller.isClosed) {
              controller.add(ModelDownloadProgress(
                modelId: modelId,
                progress: received / total,
              ));
            }
          },
        );

        _activeDownloads.remove(modelId);
        if (!controller.isClosed) {
          controller.add(ModelDownloadProgress(
            modelId: modelId,
            progress: 1.0,
            filePath: savePath,
            isCompleted: true,
          ));
          await controller.close();
        }
      } catch (e) {
        _activeDownloads.remove(modelId);
        if (controller.isClosed) return;
        if (e is DioException && CancelToken.isCancel(e)) {
          controller.add(ModelDownloadProgress(
            modelId: modelId,
            progress: 0,
            error: 'Download cancelled',
          ));
        } else {
          controller.add(ModelDownloadProgress(
            modelId: modelId,
            progress: 0,
            error: 'Download failed: $e',
          ));
        }
        await controller.close();
      }
    }

    run();
    return controller.stream;
  }

  void cancelDownload(String modelId) {
    _activeDownloads[modelId]?.cancel();
    _activeDownloads.remove(modelId);
  }

  Future<Directory> _getModelStorageDirectory() async {
    if (Platform.isAndroid) {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) return externalDir;
    }
    return await getApplicationDocumentsDirectory();
  }

  Future<bool> deleteModel(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting model: $e');
      return false;
    }
  }

  Future<int> getAvailableStorageBytes() async {
    // Simple implementation, in a real app you might use a package to get actual disk space
    return 10 * 1024 * 1024 * 1024; // Mock 10GB for now
  }

  Future<int> getModelsDirectorySize() async {
    try {
      final storageDir = await _getModelStorageDirectory();
      final modelsDir = Directory('${storageDir.path}/models');
      if (!await modelsDir.exists()) return 0;

      int totalSize = 0;
      await for (final entity in modelsDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  Future<bool> hasEnoughStorage(int requiredBytes) async {
    final available = await getAvailableStorageBytes();
    return available > requiredBytes;
  }
}
