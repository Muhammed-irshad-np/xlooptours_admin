import 'package:intl/intl.dart';
import 'package:xloop_invoice/features/customer/domain/entities/customer_entity.dart';
import 'package:xloop_invoice/features/employee/domain/entities/employee_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_documents.dart';

/// Utility class to compare old vs new entity fields and produce
/// human-readable change summaries for activity logs.
class ChangeDiffHelper {
  ChangeDiffHelper._();

  // ---------------------------------------------------------------------------
  // Employee
  // ---------------------------------------------------------------------------

  static String? describeEmployeeChanges(
    EmployeeEntity oldE,
    EmployeeEntity newE,
  ) {
    final changes = <String>[];

    _addIfChanged(changes, 'Name', oldE.fullName, newE.fullName);
    _addIfChanged(changes, 'Position', oldE.position, newE.position);
    _addIfChanged(changes, 'Email', oldE.email, newE.email);
    _addIfChanged(changes, 'Country Code', oldE.countryCode, newE.countryCode);
    _addIfChanged(changes, 'Phone', oldE.phoneNumber, newE.phoneNumber);
    _addIfChanged(changes, 'Nationality', oldE.nationality, newE.nationality);
    _addIfChanged(changes, 'ID Type', oldE.idType, newE.idType);
    _addIfChanged(changes, 'ID Number', oldE.idNumber, newE.idNumber);
    _addDateIfChanged(changes, 'Join Date', oldE.joinDate, newE.joinDate);
    _addDateIfChanged(changes, 'Birth Date', oldE.birthDate, newE.birthDate);
    _addIfChanged(changes, 'Gender', oldE.gender, newE.gender);
    _addIfChanged(changes, 'Driver Type', oldE.driverType, newE.driverType);
    _addBoolIfChanged(changes, 'Status', oldE.isActive, newE.isActive,
        trueLabel: 'Active', falseLabel: 'Inactive');

    if ((oldE.imageUrl ?? '') != (newE.imageUrl ?? '')) {
      changes.add('Photo updated');
    }

    // Iqama
    _addIfChanged(changes, 'Iqama Number', oldE.iqama?.number, newE.iqama?.number);
    _addDateIfChanged(changes, 'Iqama Expiry', oldE.iqama?.expiryDate, newE.iqama?.expiryDate);
    if ((oldE.iqama?.attachmentUrl ?? '') != (newE.iqama?.attachmentUrl ?? '')) changes.add('Iqama attachment updated');

    // Bahrain Residence
    _addIfChanged(changes, 'Bahrain Residence Number', oldE.bahrainResidence?.number, newE.bahrainResidence?.number);
    _addDateIfChanged(changes, 'Bahrain Residence Expiry', oldE.bahrainResidence?.expiryDate, newE.bahrainResidence?.expiryDate);
    if ((oldE.bahrainResidence?.attachmentUrl ?? '') != (newE.bahrainResidence?.attachmentUrl ?? '')) changes.add('Bahrain Residence attachment updated');

    // Health Insurance
    _addDateIfChanged(changes, 'Health Insurance Expiry', oldE.healthInsurance?.expiryDate, newE.healthInsurance?.expiryDate);
    if ((oldE.healthInsurance?.attachmentUrl ?? '') != (newE.healthInsurance?.attachmentUrl ?? '')) changes.add('Health Insurance attachment updated');

    // Passport
    _addIfChanged(changes, 'Passport Name', oldE.passport?.nameOnPassport, newE.passport?.nameOnPassport);
    _addIfChanged(changes, 'Passport Number', oldE.passport?.number, newE.passport?.number);
    _addDateIfChanged(changes, 'Passport Expiry', oldE.passport?.expiryDate, newE.passport?.expiryDate);
    if ((oldE.passport?.attachmentUrl ?? '') != (newE.passport?.attachmentUrl ?? '')) changes.add('Passport attachment updated');

    // Saudi Visa
    _addIfChanged(changes, 'Saudi Visa Number', oldE.saudiVisa?.number, newE.saudiVisa?.number);
    _addDateIfChanged(changes, 'Saudi Visa Expiry', oldE.saudiVisa?.expiryDate, newE.saudiVisa?.expiryDate);
    _addIfChanged(changes, 'Saudi Visa Type', oldE.saudiVisa?.type?.name, newE.saudiVisa?.type?.name);
    if ((oldE.saudiVisa?.attachmentUrl ?? '') != (newE.saudiVisa?.attachmentUrl ?? '')) changes.add('Saudi Visa attachment updated');

    // Bahrain Visa
    _addIfChanged(changes, 'Bahrain Visa Number', oldE.bahrainVisa?.number, newE.bahrainVisa?.number);
    _addDateIfChanged(changes, 'Bahrain Visa Expiry', oldE.bahrainVisa?.expiryDate, newE.bahrainVisa?.expiryDate);
    _addIfChanged(changes, 'Bahrain Visa Type', oldE.bahrainVisa?.type?.name, newE.bahrainVisa?.type?.name);
    if ((oldE.bahrainVisa?.attachmentUrl ?? '') != (newE.bahrainVisa?.attachmentUrl ?? '')) changes.add('Bahrain Visa attachment updated');

    // Dubai Visa
    _addIfChanged(changes, 'Dubai Visa Number', oldE.dubaiVisa?.number, newE.dubaiVisa?.number);
    _addDateIfChanged(changes, 'Dubai Visa Expiry', oldE.dubaiVisa?.expiryDate, newE.dubaiVisa?.expiryDate);
    _addIfChanged(changes, 'Dubai Visa Type', oldE.dubaiVisa?.type?.name, newE.dubaiVisa?.type?.name);
    if ((oldE.dubaiVisa?.attachmentUrl ?? '') != (newE.dubaiVisa?.attachmentUrl ?? '')) changes.add('Dubai Visa attachment updated');

    // Qatar Visa
    _addIfChanged(changes, 'Qatar Visa Number', oldE.qatarVisa?.number, newE.qatarVisa?.number);
    _addDateIfChanged(changes, 'Qatar Visa Expiry', oldE.qatarVisa?.expiryDate, newE.qatarVisa?.expiryDate);
    _addIfChanged(changes, 'Qatar Visa Type', oldE.qatarVisa?.type?.name, newE.qatarVisa?.type?.name);
    if ((oldE.qatarVisa?.attachmentUrl ?? '') != (newE.qatarVisa?.attachmentUrl ?? '')) changes.add('Qatar Visa attachment updated');

    // Driving License
    _addIfChanged(changes, 'License Country', oldE.drivingLicense?.countryOfOrigin, newE.drivingLicense?.countryOfOrigin);
    _addIfChanged(changes, 'License Number', oldE.drivingLicense?.number, newE.drivingLicense?.number);
    _addDateIfChanged(changes, 'License Expiry', oldE.drivingLicense?.expiryDate, newE.drivingLicense?.expiryDate);
    _addIfChanged(changes, 'License Type', oldE.drivingLicense?.type?.name, newE.drivingLicense?.type?.name);
    if ((oldE.drivingLicense?.attachmentUrl ?? '') != (newE.drivingLicense?.attachmentUrl ?? '')) changes.add('Driving License attachment updated');

    // Contacts
    if (oldE.contacts.length != newE.contacts.length) {
      changes.add('Contacts list updated');
    } else {
      bool contactsChanged = false;
      for (int i = 0; i < oldE.contacts.length; i++) {
        if (oldE.contacts[i] != newE.contacts[i]) {
          contactsChanged = true;
          break;
        }
      }
      if (contactsChanged) changes.add('Contacts list updated');
    }

    if (changes.isEmpty) return null;
    return changes.join(', ');
  }

