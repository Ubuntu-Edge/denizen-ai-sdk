class OfflineModel {
  final String id;
  final String name;
  final String author;
  final int size; // Using 'size' to match DefaultOfflineModels
  final String? downloadUrl;
  final String filename;
  final String quantization;
  final String description;
  final List<String> tags;
  final int contextSize;
  final bool isDownloaded;
  final double downloadProgress;
  final String? localPath;

  const OfflineModel({
    required this.id,
    required this.name,
    this.author = 'Unknown',
    required this.size,
    this.downloadUrl,
    required this.filename,
    this.quantization = 'Unknown',
    required this.description,
    this.tags = const [],
    this.contextSize = 2048,
    this.isDownloaded = false,
    this.downloadProgress = 0,
    this.localPath,
  });

  double get sizeMB => size / (1024 * 1024);

  OfflineModel copyWith({
    bool? isDownloaded,
    double? downloadProgress,
    String? localPath,
  }) {
    return OfflineModel(
      id: id,
      name: name,
      author: author,
      size: size,
      downloadUrl: downloadUrl,
      filename: filename,
      quantization: quantization,
      description: description,
      tags: tags,
      contextSize: contextSize,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      localPath: localPath ?? this.localPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'author': author,
        'size': size,
        'downloadUrl': downloadUrl,
        'filename': filename,
        'quantization': quantization,
        'description': description,
        'tags': tags,
        'contextSize': contextSize,
        'isDownloaded': isDownloaded,
        'downloadProgress': downloadProgress,
        'localPath': localPath,
      };

  factory OfflineModel.fromJson(Map<String, dynamic> json) {
    return OfflineModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      author: json['author'] ?? 'Unknown',
      size: json['size'] ?? 0,
      downloadUrl: json['downloadUrl'],
      filename: json['filename'] ?? '',
      quantization: json['quantization'] ?? 'Unknown',
      description: json['description'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      contextSize: json['contextSize'] ?? 2048,
      isDownloaded: json['isDownloaded'] ?? false,
      downloadProgress: (json['downloadProgress'] ?? 0).toDouble(),
      localPath: json['localPath'],
    );
  }
}
