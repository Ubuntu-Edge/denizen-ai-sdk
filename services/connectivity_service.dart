import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service to monitor network connectivity and automatically manage online/offline state
/// This service verifies ACTUAL internet connectivity, not just network interface status
class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService instance = ConnectivityService._init();
  ConnectivityService._init();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _periodicCheckTimer;
  
  bool _isOnline = false; // Start as offline until verified
  bool _hasNetworkInterface = false;
  bool get isOnline => _isOnline;
  bool get hasNetworkInterface => _hasNetworkInterface;
  
  bool _hasCheckedInitialState = false;
  bool _isCheckingConnectivity = false;
  
  /// URLs to check for internet connectivity
  static const List<String> _connectivityCheckUrls = [
    'https://www.google.com',
    'https://www.cloudflare.com',
    'https://www.microsoft.com',
  ];
  
  /// Timeout for connectivity checks
  static const Duration _connectivityTimeout = Duration(seconds: 5);
  
  /// Interval for periodic connectivity checks when network is available
  static const Duration _periodicCheckInterval = Duration(seconds: 30);

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    await _updateConnectionStatus(result);
    _hasCheckedInitialState = true;
    
    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) async {
      await _updateConnectionStatus(results);
    });
    
    // Start periodic connectivity checks
    _startPeriodicCheck();
    
    debugPrint('🌐 Connectivity service initialized. Initial status: ${_isOnline ? "Online" : "Offline"}');
  }

  /// Start periodic connectivity verification
  void _startPeriodicCheck() {
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = Timer.periodic(_periodicCheckInterval, (_) async {
      if (_hasNetworkInterface && !_isCheckingConnectivity) {
        await _verifyActualConnectivity();
      }
    });
  }

  /// Update connection status based on connectivity result
  Future<void> _updateConnectionStatus(List<ConnectivityResult> results) async {
    final wasOnline = _isOnline;
    final hadInterface = _hasNetworkInterface;
    
    // Check if any network interface is available (WiFi, Mobile, Ethernet)
    _hasNetworkInterface = results.any((result) => 
      result == ConnectivityResult.wifi ||
      result == ConnectivityResult.mobile ||
      result == ConnectivityResult.ethernet
    );
    
    if (!_hasNetworkInterface) {
      // No network interface at all - definitely offline
      _isOnline = false;
      if (wasOnline) {
        debugPrint('❌ Network interface lost - Switching to offline mode');
        notifyListeners();
      }
      return;
    }
    
    // Network interface available - verify actual internet connectivity
    if (_hasNetworkInterface && (!hadInterface || !_isOnline)) {
      debugPrint('📡 Network interface detected, verifying internet connectivity...');
      await _verifyActualConnectivity();
    }
    
    if (wasOnline != _isOnline && _hasCheckedInitialState) {
      debugPrint(_isOnline 
        ? '✅ Internet connection verified - Switching to online mode' 
        : '❌ No internet access - Switching to offline mode'
      );
      notifyListeners();
    } else if (!_hasCheckedInitialState) {
      notifyListeners();
    }
  }

  /// Verify actual internet connectivity by making HTTP requests
  Future<bool> _verifyActualConnectivity() async {
    if (_isCheckingConnectivity) return _isOnline;
    
    _isCheckingConnectivity = true;
    final wasOnline = _isOnline;
    
    try {
      // Try multiple endpoints in case one is blocked
      for (final url in _connectivityCheckUrls) {
        try {
          final response = await http.head(
            Uri.parse(url),
          ).timeout(_connectivityTimeout);
          
          if (response.statusCode >= 200 && response.statusCode < 400) {
            _isOnline = true;
            if (!wasOnline) {
              debugPrint('✅ Internet connectivity verified via $url');
              notifyListeners();
            }
            _isCheckingConnectivity = false;
            return true;
          }
        } on SocketException {
          continue;
        } on TimeoutException {
          continue;
        } on http.ClientException {
          continue;
        } catch (e) {
          continue;
        }
      }
      
      // All URLs failed - no internet
      _isOnline = false;
      if (wasOnline) {
        debugPrint('❌ Internet connectivity check failed - all endpoints unreachable');
        notifyListeners();
      }
      _isCheckingConnectivity = false;
      return false;
    } catch (e) {
      _isOnline = false;
      debugPrint('❌ Connectivity check error: $e');
      if (wasOnline) {
        notifyListeners();
      }
      _isCheckingConnectivity = false;
      return false;
    }
  }

  /// Force a connectivity check - useful when user wants to verify status
  Future<bool> checkConnectivity() async {
    if (!_hasNetworkInterface) {
      _isOnline = false;
      notifyListeners();
      return false;
    }
    return await _verifyActualConnectivity();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicCheckTimer?.cancel();
    super.dispose();
  }
}
