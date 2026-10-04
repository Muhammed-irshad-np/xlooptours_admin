import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/core/utils/form_validation_helper.dart';

void main() {
  testWidgets('scrolls to and focuses the topmost invalid field', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    final nameFocus = FocusNode();
    final emailFocus = FocusNode();
    String? required(String? v) => (v ?? '').isEmpty ? 'Required' : null;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextFormField(initialValue: 'filled', validator: required),
                  const SizedBox(height: 2000),
                  TextFormField(
                    key: const Key('name'),
                    focusNode: nameFocus,
                    validator: required,
                  ),
                  const SizedBox(height: 2000),
                  TextFormField(focusNode: emailFocus, validator: required),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('name')).hitTestable(), findsNothing);

    final valid = validateAndRevealFirstError(formKey.currentState!);
    await tester.pumpAndSettle();

    expect(valid, isFalse);
    expect(nameFocus.hasFocus, isTrue);
    expect(emailFocus.hasFocus, isFalse);
    expect(find.byKey(const Key('name')).hitTestable(), findsOneWidget);
  });

  testWidgets('focuses an invalid dropdown', (tester) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: DropdownButtonFormField<String>(
              items: const [DropdownMenuItem(value: 'a', child: Text('a'))],
              onChanged: (_) {},
              validator: (v) => v == null ? 'Required' : null,
            ),
          ),
        ),
      ),
    );

    expect(validateAndRevealFirstError(formKey.currentState!), isFalse);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.context, isNotNull);
    expect(
      find.ancestor(
        of: find.byWidget(FocusManager.instance.primaryFocus!.context!.widget),
        matching: find.byType(DropdownButtonFormField<String>),
      ),
      findsOneWidget,
    );
  });

  testWidgets('returns true when the form is valid', (tester) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: TextFormField(initialValue: 'x', validator: (_) => null),
          ),
        ),
      ),
    );
    expect(validateAndRevealFirstError(formKey.currentState!), isTrue);
  });
}
