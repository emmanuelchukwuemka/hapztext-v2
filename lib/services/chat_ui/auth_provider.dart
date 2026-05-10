import 'package:flutter/foundation.dart';
import 'package:haptext_api/services/chat_ui/hapztext_api_service.dart';

class AuthProvider with ChangeNotifier {
  final HapzTextApiService _apiService = HapzTextApiService();
  bool _isAuthenticated = false;
  String? _currentUserToken;
  String? _currentUserId;

  bool get isAuthenticated => _isAuthenticated;
  String? get currentUserToken => _currentUserToken;
  String? get currentUserId => _currentUserId;
  HapzTextApiService get apiService => _apiService;

  /// Sync token from the main auth system (SessionManager/AuthCubit)
  /// Call this after login or when restoring a session from splash screen.
  void setTokenFromSession(String token, String? userId) {
    if (token.isNotEmpty) {
      _currentUserToken = token;
      _currentUserId = userId;
      _isAuthenticated = true;
      _apiService.setToken(token);
      _apiService.currentUserId = userId;
      notifyListeners();
    }
  }

  // Register a new user
  Future<bool> register({
    required String email,
    required String username,
    required String password,
  }) async {
    final result = await _apiService.registerUser(
      email: email,
      username: username,
      password: password,
    );

    if (result != null && result['success']) {
      // Auto-login after registration
      return await login(username: username, password: password);
    } else {
      return false;
    }
  }

  // Login user
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    final result = await _apiService.loginUser(
      username: username,
      password: password,
    );

    if (result != null &&
        (result['success'] == true || result['status_code'] == 200)) {
      _currentUserToken = result['data']['access_token'];
      // Handle different possible response shapes
      if (result['data']['user'] != null) {
        _currentUserId = result['data']['user']['id']?.toString();
      } else {
        _currentUserId = result['data']['user_id']?.toString();
      }
      _isAuthenticated = true;

      // Set the token and userId in the API service
      _apiService.setToken(_currentUserToken!);
      _apiService.currentUserId = _currentUserId;

      notifyListeners();
      return true;
    } else {
      return false;
    }
  }

  // Logout user
  Future<void> logout() async {
    _isAuthenticated = false;
    _currentUserToken = null;
    _currentUserId = null;
    _apiService.setToken(''); // Reset token in API service

    notifyListeners();
  }

  // Check if token is still valid
  Future<bool> checkAuthStatus() async {
    if (_currentUserToken != null) {
      // Try to make a simple API call to check if token is still valid
      final isConnected = await _apiService.testConnection();
      if (isConnected) {
        _isAuthenticated = true;
        _apiService.setToken(_currentUserToken!);
      } else {
        _isAuthenticated = false;
        _currentUserToken = null;
        _currentUserId = null;
      }
      notifyListeners();
      return _isAuthenticated;
    }
    return false;
  }

  // Initialize auth state (call this on app start)
  Future<void> initializeAuth() async {
    // Here you would typically check stored credentials
    // For now, just test if we have a stored token and if it's valid
    await checkAuthStatus();
  }
}
