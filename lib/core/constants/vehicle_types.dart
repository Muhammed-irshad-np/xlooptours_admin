/// Predefined vehicle body types, so vehicle type is picked from a fixed list
/// instead of typed freely (keeps spelling consistent for maintenance
/// intervals, filtering and reporting).
const List<String> kVehicleTypes = [
  'Sedan',
  'SUV',
  'Hatchback',
  'Coupe',
  'Pickup',
  'Van',
  'Minibus',
  'Bus',
  'Truck',
];

/// Maps a stored type onto its predefined spelling ignoring case and spaces
/// ("suv " -> "SUV"). Values not in [kVehicleTypes] are returned trimmed but
/// otherwise unchanged, so older free-typed data is never lost.
String normalizeVehicleType(String type) {
  final trimmed = type.trim();
  for (final option in kVehicleTypes) {
    if (option.toLowerCase() == trimmed.toLowerCase()) return option;
  }
  return trimmed;
}

/// Dropdown options for a vehicle type field. A legacy value that isn't in
/// [kVehicleTypes] is appended so existing records still display and save
/// as-is.
List<String> vehicleTypeOptions(String? current) {
  final value = current == null ? '' : normalizeVehicleType(current);
  if (value.isEmpty || kVehicleTypes.contains(value)) return kVehicleTypes;
  return [...kVehicleTypes, value];
}
