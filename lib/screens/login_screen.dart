import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../features/auth/presentation/providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final ValueNotifier<bool> _isLoading = ValueNotifier(false);
  final ValueNotifier<String?> _errorMessage = ValueNotifier(null);

  @override
  void dispose() {
    _isLoading.dispose();
    _errorMessage.dispose();
    super.dispose();
  }

  Future<void> _loginWithGoogle() async {
    _isLoading.value = true;
    _errorMessage.value = null;

    try {
      final success = await context.read<AuthProvider>().loginWithGoogle();
      if (!success && mounted) {
        _errorMessage.value =
            context.read<AuthProvider>().errorMessage ?? 'Login failed.';
      }
      // Navigation is handled by the auth state stream in main.dart
    } catch (e) {
      if (mounted) {
        _errorMessage.value =
            'An unexpected error occurred. Please try again. $e';
      }
    } finally {
      if (mounted) {
        _isLoading.value = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo or App Name
                Text(
                  'Xloop Invoice',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.merriweather(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 48),

                AnimatedBuilder(
                  animation: Listenable.merge([_isLoading, _errorMessage]),
                  builder: (context, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Error Message
                        if (_errorMessage.value != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              border: Border.all(color: Colors.red.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _errorMessage.value!,
                              style: TextStyle(color: Colors.red.shade800),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        // Google Sign-In Button
                        FilledButton.icon(
                          onPressed: _isLoading.value ? null : _loginWithGoogle,
                          icon: _isLoading.value
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.login),
                          label: const Text('Sign in with Google'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 24),
                const Text(
                  'Sign in with your Google account to access the dashboard.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
