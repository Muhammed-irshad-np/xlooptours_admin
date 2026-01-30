import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Import for kReleaseMode
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:url_strategy/url_strategy.dart'; // Import url_strategy
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'firebase_options.dart';

import 'screens/invoice_form_screen.dart';
import 'screens/pdf_preview_screen.dart';
import 'models/invoice_model.dart';
import 'screens/admin_layout.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'models/company_model.dart';
import 'screens/public/registration_screen.dart';
import 'screens/companies_screen.dart';
import 'screens/company_form_screen.dart';
import 'screens/invoice_list_screen.dart';
import 'screens/analytics_screen.dart';
import 'models/customer_model.dart';
import 'screens/customer_form_screen.dart';
import 'screens/customer_list_screen.dart';
import 'screens/public/under_maintenance_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setPathUrlStrategy(); // Remove hash (#) from URL

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');
  } catch (e, stackTrace) {
    final errorMessage = e.toString().toLowerCase();
    if (errorMessage.contains('already initialized') ||
        errorMessage.contains('duplicate app')) {
      debugPrint('Firebase already initialized');
    } else {
      debugPrint('Firebase initialization error: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    _router = GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        final isLoggedIn = AuthService.instance.currentUser != null;
        final isLoggingIn = state.uri.path == '/login';
        final isRegistering = state.uri.path == '/register';
        final isRoot = state.uri.path == '/';

        // Allow public access to registration
        // Maintenance Screen logic:
        // - In Release Mode: Always show maintenance screen at root '/'
        // - In Debug/Profile Mode: Bypass maintenance, treat '/' as normal app root (login or home)

        if (isRegistering) {
          return null;
        }

        // Maintenance Screen Logic
        if (isRoot) {
          if (kReleaseMode) {
            // In Release mode, let it go to '/' which is UnderMaintenanceScreen
            return null;
          } else {
            // In Debug/Learner mode, we want to skip maintenance.
            // So we fall through to Auth checks below.
            // Note: If we are logged in, we should redirect to /home.
            // If not logged in, we should redirect to /login.
          }
        }

        if (!isLoggedIn && !isLoggingIn) {
          return '/login';
        }

        if (isLoggedIn && (isLoggingIn || isRoot)) {
          return '/home';
        }

        return null;
      },
      refreshListenable: Listenable.merge([AuthService.instance]),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const UnderMaintenanceScreen(),
        ),
        GoRoute(path: '/admin', redirect: (_, __) => '/home'),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const AdminLayout(),
        ),
        GoRoute(
          path: '/invoice',
          builder: (context, state) {
            final invoice = state.extra as InvoiceModel?;
            return InvoiceFormScreen(invoiceToEdit: invoice);
          },
        ),
        GoRoute(
          path: '/preview',
          builder: (context, state) {
            final invoice = state.extra as InvoiceModel;
            return PDFPreviewScreen(invoice: invoice);
          },
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) {
            final companyId = state.uri.queryParameters['companyId'];
            return RegistrationScreen(companyId: companyId);
          },
        ),
        GoRoute(
          path: '/companies',
          builder: (context, state) {
            final isSelectionMode =
                state.uri.queryParameters['selection'] == 'true';
            return CompaniesScreen(isSelectionMode: isSelectionMode);
          },
        ),
        GoRoute(
          path: '/companies/form',
          builder: (context, state) {
            final company = state.extra as CompanyModel?;
            return CompanyFormScreen(company: company);
          },
        ),
        GoRoute(
          path: '/customers',
          builder: (context, state) => const CustomerListScreen(),
        ),
        GoRoute(
          path: '/customers/form',
          builder: (context, state) {
            final customer = state.extra as CustomerModel?;
            return CustomerFormScreen(customer: customer);
          },
        ),
        GoRoute(
          path: '/analytics',
          builder: (context, state) => const AnalyticsScreen(),
        ),
        GoRoute(
          path: '/invoices',
          builder: (context, state) => const InvoiceListScreen(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(1440, 900),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) {
        return MaterialApp.router(
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
          title: 'XLoop Tours Admin',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF13b1f2),
            ),
            useMaterial3: true,
            textTheme: GoogleFonts.merriweatherTextTheme(),
          ),
        );
      },
    );
  }
}
