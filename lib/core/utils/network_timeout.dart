import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';

import '../error/exceptions.dart';

/// How long a Firestore write, or an upload that stops making progress,
/// may wait before it is treated as a lost connection.
const Duration kNetworkTimeout = Duration(seconds: 15);

extension NetworkTimeout<T> on Future<T> {
  /// Firestore writes never fail while offline — they wait for the connection
  /// to come back. This turns that wait into a [NetworkException].
  Future<T> withNetworkTimeout([Duration timeout = kNetworkTimeout]) {
    return this.timeout(timeout, onTimeout: () => throw NetworkException());
  }
}

/// Waits for [task], cancelling it with a [NetworkException] if no bytes are
/// transferred for [stallTimeout]. A slow upload keeps going as long as it
/// makes progress; an offline one would otherwise retry for minutes.
Future<TaskSnapshot> awaitUpload(
  UploadTask task, {
  Duration stallTimeout = kNetworkTimeout,
}) {
  final completer = Completer<TaskSnapshot>();
  Timer? timer;

  void fail() {
    if (completer.isCompleted) return;
    completer.completeError(NetworkException());
    task.cancel();
  }

  void restartTimer() {
    timer?.cancel();
    timer = Timer(stallTimeout, fail);
  }

  restartTimer();
  var lastBytes = 0;
  final subscription = task.snapshotEvents.listen((snapshot) {
    if (snapshot.bytesTransferred > lastBytes) {
      lastBytes = snapshot.bytesTransferred;
      restartTimer();
    }
  }, onError: (_) {});

  task.then(
    (snapshot) {
      if (!completer.isCompleted) completer.complete(snapshot);
    },
    onError: (Object error, StackTrace stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    },
  );

  return completer.future.whenComplete(() {
    timer?.cancel();
    subscription.cancel();
  });
}
