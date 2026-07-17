import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';
import '../services/ai_service.dart' show AIService, AIServiceException;
import '../services/offline_ai_service.dart';
import '../services/connectivity_service.dart';
import './offline_model_provider.dart';

/// Mode for AI inference
enum AIMode {
  online, // Use online API (existing)
  offline, // Use offline llama.cpp model
}

/// Provider for managing chat sessions with online/offline AI routing.
///
/// This provider demonstrates the core online↔offline routing logic:
/// - User manually selects online or offline mode
/// - Smart fallback: if online mode fails and offline model is loaded, auto-falls back
/// - If no internet and no offline model, shows helpful error
///
/// NOTE: This is extracted from the full app. In the original app, it also
/// depends on DatabaseService for chat persistence. For the standalone
/// architecture, the database calls are replaced with TODO comments so
/// developers can plug in their own persistence layer.
class ChatProvider with ChangeNotifier {
  final AIService _aiService = AIService.instance;
  final OfflineAIService _offlineAIService = OfflineAIService.instance;
  final ConnectivityService _connectivityService = ConnectivityService.instance;
  final Uuid _uuid = const Uuid();

  // Persistence key for AI mode
  static const String _aiModeKey = 'chat_ai_mode';

  // AI mode selection - persisted across app restarts
  AIMode _aiMode = AIMode.online;

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _currentSessionId;
  bool _isInitialized = false;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get sessionId => _currentSessionId;
  AIMode get aiMode => _aiMode;
  bool get isInitialized => _isInitialized;

  /// Check if offline mode is available (model loaded)
  bool get isOfflineAvailable => _offlineAIService.isModelLoaded;

  /// Check if device is online
  bool get isOnline => _connectivityService.isOnline;

  ChatProvider() {
    // Initialize connectivity service but don't auto-switch modes
    // User manually chooses between online/offline
    _connectivityService.addListener(_handleConnectivityChange);
    // Immediately start async initialization (will complete in background)
    _initialize();
  }

  /// Main initialization that sets up AI mode
  Future<void> _initialize() async {
    await _initializeAIMode();
    _isInitialized = true;
    notifyListeners();
  }

