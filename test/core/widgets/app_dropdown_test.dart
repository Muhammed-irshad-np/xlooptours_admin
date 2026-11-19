import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xloop_invoice/core/widgets/app_dropdown.dart';

/// Dropdowns with 4+ items must open a search dialog (rules.md §6).
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  List<DropdownMenuItem<String?>> items(List<String> names, {bool withAll = false}) => [
        if (withAll) const DropdownMenuItem<String?>(value: null, child: Text('All')),
        for (final n in names) DropdownMenuItem<String?>(value: n, child: Text(n)),
      ];

  Widget host(Widget child) => ScreenUtilInit(
        designSize: const Size(1440, 900),
        builder: (_, __) => MaterialApp(
          home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
        ),
      );

  testWidgets('form field with 4+ items searches and picks', (tester) async {
    String? picked;
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(host(Form(
      key: formKey,
      child: AppDropdownFormField<String?>(
        decoration: const InputDecoration(labelText: 'City'),
        items: items(['Riyadh', 'Jeddah', 'Dammam', 'Khobar', 'Mecca']),
        onChanged: (v) => picked = v,
        validator: (v) => v == null ? 'Required' : null,
      ),
    )));

    await tester.tap(find.byType(AppDropdownFormField<String?>));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'kho');
    await tester.pumpAndSettle();
    Finder inDialog(String t) => find.descendant(of: find.byType(Dialog), matching: find.text(t));
    expect(inDialog('Khobar'), findsOneWidget);
    expect(inDialog('Riyadh'), findsNothing);
    expect(inDialog('Jeddah'), findsNothing);

    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Khobar')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(picked, 'Khobar');
    // The real form field holds the value, so validation passes.
    expect(formKey.currentState!.validate(), isTrue);
    expect(find.text('Khobar'), findsOneWidget);
  });

  testWidgets('Enter picks the first match', (tester) async {
    String? picked;
    await tester.pumpWidget(host(AppDropdownFormField<String?>(
      items: items(['Alpha', 'Beta', 'Gamma', 'Delta']),
      onChanged: (v) => picked = v,
    )));
    await tester.tap(find.byType(AppDropdownFormField<String?>));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'gam');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(picked, 'Gamma');
  });

  testWidgets('a null-valued "All" item can be picked', (tester) async {
    String? picked = 'Beta';
    var calls = 0;
    await tester.pumpWidget(host(StatefulBuilder(
      builder: (context, setState) => AppDropdownButton<String?>(
        value: picked,
        items: items(['Alpha', 'Beta', 'Gamma'], withAll: true),
        onChanged: (v) => setState(() {
          calls++;
          picked = v;
        }),
      ),
    )));
    await tester.tap(find.byType(AppDropdownButton<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('All')));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(picked, isNull);
  });

  testWidgets('closing the dialog changes nothing', (tester) async {
    var calls = 0;
    await tester.pumpWidget(host(AppDropdownFormField<String?>(
      items: items(['A', 'B', 'C', 'D']),
      onChanged: (_) => calls++,
    )));
    await tester.tap(find.byType(AppDropdownFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close search'));
    await tester.pumpAndSettle();
    expect(calls, 0);
  });

  testWidgets('fewer than 4 items opens the normal menu', (tester) async {
    await tester.pumpWidget(host(AppDropdownFormField<String?>(
      items: items(['Yes', 'No', 'Maybe']),
      onChanged: (_) {},
    )));
    await tester.tap(find.byType(AppDropdownFormField<String?>));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Maybe'), findsWidgets);
  });

  testWidgets('a suffix button in the decoration stays clickable', (tester) async {
    var added = 0;
    await tester.pumpWidget(host(AppDropdownFormField<String?>(
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Shop',
        suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: () => added++),
      ),
      items: items(['A', 'B', 'C', 'D']),
      onChanged: (_) {},
    )));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(added, 1);
    expect(find.byType(Dialog), findsNothing);
  });
}