  // ---------------------------------------------------------------------------
  // Vehicle
  // ---------------------------------------------------------------------------

  /// Compares two [VehicleEntity] instances and returns a human-readable
  /// summary of the fields that changed.
  static String? describeVehicleChanges(
    VehicleEntity oldV,
    VehicleEntity newV,
  ) {
    final changes = <String>[];

    _addIfChanged(changes, 'Make', oldV.make, newV.make);
    _addIfChanged(changes, 'Model', oldV.model, newV.model);
    _addIfChanged(
        changes, 'Year', oldV.year.toString(), newV.year.toString());
    _addIfChanged(changes, 'Color', oldV.color, newV.color);
    _addIfChanged(
        changes, 'Plate Number', oldV.plateNumber, newV.plateNumber);
    _addIfChanged(changes, 'Type', oldV.type, newV.type);
    _addIfChanged(changes, 'VIN', oldV.vinNumber, newV.vinNumber);
    _addIfChanged(
        changes, 'Engine Number', oldV.engineNumber, newV.engineNumber);
    _addIfChanged(changes, 'Fuel Type', oldV.fuelType, newV.fuelType);
    _addIfChanged(
        changes, 'Transmission', oldV.transmission, newV.transmission);
    _addDateIfChanged(
        changes, 'Purchase Date', oldV.purchaseDate, newV.purchaseDate);
    _addNumIfChanged(
        changes, 'Purchase Price', oldV.purchasePrice, newV.purchasePrice);
    _addNumIfChanged(changes, 'Purchase Odometer',
        oldV.purchaseOdometer?.toDouble(), newV.purchaseOdometer?.toDouble());
    _addNumIfChanged(changes, 'Current Odometer',
        oldV.currentOdometer?.toDouble(), newV.currentOdometer?.toDouble());
    _addIfChanged(changes, 'GVWR', oldV.gvwr, newV.gvwr);
    _addIfChanged(changes, 'Tire Size', oldV.tireSize, newV.tireSize);
    _addIfChanged(changes, 'Department', oldV.department, newV.department);
    _addIfChanged(changes, 'Status', oldV.status, newV.status);

    if ((oldV.imageUrl ?? '') != (newV.imageUrl ?? '')) {
      changes.add('Photo updated');
    }

    // Document expiry changes
    _addDocumentChange(changes, 'Insurance', oldV.insurance, newV.insurance);
    _addDocumentChange(changes, 'Bahrain Insurance', oldV.bahrainInsurance,
        newV.bahrainInsurance);
    _addDocumentChange(
        changes, 'Registration', oldV.registration, newV.registration);
    _addDocumentChange(changes, 'Fahas', oldV.fahas, newV.fahas);

    if (changes.isEmpty) return null;
    return changes.join(', ');
  }

