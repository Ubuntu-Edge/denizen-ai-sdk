# Developer Walkthrough: Building an Offline Medical AI App for Community Health Workers (CHWs)

> **Use Case**: Building a 100% offline, privacy-first mobile medical assistant for Community Health Workers (CHWs) operating in rural/low-connectivity clinics.  
> **Key Capabilities**: Offline Clinical Q&A, WHO Treatment Guidelines RAG, Structured Emergency Triage Tool Calling, Hands-Free Voice Consultation, and Image Analysis.

---

## 🎯 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│              CHW Rural Mobile Application (Flutter)                     │
│ ┌───────────────────┐ ┌────────────────────┐ ┌──────────────────────┐ │
│ │  Hands-free Voice │ │  Clinical Document │ │ Emergency Triage &   │ │
│ │  Consultation     │ │  RAG Guidelines    │ │ Structured Forms     │ │
│ └─────────┬─────────┘ └──────────┬─────────┘ └──────────┬───────────┘ │
├───────────┼──────────────────────┼──────────────────────┼─────────────┤
│           ▼                      ▼                      ▼             │
│                       Denizen AI SDK Layer                            │
│ ┌───────────────────┐ ┌────────────────────┐ ┌──────────────────────┐ │
│ │DenizenVoiceSession│ │ DocumentIngestion  │ │  DenizenToolSession  │ │
│ │ (STT / TTS Loop)  │ │   Service (RAG)    │ │ (GBNF Schema Triage) │ │
│ └─────────┬─────────┘ └──────────┬─────────┘ └──────────┬───────────┘ │
│           │                      │                      │             │
│           └──────────────────────┼──────────────────────┘             │
│                                  ▼                                    │
│                         DenizenEngine (GGUF)                          │
├───────────────────────────────────────────────────────────────────────┤
│                 Native Hardware Acceleration (Offline)                │
│    • Android (libllama.so)               • Windows (vec0.dll)         │
└───────────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Step 1: Add Dependencies to `pubspec.yaml`

Add `denizen_ai` and standard Flutter helper packages:

```yaml
name: rural_chw_medical_app
description: "Offline CHW Assistant"
publish_to: 'none'

environment:
  sdk: '>=3.3.0 <4.0.0'
  flutter: '>=3.24.0'

dependencies:
  flutter:
    sdk: flutter

  # Denizen AI Offline SDK (precompiled binary distribution)
  denizen_ai:
    git:
      url: https://github.com/Ubuntu-Edge/denizen-ai-sdk.git
      ref: main

  # File handling & storage
  path_provider: ^2.1.1
  file_picker: ^10.3.7

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

---

## 🧠 Step 2: Initialize Denizen AI Engine & Load Medical Model

In rural clinics, models are downloaded once over Wi-Fi at the district center and saved to local app storage:

```dart
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:denizen_ai/denizen_ai.dart';
import 'package:path/path.dart' as p;

class MedicalEngineService {
  static final MedicalEngineService instance = MedicalEngineService._();
  MedicalEngineService._();

  final DenizenEngine engine = DenizenEngine();
  bool isInitialized = false;

  /// Load a medical LLM GGUF model from device storage
  Future<void> initializeMedicalEngine() async {
    if (isInitialized) return;

    final docsDir = await getApplicationDocumentsDirectory();
    final modelPath = p.join(docsDir.path, 'models', 'medgemma-4b-Q4_K.gguf');

    await engine.initialize(
      modelPath: modelPath,
      contextSize: 2048,
      gpuLayers: 0, // 0 for CPU; > 0 if device has GPU acceleration
    );

    isInitialized = true;
    print('✅ Medical AI Engine loaded and ready offline!');
  }
}
```

---

## 🔍 Step 3: Offline Medical Guidelines Search (RAG)

CHWs need instant access to official **Ministry of Health (MOH) & WHO Clinical Treatment Guidelines** without internet access:

```dart
import 'package:denizen_ai/denizen_ai.dart';

class ClinicalGuidelineRAG {
  final DocumentIngestionService _ragService = DocumentIngestionService(
    embeddingProvider: TFLiteEmbeddingProvider(),
  );

  /// 1. Ingest WHO Treatment Guidelines PDF into local vector storage
  Future<void> indexGuidelines(String pdfPath) async {
    print('Indexing clinical guidelines...');
    await _ragService.ingestDocument(filePath: pdfPath);
    print('Indexing complete!');
  }

