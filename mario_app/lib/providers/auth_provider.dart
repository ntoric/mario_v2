import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend/backend_service.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  final BackendService _backend = BackendService();
  
  User? _user;
  Store? _currentStore;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;
  bool _isDbConnected = false;

  User? get user => _user;
  Store? get currentStore => _currentStore;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;
  bool get isDbConnected => _isDbConnected;
  BackendService get backend => _backend;

  bool get canViewStats => 
    _user?.role == 'superadmin' || _user?.role == 'business_owner';

  Future<void> initialize() async {
    await _backend.initialize();
    
    // Set up status change listener
    _backend.database.onConnectionStatusChanged.listen((connected) async {
      if (_isDbConnected != connected) {
        _isDbConnected = connected;
        
        if (_isDbConnected && !_isAuthenticated) {
          final prefs = await SharedPreferences.getInstance();
          final savedToken = prefs.getString('auth_token');
          if (savedToken != null) {
            try {
              _backend.currentToken = savedToken;
              final isValid = await _backend.validateToken();
              if (isValid) {
                _user = User.fromJson(_backend.currentUser!);
                _isAuthenticated = true;
                if (_user?.stores != null && _user!.stores!.isNotEmpty) {
                  _currentStore = _user!.stores!.first;
                }
              }
            } catch (e) {
              print('Lazy-connect token validation error: $e');
            }
          }
        }
        notifyListeners();
      }
    });

    // Attempt startup connection
    try {
      final connected = await _backend.database.connect().timeout(const Duration(seconds: 3));
      _isDbConnected = connected;
    } catch (e) {
      _isDbConnected = false;
      print('Auto-connect database error on startup: $e');
    }
    
    // Try to load saved token
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('auth_token');
    
    if (_isDbConnected && savedToken != null) {
      try {
        _backend.currentToken = savedToken;
        final isValid = await _backend.validateToken();
        if (isValid) {
          _user = User.fromJson(_backend.currentUser!);
          _isAuthenticated = true;
          
          if (_user?.stores != null && _user!.stores!.isNotEmpty) {
            _currentStore = _user!.stores!.first;
          }
        }
      } catch (e) {
        _isAuthenticated = false;
        print('Token validation error on startup: $e');
      }
    }
    
    notifyListeners();
  }

  Future<bool> connectDatabase(DatabaseConfig config) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final connected = await _backend.connectToDatabase(config);
      _isDbConnected = connected;
      
      if (!connected) {
        _error = 'Failed to connect to database. Please check your settings.';
      }
      
      _isLoading = false;
      notifyListeners();
      return connected;
    } catch (e) {
      _error = 'Database connection error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String username, String password) async {
    if (!_isDbConnected) {
      _error = 'Database not connected. Please configure database first.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _backend.login(username, password);
      
      if (success) {
        _user = User.fromJson(_backend.currentUser!);
        _isAuthenticated = true;
        
        if (_user?.stores != null && _user!.stores!.isNotEmpty) {
          _currentStore = _user!.stores!.first;
        }
        
        // Save token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _backend.currentToken!);
      } else {
        _error = 'Invalid username or password';
      }
      
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = 'Login error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _backend.logout();
    _user = null;
    _currentStore = null;
    _isAuthenticated = false;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    
    notifyListeners();
  }

  Future<void> switchStore(Store store) async {
    try {
      final result = await _backend.stores.switchStore(_user!.id, store.id);
      if (result['store'] != null) {
        _currentStore = Store.fromJson(result['store']);
      } else {
        _currentStore = store;
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _backend.auth.changePassword(
        _user!.id,
        currentPassword,
        newPassword,
      );
      
      if (!success) {
        _error = 'Current password is incorrect';
      }
      
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void setBaseUrl(String url) {
    // Not used in local backend mode
  }

  String get baseUrl => 'local';
}