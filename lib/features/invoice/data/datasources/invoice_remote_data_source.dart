import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/invoice_model.dart';
import '../models/line_item_model.dart';
import '../../../../features/company/data/models/company_model.dart';

abstract class InvoiceRemoteDataSource {
  Future<void> insertInvoice(InvoiceModel invoice);
  Future<List<InvoiceModel>> getAllInvoices({int? month, int? year});
  Future<void> updateInvoice(InvoiceModel invoice);
  Future<void> deleteInvoice(String id);
  Future<String> generateNewInvoiceNumber();
}

class InvoiceRemoteDataSourceImpl implements InvoiceRemoteDataSource {
  final FirebaseFirestore firestore;

  InvoiceRemoteDataSourceImpl({required this.firestore});

  // Helper method to fetch company
  Future<CompanyModel?> _getCompanyById(String id) async {
    final doc = await firestore.collection('companies').doc(id).get();
    if (doc.exists && doc.data() != null) {
      return CompanyModel.fromJson(doc.data()!);
    }
    // Fallback check in customers (Legacy)
    final oldDoc = await firestore.collection('customers').doc(id).get();
    if (oldDoc.exists && oldDoc.data() != null) {
      return CompanyModel.fromJson(oldDoc.data()!);
    }
    return null;
  }

  @override
  Future<String> generateNewInvoiceNumber() async {
    final now = DateTime.now();
    final year = now.year.toString();

    final counterRef = firestore
        .collection('counters')
        .doc('invoice_counter_global');

    return firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);

      int currentSequence;

      if (!snapshot.exists) {
        try {
          final recentSnapshot = await firestore
              .collection('invoices')
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get();

          if (recentSnapshot.docs.isNotEmpty) {
            final data = recentSnapshot.docs.first.data();
            final invoiceNum = data['invoiceNumber'] as String;
            final parts = invoiceNum.split('-');
            if (parts.length >= 3) {
              final seqStr = parts.last;
              currentSequence = int.tryParse(seqStr) ?? 1640;
            } else {
              currentSequence = 1640;
            }
          } else {
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
              currentSequence = 1640;
            }
          }
        } catch (e) {
          debugPrint('Error determining last sequence: \$e');
          currentSequence = 1640;
        }
      } else {
        currentSequence = snapshot.data()!['currentSequence'] as int;
      }

      final nextSequence = currentSequence + 1;
      transaction.set(counterRef, {'currentSequence': nextSequence});

      return 'INT-$year-$nextSequence';
    });
  }

  @override
  Future<void> insertInvoice(InvoiceModel invoice) async {
    if (invoice.id == null) {
      throw Exception('Invoice ID is required');
    }

    final invoiceData = invoice.toJson();

    invoiceData.remove('company');
    invoiceData.remove('customer');

    invoiceData['date'] = Timestamp.fromDate(invoice.date);
    invoiceData['createdAt'] = Timestamp.now();

    if (invoice.company != null) {
      invoiceData['companyId'] = invoice.company!.id;
      invoiceData['customerId'] = invoice.company!.id;
    }

    await firestore.collection('invoices').doc(invoice.id).set(invoiceData);
  }

  @override
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

    final Set<String> companyIds = {};
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final companyId = data['companyId'] ?? data['customerId'];
      if (companyId != null) {
        companyIds.add(companyId as String);
      }
    }

    final Map<String, CompanyModel> companiesMap = {};
    if (companyIds.isNotEmpty) {
      final companyFutures = companyIds.map((id) async {
        try {
          final company = await _getCompanyById(id);
          if (company != null) {
            return MapEntry(id, company);
          }
        } catch (e) {
          debugPrint('Error fetching company \$id: \$e');
        }
        return null;
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

      final invoiceMap = Map<String, dynamic>.from(data);
      invoiceMap['id'] = invoiceId;

      final dateValue = data['date'];
      if (dateValue is Timestamp) {
        invoiceMap['date'] = dateValue.toDate().millisecondsSinceEpoch;
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

      invoices.add(
        InvoiceModel.fromMap(invoiceMap, company: company, items: lineItems),
      );
    }

    return invoices;
  }

  @override
  Future<void> updateInvoice(InvoiceModel invoice) async {
    final invoiceData = invoice.toJson();

    invoiceData.remove('company');
    invoiceData['date'] = Timestamp.fromDate(invoice.date);

    if (invoice.company != null) {
      invoiceData['companyId'] = invoice.company!.id;
      invoiceData['customerId'] = invoice.company!.id;
    }

    await firestore.collection('invoices').doc(invoice.id).update(invoiceData);
  }

  @override
  Future<void> deleteInvoice(String id) async {
    await firestore.collection('invoices').doc(id).delete();
  }
}
