import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/chat_message.dart';
import '../services/offline_ai_service.dart';
import 'document_provider.dart';

class SessionProvider with ChangeNotifier {
  List<ChatMessage> _chatMessages = [];
  bool _isGenerating = false;
  bool _isOffline = true;
  String? _activeDocumentId;
  String _activeSessionTitle = 'Socratic Tutor';
  String _activeSessionMeta = 'Offline · EN';

  late Box _sessionBox;
  bool _isInitialized = false;

  // Conversation history for context window
  final List<Map<String, String>> _history = [];

  List<ChatMessage> get chatMessages => _chatMessages;
  bool get isGenerating => _isGenerating;
  bool get isOffline => _isOffline;
  String get activeSessionTitle => _activeSessionTitle;
  String get activeSessionMeta => _activeSessionMeta;
  String? get activeDocumentId => _activeDocumentId;

  // ─── Init ────────────────────────────────────────────────────

  Future<void> init() async {
    _sessionBox = await Hive.openBox('tutor_sessions');
    _loadSession();
    _isInitialized = true;
    notifyListeners();
  }

  void _loadSession() {
    final stored = _sessionBox.get('messages');
    if (stored != null) {
      final list = List<Map>.from(stored);
      _chatMessages = list.map((e) {
        return ChatMessage(
          id: e['id'],
          role: e['role'] == 'user' ? MessageRole.user : MessageRole.ai,
          content: e['content'],
          timestamp: DateTime.parse(e['timestamp']),
        );
      }).toList();
    } else {
      _chatMessages = [
        ChatMessage(
          id: 'welcome',
          role: MessageRole.ai,
          content:
          'Hello! I\'m your Socratic tutor. Upload a document and ask me anything about it — I\'ll guide you through it with questions rather than just giving answers.',
          timestamp: DateTime.now(),
        ),
      ];
    }

    _activeDocumentId = _sessionBox.get('activeDocumentId');
    _activeSessionTitle =
        _sessionBox.get('activeSessionTitle') ?? 'Socratic Tutor';
  }

  void _saveSession() {
    final list = _chatMessages.map((m) => {
      'id': m.id,
      'role': m.role == MessageRole.user ? 'user' : 'ai',
      'content': m.content,
      'timestamp': m.timestamp.toIso8601String(),
    }).toList();
    _sessionBox.put('messages', list);
    _sessionBox.put('activeDocumentId', _activeDocumentId);
    _sessionBox.put('activeSessionTitle', _activeSessionTitle);
  }

  // ─── Document Selection ──────────────────────────────────────

  void setActiveDocument(String documentId, String documentName) {
    _activeDocumentId = documentId;
    _activeSessionTitle = documentName;
    _activeSessionMeta = 'Offline · EN';
    _history.clear(); // reset history when doc changes
    _saveSession();
    notifyListeners();
  }

  // ─── Send Message ────────────────────────────────────────────

  Future<void> sendMessage(
      String text, {
        required DocumentProvider docProvider,
        bool socratic = true,
        String language = 'the same language the student uses',
      }) async {
    if (text.trim().isEmpty) return;
    if (!_isInitialized) await init();

    // Add user message
    final userMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      role: MessageRole.user,
      content: text,
      timestamp: DateTime.now(),
    );
    _chatMessages.add(userMsg);
    _history.add({'role': 'user', 'content': text});
    _isGenerating = true;
    notifyListeners();

    // Add empty AI message placeholder for streaming
    final aiMsgId = 'msg_${DateTime.now().millisecondsSinceEpoch}_ai';
    final aiMsg = ChatMessage(
      id: aiMsgId,
      role: MessageRole.ai,
      content: '',
      timestamp: DateTime.now(),
    );
    _chatMessages.add(aiMsg);
    notifyListeners();

    try {
      // Get relevant chunks if a document is selected
      List<String> chunks = [];
      if (_activeDocumentId != null) {
        chunks = docProvider.getRelevantChunks(_activeDocumentId!, text);
      }

      // Check model is loaded
      if (!OfflineAIService.instance.isModelLoaded) {
        _updateLastMessage(
          'No model loaded. Please go to Settings and download a model first.',
        );
        _isGenerating = false;
        notifyListeners();
        return;
      }

      // Stream response
      String accumulated = '';
      await for (final token in OfflineAIService.instance.tutorStream(
        userMessage: text,
        contextChunks: chunks,
        history: _history,
        socratic: socratic,
        language: language,
      )) {
        accumulated += token;
        _updateLastMessage(accumulated);
      }

      // Save AI response to history
      _history.add({'role': 'assistant', 'content': accumulated});

      // Keep history to last 10 turns to stay within context window
      if (_history.length > 10) {
        _history.removeRange(0, _history.length - 10);
      }
    } catch (e) {
      _updateLastMessage('Sorry, something went wrong: $e');
    }

    _isGenerating = false;
    _saveSession();
    notifyListeners();
  }

  void _updateLastMessage(String content) {
    if (_chatMessages.isEmpty) return;
    final last = _chatMessages.last;
    _chatMessages[_chatMessages.length - 1] = ChatMessage(
      id: last.id,
      role: last.role,
      content: content,
      timestamp: last.timestamp,
    );
    notifyListeners();
  }

  // ─── Status ───────────────────────────────────────────────────

  void toggleOffline() {
    _isOffline = !_isOffline;
    notifyListeners();
  }

  // ─── Clear ───────────────────────────────────────────────────

  void clearChat() {
    _history.clear();
    _chatMessages = [
      ChatMessage(
        id: 'welcome',
        role: MessageRole.ai,
        content:
        'Session reset. Socratic tutor is ready. What would you like to explore?',
        timestamp: DateTime.now(),
      ),
    ];
    _saveSession();
    notifyListeners();
  }

  void updateActiveSession(String title, String meta) {
    _activeSessionTitle = title;
    _activeSessionMeta = meta;
    notifyListeners();
  }
}
