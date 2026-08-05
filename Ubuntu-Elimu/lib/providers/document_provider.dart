import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/document.dart';

class DocumentProvider with ChangeNotifier {
  List<Document> _documents = [];
  String _searchQuery = '';
  String _selectedCategory = 'all';
  bool _isLoading = false;
  String? _error;

  late Box _documentBox;

  // ─────────────────────────────────────────────
  // Getters
  // ─────────────────────────────────────────────

  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;

  List<Document> get documents {
    return _documents.where((doc) {
      final matchesSearch =
      doc.name.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesCategory = _selectedCategory == 'all' ||
          doc.type.extension.toLowerCase() ==
              _selectedCategory.toLowerCase();

      return matchesSearch && matchesCategory;
    }).toList();
  }

  List<Document> get recentUploads {
    final sorted = List<Document>.from(_documents);
    sorted.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return sorted.take(3).toList();
  }

  // ─────────────────────────────────────────────
  // Init Hive
  // ─────────────────────────────────────────────

  Future<void> init() async {
    _documentBox = await Hive.openBox('documents');
    _loadFromHive();
  }

  void _loadFromHive() {
    final stored = _documentBox.values.toList();

    _documents = stored
        .map((e) => Document.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // Upload Document
  // ─────────────────────────────────────────────

  Future<void> pickAndUploadDocument() async {
    _error = null;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) return;

    final pickedFile = result.files.first;
    if (pickedFile.path == null) return;

    final sourceFile = File(pickedFile.path!);
    final extension = pickedFile.extension?.toLowerCase() ?? '';

    DocType? type;
    if (extension == 'pdf') type = DocType.pdf;
    if (extension == 'docx') type = DocType.docx;

    if (type == null) {
      _error = 'Unsupported file type';
      notifyListeners();
      return;
    }

    // Save locally
    final appDir = await getApplicationDocumentsDirectory();
    final savedPath = '${appDir.path}/${pickedFile.name}';
    await sourceFile.copy(savedPath);

    final doc = Document(
      id: 'doc_${DateTime.now().millisecondsSinceEpoch}',
      name: pickedFile.name,
      type: type,
      sizeBytes: pickedFile.size,
      addedAt: DateTime.now(),
      filePath: savedPath,
      isProcessed: false,
      chunks: [],
    );

    _documents.add(doc);
    _saveToHive(doc);
    notifyListeners();

    // Process asynchronously
    await _processDocument(doc);
  }

  // ─────────────────────────────────────────────
  // Document Processing Pipeline (AI-ready)
  // ─────────────────────────────────────────────

  Future<void> _processDocument(Document doc) async {
    if (doc.filePath == null) return;

    _setLoading(true);

    try {
      final rawText = await _extractText(doc.filePath!, doc.type);

      if (rawText.isEmpty) {
        _error = 'Could not extract text from ${doc.name}';
        _setLoading(false);
        return;
      }

      final chunks = _chunkText(rawText);

      final updated = doc.copyWith(
        extractedText: rawText,
        chunks: chunks,
        isProcessed: true,
      );

      final index = _documents.indexWhere((d) => d.id == doc.id);
      if (index != -1) _documents[index] = updated;

      _saveToHive(updated);
      notifyListeners();
    } catch (e) {
      _error = 'Processing failed: $e';
    }

    _setLoading(false);
  }

  // ─────────────────────────────────────────────
  // SAFE TEXT EXTRACTION (TEMP IMPLEMENTATION)
  // ─────────────────────────────────────────────

  Future<String> _extractText(String path, DocType type) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();

      // ⚠️ TEMP fallback (NOT real parsing)
      // This will be replaced by:
      // - native Android parser OR
      // - Rust service OR
      // - Python backend OR
      // - llama.cpp ingestion pipeline

      return String.fromCharCodes(bytes).trim();
    } catch (e) {
      return '';
    }
  }

  // ─────────────────────────────────────────────
  // Chunking (RAG ready)
  // ─────────────────────────────────────────────

  List<String> _chunkText(
      String text, {
        int chunkSize = 500,
        int overlap = 50,
      }) {
    final words = text.split(RegExp(r'\s+'));
    final chunks = <String>[];

    int start = 0;

    while (start < words.length) {
      final end = (start + chunkSize).clamp(0, words.length);

      chunks.add(words.sublist(start, end).join(' '));

      if (end == words.length) break;

      start += chunkSize - overlap;
    }

    return chunks;
  }

  // ─────────────────────────────────────────────
  // Retrieval (basic RAG)
  // ─────────────────────────────────────────────

  List<String> getRelevantChunks(
      String docId,
      String query, {
        int topK = 3,
      }) {
    final doc = _documents.firstWhere(
          (d) => d.id == docId,
      orElse: () => throw Exception('Document not found'),
    );

    if (doc.chunks.isEmpty) return [];

    final queryWords = query.toLowerCase().split(RegExp(r'\s+'));

    final scored = doc.chunks.map((chunk) {
      final lower = chunk.toLowerCase();
      final score =
          queryWords.where((w) => lower.contains(w)).length;
      return MapEntry(chunk, score);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));

    return scored.take(topK).map((e) => e.key).toList();
  }

  /// Finds documents relevant to a freeform topic across the whole library
  /// (unlike getRelevantChunks, which is scoped to one known document id).
  /// Used by the Research report flow to ground a report in real sources.
  List<MapEntry<Document, List<String>>> findRelevantAcrossLibrary(
      String query, {
        int topKPerDoc = 2,
        int maxDocs = 3,
      }) {
    final queryWords = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
    final results = <MapEntry<Document, List<String>>>[];

    for (final doc in _documents) {
      if (!doc.isProcessed || doc.chunks.isEmpty) continue;
      final chunks = getRelevantChunks(doc.id, query, topK: topKPerDoc);
      final hasMatch = chunks.any((c) {
        final lower = c.toLowerCase();
        return queryWords.any((w) => lower.contains(w));
      });
      if (hasMatch) results.add(MapEntry(doc, chunks));
    }

    results.sort((a, b) => b.value.length.compareTo(a.value.length));
    return results.take(maxDocs).toList();
  }

  // ─────────────────────────────────────────────
  // Hive Persistence
  // ─────────────────────────────────────────────

  void _saveToHive(Document doc) {
    _documentBox.put(doc.id, doc.toMap());
  }

  void removeDocument(String id) {
    _documents.removeWhere((doc) => doc.id == id);
    _documentBox.delete(id);
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // UI Helpers
  // ─────────────────────────────────────────────

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // FUTURE AI HOOK (IMPORTANT)
  // ─────────────────────────────────────────────
  // This is where you will later plug:
  // - embeddings
  // - vector DB
  // - llama.cpp inference
  // - offline RAG engine

  void attachAIEngine() {
    // TODO: connect to local model runtime
  }
}