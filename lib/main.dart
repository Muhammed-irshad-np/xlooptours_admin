import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/invoice_form_screen.dart';
import 'screens/pdf_preview_screen.dart';
import 'models/invoice_model.dart';
import 'screens/admin_layout.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase - this is safe to call multiple times
    // If already initialized, it will just return the existing app
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');
  } catch (e, stackTrace) {
    // Check if it's an "already initialized" error
    final errorMessage = e.toString().toLowerCase();
    if (errorMessage.contains('already initialized') ||
        errorMessage.contains('duplicate app')) {
      debugPrint('Firebase already initialized');
    } else {
      debugPrint('Firebase initialization error: $e');
      debugPrint('Stack trace: $stackTrace');
      // Continue anyway - DatabaseService will handle the error
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(1440, 900),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'XLoop Tours Admin',
          theme: ThemeData(
            // Cyan/Teal based on the logo description (Blue/Cyan mix)
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF00BCD4),
            ),
            useMaterial3: true,
            textTheme: GoogleFonts.merriweatherTextTheme(),
          ),
          home: child,
          routes: {
            '/home': (context) => const HomeScreen(),
            '/invoice': (context) => const InvoiceFormScreen(),
            '/preview': (context) {
              final invoice =
                  ModalRoute.of(context)!.settings.arguments as InvoiceModel;
              return PDFPreviewScreen(invoice: invoice);
            },
          },
        );
      },
      child: StreamBuilder<User?>(
        stream: AuthService.instance.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData) {
            return const AdminLayout();
          }

          return const LoginScreen();
        },
      ),
    );
  }
}
