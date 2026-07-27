/// Represents an offline GGUF model available for local inference
class OfflineModel {
  final String id;
  final String name;
  final String author;
  final int size; // in bytes
  final String? downloadUrl;
  final String? filename;
  final bool isDownloaded;
  final double downloadProgress; // 0.0 to 100.0
  final String? localPath;
  final String? description;
  final String? quantization; // Q4_K_M, Q6_K, Q8_0, etc.
  final List<String> tags; // ['medical', 'reasoning', etc.]
  final int contextSize; // Context window size

  OfflineModel({
    required this.id,
    required this.name,
    required this.author,
    required this.size,
    this.downloadUrl,
    this.filename,
    this.isDownloaded = false,
    this.downloadProgress = 0.0,
    this.localPath,
    this.description,
    this.quantization,
    this.tags = const [],
    this.contextSize = 2048,
  });

  /// Get size in MB
  double get sizeMB => size / (1024 * 1024);

  /// Get size in GB
  double get sizeGB => size / (1024 * 1024 * 1024);

  /// Create a copy with modified fields
  OfflineModel copyWith({
    String? id,
    String? name,
    String? author,
    int? size,
    String? downloadUrl,
    String? filename,
    bool? isDownloaded,
    double? downloadProgress,
    String? localPath,
    String? description,
    String? quantization,
    List<String>? tags,
    int? contextSize,
  }) {
    return OfflineModel(
      id: id ?? this.id,
      name: name ?? this.name,
      author: author ?? this.author,
      size: size ?? this.size,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      filename: filename ?? this.filename,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      localPath: localPath ?? this.localPath,
      description: description ?? this.description,
      quantization: quantization ?? this.quantization,
      tags: tags ?? this.tags,
      contextSize: contextSize ?? this.contextSize,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'author': author,
        'size': size,
        'downloadUrl': downloadUrl,
        'filename': filename,
        'isDownloaded': isDownloaded,
        'downloadProgress': downloadProgress,
        'localPath': localPath,
        'description': description,
        'quantization': quantization,
        'tags': tags,
        'contextSize': contextSize,
      };

  /// Create from JSON
  factory OfflineModel.fromJson(Map<String, dynamic> json) {
    return OfflineModel(
      id: json['id'] as String,
      name: json['name'] as String,
      author: json['author'] as String,
      size: json['size'] as int,
      downloadUrl: json['downloadUrl'] as String?,
      filename: json['filename'] as String?,
      isDownloaded: json['isDownloaded'] as bool? ?? false,
      downloadProgress: (json['downloadProgress'] as num?)?.toDouble() ?? 0.0,
      localPath: json['localPath'] as String?,
      description: json['description'] as String?,
      quantization: json['quantization'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      contextSize: json['contextSize'] as int? ?? 2048,
    );
  }

  @override
  String toString() => 'OfflineModel(id: $id, name: $name, size: ${sizeMB.toStringAsFixed(1)} MB)';
}
