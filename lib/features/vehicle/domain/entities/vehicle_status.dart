/// Canonical values for `VehicleEntity.status`.
///
/// These are the strings the vehicle form has always written
/// (`Active`, `In-Shop`, `Out-of-Service`, `Retired`); this class just gives
/// them a name so the maintenance work order flow and the fleet list agree
/// on spelling and on what each one means.
class VehicleStatus {
  VehicleStatus._();

  static const String active = 'Active';

  /// At the workshop right now — set automatically while a maintenance work
  /// order is in progress.
  static const String inShop = 'In-Shop';

  static const String outOfService = 'Out-of-Service';
  static const String retired = 'Retired';

  static const List<String> all = [
    active,
    inShop,
    outOfService,
    retired,
  ];

  static String normalize(String? status) {
    final raw = status?.trim() ?? '';
    if (raw.isEmpty) return active;
    for (final known in all) {
      if (known.toLowerCase() == raw.toLowerCase()) return known;
    }
    return raw;
  }

  static bool isInShop(String? status) =>
      normalize(status).toLowerCase() == inShop.toLowerCase();

  /// Whether the vehicle belongs in the working fleet list.
  ///
  /// A car at the workshop is still part of the fleet — it is temporarily
  /// unavailable, not decommissioned — so [inShop] counts as part of the
  /// fleet and is surfaced with a badge instead of being hidden away with
  /// retired vehicles.
  static bool isInFleet(String? status) {
    final s = normalize(status).toLowerCase();
    return s == active.toLowerCase() || s == inShop.toLowerCase();
  }

  /// Whether the vehicle can actually be dispatched today.
  static bool isAvailable(String? status) =>
      normalize(status).toLowerCase() == active.toLowerCase();
}
