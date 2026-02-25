import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Import for kReleaseMode
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:url_strategy/url_strategy.dart'; // Import url_strategy
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'firebase_options.dart';
import 'injection_container.dart' as di;
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/notifications/presentation/providers/notification_provider.dart';
import 'features/company/presentation/providers/company_provider.dart';
import 'features/customer/presentation/providers/customer_provider.dart';
import 'features/employee/presentation/providers/employee_provider.dart';
import 'features/vehicle/presentation/providers/vehicle_provider.dart';
import 'features/invoice/presentation/providers/invoice_provider.dart';
import 'features/analytics/presentation/providers/analytics_provider.dart';

import 'screens/invoice_form_screen.dart';
import 'screens/pdf_preview_screen.dart';
import 'features/invoice/domain/entities/invoice_entity.dart';
import 'screens/admin_layout.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'features/company/domain/entities/company_entity.dart';
import 'screens/public/registration_screen.dart';
import 'screens/companies_screen.dart';
import 'screens/company_form_screen.dart';

import 'features/vehicle/domain/entities/vehicle_entity.dart';
import 'screens/invoice_list_screen.dart';
import 'screens/analytics_screen.dart';
import 'features/customer/domain/entities/customer_entity.dart';
import 'screens/customer_form_screen.dart';
import 'screens/customer_list_screen.dart';
import 'screens/public/under_maintenance_screen.dart';
// Added
// import 'screens/vehicles_screen.dart'; // Removed unused import
import 'screens/vehicle_form_screen.dart'; // Added

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setPathUrlStrategy(); // Remove hash (#) from URL

  // Global Error Handling
  FlutterError.onError = (FlutterErrorDetails details) {
    // Log the error (can be sent to Crashlytics/Sentry here)
    debugPrint('Flutter Error: ${details.exception}');
    debugPrint('Stacktrace: ${details.stack}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    // Catch asynchronous errors
    debugPrint('Async Error: $error');
    debugPrint('Stacktrace: $stack');
    return true; // Prevent default error handling
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                kDebugMode
                    ? details.exceptionAsString()
                    : 'An unexpected error occurred.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  };

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

  await di.init(); // Initialize Dependency Injection

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
        final authProvider = di.sl<AuthProvider>();
        final isLoggedIn = authProvider.user != null;
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
      refreshListenable: di.sl<AuthProvider>(),
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
            final invoice = state.extra as InvoiceEntity?;
            return InvoiceFormScreen(invoiceToEdit: invoice);
          },
        ),
        GoRoute(
          path: '/preview',
          builder: (context, state) {
            final invoice = state.extra as InvoiceEntity;
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
            final company = state.extra as CompanyEntity?;
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
            final customer = state.extra as CustomerEntity?;
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
        GoRoute(
          path: '/vehicles/form',
          builder: (context, state) {
            final vehicle = state.extra as VehicleEntity?;
            return VehicleFormScreen(vehicle: vehicle);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => di.sl<AuthProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<NotificationProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<CompanyProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<CustomerProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<EmployeeProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<VehicleProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<InvoiceProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<AnalyticsProvider>()),
      ],
      child: ScreenUtilInit(
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
      ),
    );
  }
}