  /// 2. Query Guidelines Offline during patient consultation
  Future<List<String>> searchTreatmentProtocol(String symptomQuery) async {
    final matches = await _ragService.queryVectorStore(
      query: symptomQuery,
      topK: 3,
    );

    return matches.map((m) => m.content).toList();
  }
}
```

---

## 🛠️ Step 4: Structured Emergency Patient Triage (Tool Calling)

To prevent clinical errors, the AI must output **strictly validated JSON structured emergency triage reports** using dynamic GBNF grammar constraints:

```dart
import 'package:denizen_ai/denizen_ai.dart';

class PatientTriageManager {
  final DenizenToolRegistry registry = DenizenToolRegistry();
  late final DenizenToolSession toolSession;

  PatientTriageManager(DenizenEngine engine) {
    // Register Emergency Triage Form Tool with JSON Schema validation
    registry.registerTool(
      name: 'log_emergency_triage',
      description: 'Logs patient triage assessment and referral priority',
      parameters: {
        'type': 'object',
        'properties': {
          'patient_age': {'type': 'integer'},
          'primary_symptom': {'type': 'string'},
          'danger_signs': {
            'type': 'array',
            'items': {'type': 'string'}
          },
          'urgency_level': {
            'type': 'string',
            'enum': ['NORMAL', 'URGENT', 'CRITICAL_REFERRAL']
          },
          'recommended_action': {'type': 'string'}
        },
        'required': ['patient_age', 'primary_symptom', 'urgency_level', 'recommended_action']
      },
      handler: (args) async {
        // Save structured record to local SQLite clinic database
        print('🚨 EMERGENCY TRIAGE RECORD: $args');
        return 'Triage recorded successfully. Referral Priority: ${args['urgency_level']}';
      },
    );

    toolSession = DenizenToolSession(
      engine: engine,
      registry: registry,
    );
  }

  /// Execute triage reasoning with enforced GBNF JSON Schema
  Future<String> evaluatePatientCase(String patientVitalsNotes) async {
    return await toolSession.chat(
      'Evaluate patient: $patientVitalsNotes. Log emergency triage status if danger signs exist.',
    );
  }
}
```

---

## 🎙️ Step 5: Hands-Free Voice Consultation in Rural Home Visits

CHWs examining patients in home visits need a hands-free voice consultation loop:

```dart
import 'package:denizen_ai/denizen_ai.dart';

class CHWVoiceConsultation {
  late final DenizenVoiceSession _voiceSession;

  CHWVoiceConsultation(DenizenEngine engine) {
    _voiceSession = DenizenVoiceSession(
      engine: engine,
      sttService: OfflineAudioService(),
    );
  }

  /// Start hands-free clinical voice session
  Future<void> startVoiceConsultation({
    required Function(String userVoiceText) onCHWSpoke,
    required Function(String aiVoiceReply) onAIAwsered,
  }) async {
    await _voiceSession.startListening(
      onSpeechRecognized: (text) {
        onCHWSpoke(text);
      },
      onResponseGenerated: (reply) {
        onAIAwsered(reply);
      },
    );
  }
}
```

---

## 👁️ Step 6: Visual Wound & Skin Lesion Inspection (Vision Session)

Analyze clinical photos of skin lesions, rash, or wound healing offline:

```dart
import 'dart:typed_data';
import 'package:denizen_ai/denizen_ai.dart';

class ClinicalVisionInspector {
  final DenizenVisionSession _visionSession = DenizenVisionSession(
    systemPrompt: 'You are a clinical skin lesion inspector assistant.',
  );

  /// Analyze wound photo bytes offline
  Future<String> inspectSkinWound(Uint8List imageBytes) async {
    return await _visionSession.analyzeImage(
      imageBytes,
      prompt: 'Check for signs of infection, inflammation, or erythema.',
    );
  }
}
```

---

## 📱 Complete Developer App Workflow Summary

1. **At District Health Center (Online)**:
   - CHW syncs app and downloads local GGUF medical model (`medgemma-4b-Q4_K.gguf`) & WHO PDF guidelines once.

2. **In Remote Village (100% Offline)**:
   - **Voice**: CHW asks questions hands-free during patient examination.
   - **RAG**: App queries local vector database for exact MOH dosage protocols.
   - **Tools**: Emergency danger signs automatically trigger a validated `CRITICAL_REFERRAL` JSON log.
   - **Vision**: CHW captures wound photo for immediate local visual inspection.

---

## 🔒 Security & Medical Compliance

- **Zero Cloud Leakage**: Patient vitals and clinical notes never leave the device.
- **Audit Compliance**: All structured triage logs are written locally with full cryptographic hash logs.