  // ---------------------------------------------------------------------------
  // Customer
  // ---------------------------------------------------------------------------

  /// Compares two [CustomerEntity] instances and returns a human-readable
  /// summary of the fields that changed.
  static String? describeCustomerChanges(
    CustomerEntity oldC,
    CustomerEntity newC,
  ) {
    final changes = <String>[];

    _addIfChanged(changes, 'Name', oldC.name, newC.name);
    _addIfChanged(changes, 'Phone', oldC.phone, newC.phone);
    _addIfChanged(changes, 'Email', oldC.email, newC.email);
    _addIfChanged(changes, 'Company', oldC.companyName, newC.companyName);
    _addIfChanged(changes, 'Status', oldC.status, newC.status);

    // Case codes
    final oldCodes = Set<String>.from(oldC.assignedCaseCodes);
    final newCodes = Set<String>.from(newC.assignedCaseCodes);
    final addedCodes = newCodes.difference(oldCodes);
    final removedCodes = oldCodes.difference(newCodes);
    if (addedCodes.isNotEmpty) {
      changes.add('Case codes added: ${addedCodes.join(", ")}');
    }
    if (removedCodes.isNotEmpty) {
      changes.add('Case codes removed: ${removedCodes.join(", ")}');
    }

    if (changes.isEmpty) return null;
    return changes.join(', ');
  }

  // ---------------------------------------------------------------------------
  // Maintenance Records
  // ---------------------------------------------------------------------------

  /// Produces a detailed description for newly added maintenance records.
  static String describeMaintenanceRecords(
    List<({String typeId, MaintenanceRecord record})> records,
    VehicleEntity vehicle,
  ) {
    final parts = <String>[];
    for (final entry in records) {
      final r = entry.record;
      final sb = StringBuffer(r.serviceType ?? 'Unknown');

      if (r.cost != null && r.cost! > 0) {
        sb.write(' — Cost: SAR ${r.cost!.toStringAsFixed(2)}');
      }
      if (r.serviceProvider != null && r.serviceProvider!.isNotEmpty) {
        sb.write(', Shop: ${r.serviceProvider}');
      }
      if (r.mileage > 0) {
        sb.write(', Service Odometer: ${_formatNumber(r.mileage)} km');
      }
      parts.add(sb.toString());
    }
    return 'Maintenance added for ${vehicle.make} ${vehicle.model} '
        '(${vehicle.plateNumber}): ${parts.join("; ")}.';
  }

