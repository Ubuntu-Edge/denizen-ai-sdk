// Denizen AI Website Interactive Script

// Theme Toggle
const themeToggleBtn = document.getElementById('theme-toggle');
const htmlEl = document.documentElement;

themeToggleBtn.addEventListener('click', () => {
  if (htmlEl.classList.contains('dark')) {
    htmlEl.classList.remove('dark');
    htmlEl.classList.add('light');
    themeToggleBtn.innerHTML = '<i class="fa-solid fa-sun"></i>';
  } else {
    htmlEl.classList.remove('light');
    htmlEl.classList.add('dark');
    themeToggleBtn.innerHTML = '<i class="fa-solid fa-moon"></i>';
  }
});

// Copy Command Function
function copyInstallCmd() {
  const cmdText = document.getElementById('pub-command').innerText;
  navigator.clipboard.writeText(cmdText).then(() => {
    const copyText = document.getElementById('copy-text');
    const copyIcon = document.getElementById('copy-icon');
    
    copyText.innerText = 'Copied!';
    copyIcon.className = 'fa-solid fa-check text-mint';
    
    setTimeout(() => {
      copyText.innerText = 'Copy';
      copyIcon.className = 'fa-regular fa-copy';
    }, 2000);
  });
}

// Quant Studio Interactive Simulator
const quantData = {
  'Q4_K_M': { orig: '6.8 GB', quant: '1.9 GB', ram: '2.4 GB', ratio: '3.5x' },
  'Q5_K_M': { orig: '6.8 GB', quant: '2.4 GB', ram: '3.0 GB', ratio: '2.8x' },
  'Q8_0':   { orig: '6.8 GB', quant: '3.7 GB', ram: '4.2 GB', ratio: '1.8x' },
  'Q2_K':   { orig: '6.8 GB', quant: '1.1 GB', ram: '1.6 GB', ratio: '6.1x' }
};

function updateQuantSim() {
  const select = document.getElementById('quant-method');
  const selected = select.value;
  const data = quantData[selected];

  document.getElementById('stat-orig').innerText = data.orig;
  document.getElementById('stat-quant').innerText = data.quant;
  document.getElementById('stat-ram').innerText = data.ram;
}

function simulateQuantization() {
  const btn = document.getElementById('run-quant-btn');
  const consoleLogs = document.getElementById('console-logs');
  const progressFill = document.getElementById('quant-progress');
  const selected = document.getElementById('quant-method').value;

  btn.disabled = true;
  btn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Quantizing Model...';
  progressFill.style.width = '0%';

  const logs = [
    `[INFO] Target selected: ${selected} (GGUF Format)`,
    `[INFO] Analyzing model layers: 32 Attention Blocks, 4096 Hidden Dim`,
    `[INFO] Preserving local Swahili/English vocabulary & clinical tokenizer...`,
    `[RUNNING] Applying ${selected} quantization matrix...`,
    `[STATUS] Extracting weights & compiling GBNF grammar constraints...`,
    `[SUCCESS] GGUF Model successfully compiled! Output size: ${quantData[selected].quant}`,
    `[READY] Package ready for Flutter deployment with zero cloud dependencies!`
  ];

  let currentStep = 0;
  consoleLogs.innerHTML = `<span class="log-info">[START] Beginning Quant Studio build...</span>\n`;

  const interval = setInterval(() => {
    if (currentStep < logs.length) {
      const stepText = logs[currentStep];
      let cssClass = 'log-info';
      if (stepText.includes('SUCCESS')) cssClass = 'log-success';
      if (stepText.includes('RUNNING') || stepText.includes('STATUS')) cssClass = 'log-warn';

      consoleLogs.innerHTML += `<span class="${cssClass}">${stepText}</span>\n`;
      consoleLogs.scrollTop = consoleLogs.scrollHeight;
      
      currentStep++;
      progressFill.style.width = `${Math.min(100, (currentStep / logs.length) * 100)}%`;
    } else {
      clearInterval(interval);
      btn.disabled = false;
      btn.innerHTML = '<i class="fa-solid fa-check"></i> Quantization Complete!';
      
      setTimeout(() => {
        btn.innerHTML = '<i class="fa-solid fa-play"></i> Run One-Click Quantization';
      }, 3000);
    }
  }, 600);
}

// Code Demo Tab Switcher
const codeSnippets = {
  init: `import 'package:flutter/material.dart';
import 'package:denizen_ai/denizen_ai.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // High-level DenizenAI Singleton instance
  final denizen = DenizenAI();

  final docsDir = await getApplicationDocumentsDirectory();
  final modelPath = '\${docsDir.path}/models/ubuntu-afya-medgemma.gguf';

  // Download & load GGUF model into native memory
  await denizen.models.initializeModel(modelPath: modelPath);

  // Start stateful session & stream tokens locally
  final session = denizen.createSession();
  final tokenStream = session.chatStream('What are the primary danger signs in pediatric fever?');

  await for (final token in tokenStream) {
    print(token);
  }
}`,

  rag: `import 'package:denizen_ai/denizen_ai.dart';

// Initialize Offline RAG Service with local vector storage
final ragService = DocumentIngestionService(
  embeddingProvider: TFLiteEmbeddingProvider(),
);

// Ingest domain guidelines PDF offline
await ragService.ingestDocument(
  filePath: '/path/to/treatment_guidelines.pdf',
);

// Query local sqlite-vec database
final matches = await ragService.queryVectorStore(
  query: 'Emergency protocol for pediatric fever',
  topK: 3,
);

for (final match in matches) {
  print('Snippet: \${match.content} (Score: \${match.score})');
}`,

  triage: `import 'package:denizen_ai/denizen_ai.dart';

// Custom on-device tool definition
class EmergencyTriageTool extends DenizenTool {
  EmergencyTriageTool()
      : super(
          name: 'log_emergency_triage',
          description: 'Logs patient triage assessment',
          parametersSchema: {
            'type': 'object',
            'properties': {
              'urgency_level': {
                'type': 'string',
                'enum': ['NORMAL', 'URGENT', 'CRITICAL_REFERRAL']
              },
            },
            'required': ['urgency_level']
          },
        );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    return {'status': 'recorded', 'priority': arguments['urgency_level']};
  }
}

final registry = DenizenToolRegistry();
registry.register(EmergencyTriageTool());

final denizen = DenizenAI();
final toolSession = denizen.createToolSession(registry: registry);

// Guarantees 100% valid structured JSON output without syntax errors
final result = await toolSession.chat('Evaluate patient with high fever & neck stiffness.');
print(result);`,

  voice: `import 'package:denizen_ai/denizen_ai.dart';

final denizen = DenizenAI();

// Initialize Hands-Free Voice Consultation Session
final voiceSession = denizen.createVoiceSession();

// Start hands-free voice loop for field operations
await voiceSession.startListening(
  onSpeechRecognized: (userVoiceText) {
    print('User Spoke: \$userVoiceText');
  },
  onResponseGenerated: (aiReplyText) {
    print('AI Replied: \$aiReplyText');
  },
);`
};

function switchTab(tabKey) {
  const tabs = document.querySelectorAll('.tab-btn');
  tabs.forEach(t => t.classList.remove('active'));
  
  event.target.classList.add('active');
  document.getElementById('code-display').innerText = codeSnippets[tabKey];
}

// Registration Form Simulation
function handleRegistration(e) {
  e.preventDefault();
  const msg = document.getElementById('reg-msg');
  msg.className = 'reg-message text-mint';
  msg.innerText = '🎉 You are on the priority list for the next Buildathon!';
  e.target.reset();
}
