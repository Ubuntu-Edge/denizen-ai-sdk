# Ubuntu Elimu: Enterprise-Grade Offline Student Copilot

Ubuntu Elimu is a fully autonomous, local-first educational copilot engineered to bypass the digital divide. By running state-of-the-art quantized Small Language Models (SLMs) natively on consumer edge devices, it eliminates internet dependency, cellular data costs, and cloud infrastructure latency.

Built directly on top of the Ubuntu Edge AI architecture, Ubuntu Elimu turns standard tablets, smartphones, and low-cost computer labs into secure, high-performance, and deeply personalized Socratic educational hubs.

## 🚀 Key Features

*   **Offline AI Tutor:** Active Socratic retrieval that guides students through curriculum concepts instead of giving raw answers.
*   **PDF & Document Summarizer:** Hierarchical Map-Reduce summarization pipeline built to avoid Out-of-Memory (OOM) errors on low-spec hardware.
*   **Exam Prep & Flashcards:** Automatic JSON extraction of key definitions mapped directly to a local, offline SM-2 spaced repetition engine.
*   **Bilingual Cognitive Scaffolding:** Real-time, localized translation and tutoring (e.g., Kiswahili, French, and local dialects) run entirely offline.
*   **Lecture Notes & QA:** High-precision local Retrieval-Augmented Generation (RAG) powered by hardware-accelerated semantic search.
*   **Research Assistant:** Synthesis and cross-referencing between handbooks, upload files, and personal study histories.
*   **Offline Past Paper Assessor:** Evaluates draft student exam responses against compressed, pre-loaded national marking schemes.

## 🏗️ Technical Pipeline & Architecture

Ubuntu Elimu executes the entire document extraction, embedding, vector storage, and generation loop completely offline:

```text
[ Student Ingests: PDF, Slides, Notes ]
           │
           ▼
[ Local Document Parser Isolate ]
- Structured Native Parser
- Dynamic 300-Token Chunking
           │
           ▼
[ Local Embedding Engine: ONNX / BGE-Micro ]
- Ultra-lightweight 384-dimensional extraction
           │
           ▼
[ Embedded Vector DB: sqlite-vec ]
- Local hardware-accelerated similarity search
           │
           ▼
[ Local SLMs: Llama 3.2 1B & 3B GGUF Q4_K_M ]
- Hardware-optimized inference and streaming
```

## 🛠️ Tech Stack

*   **Frontend:** [Flutter](https://flutter.dev/) (Multi-platform)
*   **UI Design:** Custom Dark Theme with Space Grotesk & Inter typography.
*   **Local Inference:** [MediaPipe LLM Inference](https://developers.google.com/mediapipe/solutions/genai/llm_inference) / [llama.cpp](https://github.com/ggerganov/llama.cpp) (GGUF support).
*   **Vector Database:** [sqlite-vec](https://github.com/asg017/sqlite-vec) for high-performance edge similarity search.
*   **Embeddings:** BGE-micro-v2 (quantized) for semantic understanding.
*   **State Management:** Riverpod.

## 📦 Getting Started

### Prerequisites
*   Flutter SDK (stable)
*   Android NDK (for native library support)
*   Minimum 4GB RAM on target device for 1B/3B model inference.

### Installation
1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-org/ubuntu-elimu.git
    cd ubuntu-elimu
    ```
2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```
3.  **Setup Models:**
    Place your quantized GGUF models in the `assets/models/` directory as specified in the configuration.
4.  **Run the application:**
    ```bash
    flutter run --release
    ```

## 🤝 Contributing

We welcome educational researchers, edge AI developers, and hardware enthusiasts to join us in building an open-source educational standard for offline learning. Please read our `CONTRIBUTING.md` guidelines for detailing security sandboxes, hardware testing protocols, and local translation alignment pipelines.

## 📄 License

This project is licensed under the Apache 2.0 License - see the [LICENSE](LICENSE) file for details.
