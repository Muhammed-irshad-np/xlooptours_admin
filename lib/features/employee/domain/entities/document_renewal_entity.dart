import 'package:equatable/equatable.dart';
import 'employee_entity.dart';

/// One renewal of an employee document (Iqama, visa, passport, …): what the
/// document looked like before, what it looks like now, and who changed it.
///
/// Records are append-only. A renewal that had to be rolled back is marked
/// [voided] instead of deleted, and is hidden from the history.
class DocumentRenewalEntity extends Equatable {
  final String id;
  final String employeeId;

  /// Display label, matching the alert labels ('Iqama', 'Saudi Visa', …).
  final String documentType;
  final String? previousNumber;
  final String? newNumber;
  final DateTime previousExpiryDate;
  final DateTime newExpiryDate;

  /// Scan on file before the renewal, kept so the old copy stays reachable.
  final String? previousAttachmentUrl;
  final String? newAttachmentUrl;
  final DateTime renewedAt;
  final String? renewedBy;

  /// Where the renewal was entered, e.g. 'Expiry alert' or 'Employee form'.
  final String? source;
  final bool voided;

  const DocumentRenewalEntity({
    required this.id,
    required this.employeeId,
    required this.documentType,
    this.previousNumber,
    this.newNumber,
    required this.previousExpiryDate,
    required this.newExpiryDate,
    this.previousAttachmentUrl,
    this.newAttachmentUrl,
    required this.renewedAt,
    this.renewedBy,
    this.source,
    this.voided = false,
  });

  bool get numberChanged =>
      (previousNumber ?? '') != (newNumber ?? '') &&
      (previousNumber ?? '').isNotEmpty;

  /// Every renewal between [before] and [after]: a document that existed in
  /// both and whose expiry moved to another calendar day. Adding a document
  /// for the first time, removing one, or only correcting its number is not a
  /// renewal.
  static List<DocumentRenewalEntity> detect(
    EmployeeEntity before,
    EmployeeEntity after, {
    required DateTime renewedAt,
    required String Function() newId,
    String? renewedBy,
    String? source,
  }) {
    final previous = _snapshots(before);
    final current = _snapshots(after);
    final renewals = <DocumentRenewalEntity>[];

    for (final entry in current.entries) {
      final old = previous[entry.key];
      final now = entry.value;
      if (old == null || _sameDay(old.expiry, now.expiry)) continue;
      renewals.add(
        DocumentRenewalEntity(
          id: newId(),
          employeeId: after.id,
          documentType: entry.key,
          previousNumber: old.number,
          newNumber: now.number,
          previousExpiryDate: old.expiry,
          newExpiryDate: now.expiry,
          previousAttachmentUrl: old.attachmentUrl,
          newAttachmentUrl: now.attachmentUrl,
          renewedAt: renewedAt,
          renewedBy: renewedBy,
          source: source,
        ),
      );
    }
    return renewals;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Label → snapshot of each document the employee currently holds. Labels
  /// match the expiry alerts so the history reads the same as the alerts.
  static Map<String, _DocSnapshot> _snapshots(EmployeeEntity e) {
    return {
      if (e.iqama != null)
        'Iqama': _DocSnapshot(
          e.iqama!.number,
          e.iqama!.expiryDate,
          e.iqama!.attachmentUrl,
        ),
      if (e.bahrainResidence != null)
        'Bahrain Residence ID': _DocSnapshot(
          e.bahrainResidence!.number,
          e.bahrainResidence!.expiryDate,
          e.bahrainResidence!.attachmentUrl,
        ),
      if (e.passport != null)
        'Passport': _DocSnapshot(
          e.passport!.number,
          e.passport!.expiryDate,
          e.passport!.attachmentUrl,
        ),
      if (e.drivingLicense != null)
        'Driving License': _DocSnapshot(
          e.drivingLicense!.number,
          e.drivingLicense!.expiryDate,
          e.drivingLicense!.attachmentUrl,
        ),
      if (e.saudiVisa != null)
        'Saudi Visa': _DocSnapshot(
          e.saudiVisa!.number,
          e.saudiVisa!.expiryDate,
          e.saudiVisa!.attachmentUrl,
        ),
      if (e.bahrainVisa != null)
        'Bahrain Visa': _DocSnapshot(
          e.bahrainVisa!.number,
          e.bahrainVisa!.expiryDate,
          e.bahrainVisa!.attachmentUrl,
        ),
      if (e.dubaiVisa != null)
        'Dubai Visa': _DocSnapshot(
          e.dubaiVisa!.number,
          e.dubaiVisa!.expiryDate,
          e.dubaiVisa!.attachmentUrl,
        ),
      if (e.qatarVisa != null)
        'Qatar Visa': _DocSnapshot(
          e.qatarVisa!.number,
          e.qatarVisa!.expiryDate,
          e.qatarVisa!.attachmentUrl,
        ),
      if (e.healthInsurance != null)
        'Health Insurance': _DocSnapshot(
          null,
          e.healthInsurance!.expiryDate,
          e.healthInsurance!.attachmentUrl,
        ),
      if (e.authorization != null)
        'Authorization': _DocSnapshot(
          null,
          e.authorization!.expiryDate,
          e.authorization!.attachmentUrl,
        ),
    };
  }

  @override
  List<Object?> get props => [
    id,
    employeeId,
    documentType,
    previousNumber,
    newNumber,
    previousExpiryDate,
    newExpiryDate,
    previousAttachmentUrl,
    newAttachmentUrl,
    renewedAt,
    renewedBy,
    source,
    voided,
  ];
}

class _DocSnapshot {
  final String? number;
  final DateTime expiry;
  final String? attachmentUrl;

  const _DocSnapshot(this.number, this.expiry, this.attachmentUrl);
}
