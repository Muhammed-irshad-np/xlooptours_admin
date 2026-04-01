import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'features/auth/data/datasources/auth_remote_data_source.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/auth_getters.dart';
import 'features/auth/domain/usecases/sign_in_with_email.dart';
import 'features/auth/domain/usecases/sign_in_with_google.dart';
import 'features/auth/domain/usecases/sign_out.dart';
import 'features/auth/presentation/providers/auth_provider.dart';

import 'features/notifications/data/datasources/notification_remote_data_source.dart';
import 'features/notifications/data/repositories/notification_repository_impl.dart';
import 'features/notifications/domain/repositories/notification_repository.dart';
import 'features/notifications/domain/usecases/notification_usecases.dart';
import 'features/notifications/presentation/providers/notification_provider.dart';

import 'features/employee/domain/usecases/get_employee_expiry_alerts_usecase.dart';

import 'features/employee/data/datasources/employee_remote_data_source.dart';
import 'features/employee/data/repositories/employee_repository_impl.dart';
import 'features/employee/domain/repositories/employee_repository.dart';
import 'features/employee/domain/usecases/delete_employee_usecase.dart';
import 'features/employee/domain/usecases/get_all_employees_usecase.dart';
import 'features/employee/domain/usecases/insert_employee_usecase.dart';
import 'features/employee/domain/usecases/update_employee_usecase.dart';
import 'features/employee/domain/usecases/upload_document_attachment_usecase.dart';
import 'features/employee/domain/usecases/upload_employee_image_usecase.dart';
import 'features/employee/presentation/providers/employee_provider.dart';

import 'features/vehicle/data/datasources/vehicle_remote_data_source.dart';
import 'features/vehicle/data/repositories/vehicle_repository_impl.dart';
import 'features/vehicle/domain/repositories/vehicle_repository.dart';
import 'features/vehicle/domain/usecases/assign_driver_to_vehicle_usecase.dart';
import 'features/vehicle/domain/usecases/delete_vehicle_make_usecase.dart';
import 'features/vehicle/domain/usecases/delete_vehicle_usecase.dart';
import 'features/vehicle/domain/usecases/get_all_vehicle_makes_usecase.dart';
import 'features/vehicle/domain/usecases/get_all_vehicles_usecase.dart';
import 'features/vehicle/domain/usecases/insert_vehicle_make_usecase.dart';
import 'features/vehicle/domain/usecases/insert_vehicle_usecase.dart';
import 'features/vehicle/domain/usecases/update_vehicle_make_usecase.dart';
import 'features/vehicle/domain/usecases/update_vehicle_usecase.dart';
import 'features/vehicle/domain/usecases/upload_vehicle_document_usecase.dart';
import 'features/vehicle/domain/usecases/upload_vehicle_image_usecase.dart';
import 'features/vehicle/domain/usecases/get_vehicles_needing_odo_update_usecase.dart';
import 'features/vehicle/domain/usecases/get_vehicle_maintenance_alerts_usecase.dart';
import 'features/vehicle/presentation/providers/vehicle_provider.dart';

import 'features/company/data/datasources/company_remote_data_source.dart';
import 'features/company/data/repositories/company_repository_impl.dart';
import 'features/company/domain/repositories/company_repository.dart';
import 'features/company/domain/usecases/company_usecases.dart';
import 'features/company/presentation/providers/company_provider.dart';

import 'features/customer/data/datasources/customer_remote_data_source.dart';
import 'features/customer/data/repositories/customer_repository_impl.dart';
import 'features/customer/domain/repositories/customer_repository.dart';
import 'features/customer/domain/usecases/get_all_customers_usecase.dart';
import 'features/customer/domain/usecases/get_customers_for_company_usecase.dart';
import 'features/customer/domain/usecases/insert_customer_usecase.dart';
import 'features/customer/domain/usecases/update_customer_usecase.dart';
import 'features/customer/domain/usecases/delete_customer_usecase.dart';
import 'features/customer/presentation/providers/customer_provider.dart';

import 'features/invoice/data/datasources/invoice_remote_data_source.dart';
import 'features/invoice/data/repositories/invoice_repository_impl.dart';
import 'features/invoice/domain/repositories/invoice_repository.dart';
import 'features/invoice/domain/usecases/delete_invoice_usecase.dart';
import 'features/invoice/domain/usecases/generate_invoice_number_usecase.dart';
import 'features/invoice/domain/usecases/get_all_invoices_usecase.dart';
import 'features/invoice/domain/usecases/insert_invoice_usecase.dart';
import 'features/invoice/domain/usecases/update_invoice_usecase.dart';
import 'features/invoice/presentation/providers/invoice_provider.dart';