  /// Initialize AI mode from saved preference or auto-detect
  Future<void> _initializeAIMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_aiModeKey);

    if (savedMode != null) {
      // Restore saved mode
      _aiMode = savedMode == 'offline' ? AIMode.offline : AIMode.online;
      debugPrint(
          '💾 Restored AI mode: ${_aiMode == AIMode.online ? "Online" : "Offline"}');
    } else {
      // Smart detection: if offline model is loaded, default to offline
      if (_offlineAIService.isModelLoaded) {
        _aiMode = AIMode.offline;
        debugPrint('🤖 Offline model detected - defaulting to offline mode');
      } else {
        _aiMode = AIMode.online;
        debugPrint(
            '🌐 No offline model yet - defaulting to online mode (will recheck)');
      }
    }
    notifyListeners();
  }

  /// Called by UI when OfflineModelProvider is available
  /// Rechecks if offline model is loaded and updates mode accordingly
  Future<void> checkAndUpdateModeFromModelState(
      OfflineModelProvider modelProvider) async {
    debugPrint('🔍 Checking mode against model state...');
    debugPrint('  Offline model loaded: ${_offlineAIService.isModelLoaded}');
    debugPrint(
        '  Current mode: ${_aiMode == AIMode.online ? "Online" : "Offline"}');

    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_aiModeKey);
    debugPrint('  Saved mode preference: $savedMode');

    if (savedMode == null &&
        _offlineAIService.isModelLoaded &&
        _aiMode == AIMode.online) {
      debugPrint(
          '✅ Model loaded after ChatProvider init - auto-switching to offline mode');
      _aiMode = AIMode.offline;
      await prefs.setString(_aiModeKey, 'offline');
      notifyListeners();
    } else {
      debugPrint('ℹ️  No mode change needed');
    }
  }

  /// Monitor connectivity changes for informational purposes
  /// Does NOT auto-switch modes - user controls that manually
  void _handleConnectivityChange() {
    notifyListeners();
    debugPrint(
        '📡 Connectivity changed: ${_connectivityService.isOnline ? "Online" : "Offline"}');
  }

  /// Switch AI mode (online/offline)
  Future<void> setAIMode(AIMode mode) async {
    // If switching to offline, check if model is loaded
    if (mode == AIMode.offline && !_offlineAIService.isModelLoaded) {
      debugPrint('❌ Cannot switch to offline mode: no model loaded');
      return;
    }
    _aiMode = mode;

    // Persist the mode
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _aiModeKey, mode == AIMode.online ? 'online' : 'offline');

    notifyListeners();
    debugPrint(
        '✅ AI mode switched to: ${mode == AIMode.online ? "Online" : "Offline"}');
  }

  /// Toggle between online and offline mode
  Future<void> toggleAIMode() async {
    final newMode = _aiMode == AIMode.online ? AIMode.offline : AIMode.online;
    await setAIMode(newMode);
  }

  // Start a new conversation session
  void startNewSession(String patientId, {String? patientName}) {
    _currentSessionId = _uuid.v4();
    final displayName = patientName ?? 'this patient';
    final initialMessage = ChatMessage(
      id: _uuid.v4(),
      patientId: patientId,
      sessionId: _currentSessionId!,
      sender: 'AI',
      message: 'Hello! How can I assist you with $displayName today?',
      timestamp: DateTime.now(),
    );
    _messages = [initialMessage];
    notifyListeners();
  }

  // Send a message and stream the response
  Future<void> sendMessage(String text, String patientId,
      {String? systemPrompt}) async {
    if (text.isEmpty) return;

    // Wait for initialization to complete before sending
    if (!_isInitialized) {
      debugPrint('⏳ Waiting for ChatProvider initialization...');
      int attempts = 0;
      while (!_isInitialized && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      if (!_isInitialized) {
        debugPrint('❌ ChatProvider initialization timeout');
        return;
      }
      debugPrint('✅ ChatProvider initialized, proceeding with message');
    }

    final userMessage = ChatMessage(
      id: _uuid.v4(),
      patientId: patientId,
      sessionId: _currentSessionId!,
      sender: 'You',
      message: text,
      timestamp: DateTime.now(),
    );

    // TODO: Persist user message to your database here
    _messages.add(userMessage);
    _isLoading = true;
    notifyListeners();

    // AI Response placeholder
    final aiResponse = ChatMessage(
      id: _uuid.v4(),
      patientId: patientId,
      sessionId: _currentSessionId!,
      sender: 'AI',
      message: '', // Start with an empty message
      timestamp: DateTime.now(),
    );
    _messages.add(aiResponse);
    notifyListeners();

    try {
      // Check connectivity and model availability
      if (_aiMode == AIMode.offline && !_offlineAIService.isModelLoaded) {
        // No offline model loaded - provide helpful guidance
        final index = _messages.indexWhere((m) => m.id == aiResponse.id);
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
              message: "No offline AI model is currently loaded.\n\n"
                  "To use the AI assistant offline:\n"
                  "1. Tap the menu (⋮) in the top right\n"
                  "2. Select 'Download Models'\n"
                  "3. If you haven't downloaded a model, download one (e.g., Phi-3.5 Mini - 2.4 GB)\n"
                  "4. If you have a downloaded model, tap 'Use Now' or select it from the list\n"
                  "5. Return here to chat\n\n"
                  "Or, connect to the internet to use online mode.");
        }
        // TODO: Persist AI message to your database here
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Smart routing: Check actual conditions, not just mode
      final hasInternet = _connectivityService.isOnline;
      final hasOfflineModel = _offlineAIService.isModelLoaded;

      debugPrint('📡 Routing decision:');
      debugPrint('  Mode: ${_aiMode == AIMode.online ? "Online" : "Offline"}');
      debugPrint('  Has Internet: $hasInternet');
      debugPrint('  Has Offline Model: $hasOfflineModel');

      if (_aiMode == AIMode.online) {
        // User wants online mode
        if (hasInternet) {
          debugPrint('  ✅ Trying online service...');
          try {
            await _handleOnlineResponse(text, patientId, aiResponse);
          } on AIServiceException catch (e) {
            debugPrint('  ⚠️ Online service failed: ${e.message}');
            if (hasOfflineModel && e.isNetworkError) {
              debugPrint('  🔄 Falling back to offline model');
              await _handleOfflineResponse(
                  text, patientId, aiResponse, systemPrompt);
            } else {
              final index = _messages.indexWhere((m) => m.id == aiResponse.id);
              if (index != -1) {
                _messages[index] = _messages[index].copyWith(
                    message: hasOfflineModel
                        ? "Online service error: ${e.message}\n\nSwitching to offline mode. Please try again."
                        : "Online service error: ${e.message}\n\nNo offline model available. Please check your connection or download an offline model.");
              }
              // TODO: Persist AI message to your database here
              _isLoading = false;
              notifyListeners();
              return;
            }
          }
        } else if (hasOfflineModel) {
          debugPrint('  ⚠️ No internet, falling back to offline model');
          await _handleOfflineResponse(
              text, patientId, aiResponse, systemPrompt);
        } else {
          debugPrint('  ❌ No internet and no offline model');
          final index = _messages.indexWhere((m) => m.id == aiResponse.id);
          if (index != -1) {
            _messages[index] = _messages[index].copyWith(
                message:
                    "No internet connection and no offline model available.\n\n"
                    "Please connect to the internet or download an offline model.");
          }
          // TODO: Persist AI message to your database here
          _isLoading = false;
          notifyListeners();
          return;
        }
      } else {
        // User wants offline mode - use offline service
        debugPrint('  📱 Using offline service');
        await _handleOfflineResponse(text, patientId, aiResponse, systemPrompt);
      }

      // TODO: Persist final AI message to your database here
    } catch (e) {
      final index = _messages.indexWhere((m) => m.id == aiResponse.id);
      if (index != -1) {
        _messages[index] =
            _messages[index].copyWith(message: "Sorry, an error occurred: $e");
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Handle online AI response (existing behavior)
  Future<void> _handleOnlineResponse(
      String text, String patientId, ChatMessage aiResponse) async {
    final stream =
        _aiService.generateResponseStream("For patient $patientId: $text");
    String currentResponse = '';

    await for (var token in stream) {
      currentResponse += token;
      final index = _messages.indexWhere((m) => m.id == aiResponse.id);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(message: currentResponse);
        notifyListeners();
      }
    }
  }

  /// Handle offline AI response (new functionality)
  Future<void> _handleOfflineResponse(String text, String patientId,
      ChatMessage aiResponse, String? systemPrompt) async {
    try {
      final effectiveSystemPrompt =
          systemPrompt ?? AIService.offlineSystemPrompt;

      String currentResponse = '';

      // Stream raw tokens so the user sees activity while the model generates
      await for (var token in _offlineAIService.generateResponseStream(
        prompt: text,
        systemPrompt: effectiveSystemPrompt,
      )) {
        currentResponse += token;
        final index = _messages.indexWhere((m) => m.id == aiResponse.id);
        if (index != -1) {
          _messages[index] =
              _messages[index].copyWith(message: currentResponse);
          notifyListeners();
        }
      }

      // Post-process the completed response: strip markdown, normalise sections, safety filter
      final processed = _aiService.processOfflineResponse(currentResponse);
      final index = _messages.indexWhere((m) => m.id == aiResponse.id);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(message: processed);
        notifyListeners();
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error in offline response: $e');
      debugPrint('Stack trace: $stackTrace');

      final index = _messages.indexWhere((m) => m.id == aiResponse.id);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
            message: "Sorry, the offline AI model encountered an error.\n\n"
                "Error: $e\n\n"
                "Try:\n"
                "1. Reloading the model from the Download Models screen\n"
                "2. Using a different model\n"
                "3. Switching to online mode if you have internet");
        notifyListeners();
      }
    }
  }

  // Permanently deletes all conversations for a patient
  Future<void> deleteAllHistory(String patientId) async {
    // TODO: Delete from your database here
    _messages = [];
    startNewSession(patientId);
  }
}
