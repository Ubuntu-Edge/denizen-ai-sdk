import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:denizen_ai/denizen_ai.dart';
import 'package:denizen_ai/src/services/model_download_service.dart';
import 'package:denizen_ai/src/services/offline_ai_service.dart';
import 'package:denizen_ai/src/models/offline_model.dart';

class FakeModelDownloadService implements ModelDownloadService {
  final Directory tempDir;
  int availableStorageBytes;
  final List<String> existingModelPaths;
  
  FakeModelDownloadService({
    required this.tempDir, 
    required this.availableStorageBytes,
    this.existingModelPaths = const [],
  });

  @override
  Future<Directory> getModelStorageDirectory() async => tempDir;

  @override
  Future<List<String>> getDownloadedModelPaths() async {
    return existingModelPaths;
  }

  @override
  Future<bool> hasEnoughStorage(int requiredBytes) async {
    return availableStorageBytes >= requiredBytes;
  }

  @override
  Future<int> getAvailableStorageBytes() async {
    return availableStorageBytes;
  }

  @override
  Future<void> deleteModel(String filePath) async {
    existingModelPaths.remove(filePath);
    // Simulate freeing up some generic space (e.g., 2 GB)
    availableStorageBytes += 2 * 1024 * 1024 * 1024;
  }

  @override
  Stream<ModelDownloadProgress> downloadModel({
    required String url,
    required String modelId,
    required String fileName,
    required String author,
    bool useCompression = true,
  }) async* {
    yield ModelDownloadProgress(
      modelId: modelId,
      stage: ModelDownloadStage.completed,
      progress: 100,
      localPath: '${tempDir.path}/models/$author/$fileName',
    );
  }
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeOfflineAIService implements OfflineAIService {
  @override
  bool get isModelLoaded => false;

  @override
  String? get loadedModelPath => null;

  @override
  Future<bool> loadModel({required String modelPath, required OfflineModel model, dynamic contextParams}) async {
    return true; // Simulate successful load
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('denizen_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('load() successfully downloads model when space is ample', () async {
    final fakeDownloadService = FakeModelDownloadService(
      tempDir: tempDir,
      availableStorageBytes: 10 * 1024 * 1024 * 1024, // 10 GB
    );
    final fakeAiService = FakeOfflineAIService();
    
    final manager = DenizenModelManager(fakeDownloadService, fakeAiService);
    
    // We expect this to complete normally
    await manager.load('gemma-2b-it');
    
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('denizen_last_accessed_gemma-2b-it'), isNotNull);
  });

  test('load() evicts oldest model when space is constrained', () async {
    // Let's create a fake existing model
    final oldModelPath = '${tempDir.path}/models/google/gemma-1.gguf';
    final fakeDownloadService = FakeModelDownloadService(
      tempDir: tempDir,
      availableStorageBytes: 100 * 1024 * 1024, // Only 100 MB available
      existingModelPaths: [oldModelPath],
    );
    
    // Create the dummy file so file.length() doesn't throw
    final oldModelFile = File(oldModelPath);
    await oldModelFile.create(recursive: true);
    await oldModelFile.writeAsBytes(List.filled(10, 0)); // dummy size

    final fakeAiService = FakeOfflineAIService();
    final manager = DenizenModelManager(fakeDownloadService, fakeAiService);
    
    // Set old model as accessed long ago
    SharedPreferences.setMockInitialValues({
      'denizen_last_accessed_gemma-1': 1000,
    });

    await manager.load('gemma-2b-it');

    // old model should have been evicted to make room
    expect(fakeDownloadService.existingModelPaths.contains(oldModelPath), isFalse);
  });

  test('load() throws StorageQuotaException if resident models prevent eviction', () async {
    // Create a fake existing model that is pinned as resident
    final residentModelPath = '${tempDir.path}/models/google/resident.gguf';
    final fakeDownloadService = FakeModelDownloadService(
      tempDir: tempDir,
      availableStorageBytes: 100 * 1024 * 1024, // Only 100 MB available
      existingModelPaths: [residentModelPath],
    );
    
    final residentModelFile = File(residentModelPath);
    await residentModelFile.create(recursive: true);
    await residentModelFile.writeAsBytes(List.filled(10, 0)); 

    final fakeAiService = FakeOfflineAIService();
    final manager = DenizenModelManager(fakeDownloadService, fakeAiService);
    
    SharedPreferences.setMockInitialValues({
      'denizen_last_accessed_resident': 1000,
      'denizen_resident_models': ['resident.gguf'], // Pin the file name as ID fallback
    });

    // Expect StorageQuotaException
    expect(
      () => manager.load('gemma-2b-it'),
      throwsA(isA<StorageQuotaException>()),
    );
    
    // Ensure the resident model wasn't deleted
    expect(fakeDownloadService.existingModelPaths.contains(residentModelPath), isTrue);
  });
}
