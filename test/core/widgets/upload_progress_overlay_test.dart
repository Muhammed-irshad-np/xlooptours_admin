import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/core/utils/upload_progress.dart';
import 'package:xloop_invoice/core/widgets/upload_progress_overlay.dart';

class _FakeSnapshot implements TaskSnapshot {
  @override
  final int bytesTransferred;
  @override
  final int totalBytes;

  _FakeSnapshot(this.bytesTransferred, this.totalBytes);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUploadTask implements UploadTask {
  final _events = StreamController<TaskSnapshot>.broadcast();
  final _done = Completer<TaskSnapshot>();

  void progress(int sent, int total) => _events.add(_FakeSnapshot(sent, total));
  void finish() => _done.complete(_FakeSnapshot(100, 100));
  void fail() => _done.completeError(Exception('upload failed'));

  @override
  Stream<TaskSnapshot> get snapshotEvents => _events.stream;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(TaskSnapshot) onValue, {
    Function? onError,
  }) =>
      _done.future.then(onValue, onError: onError);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget app(UploadProgressTracker tracker) => MaterialApp(
        builder: (context, child) =>
            UploadProgressOverlay(tracker: tracker, child: child!),
        home: const Scaffold(body: Text('page')),
      );

  testWidgets('shows label and percent while uploading, hides when done',
      (tester) async {
    final tracker = UploadProgressTracker.instance;
    final task = _FakeUploadTask();
    await tester.pumpWidget(app(tracker));
    expect(find.byType(LinearProgressIndicator), findsNothing);

    tracker.track(task, label: 'receipt');
    await tester.pump();
    expect(find.text('Uploading receipt…'), findsOneWidget);
    expect(
      tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      ).value,
      isNull,
    );

    task.progress(40, 100);
    await tester.pump();
    expect(find.text('40%'), findsOneWidget);

    task.finish();
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tracker.isUploading, isFalse);
  });

  testWidgets('combines several uploads and clears a failed one',
      (tester) async {
    final tracker = UploadProgressTracker.instance;
    final a = _FakeUploadTask();
    final b = _FakeUploadTask();
    await tester.pumpWidget(app(tracker));

    tracker.track(a, label: 'a.pdf');
    tracker.track(b, label: 'b.pdf');
    a.progress(50, 100);
    b.progress(0, 300);
    await tester.pump();
    expect(find.text('Uploading 2 files…'), findsOneWidget);
    expect(find.text('13%'), findsOneWidget); // 50 of 400 bytes

    b.fail();
    await tester.pump();
    expect(find.text('Uploading a.pdf…'), findsOneWidget);

    a.finish();
    await tester.pumpAndSettle();
    expect(tracker.isUploading, isFalse);
  });
}