  /// Produces a detailed description for a maintenance record updated via
  /// the notification update dialog.
  static String describeMaintenanceUpdate({
    required String category,
    required String plateNumber,
    required MaintenanceRecord newRecord,
  }) {
    final sb = StringBuffer('$category maintenance completed for $plateNumber');

    if (newRecord.cost != null && newRecord.cost! > 0) {
      sb.write(' — Cost: SAR ${newRecord.cost!.toStringAsFixed(2)}');
    }
    if (newRecord.serviceProvider != null &&
        newRecord.serviceProvider!.isNotEmpty) {
      sb.write(', Shop: ${newRecord.serviceProvider}');
    }
    if (newRecord.mileage > 0) {
      sb.write(', Service Odometer: ${_formatNumber(newRecord.mileage)} km');
    }
    sb.write('.');
    return sb.toString();
  }

  /// Produces a detailed description for an employee document update.
  static String describeEmployeeDocumentUpdate({
    required String employeeName,
    required String documentType,
    required DateTime? newExpiryDate,
  }) {
    final sb = StringBuffer("$employeeName's $documentType updated");

    if (newExpiryDate != null) {
      sb.write(
          ' — New expiry: ${DateFormat('MMM dd, yyyy').format(newExpiryDate)}');
    } else {
      sb.write(' — Document cleared');
    }
    sb.write('.');
    return sb.toString();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static void _addIfChanged(
    List<String> changes,
    String label,
    String? oldVal,
    String? newVal,
  ) {
    final o = (oldVal ?? '').trim();
    final n = (newVal ?? '').trim();
    if (o != n) {
      if (o.isEmpty) {
        changes.add("$label set to '$n'");
      } else if (n.isEmpty) {
        changes.add('$label cleared');
      } else {
        changes.add("$label: '$o' → '$n'");
      }
    }
  }

  static void _addDateIfChanged(
    List<String> changes,
    String label,
    DateTime? oldVal,
    DateTime? newVal,
  ) {
    final fmt = DateFormat('MMM dd, yyyy');
    final o = oldVal != null ? fmt.format(oldVal) : '';
    final n = newVal != null ? fmt.format(newVal) : '';
    if (o != n) {
      if (o.isEmpty) {
        changes.add('$label set to $n');
      } else if (n.isEmpty) {
        changes.add('$label cleared');
      } else {
        changes.add('$label: $o → $n');
      }
    }
  }

  static void _addNumIfChanged(
    List<String> changes,
    String label,
    double? oldVal,
    double? newVal,
  ) {
    if (oldVal != newVal) {
      final o = oldVal?.toStringAsFixed(0) ?? '—';
      final n = newVal?.toStringAsFixed(0) ?? '—';
      changes.add('$label: $o → $n');
    }
  }

  static void _addBoolIfChanged(
    List<String> changes,
    String label,
    bool oldVal,
    bool newVal, {
    required String trueLabel,
    required String falseLabel,
  }) {
    if (oldVal != newVal) {
      changes.add(
          '$label: ${oldVal ? trueLabel : falseLabel} → ${newVal ? trueLabel : falseLabel}');
    }
  }

  static void _addDocumentChange(
    List<String> changes,
    String label,
    VehicleDocument? oldDoc,
    VehicleDocument? newDoc,
  ) {
    final fmt = DateFormat('MMM dd, yyyy');
    if (oldDoc == null && newDoc != null) {
      changes.add('$label added (expires ${fmt.format(newDoc.expiryDate)})');
    } else if (oldDoc != null && newDoc == null) {
      changes.add('$label removed');
    } else if (oldDoc != null && newDoc != null) {
      if (oldDoc.expiryDate != newDoc.expiryDate) {
        changes.add(
            '$label expiry: ${fmt.format(oldDoc.expiryDate)} → ${fmt.format(newDoc.expiryDate)}');
      }
    }
  }

  static String _formatNumber(int number) {
    return NumberFormat('#,###').format(number);
  }
}
