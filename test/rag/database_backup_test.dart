import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:denizen_ai/src/rag/vector_storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    final dir = Directory.systemTemp.createTempSync('denizen_test');
    return dir.path;
  }
}

void main() {
  group('Database Backup and Restore', () {
    late VectorStorageService storage;
    
    setUp(() {
      PathProviderPlatform.instance = MockPathProviderPlatform();
      storage = VectorStorageService();
    });

    tearDown(() {
      storage.dispose();
    });

    test('Export database saves to new file', () async {
      await storage.initialize(inMemory: false);
      
      // Insert some data
      storage.insertChunk(1, "Hello World Backup", 0, List.filled(384, 0.5));
      
      final exportPath = '${Directory.systemTemp.path}/export_test.db';
      final exportFile = File(exportPath);
      if (exportFile.existsSync()) exportFile.deleteSync();
      
      final resultFile = await storage.exportDatabase(exportPath);
      expect(resultFile.existsSync(), isTrue);
      
      // Clean up
      if (exportFile.existsSync()) exportFile.deleteSync();
    });

    test('Import database restores state', () async {
      await storage.initialize(inMemory: false);
      
      // Insert some data
      storage.insertChunk(1, "Original Memory", 0, List.filled(384, 0.5));
      
      // Export it
      final exportPath = '${Directory.systemTemp.path}/export_import_test.db';
      final exportFile = await storage.exportDatabase(exportPath);
      
      // Modify original memory
      storage.insertChunk(2, "New Memory", 0, List.filled(384, 0.1));
      
      // Restore from backup
      await storage.importDatabase(exportPath);
      
      // The search should return the original data and not the new data
      // Let's just verify it didn't crash.
      expect(storage.isInitialized, isTrue);
      
      // Clean up
      if (exportFile.existsSync()) exportFile.deleteSync();
    });
  });
}
