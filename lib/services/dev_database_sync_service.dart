import 'dart:convert';
import 'package:http/http.dart' as http;

class DevDatabaseSyncService {
  final http.Client client;

  DevDatabaseSyncService({required this.client});

  static const String prodProject = 'xloop-tours-invoice';
  static const String devProject = 'xloop-tours-dev';

  static const List<String> collections = [
    "Settings",
    "allowed_users",
    "companies",
    "counters",
    "customers",
    "employees",
    "invoices",
    "maintenance_types",
    "notifications",
    "settings",
    "travelers",
    "vat_filings",
    "vehicle_makes",
    "vehicles",
    "xloop_company"
  ];

  Stream<String> syncAll() async* {
    yield "=== Starting Firestore Sync: PROD -> DEV ===";

    for (final col in collections) {
      yield "\nProcessing collection: '$col'";

      // 1. Fetch existing dev docs
      yield "  Retrieving existing DEV documents...";
      List<dynamic> devDocs = [];
      try {
        devDocs = await _fetchAllDocuments(devProject, col);
      } catch (e) {
        yield "  Error retrieving DEV documents: $e";
        continue;
      }

      if (devDocs.isNotEmpty) {
        yield "  Found ${devDocs.length} documents in DEV. Deleting...";
        List<Map<String, dynamic>> deleteWrites = [];
        for (var doc in devDocs) {
          deleteWrites.add({"delete": doc["name"]});

          if (deleteWrites.length == 200) {
            try {
              await _commitBatch(devProject, deleteWrites);
            } catch (e) {
              yield "  Error committing delete batch: $e";
            }
            deleteWrites = [];
          }
        }
        if (deleteWrites.isNotEmpty) {
          try {
            await _commitBatch(devProject, deleteWrites);
          } catch (e) {
            yield "  Error committing delete batch: $e";
          }
        }
        yield "  DEV documents deleted.";
      } else {
        yield "  No existing documents found in DEV.";
      }

      // 2. Fetch prod docs to copy
      yield "  Retrieving PROD documents...";
      List<dynamic> prodDocs = [];
      try {
        prodDocs = await _fetchAllDocuments(prodProject, col);
      } catch (e) {
        yield "  Error retrieving PROD documents: $e";
        continue;
      }

      if (prodDocs.isNotEmpty) {
        yield "  Found ${prodDocs.length} documents in PROD. Copying to DEV...";
        List<Map<String, dynamic>> updateWrites = [];
        for (var doc in prodDocs) {
          String prodName = doc["name"] as String;
          String devName = prodName.replaceAll("projects/$prodProject", "projects/$devProject");

          updateWrites.add({
            "update": {
              "name": devName,
              "fields": doc["fields"] ?? {}
            }
          });

          if (updateWrites.length == 200) {
            try {
              await _commitBatch(devProject, updateWrites);
            } catch (e) {
              yield "  Error committing update batch: $e";
            }
            updateWrites = [];
          }
        }
        if (updateWrites.isNotEmpty) {
          try {
            await _commitBatch(devProject, updateWrites);
          } catch (e) {
            yield "  Error committing update batch: $e";
          }
        }
        yield "  Successfully copied ${prodDocs.length} documents.";
      } else {
        yield "  No documents found in PROD to copy.";
      }
    }

    yield "\n=== Firestore sync completed successfully! ===";
  }

  Future<List<dynamic>> _fetchAllDocuments(String projectId, String collectionId) async {
    List<dynamic> docs = [];
    String? pageToken;

    do {
      String url = "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/$collectionId?pageSize=300";
      if (pageToken != null) {
        url += "&pageToken=$pageToken";
      }

      final response = await client.get(Uri.parse(url));
      if (response.statusCode == 404) {
        break; // Collection does not exist or empty
      }
      if (response.statusCode != 200) {
        throw Exception("Failed to fetch documents: ${response.body}");
      }

      final data = json.decode(response.body);
      final pageDocs = data["documents"] as List<dynamic>?;
      if (pageDocs != null) {
        docs.addAll(pageDocs);
      }
      pageToken = data["nextPageToken"] as String?;
    } while (pageToken != null);

    return docs;
  }

  Future<void> _commitBatch(String projectId, List<Map<String, dynamic>> writes) async {
    final url = "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents:commit";
    final response = await client.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"writes": writes}),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to commit batch: ${response.body}");
    }
  }
}