import 'features/analytics/domain/usecases/get_analytics_usecase.dart';
import 'features/analytics/presentation/providers/analytics_provider.dart';

final sl = GetIt.instance; // sl stands for Service Locator

Future<void> init() async {
  //! Features - Authentication
  // State Management (Provider)
  sl.registerFactory(
    () => AuthProvider(
      signInWithEmail: sl(),
      signInWithGoogle: sl(),
      signOut: sl(),
      getCurrentUser: sl(),
      getAuthStateChanges: sl(),
    ),
  );

  // UseCases
  sl.registerLazySingleton(() => SignInWithEmail(sl()));
  sl.registerLazySingleton(() => SignInWithGoogle(sl()));
  sl.registerLazySingleton(() => SignOut(sl()));
  sl.registerLazySingleton(() => GetCurrentUser(sl()));
  sl.registerLazySingleton(() => GetAuthStateChanges(sl()));

  // Repositories
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl()),
  );

  // Data sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(
      auth: sl(),
      googleSignIn: sl(),
      firestore: sl(),
    ),
  );

  //! Features - Notifications
  // State Management (Provider)
  sl.registerFactory(
    () => NotificationProvider(
      getNotifications: sl(),
      insertNotification: sl(),
      markNotificationAsRead: sl(),
      getEmployeeExpiryAlerts: sl(),
      getVehicleMaintenanceAlerts: sl(),
    ),
  );

  // UseCases
  sl.registerLazySingleton(() => GetNotifications(sl()));
  sl.registerLazySingleton(() => InsertNotification(sl()));
  sl.registerLazySingleton(() => MarkNotificationAsRead(sl()));

  // Repositories
  sl.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(remoteDataSource: sl()),
  );

  // Data sources
  sl.registerLazySingleton<NotificationRemoteDataSource>(
    () => NotificationRemoteDataSourceImpl(firestore: sl()),
  );

  //! Features - Company
  // State Management (Provider)
  sl.registerFactory(
    () => CompanyProvider(
      getCompaniesUseCase: sl(),
      getCompanyByIdUseCase: sl(),
      insertCompanyUseCase: sl(),
      updateCompanyUseCase: sl(),
      deleteCompanyUseCase: sl(),
    ),
  );

  // UseCases
  sl.registerLazySingleton(() => GetCompanies(sl()));
  sl.registerLazySingleton(() => GetCompanyById(sl()));
  sl.registerLazySingleton(() => InsertCompany(sl()));
  sl.registerLazySingleton(() => UpdateCompany(sl()));
  sl.registerLazySingleton(() => DeleteCompany(sl()));

  // Repositories
  sl.registerLazySingleton<CompanyRepository>(
    () => CompanyRepositoryImpl(remoteDataSource: sl()),
  );

  // Data sources
  sl.registerLazySingleton<CompanyRemoteDataSource>(
    () => CompanyRemoteDataSourceImpl(firestore: sl()),
  );

  //! Features - Customer
  // State Management (Provider)
  sl.registerFactory(
    () => CustomerProvider(
      getAllCustomersUseCase: sl(),
      getCustomersForCompanyUseCase: sl(),
      insertCustomerUseCase: sl(),
      updateCustomerUseCase: sl(),
      deleteCustomerUseCase: sl(),
    ),
  );

  // UseCases
  sl.registerLazySingleton(() => GetAllCustomersUseCase(sl()));
  sl.registerLazySingleton(() => GetCustomersForCompanyUseCase(sl()));
  sl.registerLazySingleton(() => InsertCustomerUseCase(sl()));
  sl.registerLazySingleton(() => UpdateCustomerUseCase(sl()));
  sl.registerLazySingleton(() => DeleteCustomerUseCase(sl()));

  // Repositories
  sl.registerLazySingleton<CustomerRepository>(
    () => CustomerRepositoryImpl(remoteDataSource: sl()),
  );

  // Data sources
  sl.registerLazySingleton<CustomerRemoteDataSource>(
    () => CustomerRemoteDataSourceImpl(firestore: sl()),
  );

  //! Features - Employee
  // State Management (Provider)
  sl.registerFactory(
    () => EmployeeProvider(
      getAllEmployeesUseCase: sl(),
      insertEmployeeUseCase: sl(),
      updateEmployeeUseCase: sl(),
      deleteEmployeeUseCase: sl(),
      uploadEmployeeImageUseCase: sl(),
      uploadDocumentAttachmentUseCase: sl(),
    ),
  );

  // UseCases
  sl.registerLazySingleton(() => GetAllEmployeesUseCase(sl()));
  sl.registerLazySingleton(() => InsertEmployeeUseCase(sl()));
  sl.registerLazySingleton(() => UpdateEmployeeUseCase(sl()));
  sl.registerLazySingleton(() => DeleteEmployeeUseCase(sl()));
  sl.registerLazySingleton(() => UploadEmployeeImageUseCase(sl()));
  sl.registerLazySingleton(() => UploadDocumentAttachmentUseCase(sl()));
  sl.registerLazySingleton(() => GetEmployeeExpiryAlertsUseCase(sl()));

  // Repositories
  sl.registerLazySingleton<EmployeeRepository>(
    () => EmployeeRepositoryImpl(remoteDataSource: sl()),
  );

  // Data sources
  sl.registerLazySingleton<EmployeeRemoteDataSource>(
    () => EmployeeRemoteDataSourceImpl(firestore: sl(), storage: sl()),
  );

  //! Features - Vehicle
  // State Management (Provider)
  sl.registerFactory(
    () => VehicleProvider(
      getAllVehiclesUseCase: sl(),
      insertVehicleUseCase: sl(),
      updateVehicleUseCase: sl(),
      deleteVehicleUseCase: sl(),
      assignDriverToVehicleUseCase: sl(),
      uploadVehicleImageUseCase: sl(),
      uploadVehicleDocumentUseCase: sl(),
      getAllVehicleMakesUseCase: sl(),
      insertVehicleMakeUseCase: sl(),
      updateVehicleMakeUseCase: sl(),
      deleteVehicleMakeUseCase: sl(),
    ),
  );

  // UseCases
  sl.registerLazySingleton(() => GetAllVehiclesUseCase(sl()));
  sl.registerLazySingleton(() => InsertVehicleUseCase(sl()));
  sl.registerLazySingleton(() => UpdateVehicleUseCase(sl()));
  sl.registerLazySingleton(() => DeleteVehicleUseCase(sl()));
  sl.registerLazySingleton(() => AssignDriverToVehicleUseCase(sl()));
  sl.registerLazySingleton(() => UploadVehicleImageUseCase(sl()));
  sl.registerLazySingleton(() => UploadVehicleDocumentUseCase(sl()));
  sl.registerLazySingleton(() => GetVehiclesNeedingOdometerUpdateUseCase());
  sl.registerLazySingleton(() => GetVehicleMaintenanceAlertsUseCase());

  sl.registerLazySingleton(() => GetAllVehicleMakesUseCase(sl()));
  sl.registerLazySingleton(() => InsertVehicleMakeUseCase(sl()));
  sl.registerLazySingleton(() => UpdateVehicleMakeUseCase(sl()));
  sl.registerLazySingleton(() => DeleteVehicleMakeUseCase(sl()));

  // Repositories
  sl.registerLazySingleton<VehicleRepository>(
    () => VehicleRepositoryImpl(remoteDataSource: sl()),
  );

  // Data sources
  sl.registerLazySingleton<VehicleRemoteDataSource>(
    () => VehicleRemoteDataSourceImpl(firestore: sl(), storage: sl()),
  );

  //! Features - Invoice
  // State Management (Provider)
  sl.registerFactory(
    () => InvoiceProvider(
      insertInvoiceUseCase: sl(),
      getAllInvoicesUseCase: sl(),
      updateInvoiceUseCase: sl(),
      deleteInvoiceUseCase: sl(),
      generateInvoiceNumberUseCase: sl(),
    ),
  );

  // UseCases
  sl.registerLazySingleton(() => InsertInvoiceUseCase(sl()));
  sl.registerLazySingleton(() => GetAllInvoicesUseCase(sl()));
  sl.registerLazySingleton(() => UpdateInvoiceUseCase(sl()));
  sl.registerLazySingleton(() => DeleteInvoiceUseCase(sl()));
  sl.registerLazySingleton(() => GenerateInvoiceNumberUseCase(sl()));

  // Repositories
  sl.registerLazySingleton<InvoiceRepository>(
    () => InvoiceRepositoryImpl(remoteDataSource: sl()),
  );

  // Data sources
  sl.registerLazySingleton<InvoiceRemoteDataSource>(
    () => InvoiceRemoteDataSourceImpl(firestore: sl()),
  );

  //! Features - Analytics
  // State Management (Provider)
  sl.registerFactory(() => AnalyticsProvider(getAnalyticsUseCase: sl()));

  // UseCases
  sl.registerLazySingleton(() => GetAnalyticsUseCase(sl()));

  //! Core
  // e.g. NetworkInfo

  //! External
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;
  final googleSignIn = GoogleSignIn();
  final storage = FirebaseStorage.instance;

  sl.registerLazySingleton(() => auth);
  sl.registerLazySingleton(() => firestore);
  sl.registerLazySingleton(() => googleSignIn);
  sl.registerLazySingleton(() => storage);
}
