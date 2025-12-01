import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:xloop_invoice/models/invoice_model.dart';
import 'package:xloop_invoice/models/line_item_model.dart';
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

  // Customer CRUD operations
  Future<void> insertCustomer(CustomerModel customer) async {
    try {
      debugPrint('DatabaseService: Inserting customer ${customer.id}');
      debugPrint('Customer data: ${customer.toJson()}');

      await firestore
          .collection('customers')
          .doc(customer.id)
          .set(customer.toJson());

      debugPrint('DatabaseService: Customer ${customer.id} saved successfully');
    } catch (e, stackTrace) {
      debugPrint('DatabaseService: Error inserting customer: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<List<CustomerModel>> getAllCustomers() async {
    final snapshot = await firestore
        .collection('customers')
        .orderBy('companyName')
        .get();

    return snapshot.docs
        .map((doc) => CustomerModel.fromJson(doc.data()))
        .toList();
  }

  Future<CustomerModel?> getCustomerById(String id) async {
    final doc = await firestore.collection('customers').doc(id).get();

    if (doc.exists) {
      return CustomerModel.fromJson(doc.data()!);
    }
    return null;
  }

  Future<void> updateCustomer(CustomerModel customer) async {
    await firestore
        .collection('customers')
        .doc(customer.id)
        .update(customer.toJson());
  }

  Future<void> deleteCustomer(String id) async {
    await firestore.collection('customers').doc(id).delete();
  }

  // Invoice Operations

  Future<String> generateNewInvoiceNumber() async {
    final now = DateTime.now();
    // Pattern: INT-YYYY-SEQ
    // Sequence starts at 1640
    final year = now.year.toString();

    final nextYear = (now.year + 1).toString();
    final snapshot = await firestore
        .collection('invoices')
        .where('invoiceNumber', isGreaterThanOrEqualTo: 'INT-$year-')
        .where('invoiceNumber', isLessThan: 'INT-$nextYear-')
        .get();

    final count = snapshot.docs.length;
    final sequence = (1640 + count).toString();

    return 'INT-$year-$sequence';
  }

  Future<void> insertInvoice(InvoiceModel invoice) async {
    if (invoice.id == null) {
      throw Exception('Invoice ID is required');
    }

    print('DEBUG INSERT: Saving invoice with ID: ${invoice.id}');
    print('DEBUG INSERT: Invoice has ${invoice.lineItems.length} line items');

    // Convert invoice to Firestore document
    final invoiceData = invoice.toJson();

    // Remove customer object (we store customerId instead and fetch customer separately)
    invoiceData.remove('customer');

    // Convert date to Timestamp
    invoiceData['date'] = Timestamp.fromDate(invoice.date);
    invoiceData['createdAt'] = Timestamp.now();

    // Store customerId if customer exists (for reference/lookup)
    if (invoice.customer != null) {
      invoiceData['customerId'] = invoice.customer!.id;
    }

    // Store line items as nested array (already included from toJson())
    // invoiceData['lineItems'] is already set from invoice.toJson()

    print('DEBUG INSERT: Invoice map ID: ${invoiceData['id']}');

    await firestore.collection('invoices').doc(invoice.id).set(invoiceData);

    print(
      'DEBUG INSERT: Successfully saved ${invoice.lineItems.length} line items',
    );
  }

  Future<List<InvoiceModel>> getAllInvoices({int? month, int? year}) async {
    Query query = firestore.collection('invoices');

    if (month != null && year != null) {
      // Filter by month and year
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 1);

      query = query
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThan: Timestamp.fromDate(endDate));
    }

    query = query.orderBy('date', descending: true);

    final snapshot = await query.get();

    print('DEBUG RETRIEVE: Found ${snapshot.docs.length} invoices in database');

    // Collect all unique customer IDs first
    final Set<String> customerIds = {};
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final customerId = data['customerId'];
      if (customerId != null) {
        customerIds.add(customerId as String);
      }
    }

    // Batch fetch all customers in parallel (much more efficient than sequential!)
    final Map<String, CustomerModel> customersMap = {};
    if (customerIds.isNotEmpty) {
      // Fetch all customers in parallel using Future.wait
      final customerFutures = customerIds.map((customerId) async {
        try {
          final doc = await firestore
              .collection('customers')
              .doc(customerId)
              .get();
          if (doc.exists) {
            return MapEntry(customerId, CustomerModel.fromJson(doc.data()!));
          }
        } catch (e) {
          print('Error fetching customer $customerId: $e');
        }
        return null;
      }).toList();

      final customerResults = await Future.wait(customerFutures);
      for (var result in customerResults) {
        if (result != null) {
          customersMap[result.key] = result.value;
        }
      }
    }

    List<InvoiceModel> invoices = [];

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final invoiceId = doc.id;
      print('DEBUG RETRIEVE: Processing invoice ID: $invoiceId');

      // Get customer from map (no individual query needed!)
      CustomerModel? customer;
      final customerId = data['customerId'];
      if (customerId != null) {
        customer = customersMap[customerId as String];
      }

      // Extract line items from nested array
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

      print(
        'DEBUG RETRIEVE: Invoice $invoiceId has ${lineItems.length} line items in DB',
      );

      // Convert Timestamp to DateTime for InvoiceModel
      final invoiceMap = Map<String, dynamic>.from(data);
      invoiceMap['id'] = invoiceId;

      final dateValue = data['date'];
      if (dateValue is Timestamp) {
        invoiceMap['date'] = dateValue.toDate().millisecondsSinceEpoch;
      }

      invoices.add(
        InvoiceModel.fromMap(invoiceMap, customer: customer, items: lineItems),
      );
    }

    return invoices;
  }

  Future<Map<String, dynamic>> getAnalytics({int? month, int? year}) async {
    // Get all invoices for the period
    final invoices = await getAllInvoices(month: month, year: year);

    // Calculate total revenue and other metrics
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

    // Get monthly revenue breakdown (last 6 months)
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

    // Get top customers by revenue
    Map<String, Map<String, dynamic>> customerRevenue = {};

    for (var invoice in invoices) {
      if (invoice.customer != null) {
        final customerId = invoice.customer!.id;
        if (!customerRevenue.containsKey(customerId)) {
          customerRevenue[customerId] = {
            'customer': invoice.customer,
            'revenue': 0.0,
            'invoiceCount': 0,
          };
        }
        customerRevenue[customerId]!['revenue'] += invoice.grandTotal;
        customerRevenue[customerId]!['invoiceCount'] += 1;
      }
    }

    // Sort customers by revenue and get top 5
    final topCustomers = customerRevenue.values.toList()
      ..sort(
        (a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double),
      );
    final top5Customers = topCustomers.take(5).toList();

    return {
      'totalRevenue': totalRevenue,
      'invoiceCount': invoiceCount,
      'averageInvoiceValue': averageInvoiceValue,
      'totalTax': totalTax,
      'totalDiscount': totalDiscount,
      'monthlyRevenue': monthlyRevenue,
      'topCustomers': top5Customers,
    };
  }

  Future<void> updateInvoice(InvoiceModel invoice) async {
    final invoiceData = invoice.toJson();

    // Remove customer object (we store customerId instead)
    invoiceData.remove('customer');

    // Convert date to Timestamp
    invoiceData['date'] = Timestamp.fromDate(invoice.date);

    // Store customerId if customer exists
    if (invoice.customer != null) {
      invoiceData['customerId'] = invoice.customer!.id;
    }

    await firestore.collection('invoices').doc(invoice.id).update(invoiceData);
  }

  Future<void> deleteInvoice(String invoiceId) async {
    await firestore.collection('invoices').doc(invoiceId).delete();
  }
}
