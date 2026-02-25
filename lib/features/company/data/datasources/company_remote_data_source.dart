import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/error/exceptions.dart';
import '../models/company_model.dart';
import 'package:flutter/foundation.dart';

abstract class CompanyRemoteDataSource {
  Future<List<CompanyModel>> getCompanies();
  Future<CompanyModel?> getCompanyById(String id);
  Future<void> insertCompany(CompanyModel company);
  Future<void> updateCompany(CompanyModel company);
  Future<void> deleteCompany(String id);
}

class CompanyRemoteDataSourceImpl implements CompanyRemoteDataSource {
  final FirebaseFirestore firestore;

  CompanyRemoteDataSourceImpl({required this.firestore});

  @override
  Future<List<CompanyModel>> getCompanies() async {
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

      // 2. Fetch from legacy 'customers' collection (to ensure no data is lost)
      final customersSnapshot = await firestore
          .collection('customers')
          .orderBy('companyName')
          .get();

      final oldCompanies = customersSnapshot.docs
          .map((doc) => CompanyModel.fromJson(doc.data()))
          .toList();

      for (var company in oldCompanies) {
        if (!companyIds.contains(company.id)) {
          allCompanies.add(company);
          companyIds.add(company.id);
        }
      }

      allCompanies.sort((a, b) => a.companyName.compareTo(b.companyName));
      return allCompanies;
    } catch (e) {
      debugPrint('Error fetching companies in datasource: $e');
      throw ServerException('Failed to fetch companies');
    }
  }

  @override
  Future<CompanyModel?> getCompanyById(String id) async {
    try {
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
    } catch (e) {
      throw ServerException('Failed to fetch company by ID: $e');
    }
  }

  @override
  Future<void> insertCompany(CompanyModel company) async {
    try {
      await firestore
          .collection('companies')
          .doc(company.id)
          .set(company.toJson());
    } catch (e) {
      throw ServerException('Failed to insert company: $e');
    }
  }

  @override
  Future<void> updateCompany(CompanyModel company) async {
    try {
      await firestore
          .collection('companies')
          .doc(company.id)
          .set(company.toJson());
    } catch (e) {
      throw ServerException('Failed to update company: $e');
    }
  }

  @override
  Future<void> deleteCompany(String id) async {
    try {
      await firestore.collection('companies').doc(id).delete();
      // Try delete from legacy as well
      await firestore.collection('customers').doc(id).delete();
    } catch (e) {
      throw ServerException('Failed to delete company: $e');
    }
  }
}
