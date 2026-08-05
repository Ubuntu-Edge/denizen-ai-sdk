import 'offline_model.dart';

/// Default offline models optimized for mobile devices and educational tutoring use cases.
class DefaultOfflineModels {
  /// Get list of recommended models for student tutoring and educational use
  static List<OfflineModel> getEducationModels() {
    return [
      // Priority 1: Recommended — best balance for tutoring
      OfflineModel(
        id: 'llama-3.2-1b-q8',
        name: 'Llama 3.2 1B Instruct',
        author: 'Meta',
        size: 1320000000, // 1.32 GB
        downloadUrl:
        'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q8_0.gguf',
        filename: 'Llama-3.2-1B-Instruct-Q8_0.gguf',
        quantization: 'Q8_0',
        description:
        'Fast, lightweight model. Good for Socratic tutoring and flashcard generation on low-RAM devices.',
        tags: ['education', 'tutoring', 'lightweight', 'recommended'],
        contextSize: 4096,
        isDownloaded: false,
        downloadProgress: 0,
      ),

      // Priority 2: Multilingual — good for Kiswahili support
      OfflineModel(
        id: 'qwen2.5-1.5b-q8',
        name: 'Qwen2.5 1.5B Instruct',
        author: 'Alibaba',
        size: 1890000000, // 1.89 GB
        downloadUrl:
        'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q8_0.gguf',
        filename: 'qwen2.5-1.5b-instruct-q8_0.gguf',
        quantization: 'Q8_0',
        description:
        'Strong multilingual support including Kiswahili. Good for summarization and study plans.',
        tags: ['education', 'multilingual', 'kiswahili', 'summarization'],
        contextSize: 32768,
        isDownloaded: false,
        downloadProgress: 0,
      ),

      // Priority 3: Slightly larger, better reasoning
      OfflineModel(
        id: 'llama-3.2-3b-q4',
        name: 'Llama 3.2 3B Instruct',
        author: 'Meta',
        size: 1800000000, // 1.80 GB
        downloadUrl:
        'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
        filename: 'Llama-3.2-3B-Instruct-Q4_K_M.gguf',
        quantization: 'Q4_K_M',
        description:
        'Better reasoning and longer answers. Good for exam prep and detailed explanations.',
        tags: ['education', 'reasoning', 'exam-prep'],
        contextSize: 8192,
        isDownloaded: false,
        downloadProgress: 0,
      ),

      // Priority 4: Smallest — for very low-end devices
      OfflineModel(
        id: 'smollm2-1.7b-q4',
        name: 'SmolLM2 1.7B Instruct',
        author: 'HuggingFace',
        size: 980000000, // 0.98 GB
        downloadUrl:
        'https://huggingface.co/bartowski/SmolLM2-1.7B-Instruct-GGUF/resolve/main/SmolLM2-1.7B-Instruct-Q4_K_M.gguf',
        filename: 'SmolLM2-1.7B-Instruct-Q4_K_M.gguf',
        quantization: 'Q4_K_M',
        description:
        'Smallest model, under 1GB. For very low-end Android devices. Basic tutoring only.',
        tags: ['education', 'lightweight', 'low-ram'],
        contextSize: 2048,
        isDownloaded: false,
        downloadProgress: 0,
      ),
    ];
  }

  /// Get model by ID
  static OfflineModel? getModelById(String id) {
    try {
      return getEducationModels().firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get models filtered by tags
  static List<OfflineModel> getModelsByTags(List<String> tags) {
    return getEducationModels()
        .where((model) => model.tags.any((tag) => tags.contains(tag)))
        .toList();
  }

  /// Get recommended model for device RAM limits
  static OfflineModel getRecommendedForRAM(int ramMB) {
    final models = getEducationModels();
    if (ramMB < 3072) {
      return models.firstWhere((m) => m.id == 'smollm2-1.7b-q4');
    } else if (ramMB < 5120) {
      return models.firstWhere((m) => m.id == 'llama-3.2-1b-q8');
    } else if (ramMB < 7168) {
      return models.firstWhere((m) => m.id == 'qwen2.5-1.5b-q8');
    } else {
      return models.firstWhere((m) => m.id == 'llama-3.2-3b-q4');
    }
  }

  /// Get the default recommended model for educational use
  static OfflineModel getDefaultEducationModel() {
    return getEducationModels().firstWhere((m) => m.id == 'llama-3.2-1b-q8');
  }
}