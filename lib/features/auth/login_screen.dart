import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import 'auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static final RegExp _emailRegex =
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _googleLoading = false; // ⭐ NEW
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? SpendlyColors.darkGradient
              : const LinearGradient(
                  colors: [Color(0xFFF0F4FF), Color(0xFFFFFFFF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),

                /// LOGO (same as yours)
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: SpendlyColors.primaryGradient,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Spendly',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 52),

                Text(
                  'Welcome back',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),

                const SizedBox(height: 6),

                Text(
                  'Sign in to your account',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: SpendlyColors.neutral500,
                      ),
                ),

                if (useDemoMode) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: SpendlyColors.warning.withAlpha(24),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: SpendlyColors.warning.withAlpha(80)),
                    ),
                    child: const Text(
                      'Demo Mode Enabled',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: SpendlyColors.warning,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                /// EMAIL
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),

                const SizedBox(height: 16),

                /// PASSWORD
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  onSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                /// EMAIL LOGIN
                _buildLoginButton(),

                if (!useDemoMode) ...[
                  const SizedBox(height: 16),
                  _buildGoogleButton(),
                ],

                if (useDemoMode) ...[
                  const SizedBox(height: 16),
                  _buildDemoButton(),
                ],

                const SizedBox(height: 28),

                Center(
                  child: TextButton(
                    onPressed: () => context.push('/register'),
                    child: const Text("Don't have an account? Sign up"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// EMAIL LOGIN BUTTON
  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _login,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: SpendlyColors.primaryGradient,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text("Sign In",
                  style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  /// ⭐ GOOGLE BUTTON (NEW)
  Widget _buildGoogleButton() {
    return OutlinedButton.icon(
      onPressed: _googleLoading ? null : _googleLogin,
      icon: const Icon(Icons.login),
      label: _googleLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text("Sign in with Google"),
    );
  }

  Widget _buildDemoButton() {
    return OutlinedButton(
      onPressed: _demoLogin,
      child: const Text('Continue as Demo User'),
    );
  }

  /// EMAIL LOGIN
  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Enter email & password');
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      _showError('Enter a valid email address');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(authProvider.notifier).login(email, password);

      if (mounted) context.go('/home');
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// ⭐ GOOGLE LOGIN
  Future<void> _googleLogin() async {
    setState(() => _googleLoading = true);

    try {
      await ref.read(authProvider.notifier).signInWithGoogle();

      if (mounted) context.go('/home');
    } catch (e) {
      _showError("Google Sign-In failed");
    } finally {
      if (mounted) {
        setState(() => _googleLoading = false);
      }
    }
  }

  Future<void> _demoLogin() async {
    try {
      await ref.read(authProvider.notifier).login('alice@spendly.app', 'demo');
      if (mounted) context.go('/home');
    } catch (_) {
      if (mounted) {
        _showError('Demo login failed. Ensure you launched with SPENDLY_MODE=demo.');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}