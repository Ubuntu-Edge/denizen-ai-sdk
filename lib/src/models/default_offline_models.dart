import 'offline_model.dart';

/// Default offline models based on PocketPal AI configuration
/// These models are optimized for mobile devices and medical use cases
class DefaultOfflineModels {
  /// Get list of recommended models for CHW medical use
  static List<OfflineModel> getMedicalModels() {
    return [
      // Priority 1: Best for Medical Reasoning
      OfflineModel(
        id: 'phi-3.5-mini-q4',
        name: 'Phi-3.5 Mini Instruct',
        author: 'Microsoft',
        size: 2390000000, // 2.39 GB
        downloadUrl:
            'https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf',
        filename: 'phi-3.5-mini-instruct-Q4_K_M.gguf',
        quantization: 'Q4_K_M',
        description:
            'Excellent for medical reasoning, multilingual support, and structured responses. Recommended for CHW use.',
        tags: ['medical', 'reasoning', 'multilingual', 'recommended'],
        contextSize: 4096,
        isDownloaded: false,
        downloadProgress: 0,
      ),

      // Priority 2: High Quality, Balanced
      OfflineModel(
        id: 'medgemma-4b-it-q4',
        name: 'MedGemma 4B Instruct',
        author: 'Google',
        size: 2490000000, // 2.49 GB
        downloadUrl:
            'https://huggingface.co/Fadhili254/medgemma-4b-it-q4_k_m.gguf/resolve/main/medgemma-4b-it-q4_k_m.gguf?download=true',
        filename: 'medgemma-4b-it-q4_k_m.gguf',
        quantization: 'Q4_K',
        description:
            'High-quality responses for question answering, summarization, and reasoning. Good balance of size and performance.',
        tags: ['medical', 'qa', 'summarization', 'high-quality'],
        contextSize: 8192,
        isDownloaded: false,
        downloadProgress: 0,
      ),

      // Priority 3: Lightweight, Fast
      OfflineModel(
        id: 'qwen2.5-1.5b-q8',
        name: 'Qwen2.5-1.5B Instruct',
        author: 'Alibaba',
        size: 1890000000, // 1.89 GB
        downloadUrl:
            'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q8_0.gguf',
        filename: 'qwen2.5-1.5b-instruct-q8_0.gguf',
        quantization: 'Q8_0',
        description:
            'Fast inference, multilingual, good for instructions and roleplay. Works well on low-RAM devices.',
        tags: ['lightweight', 'fast', 'multilingual', 'low-ram'],
        contextSize: 32768,
        isDownloaded: false,
        downloadProgress: 0,
      ),

      // Priority 4: Balanced Size
      OfflineModel(
        id: 'llama-3.2-3b-q6',
        name: 'Llama 3.2 3B Instruct',
        author: 'Meta',
        size: 2640000000, // 2.64 GB
        downloadUrl:
            'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q6_K.gguf',
        filename: 'Llama-3.2-3B-Instruct-Q6_K.gguf',
        quantization: 'Q6_K',
        description:
            'Strong instruction following, summarization, and rewriting capabilities. Good for patient notes and reports.',
        tags: ['medical', 'instructions', 'summarization', 'reports'],
        contextSize: 8192,
        isDownloaded: false,
        downloadProgress: 0,
      ),

      // Priority 5: Testing Model (Smallest)
      OfflineModel(
        id: 'smollm2-1.7b-q8',
        name: 'SmolLM2-1.7B Instruct',
        author: 'HuggingFace',
        size: 1820000000, // 1.82 GB
        downloadUrl:
            'https://huggingface.co/bartowski/SmolLM2-1.7B-Instruct-GGUF/resolve/main/SmolLM2-1.7B-Instruct-Q8_0.gguf',
        filename: 'SmolLM2-1.7B-Instruct-Q8_0.gguf',
        quantization: 'Q8_0',
        description:
            'Smallest model, good for testing and low-resource devices. General purpose assistant.',
        tags: ['testing', 'lightweight', 'general'],
        contextSize: 2048,
        isDownloaded: false,
        downloadProgress: 0,
      ),
    ];
  }

  /// Get model by ID
  static OfflineModel? getModelById(String id) {
    try {
      return getMedicalModels().firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get models filtered by tags
  static List<OfflineModel> getModelsByTags(List<String> tags) {
    return getMedicalModels()
        .where((model) => model.tags.any((tag) => tags.contains(tag)))
        .toList();
  }

  /// Get recommended model for device RAM
  static OfflineModel getRecommendedForRAM(int ramMB) {
    final models = getMedicalModels();

    if (ramMB < 4096) {
      // < 4GB RAM: Use smallest model
      return models.firstWhere((m) => m.id == 'smollm2-1.7b-q8');
    } else if (ramMB < 6144) {
      // 4-6GB RAM: Use lightweight model
      return models.firstWhere((m) => m.id == 'qwen2.5-1.5b-q8');
    } else if (ramMB < 8192) {
      // 6-8GB RAM: Use balanced model
      return models.firstWhere((m) => m.id == 'phi-3.5-mini-q4');
    } else {
      // 8GB+ RAM: Use highest quality
      return models.firstWhere((m) => m.id == 'medgemma-4b-it-q4');
    }
  }

  /// Get the recommended model for medical CHW use (default)
  static OfflineModel getDefaultMedicalModel() {
    return getMedicalModels().firstWhere((m) => m.id == 'phi-3.5-mini-q4');
  }
}
