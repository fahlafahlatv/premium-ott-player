import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showRegisterForm = false;
  late TextEditingController _registerUsernameController;
  late TextEditingController _registerEmailController;
  late TextEditingController _registerPasswordController;
  late TextEditingController _registerConfirmPasswordController;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    _registerUsernameController = TextEditingController();
    _registerEmailController = TextEditingController();
    _registerPasswordController = TextEditingController();
    _registerConfirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _registerUsernameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final authService = context.read<AuthService>();
    setState(() => _isLoading = true);

    final success = await authService.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PremiumOttPlayerScreen()),
      );
    }
  }

  Future<void> _handleRegister() async {
    if (_registerPasswordController.text != _registerConfirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    final authService = context.read<AuthService>();
    setState(() => _isLoading = true);

    final success = await authService.register(
      _registerUsernameController.text.trim(),
      _registerEmailController.text.trim(),
      _registerPasswordController.text,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PremiumOttPlayerScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TivioColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: TivioColors.cyan.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: TivioColors.cyan.withOpacity(0.55),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: TivioColors.cyan.withOpacity(0.25),
                        blurRadius: 30,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.live_tv_rounded,
                    color: TivioColors.cyan,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'TIVIO',
                  style: TextStyle(
                    color: TivioColors.cyan,
                    fontSize: 32,
                    letterSpacing: 6,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _showRegisterForm ? 'Create your account' : 'Sign in to continue',
                  style: const TextStyle(
                    color: TivioColors.muted,
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 32),
                Consumer<AuthService>(
                  builder: (context, authService, _) {
                    return Column(
                      children: [
                        if (!_showRegisterForm) ..._buildLoginForm(authService),
                        if (_showRegisterForm) ..._buildRegisterForm(authService),
                        const SizedBox(height: 16),
                        if (authService.errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.5),
                              ),
                            ),
                            child: Text(
                              authService.errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    setState(() => _showRegisterForm = !_showRegisterForm);
                    context.read<AuthService>().errorMessage;
                  },
                  child: Text(
                    _showRegisterForm
                        ? 'Already have an account? Sign in'
                        : 'Don\'t have an account? Sign up',
                    style: const TextStyle(
                      color: TivioColors.cyan,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLoginForm(AuthService authService) {
    return [
      TextField(
        controller: _usernameController,
        enabled: !_isLoading,
        decoration: InputDecoration(
          hintText: 'Username or email',
          filled: true,
          fillColor: TivioColors.panel,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white10),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white10),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: TivioColors.cyan),
          ),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _passwordController,
        enabled: !_isLoading,
        obscureText: !_showPassword,
        decoration: InputDecoration(
          hintText: 'Password',
          filled: true,
          fillColor: TivioColors.panel,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white10),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white10),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: TivioColors.cyan),
          ),
          suffixIcon: IconButton(
            icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _showPassword = !_showPassword),
            color: TivioColors.muted,
          ),
        ),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: TivioColors.cyan,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                )
              : const Text(
                  'Sign In',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),
        ),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: TivioColors.panel,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Demo Credentials:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            SizedBox(height: 6),
            Text(
              'Username: demo | Password: demo123',
              style: TextStyle(color: TivioColors.muted, fontSize: 11),
            ),
            SizedBox(height: 4),
            Text(
              'Username: admin | Password: admin123',
              style: TextStyle(color: TivioColors.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildRegisterForm(AuthService authService) {
    return [
      TextField(
        controller: _registerUsernameController,
        enabled: !_isLoading,
        decoration: InputDecoration(
          hintText: 'Choose a username',
          filled: true,
          fillColor: TivioColors.panel,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white10),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white10),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: TivioColors.cyan),
          ),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _registerEmailController,
        enabled: !_isLoading,
        decoration: InputDecoration(
          hintText: 'Email address',
          filled: true,
          fillColor: TivioColors.panel,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white10),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white10),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: TivioColors.cyan),
          ),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _registerPasswordController,
        enabled: !_isLoading,
        obscureText: !_showPassword,
        decoration: InputDecoration(
          hintText: 'Create a password',
          filled: true,
          fillColor: TivioColors.panel,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white10),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white10),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: TivioColors.cyan),
          ),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _registerConfirmPasswordController,
        enabled: !_isLoading,
        obscureText: !_showPassword,
        decoration: InputDecoration(
          hintText: 'Confirm password',
          filled: true,
          fillColor: TivioColors.panel,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white10),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white10),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: TivioColors.cyan),
          ),
        ),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleRegister,
          style: ElevatedButton.styleFrom(
            backgroundColor: TivioColors.cyan,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                )
              : const Text(
                  'Create Account',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),
        ),
      ),
    ];
  }
}
