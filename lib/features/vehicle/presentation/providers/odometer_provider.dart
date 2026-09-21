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

  String? _queueError;
  bool _queueLoaded = false;

  List<OdometerReviewItem> get reviewQueue => _reviewQueue;
  double? get fleetDailyMedian => _fleetDailyMedian;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  /// Why the review queue could not be built, if it could not be.
  ///
  /// Kept distinct from an empty queue so the screen can say "could not load"
  /// instead of "nothing to review" — the two look identical to a user and mean
  /// opposite things.
  String? get queueError => _queueError;

  /// True once a queue build has actually completed, successfully or not.
  bool get queueLoaded => _queueLoaded;

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
    _queueError = null;

    try {
      final active = vehicles.where((v) => v.isActive).toList();

      // Read every active vehicle's log directly.
      //
      // An earlier version drove this from a single collection-group query for
      // quarantined readings. That query needs a composite index, and when the
      // index is missing it throws — which left the queue empty and the screen
      // claiming there was nothing to review. It also meant one failing query
      // suppressed stale and cross-source detection, neither of which needs it.
      //
      // Per-vehicle subcollection reads need no index at all and cannot fail
      // that way. This runs on an admin screen, not a hot path, so the extra
      // reads are worth the reliability. They are issued in parallel.
      final results = await Future.wait(
        active.map((v) => _fetchReadings(v.id)),
      );

      final map = <String, List<OdometerReadingEntity>>{};
      for (var i = 0; i < active.length; i++) {
        _readingsByVehicle[active[i].id] = results[i];
        map[active[i].id] = results[i];
      }

      _reviewQueue = getReviewQueueUseCase(
        vehicles: active,
        readingsByVehicle: map,
      );
      _errorMessage = null;
    } catch (e) {
      // Surfaced to the UI, not just the console: an empty queue and a failed
      // load must never look the same to whoever is reviewing.
      _queueError = 'Could not load odometer readings: $e';
      _reviewQueue = [];
      debugPrint(_queueError);
    } finally {
      _queueLoaded = true;
      _setLoading(false);
    }
  }

  /// Fetches one vehicle's readings without touching shared loading state.
  ///
  /// Used when loading many vehicles at once, so the queue build notifies
  /// listeners once at the end rather than once per vehicle.
  Future<List<OdometerReadingEntity>> _fetchReadings(String vehicleId) async {
    final readings = await getReadingsUseCase(vehicleId);
    readings.sort((a, b) => a.readingAt.compareTo(b.readingAt));
    return readings;
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
