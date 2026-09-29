import 'package:flutter/foundation.dart';
import '../models/user.dart';

class AuthService extends ChangeNotifier {
  // Mock user database - in production, connect to a real backend
  static final Map<String, User> _users = {
    'demo': User(
      id: '1',
      username: 'demo',
      email: 'demo@tivio.com',
      password: 'demo123', // Simple demo password
      accessibleChannelIds: ['tivio-one', 'tivio-cinema', 'tivio-music'],
      isSubscribed: true,
      subscriptionExpiry: DateTime.now().add(const Duration(days: 365)),
    ),
    'admin': User(
      id: '2',
      username: 'admin',
      email: 'admin@tivio.com',
      password: 'admin123',
      accessibleChannelIds: ['tivio-one', 'tivio-sport', 'tivio-cinema', 'tivio-music'],
      isSubscribed: true,
      subscriptionExpiry: DateTime.now().add(const Duration(days: 365)),
    ),
    'test': User(
      id: '3',
      username: 'test',
      email: 'test@tivio.com',
      password: 'test123',
      accessibleChannelIds: ['tivio-one', 'tivio-music'],
      isSubscribed: true,
      subscriptionExpiry: DateTime.now().add(const Duration(days: 30)),
    ),
  };

  User? _currentUser;
  bool _isAuthenticated = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  String? get errorMessage => _errorMessage;

  Future<bool> login(String username, String password) async {
    _errorMessage = null;
    notifyListeners();

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    final user = _users[username];

    if (user == null) {
      _errorMessage = 'Username not found';
      notifyListeners();
      return false;
    }

    if (user.password != password) {
      _errorMessage = 'Incorrect password';
      notifyListeners();
      return false;
    }

    if (!user.isSubscribed) {
      _errorMessage = 'Subscription expired. Please renew your plan.';
      notifyListeners();
      return false;
    }

    if (user.subscriptionExpiry.isBefore(DateTime.now())) {
      _errorMessage = 'Your subscription has expired';
      notifyListeners();
      return false;
    }

    _currentUser = user;
    _isAuthenticated = true;
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  Future<bool> register(String username, String email, String password) async {
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 800));

    if (_users.containsKey(username)) {
      _errorMessage = 'Username already taken';
      notifyListeners();
      return false;
    }

    final newUser = User(
      id: '${_users.length + 1}',
      username: username,
      email: email,
      password: password,
      accessibleChannelIds: ['tivio-one', 'tivio-music'], // New users get limited access
      isSubscribed: true,
      subscriptionExpiry: DateTime.now().add(const Duration(days: 7)), // 7-day trial
    );

    _users[username] = newUser;
    _currentUser = newUser;
    _isAuthenticated = true;
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  void logout() {
    _currentUser = null;
    _isAuthenticated = false;
    _errorMessage = null;
    notifyListeners();
  }

  bool canAccessChannel(String channelId) {
    if (_currentUser == null) return false;
    return _currentUser!.hasAccessToChannel(channelId);
  }
}
