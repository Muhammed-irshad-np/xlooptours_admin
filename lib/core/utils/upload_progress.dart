import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// One file being uploaded to Firebase Storage.
class ActiveUpload {
  final int id;
  final String label;
  final int bytesTransferred;
  final int totalBytes;

  const ActiveUpload({
    required this.id,
    required this.label,
    this.bytesTransferred = 0,
    this.totalBytes = 0,
  });

  /// 0–1, or null while the total size is not known yet.
  double? get fraction =>
      totalBytes > 0 ? (bytesTransferred / totalBytes).clamp(0.0, 1.0) : null;

  ActiveUpload copyWith({int? bytesTransferred, int? totalBytes}) =>
      ActiveUpload(
        id: id,
        label: label,
        bytesTransferred: bytesTransferred ?? this.bytesTransferred,
        totalBytes: totalBytes ?? this.totalBytes,
      );
}

/// App-wide list of uploads in flight. The progress card in the app root
/// listens to this, so every upload shows progress without each screen
/// wiring its own indicator.
class UploadProgressTracker extends ChangeNotifier {
  UploadProgressTracker._();
  static final UploadProgressTracker instance = UploadProgressTracker._();

  final Map<int, ActiveUpload> _uploads = {};
  int _nextId = 0;

  List<ActiveUpload> get uploads => List.unmodifiable(_uploads.values);
  bool get isUploading => _uploads.isNotEmpty;

  /// Combined progress of every upload in flight, or null if no sizes are
  /// known yet.
  double? get overallFraction {
    final known = _uploads.values.where((u) => u.totalBytes > 0);
    if (known.isEmpty) return null;
    final total = known.fold<int>(0, (sum, u) => sum + u.totalBytes);
    final sent = known.fold<int>(0, (sum, u) => sum + u.bytesTransferred);
    return (sent / total).clamp(0.0, 1.0);
  }

  /// Shows [task] in the progress card until it finishes, fails or is
  /// cancelled.
  void track(UploadTask task, {String label = 'file'}) {
    final id = _nextId++;
    _uploads[id] = ActiveUpload(id: id, label: label);
    notifyListeners();

    late final StreamSubscription<TaskSnapshot> subscription;
    void done() {
      subscription.cancel();
      if (_uploads.remove(id) != null) notifyListeners();
    }

    subscription = task.snapshotEvents.listen((snapshot) {
      final current = _uploads[id];
      if (current == null) return;
      _uploads[id] = current.copyWith(
        bytesTransferred: snapshot.bytesTransferred,
        totalBytes: snapshot.totalBytes,
      );
      notifyListeners();
    }, onError: (_) => done());

    task.then((_) => done(), onError: (_) => done());
  }
}

/// Registers [task] with the app-wide progress card and waits for it.
Future<TaskSnapshot> trackUpload(UploadTask task, {String label = 'file'}) {
  UploadProgressTracker.instance.track(task, label: label);
  return task;
}
