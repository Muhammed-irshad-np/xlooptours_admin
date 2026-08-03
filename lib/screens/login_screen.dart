import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../features/auth/presentation/providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  final ValueNotifier<bool> _isLoading = ValueNotifier(false);
  final ValueNotifier<String?> _errorMessage = ValueNotifier(null);
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _isLoading.dispose();
    _errorMessage.dispose();
    super.dispose();
  }

  Future<void> _loginWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    _isLoading.value = true;
    _errorMessage.value = null;

    try {
      final success = await context.read<AuthProvider>().login(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );
      if (!success && mounted) {
        _errorMessage.value =
            context.read<AuthProvider>().errorMessage ?? 'Invalid email or password.';
      } else if (success && mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        _errorMessage.value = 'An unexpected error occurred. Please try again. $e';
      }
    } finally {
      if (mounted) {
        _isLoading.value = false;
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    _isLoading.value = true;
    _errorMessage.value = null;

    try {
      final success = await context.read<AuthProvider>().loginWithGoogle();
      if (!success && mounted) {
        _errorMessage.value =
            context.read<AuthProvider>().errorMessage ?? 'Google Sign-in failed.';
      } else if (success && mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        _errorMessage.value = 'An unexpected error occurred during Google sign in.';
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
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // App Title / Logo
                      Text(
                        'Xloop Invoice',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.merriweather(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF13B1F2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to access your portal',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSans(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Error Message Banner
                      ValueListenableBuilder<String?>(
                        valueListenable: _errorMessage,
                        builder: (context, errorMsg, _) {
                          if (errorMsg == null) return const SizedBox.shrink();
                          return Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              border: Border.all(color: Colors.red.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    errorMsg,
                                    style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Email is required';
                          if (!val.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Password is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Login Button
                      ValueListenableBuilder<bool>(
                        valueListenable: _isLoading,
                        builder: (context, isLoading, _) {
                          return ElevatedButton(
                            onPressed: isLoading ? null : _loginWithEmail,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF13B1F2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Divider
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'OR',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Google Sign-In Button
                      ValueListenableBuilder<bool>(
                        valueListenable: _isLoading,
                        builder: (context, isLoading, _) {
                          return OutlinedButton.icon(
                            onPressed: isLoading ? null : _loginWithGoogle,
                            icon: const Icon(Icons.g_mobiledata, size: 24),
                            label: const Text('Sign in with Google'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
