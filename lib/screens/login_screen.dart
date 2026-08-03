import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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

  Future<void> _launchEmail(String email) async {
    final Uri launchUri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_clearErrorOnTyping);
    _passwordController.addListener(_clearErrorOnTyping);
  }

  void _clearErrorOnTyping() {
    if (_errorMessage.value != null) {
      _errorMessage.value = null;
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_clearErrorOnTyping);
    _passwordController.removeListener(_clearErrorOnTyping);
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
            context.read<AuthProvider>().errorMessage ??
            'Invalid email or password.';
      } else if (success && mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        _errorMessage.value = 'An unexpected error occurred. Please try again.';
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
            context.read<AuthProvider>().errorMessage ??
            'Google Sign-in failed.';
      } else if (success && mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        _errorMessage.value =
            'An unexpected error occurred during Google sign in.';
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
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Decorative Ambient Glow Spheres
          Positioned(
            top: -120,
            left: -120,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF13B1F2).withValues(alpha: 0.18),
                    blurRadius: 140,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -120,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    blurRadius: 140,
                  ),
                ],
              ),
            ),
          ),

          // Main Centered Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 440.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Logo Container
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 10.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/logo/xloop_logo_new.png',
                          height: 48.h,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              Image.asset(
                                'assets/logo/xloop_logo.png',
                                height: 48.h,
                                fit: BoxFit.contain,
                              ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        'XLOOP TOURS W.L.L',
                        style: GoogleFonts.notoSans(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 24.h),

                      // Login Form Card
                      _buildLoginFormCard(),

                      SizedBox(height: 24.h),

                      // Footer Contact & Support
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Need assistance? ',
                            style: GoogleFonts.notoSans(
                              fontSize: 12.sp,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          InkWell(
                            onTap: () =>
                                _launchEmail('enquiries@xlooptours.com'),
                            child: Text(
                              'Contact IT Support',
                              style: GoogleFonts.notoSans(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF38BDF8),
                                decoration: TextDecoration.underline,
                                decorationColor: const Color(0xFF38BDF8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        '© ${DateTime.now().year} Xloop Tours W.L.L. All rights reserved.',
                        style: GoogleFonts.notoSans(
                          fontSize: 11.sp,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginFormCard() {
    return Container(
      padding: EdgeInsets.all(32.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome Header
            Text(
              'Sign In',
              style: GoogleFonts.merriweather(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Enter your credentials to access your administrative workspace.',
              style: GoogleFonts.notoSans(
                fontSize: 13.sp,
                color: const Color(0xFF64748B),
              ),
            ),
            SizedBox(height: 28.h),

            // Error Banner
            ValueListenableBuilder<String?>(
              valueListenable: _errorMessage,
              builder: (context, errorMsg, _) {
                if (errorMsg == null) return const SizedBox.shrink();
                return Container(
                  padding: EdgeInsets.all(12.w),
                  margin: EdgeInsets.only(bottom: 20.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: const Color(0xFFDC2626),
                        size: 18.sp,
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          errorMsg,
                          style: GoogleFonts.notoSans(
                            color: const Color(0xFF991B1B),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _errorMessage.value = null,
                        child: Icon(
                          Icons.close,
                          size: 16.sp,
                          color: const Color(0xFF991B1B),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Email Label & Input
            Text(
              'Email Address',
              style: GoogleFonts.notoSans(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
            ),
            SizedBox(height: 6.h),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              style: GoogleFonts.notoSans(
                fontSize: 14.sp,
                color: const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'name@xlooptours.com',
                hintStyle: GoogleFonts.notoSans(
                  fontSize: 13.sp,
                  color: const Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(
                  Icons.email_outlined,
                  color: Color(0xFF64748B),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 14.h,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(
                    color: Color(0xFF13B1F2),
                    width: 2,
                  ),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Email is required';
                }
                if (!val.contains('@')) return 'Enter a valid email address';
                return null;
              },
            ),
            SizedBox(height: 20.h),

            // Password Label & Input
            Text(
              'Password',
              style: GoogleFonts.notoSans(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
            ),
            SizedBox(height: 6.h),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _loginWithEmail(),
              style: GoogleFonts.notoSans(
                fontSize: 14.sp,
                color: const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: '••••••••',
                hintStyle: GoogleFonts.notoSans(
                  fontSize: 13.sp,
                  color: const Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(
                  Icons.lock_outline,
                  color: Color(0xFF64748B),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: const Color(0xFF64748B),
                    size: 20.sp,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 14.h,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(
                    color: Color(0xFF13B1F2),
                    width: 2,
                  ),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Password is required';
                }
                return null;
              },
            ),
            SizedBox(height: 28.h),

            // Login Button
            ValueListenableBuilder<bool>(
              valueListenable: _isLoading,
              builder: (context, isLoading, _) {
                return Container(
                  height: 48.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.r),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF13B1F2), Color(0xFF0284C7)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF13B1F2).withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _loginWithEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: isLoading
                        ? SizedBox(
                            width: 20.w,
                            height: 20.h,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Sign In',
                            style: GoogleFonts.notoSans(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                );
              },
            ),
            SizedBox(height: 24.h),

            // Divider
            Row(
              children: [
                Expanded(
                  child: Container(height: 1, color: const Color(0xFFE2E8F0)),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Text(
                    'OR CONTINUE WITH',
                    style: GoogleFonts.notoSans(
                      color: const Color(0xFF94A3B8),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(height: 1, color: const Color(0xFFE2E8F0)),
                ),
              ],
            ),
            SizedBox(height: 24.h),

            // Google Sign-In Button (Pure Flutter UI rendering - no SVG or CORS errors)
            ValueListenableBuilder<bool>(
              valueListenable: _isLoading,
              builder: (context, isLoading, _) {
                return OutlinedButton(
                  onPressed: isLoading ? null : _loginWithGoogle,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildGoogleLogoBadge(),
                      SizedBox(width: 12.w),
                      Text(
                        'Sign in with Google',
                        style: GoogleFonts.notoSans(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Pure Flutter Google 'G' Logo render (eliminates SVG parsing & CORS errors)
  Widget _buildGoogleLogoBadge() {
    return Container(
      width: 20.w,
      height: 20.h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF4285F4),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        'G',
        style: GoogleFonts.notoSans(
          fontSize: 13.sp,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}
