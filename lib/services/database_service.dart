import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:xloop_invoice/models/invoice_model.dart';
import 'package:xloop_invoice/models/line_item_model.dart';
import '../models/company_model.dart';
import '../models/customer_model.dart';

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
    final counterRef = firestore
        .collection('counters')
        .doc('invoice_counter_$year');

    return firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);

      int currentSequence;

      if (!snapshot.exists) {
        final nextYear = (now.year + 1).toString();
        final invoiceSnapshot = await firestore
            .collection('invoices')
            .where('invoiceNumber', isGreaterThanOrEqualTo: 'INT-$year-')
            .where('invoiceNumber', isLessThan: 'INT-$nextYear-')
            .get();

        final count = invoiceSnapshot.docs.length;
        currentSequence = 1640 + count;
      } else {
        currentSequence = snapshot.data()!['currentSequence'] as int;
      }

      final nextSequence = currentSequence + 1;

      // Update the counter
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
}
