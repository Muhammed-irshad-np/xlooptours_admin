import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:xloop_invoice/models/invoice_model.dart';
import 'package:xloop_invoice/models/line_item_model.dart';
import 'package:xloop_invoice/models/vehicle_make_model.dart'; // Added
import '../models/company_model.dart';
import '../models/customer_model.dart';
import '../models/employee_model.dart';
import '../models/notification_model.dart';
import '../models/vehicle_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  FirebaseFirestore? _firestore;

  DatabaseService._init();

  FirebaseFirestore get firestore {
    if (_firestore == null) {
      try {
        // Try to get Firestore instance - this will throw if Firebase isn't initialized
        _firestore = FirebaseFirestore.instance;
      } catch (e) {
        throw Exception(
          'Firebase is not initialized. Make sure Firebase.initializeApp() is called before using DatabaseService. Error: $e',
        );
      }
    }
    return _firestore!;
  }

  // ======================
  // COMPANY Operations
  // ======================

  Future<void> insertCompany(CompanyModel company) async {
    try {
      debugPrint('DatabaseService: Inserting company ${company.id}');
      await firestore
          .collection('companies')
          .doc(company.id)
          .set(company.toJson());

      // Also save to 'customers' collection for legacy compatibility/migration if needed,
      // but for now we are moving to 'companies'.
      // User requested "Company owns the list... Customer can be assigned...".
      // We will assume new structure primarily.

      debugPrint('DatabaseService: Company ${company.id} saved successfully');
    } catch (e, stackTrace) {
      debugPrint('DatabaseService: Error inserting company: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<List<CompanyModel>> getAllCompanies() async {
    List<CompanyModel> allCompanies = [];
    final Set<String> companyIds = {};

    try {
      // 1. Fetch from new 'companies' collection
      final companiesSnapshot = await firestore
          .collection('companies')
          .orderBy('companyName')
          .get();

      final newCompanies = companiesSnapshot.docs
          .map((doc) => CompanyModel.fromJson(doc.data()))
          .toList();

      for (var company in newCompanies) {
        if (!companyIds.contains(company.id)) {
          allCompanies.add(company);
          companyIds.add(company.id);
        }
      }

      // 2. Fetch from legacy 'customers' collection
      // We do this to ensure no data is lost during the migration phase
      final customersSnapshot = await firestore
          .collection('customers')
          .orderBy('companyName')
          .get();

      final oldCompanies = customersSnapshot.docs
          .map((doc) => CompanyModel.fromJson(doc.data()))
          .toList();

      for (var company in oldCompanies) {
        // Only add if not already present (prefer the version in 'companies' if ID exists in both)
        if (!companyIds.contains(company.id)) {
          allCompanies.add(company);
          companyIds.add(company.id);
        }
      }

      // Sort merged list
      allCompanies.sort((a, b) => a.companyName.compareTo(b.companyName));
    } catch (e) {
      debugPrint('Error fetching companies: $e');
      // Don't rethrow, return what we have to keep UI alive
    }

    return allCompanies;
  }

  Future<CompanyModel?> getCompanyById(String id) async {
    final doc = await firestore.collection('companies').doc(id).get();
    if (doc.exists) {
      return CompanyModel.fromJson(doc.data()!);
    }

    // Fallback check in customers
    final oldDoc = await firestore.collection('customers').doc(id).get();
    if (oldDoc.exists) {
      return CompanyModel.fromJson(oldDoc.data()!);
    }

    return null;
  }

  Future<void> updateCompany(CompanyModel company) async {
    // Update both just in case we are in transition, or just companies.
    // Let's write to 'companies' primarily.
    await firestore
        .collection('companies')
        .doc(company.id)
        .set(company.toJson()); // Use set to create if not exists (migration)

    // Also update legacy collection to keep sync if we want, but better to move forward.
    // We will stop writing to 'customers' for company data to avoid confusion.
  }

  Future<void> deleteCompany(String id) async {
    await firestore.collection('companies').doc(id).delete();
    // Also try delete from legacy
    await firestore.collection('customers').doc(id).delete();
  }

  // ======================
  // CUSTOMER (Traveler) Operations
  // ======================
  // Note: These are the NEW customers (people)

  Future<void> insertCustomer(CustomerModel customer) async {
    try {
      debugPrint('DatabaseService: Inserting traveler ${customer.id}');
      await firestore
          .collection(
            'travelers',
          ) // New collection to avoid name collision with legacy 'customers'
          .doc(customer.id)
          .set(customer.toJson());
    } catch (e) {
      debugPrint('DatabaseService: Error inserting traveler: $e');
      rethrow;
    }
  }

  Future<List<CustomerModel>> getAllCustomers() async {
    final snapshot = await firestore
        .collection('travelers')
        .orderBy('name')
        .get();

    return snapshot.docs
        .map((doc) => CustomerModel.fromJson(doc.data()))
        .toList();
  }

  Future<List<CustomerModel>> getCustomersForCompany(String companyId) async {
    final snapshot = await firestore
        .collection('travelers')
        .where('companyId', isEqualTo: companyId)
        .orderBy('name')
        .get();

    return snapshot.docs
        .map((doc) => CustomerModel.fromJson(doc.data()))
        .toList();
  }

  Future<void> updateCustomer(CustomerModel customer) async {
    await firestore
        .collection('travelers')
        .doc(customer.id)
        .update(customer.toJson());
  }

  Future<void> deleteCustomer(String id) async {
    await firestore.collection('travelers').doc(id).delete();
  }

  // ======================
  // INVOICE Operations
  // ======================

  Future<String> generateNewInvoiceNumber() async {
    final now = DateTime.now();
    final year = now.year.toString();

    // Use a global counter to ensure sequence continuity across years
    final counterRef = firestore
        .collection('counters')
        .doc('invoice_counter_global');

    return firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);

      int currentSequence;

      if (!snapshot.exists) {
        // Migration: Find the absolute last invoice sequence number used
        // regardless of the year.
        try {
          // Try to get the most recently created invoice
          // We use 'createdAt' if available, otherwise fallback to 'date' or safe default
          final recentSnapshot = await firestore
              .collection('invoices')
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get();

          if (recentSnapshot.docs.isNotEmpty) {
            final data = recentSnapshot.docs.first.data();
            final invoiceNum = data['invoiceNumber'] as String;
            // Expected format: INT-YYYY-SEQ
            final parts = invoiceNum.split('-');
            if (parts.length >= 3) {
              final seqStr = parts.last;
              currentSequence = int.tryParse(seqStr) ?? 1640;
            } else {
              currentSequence = 1640;
            }
          } else {
            // If no invoices by createdAt, try by date (legacy support)
            final dateSnapshot = await firestore
                .collection('invoices')
                .orderBy('date', descending: true)
                .limit(1)
                .get();

            if (dateSnapshot.docs.isNotEmpty) {
              final data = dateSnapshot.docs.first.data();
              final invoiceNum = data['invoiceNumber'] as String;
              final parts = invoiceNum.split('-');
              if (parts.length >= 3) {
                final seqStr = parts.last;
                currentSequence = int.tryParse(seqStr) ?? 1640;
              } else {
                currentSequence = 1640;
              }
            } else {
              // Absolutely no invoices found, start fresh
              currentSequence = 1640;
            }
          }
        } catch (e) {
          debugPrint('DatabaseService: Error determining last sequence: $e');
          // Fallback if query fails (e.g. missing index)
          currentSequence = 1640;
        }
      } else {
        currentSequence = snapshot.data()!['currentSequence'] as int;
      }

      final nextSequence = currentSequence + 1;

      // Update the global counter
      transaction.set(counterRef, {'currentSequence': nextSequence});

      return 'INT-$year-$nextSequence';
    });
  }

  Future<void> insertInvoice(InvoiceModel invoice) async {
    if (invoice.id == null) {
      throw Exception('Invoice ID is required');
    }

    final invoiceData = invoice.toJson();

    // Remove company object (store ID instead)
    invoiceData.remove('company');
    invoiceData.remove('customer'); // Clean up old field if present

    invoiceData['date'] = Timestamp.fromDate(invoice.date);
    invoiceData['createdAt'] = Timestamp.now();

    if (invoice.company != null) {
      invoiceData['companyId'] = invoice.company!.id;
      // Also store 'customerId' for legacy compatibility if needed, but strictly it refers to Company now
      invoiceData['customerId'] = invoice.company!.id;
    }

    await firestore.collection('invoices').doc(invoice.id).set(invoiceData);
  }

  Future<List<InvoiceModel>> getAllInvoices({int? month, int? year}) async {
    Query query = firestore.collection('invoices');

    if (month != null && year != null) {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 1);

      query = query
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThan: Timestamp.fromDate(endDate));
    }

    query = query.orderBy('date', descending: true);

    final snapshot = await query.get();

    // Collect all unique company IDs (previously customerId)
    final Set<String> companyIds = {};
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      // Check both new 'companyId' and old 'customerId'
      final companyId = data['companyId'] ?? data['customerId'];
      if (companyId != null) {
        companyIds.add(companyId as String);
      }
    }

    // Batch fetch companies
    final Map<String, CompanyModel> companiesMap = {};
    if (companyIds.isNotEmpty) {
      final companyFutures = companyIds.map((id) async {
        try {
          final company = await getCompanyById(id);
          if (company != null) {
            return MapEntry(id, company);
          }
        } catch (e) {
          print('Error fetching company $id: $e');
        }
        return null; // Should handle null entries??
      }).toList();

      final results = await Future.wait(companyFutures);
      for (var result in results) {
        if (result != null) {
          companiesMap[result.key] = result.value;
        }
      }
    }

    List<InvoiceModel> invoices = [];

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final invoiceId = doc.id;

      CompanyModel? company;
      final companyId = data['companyId'] ?? data['customerId'];
      if (companyId != null) {
        company = companiesMap[companyId as String];
      }

      List<LineItemModel> lineItems = [];
      final lineItemsData = data['lineItems'];
      if (lineItemsData != null && lineItemsData is List) {
        lineItems = lineItemsData
            .map(
              (itemMap) =>
                  LineItemModel.fromJson(itemMap as Map<String, dynamic>),
            )
            .toList();
      }

      final invoiceMap = Map<String, dynamic>.from(data);
      invoiceMap['id'] = invoiceId;

      final dateValue = data['date'];
      if (dateValue is Timestamp) {
        invoiceMap['date'] = dateValue.toDate().millisecondsSinceEpoch;
      }

      invoices.add(
        InvoiceModel.fromMap(invoiceMap, company: company, items: lineItems),
      );
    }

    return invoices;
  }

  Future<Map<String, dynamic>> getAnalytics({int? month, int? year}) async {
    final invoices = await getAllInvoices(month: month, year: year);

    double totalRevenue = 0;
    double totalTax = 0;
    double totalDiscount = 0;
    int invoiceCount = invoices.length;

    for (var invoice in invoices) {
      totalRevenue += invoice.grandTotal;
      totalTax += invoice.taxAmount;
      totalDiscount += invoice.totalDiscount;
    }

    double averageInvoiceValue = invoiceCount > 0
        ? totalRevenue / invoiceCount
        : 0;

    // Monthly revenue (last 6 months)
    final now = DateTime.now();
    List<Map<String, dynamic>> monthlyRevenue = [];

    for (int i = 5; i >= 0; i--) {
      final targetMonth = DateTime(now.year, now.month - i, 1);
      final monthInvoices = await getAllInvoices(
        month: targetMonth.month,
        year: targetMonth.year,
      );

      double monthTotal = 0;
      for (var invoice in monthInvoices) {
        monthTotal += invoice.grandTotal;
      }

      monthlyRevenue.add({
        'month': targetMonth.month,
        'year': targetMonth.year,
        'revenue': monthTotal,
        'count': monthInvoices.length,
      });
    }

    // Top Companies by Revenue
    Map<String, Map<String, dynamic>> companyRevenue = {};

    for (var invoice in invoices) {
      if (invoice.company != null) {
        final id = invoice.company!.id;
        if (!companyRevenue.containsKey(id)) {
          companyRevenue[id] = {
            'company': invoice.company,
            'revenue': 0.0,
            'invoiceCount': 0,
          };
        }
        companyRevenue[id]!['revenue'] += invoice.grandTotal;
        companyRevenue[id]!['invoiceCount'] += 1;
      }
    }

    final topCompanies = companyRevenue.values.toList()
      ..sort(
        (a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double),
      );
    final top5 = topCompanies.take(5).toList();

    return {
      'totalRevenue': totalRevenue,
      'invoiceCount': invoiceCount,
      'averageInvoiceValue': averageInvoiceValue,
      'totalTax': totalTax,
      'totalDiscount': totalDiscount,
      'monthlyRevenue': monthlyRevenue,
      'topCompanies': top5, // renamed from topCustomers
    };
  }

  Future<void> updateInvoice(InvoiceModel invoice) async {
    final invoiceData = invoice.toJson();

    invoiceData.remove('company');
    invoiceData['date'] = Timestamp.fromDate(invoice.date);

    if (invoice.company != null) {
      invoiceData['companyId'] = invoice.company!.id;
      invoiceData['customerId'] = invoice.company!.id; // Legacy Sync
    }

    await firestore.collection('invoices').doc(invoice.id).update(invoiceData);
  }

  Future<void> deleteInvoice(String invoiceId) async {
    await firestore.collection('invoices').doc(invoiceId).delete();
  }

  // ======================
  // EMPLOYEE Operations
  // ======================

  Future<void> insertEmployee(EmployeeModel employee) async {
    try {
      debugPrint('DatabaseService: Inserting employee ${employee.id}');
      await firestore
          .collection('employees')
          .doc(employee.id)
          .set(employee.toJson());
    } catch (e) {
      debugPrint('DatabaseService: Error inserting employee: $e');
      rethrow;
    }
  }

  Future<List<EmployeeModel>> getAllEmployees() async {
    final snapshot = await firestore
        .collection('employees')
        .orderBy('fullName')
        .get();

    return snapshot.docs
        .map((doc) => EmployeeModel.fromJson(doc.data()))
        .toList();
  }

  Future<void> updateEmployee(EmployeeModel employee) async {
    await firestore
        .collection('employees')
        .doc(employee.id)
        .update(employee.toJson());
  }

  Future<void> deleteEmployee(String id) async {
    await firestore.collection('employees').doc(id).delete();
  }

  Future<String> uploadEmployeeImage(XFile image, String employeeId) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('employee_images')
          .child('$employeeId.jpg');

      if (kIsWeb) {
        await storageRef.putData(await image.readAsBytes());
      } else {
        await storageRef.putFile(File(image.path));
      }

      return await storageRef.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading employee image: $e');
      rethrow;
    }
  }

  // ======================
  // NOTIFICATION Operations
  // ======================

  Future<void> insertNotification(NotificationModel notification) async {
    try {
      debugPrint('DatabaseService: Inserting notification ${notification.id}');
      await firestore
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toJson());
    } catch (e) {
      debugPrint('DatabaseService: Error inserting notification: $e');
      rethrow;
    }
  }

  Stream<List<NotificationModel>> getNotifications() {
    return firestore
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => NotificationModel.fromJson(doc.data()))
              .toList();
        });
  }

  Future<void> markNotificationAsRead(String id) async {
    await firestore.collection('notifications').doc(id).update({
      'isRead': true,
    });
  }
  // ======================
  // VEHICLE Operations
  // ======================

  Future<void> insertVehicle(VehicleModel vehicle) async {
    try {
      debugPrint('DatabaseService: Inserting vehicle ${vehicle.id}');

      // Enforce 1:1 Driver Assignment
      if (vehicle.assignedDriverId != null) {
        final batch = firestore.batch();
        final currentAssignments = await firestore
            .collection('vehicles')
            .where('assignedDriverId', isEqualTo: vehicle.assignedDriverId)
            .get();

        for (var doc in currentAssignments.docs) {
          // New vehicle, so any existing assignment is "other"
          batch.update(doc.reference, {'assignedDriverId': null});
        }
        await batch.commit();
      }

      await firestore
          .collection('vehicles')
          .doc(vehicle.id)
          .set(vehicle.toJson());
    } catch (e) {
      debugPrint('DatabaseService: Error inserting vehicle: $e');
      rethrow;
    }
  }

  Future<List<VehicleModel>> getAllVehicles() async {
    final snapshot = await firestore
        .collection('vehicles')
        .orderBy('make')
        .get();

    return snapshot.docs
        .map((doc) => VehicleModel.fromJson(doc.data()))
        .toList();
  }

  Future<void> updateVehicle(VehicleModel vehicle) async {
    try {
      // Enforce 1:1 Driver Assignment
      if (vehicle.assignedDriverId != null) {
        final batch = firestore.batch();
        final currentAssignments = await firestore
            .collection('vehicles')
            .where('assignedDriverId', isEqualTo: vehicle.assignedDriverId)
            .get();

        for (var doc in currentAssignments.docs) {
          if (doc.id != vehicle.id) {
            batch.update(doc.reference, {'assignedDriverId': null});
          }
        }
        await batch.commit();
      }
      await firestore
          .collection('vehicles')
          .doc(vehicle.id)
          .update(vehicle.toJson());
    } catch (e) {
      debugPrint('DatabaseService: Error updating vehicle: $e');
      rethrow;
    }
  }

  Future<void> deleteVehicle(String id) async {
    await firestore.collection('vehicles').doc(id).delete();
  }

  /// Assigns a driver to a vehicle, ensuing 1:1 relationship.
  /// If the driver was assigned to another vehicle, they are unassigned from it.
  /// If the vehicle had another driver, that driver is replaced.
  Future<void> assignDriverToVehicle(String? vehicleId, String driverId) async {
    try {
      final batch = firestore.batch();

      // 1. Find any OTHER vehicle currently assigned to this driver
      final currentAssignments = await firestore
          .collection('vehicles')
          .where('assignedDriverId', isEqualTo: driverId)
          .get();

      for (var doc in currentAssignments.docs) {
        if (doc.id != vehicleId) {
          // Unassign from old vehicle
          batch.update(doc.reference, {'assignedDriverId': null});
        }
      }

      // 2. Assign to new vehicle (if provided)
      if (vehicleId != null) {
        final vehicleRef = firestore.collection('vehicles').doc(vehicleId);
        batch.update(vehicleRef, {'assignedDriverId': driverId});
      }

      await batch.commit();
    } catch (e) {
      debugPrint('DatabaseService: Error assigning driver: $e');
      rethrow;
    }
  }

  // ======================
  // VEHICLE MASTER Operations
  // ======================

  Future<void> insertVehicleMake(VehicleMakeModel make) async {
    await firestore.collection('vehicle_makes').doc(make.id).set(make.toJson());
  }

  Future<List<VehicleMakeModel>> getAllVehicleMakes() async {
    final snapshot = await firestore
        .collection('vehicle_makes')
        .orderBy('name')
        .get();
    return snapshot.docs
        .map((doc) => VehicleMakeModel.fromJson(doc.data()))
        .toList();
  }

  Future<void> updateVehicleMake(VehicleMakeModel make) async {
    await firestore
        .collection('vehicle_makes')
        .doc(make.id)
        .update(make.toJson());
  }

  Future<void> deleteVehicleMake(String id) async {
    await firestore.collection('vehicle_makes').doc(id).delete();
  }
  // ======================
  // DATA SEEDING
  // ======================

  Future<void> seedVehicleMasterData() async {
    final List<VehicleMakeModel> defaultMakes = [
      VehicleMakeModel(
        id: 'toyota',
        name: 'Toyota',
        logoUrl: 'https://logo.clearbit.com/toyota.com',
        models: [
          VehicleModelDetail(name: 'Land Cruiser', type: 'SUV'),
          VehicleModelDetail(name: 'Land Cruiser Prado', type: 'SUV'),
          VehicleModelDetail(name: 'Fortuner', type: 'SUV'),
          VehicleModelDetail(name: 'Highlander', type: 'SUV'),
          VehicleModelDetail(name: 'Camry', type: 'Sedan'),
          VehicleModelDetail(name: 'Corolla', type: 'Sedan'),
          VehicleModelDetail(name: 'Yaris', type: 'Sedan'),
          VehicleModelDetail(name: 'Hiace', type: 'Van'),
          VehicleModelDetail(name: 'Granvia', type: 'Van'),
          VehicleModelDetail(name: 'Coaster', type: 'Bus'),
          VehicleModelDetail(name: 'Hilux', type: 'Pickup'),
          VehicleModelDetail(name: 'Innova', type: 'Van'),
          VehicleModelDetail(name: 'Supra', type: 'Coupe'),
        ],
        years: List.generate(12, (index) => 2015 + index), // 2015-2026
        colors: [
          'White',
          'Pearl White',
          'Black',
          'Silver',
          'Grey',
          'Beige',
          'Red',
          'Blue',
          'Gold',
        ],
      ),
      VehicleMakeModel(
        id: 'nissan',
        name: 'Nissan',
        logoUrl: 'https://logo.clearbit.com/nissan-global.com',
        models: [
          VehicleModelDetail(name: 'Patrol', type: 'SUV'),
          VehicleModelDetail(name: 'Patrol Super Safari', type: 'SUV'),
          VehicleModelDetail(name: 'X-Terra', type: 'SUV'),
          VehicleModelDetail(name: 'X-Trail', type: 'SUV'),
          VehicleModelDetail(name: 'Pathfinder', type: 'SUV'),
          VehicleModelDetail(name: 'Kicks', type: 'Crossover'),
          VehicleModelDetail(name: 'Altima', type: 'Sedan'),
          VehicleModelDetail(name: 'Maxima', type: 'Sedan'),
          VehicleModelDetail(name: 'Sunny', type: 'Sedan'),
          VehicleModelDetail(name: 'Urvan', type: 'Van'),
          VehicleModelDetail(name: 'Civilian', type: 'Bus'),
          VehicleModelDetail(name: 'Navara', type: 'Pickup'),
        ],
        years: List.generate(12, (index) => 2015 + index),
        colors: [
          'White',
          'Super Black',
          'Silver',
          'Grey',
          'Red',
          'Blue',
          'Gold',
          'Brown',
        ],
      ),
      VehicleMakeModel(
        id: 'mitsubishi',
        name: 'Mitsubishi',
        logoUrl: 'https://logo.clearbit.com/mitsubishi-motors.com',
        models: [
          VehicleModelDetail(name: 'Pajero', type: 'SUV'),
          VehicleModelDetail(name: 'Montero Sport', type: 'SUV'),
          VehicleModelDetail(name: 'Outlander', type: 'SUV'),
          VehicleModelDetail(name: 'ASX', type: 'Crossover'),
          VehicleModelDetail(name: 'Eclipse Cross', type: 'Crossover'),
          VehicleModelDetail(name: 'Xpander', type: 'MPV'),
          VehicleModelDetail(name: 'Attrage', type: 'Sedan'),
          VehicleModelDetail(name: 'L200', type: 'Pickup'),
          VehicleModelDetail(name: 'Rosa', type: 'Bus'),
        ],
        years: List.generate(12, (index) => 2015 + index),
        colors: ['White', 'Black', 'Silver', 'Grey', 'Red', 'Blue', 'Brown'],
      ),
      VehicleMakeModel(
        id: 'lexus',
        name: 'Lexus',
        logoUrl: 'https://logo.clearbit.com/lexus.com',
        models: [
          VehicleModelDetail(name: 'LX', type: 'SUV'),
          VehicleModelDetail(name: 'GX', type: 'SUV'),
          VehicleModelDetail(name: 'RX', type: 'SUV'),
          VehicleModelDetail(name: 'NX', type: 'SUV'),
          VehicleModelDetail(name: 'UX', type: 'Crossover'),
          VehicleModelDetail(name: 'ES', type: 'Sedan'),
          VehicleModelDetail(name: 'LS', type: 'Sedan'),
          VehicleModelDetail(name: 'IS', type: 'Sedan'),
          VehicleModelDetail(name: 'RC', type: 'Coupe'),
          VehicleModelDetail(name: 'LC', type: 'Coupe'),
        ],
        years: List.generate(12, (index) => 2015 + index),
        colors: [
          'White',
          'Black',
          'Titanium',
          'Sonic Quartz',
          'Sonic Titanium',
          'Deep Blue Mica',
          'Red',
        ],
      ),
      VehicleMakeModel(
        id: 'mercedes',
        name: 'Mercedes-Benz',
        logoUrl: 'https://logo.clearbit.com/mercedes-benz.com',
        models: [
          VehicleModelDetail(name: 'S-Class', type: 'Sedan'),
          VehicleModelDetail(name: 'E-Class', type: 'Sedan'),
          VehicleModelDetail(name: 'C-Class', type: 'Sedan'),
          VehicleModelDetail(name: 'G-Class', type: 'SUV'),
          VehicleModelDetail(name: 'GLE', type: 'SUV'),
          VehicleModelDetail(name: 'GLS', type: 'SUV'),
          VehicleModelDetail(name: 'GLC', type: 'SUV'),
          VehicleModelDetail(name: 'V-Class', type: 'Van'),
          VehicleModelDetail(name: 'Sprinter', type: 'Van'),
          VehicleModelDetail(name: 'Maybach', type: 'Sedan'),
        ],
        years: List.generate(12, (index) => 2015 + index),
        colors: [
          'White',
          'Obsidian Black',
          'Iridium Silver',
          'Selenite Grey',
          'Blue',
          'Designo Red',
        ],
      ),
      VehicleMakeModel(
        id: 'bmw',
        name: 'BMW',
        logoUrl: 'https://logo.clearbit.com/bmw.com',
        models: [
          VehicleModelDetail(name: '7 Series', type: 'Sedan'),
          VehicleModelDetail(name: 'X7', type: 'SUV'),
          VehicleModelDetail(name: 'X6', type: 'SUV'),
          VehicleModelDetail(name: 'X5', type: 'SUV'),
          VehicleModelDetail(name: 'X4', type: 'SUV'),
          VehicleModelDetail(name: 'X3', type: 'SUV'),
          VehicleModelDetail(name: '5 Series', type: 'Sedan'),
          VehicleModelDetail(name: '3 Series', type: 'Sedan'),
          VehicleModelDetail(name: '8 Series', type: 'Coupe'),
        ],
        years: List.generate(12, (index) => 2015 + index),
        colors: [
          'Alpine White',
          'Black Sapphire',
          'Mineral White',
          'Phytonic Blue',
          'Carbon Black',
          'Grey',
        ],
      ),
      VehicleMakeModel(
        id: 'hyundai',
        name: 'Hyundai',
        logoUrl: 'https://logo.clearbit.com/hyundai.com',
        models: [
          VehicleModelDetail(name: 'Palisade', type: 'SUV'),
          VehicleModelDetail(name: 'Santa Fe', type: 'SUV'),
          VehicleModelDetail(name: 'Tucson', type: 'SUV'),
          VehicleModelDetail(name: 'Creta', type: 'Crossover'),
          VehicleModelDetail(name: 'Staria', type: 'Van'),
          VehicleModelDetail(name: 'H-1', type: 'Van'),
          VehicleModelDetail(name: 'Sonata', type: 'Sedan'),
          VehicleModelDetail(name: 'Elantra', type: 'Sedan'),
          VehicleModelDetail(name: 'Accent', type: 'Sedan'),
        ],
        years: List.generate(12, (index) => 2015 + index),
        colors: [
          'White',
          'Black',
          'Silver',
          'Titan Grey',
          'Red',
          'Blue',
          'Creamy White',
        ],
      ),
      VehicleMakeModel(
        id: 'kia',
        name: 'Kia',
        logoUrl: 'https://logo.clearbit.com/kia.com',
        models: [
          VehicleModelDetail(name: 'Telluride', type: 'SUV'),
          VehicleModelDetail(name: 'Sorento', type: 'SUV'),
          VehicleModelDetail(name: 'Sportage', type: 'SUV'),
          VehicleModelDetail(name: 'Seltos', type: 'Crossover'),
          VehicleModelDetail(name: 'Carnival', type: 'Van'),
          VehicleModelDetail(name: 'K5', type: 'Sedan'),
          VehicleModelDetail(name: 'Cerato', type: 'Sedan'),
          VehicleModelDetail(name: 'Pegas', type: 'Sedan'),
          VehicleModelDetail(name: 'Picanto', type: 'Hatchback'),
        ],
        years: List.generate(12, (index) => 2015 + index),
        colors: [
          'Snow White Pearl',
          'Aurora Black Pearl',
          'Silky Silver',
          'Steel Grey',
          'Gravity Grey',
          'Blue',
          'Red',
        ],
      ),
      VehicleMakeModel(
        id: 'ford',
        name: 'Ford',
        logoUrl: 'https://logo.clearbit.com/ford.com',
        models: [
          VehicleModelDetail(name: 'Expedition', type: 'SUV'),
          VehicleModelDetail(name: 'Explorer', type: 'SUV'),
          VehicleModelDetail(name: 'Everest', type: 'SUV'),
          VehicleModelDetail(name: 'Edge', type: 'SUV'),
          VehicleModelDetail(name: 'Territory', type: 'Crossover'),
          VehicleModelDetail(name: 'F-150', type: 'Pickup'),
          VehicleModelDetail(name: 'Ranger', type: 'Pickup'),
          VehicleModelDetail(name: 'Mustang', type: 'Coupe'),
          VehicleModelDetail(name: 'Taurus', type: 'Sedan'),
          VehicleModelDetail(name: 'Transit', type: 'Van'),
        ],
        years: List.generate(12, (index) => 2015 + index),
        colors: [
          'Oxford White',
          'Absolute Black',
          'Iconic Silver',
          'Carbonized Grey',
          'Rapid Red',
          'Velocity Blue',
        ],
      ),
      VehicleMakeModel(
        id: 'chevrolet',
        name: 'Chevrolet',
        logoUrl: 'https://logo.clearbit.com/chevrolet.com',
        models: [
          VehicleModelDetail(name: 'Tahoe', type: 'SUV'),
          VehicleModelDetail(name: 'Suburban', type: 'SUV'),
          VehicleModelDetail(name: 'Silverado', type: 'Pickup'),
          VehicleModelDetail(name: 'Traverse', type: 'SUV'),
          VehicleModelDetail(name: 'Blazer', type: 'SUV'),
          VehicleModelDetail(name: 'Equinox', type: 'SUV'),
          VehicleModelDetail(name: 'Captiva', type: 'SUV'),
          VehicleModelDetail(name: 'Groove', type: 'Crossover'),
          VehicleModelDetail(name: 'Camaro', type: 'Coupe'),
          VehicleModelDetail(name: 'Corvette', type: 'Coupe'),
        ],
        years: List.generate(12, (index) => 2015 + index),
        colors: [
          'Summit White',
          'Black',
          'Silver Ice',
          'Shadow Grey',
          'Cherry Red',
          'Blue',
        ],
      ),
      VehicleMakeModel(
        id: 'land_rover',
        name: 'Land Rover',
        logoUrl: 'https://logo.clearbit.com/landrover.com',
        models: [
          VehicleModelDetail(name: 'Range Rover', type: 'SUV'),
          VehicleModelDetail(name: 'Range Rover Sport', type: 'SUV'),
          VehicleModelDetail(name: 'Range Rover Velar', type: 'SUV'),
          VehicleModelDetail(name: 'Range Rover Evoque', type: 'SUV'),
          VehicleModelDetail(name: 'Defender', type: 'SUV'),
          VehicleModelDetail(name: 'Discovery', type: 'SUV'),
          VehicleModelDetail(name: 'Discovery Sport', type: 'SUV'),
        ],
        years: List.generate(12, (index) => 2015 + index),
        colors: [
          'White',
          'Santorini Black',
          'Eiger Grey',
          'Hakka Silver',
          'Fuji White',
          'Blue',
        ],
      ),
      VehicleMakeModel(
        id: 'gmc',
        name: 'GMC',
        logoUrl: 'https://logo.clearbit.com/gmc.com',
        models: [
          VehicleModelDetail(name: 'Yukon', type: 'SUV'),
          VehicleModelDetail(name: 'Yukon XL', type: 'SUV'),
          VehicleModelDetail(name: 'Sierra', type: 'Pickup'),
          VehicleModelDetail(name: 'Acadia', type: 'SUV'),
          VehicleModelDetail(name: 'Terrain', type: 'SUV'),
          VehicleModelDetail(name: 'Savana', type: 'Van'),
        ],
        years: List.generate(12, (index) => 2015 + index),
        colors: [
          'Summit White',
          'Onyx Black',
          'Quicksilver',
          'Satin Steel',
          'Red Quartz',
          'Blue',
        ],
      ),
    ];

    final batch = firestore.batch();
    for (var make in defaultMakes) {
      final docRef = firestore.collection('vehicle_makes').doc(make.id);
      batch.set(docRef, make.toJson());
    }
    await batch.commit();
  }
}
