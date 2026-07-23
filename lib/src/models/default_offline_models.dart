import 'offline_model.dart';

/// Default offline models based on PocketPal AI configuration
/// These models are optimized for mobile devices and medical use cases
class DefaultOfflineModels {
  /// Get list of recommended models for CHW medical use
  static List<OfflineModel> getMedicalModels() {
    return [
      // Priority 1: Ultra-lightweight & Fast (Default Recommended for Mobile)
      OfflineModel(
        id: 'qwen2.5-0.5b-q4',
        name: 'Qwen2.5 0.5B Instruct',
        author: 'Alibaba',
        size: 398000000, // ~398 MB
        downloadUrl:
            'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
        filename: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
        quantization: 'Q4_K_M',
        description:
            'Ultra-lightweight model (~398MB). Fast inference, low RAM usage, ideal for mobile devices.',
        tags: ['lightweight', 'fast', 'mobile', 'recommended'],
        contextSize: 4096,
        isDownloaded: false,
        downloadProgress: 0,
      ),

      // Priority 2: Compact Testing Model
      OfflineModel(
        id: 'smollm2-360m-q4',
        name: 'SmolLM2 360M Instruct',
        author: 'HuggingFace',
        size: 228000000, // ~228 MB
        downloadUrl:
            'https://huggingface.co/bartowski/SmolLM2-360M-Instruct-GGUF/resolve/main/SmolLM2-360M-Instruct-Q4_K_M.gguf',
        filename: 'SmolLM2-360M-Instruct-Q4_K_M.gguf',
        quantization: 'Q4_K_M',
        description:
            'Smallest model (~228MB). Loads instantly with minimal RAM usage, ideal for low-end phones.',
        tags: ['testing', 'ultra-lightweight', 'compact'],
        contextSize: 2048,
        isDownloaded: false,
        downloadProgress: 0,
      ),

      // Priority 3: High Quality Mobile Model
      OfflineModel(
        id: 'llama-3.2-1b-q4',
        name: 'Llama 3.2 1B Instruct',
        author: 'Meta',
        size: 758000000, // ~758 MB
        downloadUrl:
            'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
        filename: 'Llama-3.2-1B-Instruct-Q4_K_M.gguf',
        quantization: 'Q4_K_M',
        description:
            'Great balance of intelligence and size (~758MB). Fast instruction following for general tasks.',
        tags: ['instructions', 'balanced', 'quality'],
        contextSize: 4096,
        isDownloaded: false,
        downloadProgress: 0,
      ),

      // Priority 4: Qwen 1.5B (Quantized Q4_K_M)
      OfflineModel(
        id: 'qwen2.5-1.5b-q4',
        name: 'Qwen2.5 1.5B Instruct (Q4)',
        author: 'Alibaba',
        size: 980000000, // ~980 MB
        downloadUrl:
            'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
        filename: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
        quantization: 'Q4_K_M',
        description:
            'Higher capability model (~980MB). Excellent reasoning while keeping RAM under 1.5GB.',
        tags: ['reasoning', 'multilingual', 'high-quality'],
        contextSize: 4096,
        isDownloaded: false,
        downloadProgress: 0,
      ),

      // Priority 5: Phi-3.5 Mini (High RAM Devices Only)
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
            'Large model (2.39 GB). High reasoning power, requires devices with 6GB+ RAM.',
        tags: ['medical', 'heavy', 'high-ram'],
        contextSize: 4096,
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
      // < 4GB RAM: Use ultra-compact model
      return models.firstWhere((m) => m.id == 'smollm2-360m-q4');
    } else if (ramMB < 6144) {
      // 4-6GB RAM: Use Qwen 0.5B
      return models.firstWhere((m) => m.id == 'qwen2.5-0.5b-q4');
    } else if (ramMB < 8192) {
      // 6-8GB RAM: Use Llama 3.2 1B
      return models.firstWhere((m) => m.id == 'llama-3.2-1b-q4');
    } else {
      // 8GB+ RAM: Use Phi-3.5 Mini
      return models.firstWhere((m) => m.id == 'phi-3.5-mini-q4');
    }
  }

  /// Get the recommended model for medical CHW use (default)
  static OfflineModel getDefaultMedicalModel() {
    return getMedicalModels().firstWhere((m) => m.id == 'qwen2.5-0.5b-q4');
  }
}
