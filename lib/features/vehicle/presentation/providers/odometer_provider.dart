import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/odometer_policy.dart';
import '../../domain/entities/odometer_reading_entity.dart';
import '../../domain/entities/odometer_review_item.dart';
import '../../domain/entities/odometer_validation.dart';
import '../../domain/entities/vehicle_entity.dart';
import '../../domain/repositories/odometer_repository.dart';
import '../../domain/usecases/get_odometer_readings_usecase.dart';
import '../../domain/usecases/get_odometer_review_queue_usecase.dart';
import '../../domain/usecases/record_odometer_reading_usecase.dart';
import '../../domain/usecases/review_odometer_reading_usecase.dart';
import '../../domain/usecases/validate_odometer_reading_usecase.dart';

/// Owns the odometer reading log: the append-only series, the plausibility
/// checks run against it, and the review queue it feeds.
///
/// Kept separate from [VehicleProvider], which is already large and whose job
/// is the vehicle master record rather than this time series.
class OdometerProvider extends ChangeNotifier {
  final GetOdometerReadingsUseCase getReadingsUseCase;
  final RecordOdometerReadingUseCase recordReadingUseCase;
  final ReviewOdometerReadingUseCase reviewReadingUseCase;
  final GetOdometerReviewQueueUseCase getReviewQueueUseCase;
  final GetFleetDailyMedianUseCase getFleetDailyMedianUseCase;
  final ValidateOdometerReadingUseCase validator;
  final OdometerRepository repository;
  final OdometerPolicy policy;

  OdometerProvider({
    required this.getReadingsUseCase,
    required this.recordReadingUseCase,
    required this.reviewReadingUseCase,
    required this.getReviewQueueUseCase,
    required this.getFleetDailyMedianUseCase,
    required this.validator,
    required this.repository,
    this.policy = OdometerPolicy.defaults,
  });

  final Map<String, List<OdometerReadingEntity>> _readingsByVehicle = {};
  List<OdometerReviewItem> _reviewQueue = [];
  double? _fleetDailyMedian;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  List<OdometerReviewItem> get reviewQueue => _reviewQueue;
  double? get fleetDailyMedian => _fleetDailyMedian;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  int get pendingReviewCount => _reviewQueue
      .where((i) => i.reason != OdometerReviewReason.stale)
      .length;

  List<OdometerReadingEntity> readingsFor(String vehicleId) =>
      _readingsByVehicle[vehicleId] ?? const [];

