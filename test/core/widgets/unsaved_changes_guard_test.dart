import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/core/widgets/unsaved_changes_guard.dart';

/// FRM-003: going back from a form with unsaved edits must warn first.
void main() {
  late TextEditingController name;
  late ValueNotifier<DateTime?> joinDate;
  late List<String> codes;
  late GlobalKey<UnsavedChangesGuardState> guardKey;

  setUp(() {
    name = TextEditingController();
    joinDate = ValueNotifier(null);
    codes = [];
    guardKey = GlobalKey();
  });

  Future<void> openForm(WidgetTester tester, {bool enabled = true}) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(1440, 900),
        builder: (_, _) => MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UnsavedChangesGuard(
                      key: guardKey,
                      enabled: enabled,
                      fields: () => [name, joinDate, codes],
                      child: Scaffold(
                        appBar: AppBar(title: const Text('Form')),
                        body: TextField(controller: name),
                      ),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapBack(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
  }

  testWidgets('leaves without asking when nothing changed', (tester) async {
    await openForm(tester);
    await tapBack(tester);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Discard unsaved changes?'), findsNothing);
  });

  testWidgets('asks before leaving with typed text; Keep Editing stays', (
    tester,
  ) async {
    await openForm(tester);
    await tester.enterText(find.byType(TextField), 'Ahmed');
    await tapBack(tester);
    expect(find.text('Discard unsaved changes?'), findsOneWidget);

    await tester.tap(find.text('Keep Editing'));
    await tester.pumpAndSettle();
    expect(find.text('Form'), findsOneWidget);
    expect(find.text('Ahmed'), findsOneWidget);
  });

  testWidgets('Discard leaves the page', (tester) async {
    await openForm(tester);
    joinDate.value = DateTime(2026, 1, 1);
    await tapBack(tester);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('a list edited in place counts as a change', (tester) async {
    await openForm(tester);
    codes.add('A-1');
    await tapBack(tester);
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
  });

  testWidgets('reverting an edit is not a change', (tester) async {
    await openForm(tester);
    await tester.enterText(find.byType(TextField), 'Ahmed');
    await tester.enterText(find.byType(TextField), '');
    await tapBack(tester);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('markClean takes values loaded later as the baseline', (
    tester,
  ) async {
    await openForm(tester);
    name.text = 'Loaded from server';
    guardKey.currentState!.markClean();
    await tapBack(tester);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('disabled guard never asks', (tester) async {
    await openForm(tester, enabled: false);
    await tester.enterText(find.byType(TextField), 'Ahmed');
    await tapBack(tester);
    expect(find.text('Open'), findsOneWidget);
  });
}
