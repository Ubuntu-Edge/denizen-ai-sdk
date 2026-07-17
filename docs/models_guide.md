# Offline AI Models Directory

## Purpose
This directory stores GGUF model files for offline AI inference using llama.cpp.

## Directory Structure
```
assets/ai_models/
├── README.md (this file)
├── Gemma 4 2B Instruct-2-2b-it-Q6_K.gguf (Download separately)
├── phi-3.5-mini-instruct-Q4_K_M.gguf (Download separately)
├── qwen2.5-1.5b-instruct-Q8_0.gguf (Download separately)
└── ... (other models)
```

## Recommended Models (Based on PocketPal AI)

### For Medical CHW Use (Prioritized):

#### 1. **Phi-3.5 Mini Instruct** (RECOMMENDED for Medical)
- **Size**: 2.39 GB
- **Quantization**: Q4_K_M (good balance)
- **Best for**: Reasoning, medical queries, multilingual
- **Download**:
  ```
  https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf
  ```

#### 2. **MedGemma 4B Instruct** (High Quality)
- **Size**: 2.49 GB
- **Quantization**: Q6_K (higher quality)
- **Best for**: Question answering, summarization, reasoning
- **Download**:
  ```
  https://huggingface.co/Fadhili254/medgemma-4b-it-q4_k_m.gguf/resolve/main/medgemma-4b-it-q4_k_m.gguf
  ```

#### 3. **Qwen2.5-1.5B Instruct** (Lightweight)
- **Size**: 1.89 GB
- **Quantization**: Q8_0 (highest quality for size)
- **Best for**: Instructions, multilingual, fast inference
- **Download**:
  ```
  https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q8_0.gguf
  ```

#### 4. **Llama 3.2 3B Instruct** (Balanced)
- **Size**: 2.64 GB
- **Quantization**: Q6_K
- **Best for**: Instructions, summarization, rewriting
- **Download**:
  ```
  https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q6_K.gguf
  ```

### For Testing (Small Size):

#### 5. **SmolLM2-1.7B Instruct** (Testing)
- **Size**: 1.82 GB
- **Quantization**: Q8_0
- **Best for**: Testing, fast inference, low RAM
- **Download**:
  ```
  https://huggingface.co/bartowski/SmolLM2-1.7B-Instruct-GGUF/resolve/main/SmolLM2-1.7B-Instruct-Q8_0.gguf
  ```

## How to Download Models

### Method 1: Manual Download (Recommended)
1. Click the download link above
2. Save the `.gguf` file to this directory (`assets/ai_models/`)
3. The app will detect it automatically

### Method 2: Using curl (Windows PowerShell)
```powershell
cd C:\Users\eugene.ogembo\Documents\Projects\Augment-CHWs\assets\ai_models

# Download Phi-3.5 Mini (Recommended for Medical)
curl -L -o phi-3.5-mini-instruct-Q4_K_M.gguf "https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf"
```

### Method 3: Using wget (if installed)
```bash
wget -O phi-3.5-mini-instruct-Q4_K_M.gguf "https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf"
```

## File Naming Convention
- Use lowercase with hyphens
- Include quantization level in filename
- Example: `phi-3.5-mini-instruct-Q4_K_M.gguf`

## Storage Requirements
- **Minimum**: 2 GB free space (1 small model)
- **Recommended**: 10 GB free space (3-4 models)
- **Optimal**: 20 GB free space (full model library)

## Device Recommendations

### Low-End Devices (2-4GB RAM)
- Use Q4_K_M quantization
- Recommended: SmolLM2-1.7B, Qwen2.5-1.5B

### Mid-Range Devices (4-8GB RAM)
- Use Q4_K_M or Q6_K quantization
- Recommended: Phi-3.5 Mini, Gemma 2 2B

### High-End Devices (8GB+ RAM)
- Use Q6_K or Q8_0 quantization
- Recommended: Llama 3.2 3B, Qwen2.5-3B

## Quantization Levels Explained
- **Q4_K_M**: 4-bit, medium quality, smallest size (best for mobile)
- **Q5_K_M**: 5-bit, good quality, medium size
- **Q6_K**: 6-bit, high quality, larger size
- **Q8_0**: 8-bit, highest quality, largest size

## Model Selection in App
The app will automatically detect models in this directory. You can select which model to use from:
- **Settings > Offline AI > Model Selection**
- Or from the AI chat screen

## Notes
- Models are **NOT included** in the repository due to large file sizes
- Download at least one model for offline functionality
- First-time model loading may take 30-60 seconds
- Models are loaded into RAM, so choose based on device capabilities

## Troubleshooting

### Model Not Detected
- Ensure file extension is `.gguf`
- Restart the app after adding models
- Check file isn't corrupted (compare file size)

### App Crashes on Model Load
- Model too large for device RAM
- Try a smaller model or lower quantization
- Close other apps to free memory

### Slow Inference
- Use lower quantization (Q4_K_M instead of Q8_0)
- Reduce context size in settings
- Enable GPU acceleration if supported

## For Developers
Models are loaded via `OfflineModelProvider` in `lib/providers/offline_model_provider.dart`
Configuration: `lib/models/offline_context_params.dart`