  /// Loads a vehicle's readings, seeding the local cache used for validation.
  Future<List<OdometerReadingEntity>> loadReadings(
    String vehicleId, {
    bool force = false,
  }) async {
    if (!force && _readingsByVehicle.containsKey(vehicleId)) {
      return _readingsByVehicle[vehicleId]!;
    }
    _setLoading(true);
    try {
      final readings = await getReadingsUseCase(vehicleId);
      readings.sort((a, b) => a.readingAt.compareTo(b.readingAt));
      _readingsByVehicle[vehicleId] = readings;
      _errorMessage = null;
      return readings;
    } catch (e) {
      _errorMessage = 'Failed to load odometer history: $e';
      debugPrint(_errorMessage);
      return const [];
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadFleetBaseline({bool force = false}) async {
    if (!force && _fleetDailyMedian != null) return;
    try {
      _fleetDailyMedian = await getFleetDailyMedianUseCase();
      notifyListeners();
    } catch (e) {
      // A missing fleet baseline is not fatal: the engine falls back to the
      // vehicle's own history, then to the configured default.
      debugPrint('Fleet odometer baseline unavailable: $e');
    }
  }

  /// Runs the plausibility checks without writing anything.
  ///
  /// Called on every keystroke in the entry dialog, so it must stay pure and
  /// cheap — which it is: the readings are already in memory.
  OdometerValidationResult validate({
    required VehicleEntity vehicle,
    required int value,
    DateTime? readingAt,
    double fuelSpendInWindow = 0,
    OdometerSource source = OdometerSource.weeklyUpdate,
  }) {
    final history = _historyFor(vehicle);
    return validator.call(
      proposedValue: value,
      readingAt: readingAt ?? DateTime.now(),
      history: history,
      fleetDailyMedian: _fleetDailyMedian,
      fuelSpendInWindow: fuelSpendInWindow,
      source: source,
    );
  }

  /// The last accepted reading, used by the entry dialog to show context and
  /// compute a live delta as the user types.
  OdometerReadingEntity? lastAcceptedFor(VehicleEntity vehicle) {
    final history = _historyFor(vehicle).where((r) => r.isUsable).toList();
    if (history.isEmpty) return null;
    return history.last;
  }

  /// Falls back to the vehicle's stored odometer when the log has not been
  /// populated yet, so validation still has an anchor on legacy vehicles.
  List<OdometerReadingEntity> _historyFor(VehicleEntity vehicle) {
    final cached = _readingsByVehicle[vehicle.id];
    if (cached != null && cached.isNotEmpty) return cached;

    final seed = vehicle.currentOdometer ?? vehicle.purchaseOdometer;
    if (seed == null || seed <= 0) return const [];

    return [
      OdometerReadingEntity(
        id: 'virtual-seed-${vehicle.id}',
        vehicleId: vehicle.id,
        value: seed,
        readingAt:
            vehicle.lastOdometerUpdateDate ??
            vehicle.purchaseDate ??
            DateTime.now().subtract(const Duration(days: 7)),
        recordedAt: DateTime.now(),
        source: OdometerSource.initial,
      ),
    ];
  }

  Future<String?> uploadPhoto(
    XFile photo,
    String vehicleId,
    String readingId,
  ) async {
    try {
      return await repository.uploadOdometerPhoto(photo, vehicleId, readingId);
    } catch (e) {
      _errorMessage = 'Failed to upload odometer photo: $e';
      debugPrint(_errorMessage);
      return null;
    }
  }

  /// Appends a reading. Rethrows [OdometerReadingRejected] so interactive
  /// callers can show the block and its suggested corrections.
  Future<RecordOdometerReadingResult> record({
    required VehicleEntity vehicle,
    required int value,
    required OdometerSource source,
    DateTime? readingAt,
    String? sourceRefId,
    String? enteredByUid,
    String? enteredByName,
    String? photoUrl,
    String? note,
    bool userConfirmed = false,
    double fuelSpendInWindow = 0,
    bool throwOnBlock = true,
  }) async {
    _isSaving = true;
    notifyListeners();
    try {
      final result = await recordReadingUseCase(
        vehicle: vehicle,
        value: value,
        source: source,
        readingAt: readingAt,
        sourceRefId: sourceRefId,
        enteredByUid: enteredByUid,
        enteredByName: enteredByName,
        photoUrl: photoUrl,
        note: note,
        userConfirmed: userConfirmed,
        fuelSpendInWindow: fuelSpendInWindow,
        fleetDailyMedian: _fleetDailyMedian,
        throwOnBlock: throwOnBlock,
      );
      await loadReadings(vehicle.id, force: true);
      _errorMessage = null;
      return result;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Best-effort capture for secondary sources (expenses, maintenance forms).
  ///
  /// Never throws and never blocks the host form from saving: an odometer that
  /// could not be logged must not cost the user their expense entry.
  Future<RecordOdometerReadingResult?> recordSilently({
    required VehicleEntity vehicle,
    required int value,
    required OdometerSource source,
    DateTime? readingAt,
    String? sourceRefId,
    String? enteredByUid,
    String? enteredByName,
    String? note,
  }) async {
    try {
      return await record(
        vehicle: vehicle,
        value: value,
        source: source,
        readingAt: readingAt,
        sourceRefId: sourceRefId,
        enteredByUid: enteredByUid,
        enteredByName: enteredByName,
        note: note,
        throwOnBlock: false,
      );
    } catch (e) {
      debugPrint('Odometer capture from ${source.label} failed: $e');
      return null;
    }
  }

  // ── Review queue ─────────────────────────────────────────────────────────

  Future<void> loadReviewQueue(List<VehicleEntity> vehicles) async {
    _setLoading(true);
    try {
      final quarantined = await repository.getQuarantinedReadings();

      // Only fetch full history for vehicles that actually have something to
      // look at, plus any that look stale — not the whole fleet.
      final vehicleIds = quarantined.map((r) => r.vehicleId).toSet();
      for (final id in vehicleIds) {
        await loadReadings(id, force: true);
      }

      final map = <String, List<OdometerReadingEntity>>{};
      for (final v in vehicles) {
        map[v.id] = _readingsByVehicle[v.id] ?? const [];
      }

      _reviewQueue = getReviewQueueUseCase(
        vehicles: vehicles,
        readingsByVehicle: map,
      );
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to build odometer review queue: $e';
      debugPrint(_errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  Future<VehicleEntity?> acceptReading({
    required VehicleEntity vehicle,
    required OdometerReadingEntity reading,
    String? reviewerUid,
    String? reviewerName,
    String? note,
  }) async {
    final updated = await reviewReadingUseCase.accept(
      vehicle: vehicle,
      reading: reading,
      reviewerUid: reviewerUid,
      reviewerName: reviewerName,
      note: note,
    );
    await loadReadings(vehicle.id, force: true);
    return updated;
  }

  Future<VehicleEntity?> rejectReading({
    required VehicleEntity vehicle,
    required OdometerReadingEntity reading,
    String? reviewerUid,
    String? reviewerName,
    String? note,
  }) async {
    final updated = await reviewReadingUseCase.reject(
      vehicle: vehicle,
      reading: reading,
      reviewerUid: reviewerUid,
      reviewerName: reviewerName,
      note: note,
    );
    await loadReadings(vehicle.id, force: true);
    return updated;
  }

  Future<VehicleEntity?> correctReading({
    required VehicleEntity vehicle,
    required OdometerReadingEntity original,
    required int correctedValue,
    String? reviewerUid,
    String? reviewerName,
    String? note,
  }) async {
    final updated = await reviewReadingUseCase.correct(
      vehicle: vehicle,
      original: original,
      correctedValue: correctedValue,
      reviewerUid: reviewerUid,
      reviewerName: reviewerName,
      note: note,
    );
    await loadReadings(vehicle.id, force: true);
    return updated;
  }

  Future<VehicleEntity?> recordClusterReplacement({
    required VehicleEntity vehicle,
    required int newValue,
    required DateTime replacedAt,
    String? reviewerUid,
    String? reviewerName,
    String? note,
  }) async {
    final updated = await reviewReadingUseCase.recordClusterReplacement(
      vehicle: vehicle,
      newValue: newValue,
      replacedAt: replacedAt,
      reviewerUid: reviewerUid,
      reviewerName: reviewerName,
      note: note,
    );
    await loadReadings(vehicle.id, force: true);
    return updated;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
