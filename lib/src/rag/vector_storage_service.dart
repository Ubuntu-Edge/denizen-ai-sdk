import 'dart:io';
import 'dart:ffi';
import 'package:sqlite3/sqlite3.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class VectorStorageService {
  Database? _db;
  String? _dbPath;
  
  bool get isInitialized => _db != null;

  Future<void> initialize({String? dbPath, bool inMemory = false}) async {
    if (inMemory) {
      _db = sqlite3.openInMemory();
    } else if (dbPath != null) {
      _dbPath = dbPath;
      _db = sqlite3.open(_dbPath!);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      _dbPath = '${dir.path}/denizen_rag.db';
      _db = sqlite3.open(_dbPath!);
    }
    
    // Enable WAL mode for better performance
    _db!.execute('PRAGMA journal_mode=WAL;');
    
    // Load sqlite-vec extension via FFI
    final DynamicLibrary lib;
    if (Platform.isAndroid) {
      DynamicLibrary? openedLib;
      try {
        openedLib = DynamicLibrary.open('libsqlite_vec.so');
      } catch (_) {
        try {
          openedLib = DynamicLibrary.open('sqlite_vec');
        } catch (_) {
          openedLib = DynamicLibrary.process();
        }
      }
      lib = openedLib;
    } else if (Platform.isWindows) {
      // Look for the pre-downloaded dll in multiple potential locations
      final possiblePaths = [
        p.join(Directory.current.path, 'windows', 'vec0.dll'),
        p.join(Directory.current.path, 'build', 'windows_deps', 'vec0.dll'),
        p.join(Directory.current.path, 'example', 'windows', 'vec0.dll'),
        p.join(Directory.current.path, 'vec0.dll'),
      ];
      String? finalDllPath;
      for (final path in possiblePaths) {
        if (File(path).existsSync()) {
          finalDllPath = path;
          break;
        }
      }
      finalDllPath ??= p.join(Directory.current.path, 'build', 'windows_deps', 'vec0.dll');
      lib = DynamicLibrary.open(finalDllPath);
    } else {
      throw UnsupportedError('Unsupported platform for sqlite-vec');
    }
    
    // Explicitly register the vec0 extension with this database connection
    sqlite3.ensureExtensionLoaded(SqliteExtension.inLibrary(lib, 'sqlite3_vec_init'));
    
    _initializeSchema();
  }

  void _initializeSchema() {
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        source_uri TEXT,
        ingested_at INTEGER
      );
    ''');
    
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS document_chunks (
        chunk_id INTEGER PRIMARY KEY AUTOINCREMENT,
        doc_id INTEGER,
        text_content TEXT,
        chunk_index INTEGER,
        FOREIGN KEY(doc_id) REFERENCES documents(id) ON DELETE CASCADE
      );
    ''');
    
    // Virtual table for embeddings via sqlite-vec
    _db!.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS vec_chunks USING vec0(
        embedding float[384]
      );
    ''');
  }

  /// Inserts a document record and returns its docId
  int insertDocument(String title, {String? sourceUri}) {
    if (_db == null) throw Exception("VectorStorageService not initialized");
    final stmt = _db!.prepare('''
      INSERT INTO documents (title, source_uri, ingested_at)
      VALUES (?, ?, ?)
    ''');
    stmt.execute([title, sourceUri ?? '', DateTime.now().millisecondsSinceEpoch]);
    final docId = _db!.lastInsertRowId;
    stmt.dispose();
    return docId;
  }

  /// Deletes a document and all its corresponding chunks and vectors
  void deleteDocument(int docId) {
    if (_db == null) return;
    try {
      _db!.execute('DELETE FROM vec_chunks WHERE rowid IN (SELECT chunk_id FROM document_chunks WHERE doc_id = ?)', [docId]);
      _db!.execute('DELETE FROM document_chunks WHERE doc_id = ?', [docId]);
      _db!.execute('DELETE FROM documents WHERE id = ?', [docId]);
    } catch (_) {}
  }

  /// Inserts a chunk and its corresponding embedding.
  int insertChunk(int docId, String textContent, int chunkIndex, List<double> embedding) {
    if (_db == null) throw Exception("VectorStorageService not initialized");
    
    final stmtChunk = _db!.prepare('''
      INSERT INTO document_chunks (doc_id, text_content, chunk_index)
      VALUES (?, ?, ?)
    ''');
    stmtChunk.execute([docId, textContent, chunkIndex]);
    final chunkId = _db!.lastInsertRowId;
    stmtChunk.dispose();
    
    // Format embedding as JSON array string for sqlite-vec
    final embeddingStr = '[${embedding.join(",")}]';
    
    final stmtVec = _db!.prepare('''
      INSERT INTO vec_chunks (rowid, embedding)
      VALUES (?, ?)
    ''');
    stmtVec.execute([chunkId, embeddingStr]);
    stmtVec.dispose();

    return chunkId;
  }

  /// Searches for the most similar chunks using cosine distance
  List<Map<String, dynamic>> search(List<double> queryEmbedding, {int limit = 5}) {
    if (_db == null) throw Exception("VectorStorageService not initialized");
    
    final embeddingStr = '[${queryEmbedding.join(",")}]';
    
    // In sqlite-vec, lower distance = more similar
    final stmt = _db!.prepare('''
      SELECT 
        c.chunk_id,
        c.doc_id,
        c.text_content,
        v.distance
      FROM vec_chunks v
      JOIN document_chunks c ON c.chunk_id = v.rowid
      WHERE v.embedding MATCH ? 
      ORDER BY v.distance
      LIMIT ?
    ''');
    
    final resultSet = stmt.select([embeddingStr, limit]);
    stmt.dispose();
    
    final results = <Map<String, dynamic>>[];
    for (final row in resultSet) {
      results.add({
        'chunk_id': row['chunk_id'],
        'doc_id': row['doc_id'],
        'text_content': row['text_content'],
        'distance': row['distance'],
      });
    }
    
    return results;
  }

  /// Safely exports the current database to a specified destination path.
  /// Used for cloud backups and cross-device sync.
  Future<File> exportDatabase(String destinationPath) async {
    if (_dbPath == null) throw Exception("Cannot export an in-memory or uninitialized database.");
    
    // Checkpoint the WAL file to ensure all transactions are flushed to the main DB file
    _db!.execute('PRAGMA wal_checkpoint(TRUNCATE);');
    
    final sourceFile = File(_dbPath!);
    return await sourceFile.copy(destinationPath);
  }

  /// Safely replaces the current database with a database from a source file.
  /// Overwrites the current RAG memory.
  Future<void> importDatabase(String sourceFilePath) async {
    if (_dbPath == null) throw Exception("Cannot import into an in-memory or uninitialized database.");
    
    final sourceFile = File(sourceFilePath);
    if (!await sourceFile.exists()) {
      throw Exception("Source database file does not exist at $sourceFilePath");
    }

    // Close existing connection
    dispose();

    // Copy over
    final targetFile = File(_dbPath!);
    await sourceFile.copy(targetFile.path);

    // Re-initialize
    await initialize(inMemory: false);
  }

  void dispose() {
    _db?.dispose();
    _db = null;
  }
}
