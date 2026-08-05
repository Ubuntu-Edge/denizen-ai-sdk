enum DocType { pdf, pptx, docx, image, other }

extension DocTypeExt on DocType {
  String get extension {
    switch (this) {
      case DocType.pdf:   return 'PDF';
      case DocType.pptx:  return 'PPTX';
      case DocType.docx:  return 'DOCX';
      case DocType.image: return 'IMG';
      case DocType.other: return 'FILE';
    }
  }

  static DocType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'PDF':   return DocType.pdf;
      case 'PPTX':  return DocType.pptx;
      case 'DOCX':  return DocType.docx;
      case 'IMG':   return DocType.image;
      default:      return DocType.other;
    }
  }
}

class Document {
  final String id;
  final String name;
  final DocType type;
  final int sizeBytes;
  final DateTime addedAt;

  // ── existing optional fields ──────────────────────────────
  final int? pageCount;
  final int? flashcardCount;

  // ── new fields ────────────────────────────────────────────
  final String? filePath;       // absolute path on device storage
  final String? extractedText;  // full raw text after extraction
  final List<String> chunks;    // 500-word segments for AI prompts
  final bool isProcessed;       // true once extraction is complete

  const Document({
    required this.id,
    required this.name,
    required this.type,
    required this.sizeBytes,
    required this.addedAt,
    this.pageCount,
    this.flashcardCount,
    this.filePath,
    this.extractedText,
    this.chunks = const [],
    this.isProcessed = false,
  });

  // ── human-readable file size ──────────────────────────────
  String get sizeLabel {
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ── quick status label for UI ─────────────────────────────
  String get processingStatus {
    if (filePath == null) return 'Not imported';
    if (!isProcessed) return 'Processing...';
    if (chunks.isEmpty) return 'No text found';
    return '${chunks.length} chunks ready';
  }

  // ── copyWith — used after extraction completes ────────────
  Document copyWith({
    String? id,
    String? name,
    DocType? type,
    int? sizeBytes,
    DateTime? addedAt,
    int? pageCount,
    int? flashcardCount,
    String? filePath,
    String? extractedText,
    List<String>? chunks,
    bool? isProcessed,
  }) {
    return Document(
      id:            id            ?? this.id,
      name:          name          ?? this.name,
      type:          type          ?? this.type,
      sizeBytes:     sizeBytes     ?? this.sizeBytes,
      addedAt:       addedAt       ?? this.addedAt,
      pageCount:     pageCount     ?? this.pageCount,
      flashcardCount: flashcardCount ?? this.flashcardCount,
      filePath:      filePath      ?? this.filePath,
      extractedText: extractedText ?? this.extractedText,
      chunks:        chunks        ?? this.chunks,
      isProcessed:   isProcessed   ?? this.isProcessed,
    );
  }

  // ── Hive persistence ──────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'id':            id,
      'name':          name,
      'type':          type.extension,
      'sizeBytes':     sizeBytes,
      'addedAt':       addedAt.toIso8601String(),
      'pageCount':     pageCount,
      'flashcardCount': flashcardCount,
      'filePath':      filePath,
      'extractedText': extractedText,
      'chunks':        chunks,
      'isProcessed':   isProcessed,
    };
  }

  factory Document.fromMap(Map<String, dynamic> map) {
    return Document(
      id:            map['id'] as String,
      name:          map['name'] as String,
      type:          DocTypeExt.fromString(map['type'] as String),
      sizeBytes:     map['sizeBytes'] as int,
      addedAt:       DateTime.parse(map['addedAt'] as String),
      pageCount:     map['pageCount'] as int?,
      flashcardCount: map['flashcardCount'] as int?,
      filePath:      map['filePath'] as String?,
      extractedText: map['extractedText'] as String?,
      chunks:        List<String>.from(map['chunks'] ?? []),
      isProcessed:   map['isProcessed'] as bool? ?? false,
    );
  }
}