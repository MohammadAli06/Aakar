import 'package:craft_connect/features/commerce/domain/commerce_engine.dart';
import 'package:craft_connect/features/commerce/presentation/craft_forms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens the shared craft form with [fields] and hands the submitted record to
/// [onResult].
Future<void> openForm(WidgetTester tester, List<CraftField> fields,
    {required void Function(Record?) onResult}) async {
  await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (context) => Scaffold(
              body: Center(
                  child: ElevatedButton(
                      onPressed: () async {
                        onResult(await craftForm(context, 'Test form', fields));
                      },
                      child: const Text('open')))))));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

String today() {
  final now = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${now.year}-${two(now.month)}-${two(now.day)}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a date field is filled from the calendar, with no time step',
      (tester) async {
    Record? result;
    await openForm(
        tester,
        const [
          CraftField('due', 'Due date', 'तारीख', required: true, date: true)
        ],
        onResult: (r) => result = r);

    // Nothing is typed here; tapping the field opens the calendar.
    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    // A date-only field must never ask for a clock time.
    expect(find.byType(TimePickerDialog), findsNothing);

    await tester.tap(find.text('Save & continue'));
    await tester.pumpAndSettle();

    expect(result!['due'], today());
  });

  testWidgets('a date & time field continues to the clock', (tester) async {
    Record? result;
    await openForm(
        tester,
        const [
          CraftField('when', 'Date & time', 'तारीख और समय',
              required: true, date: true, withTime: true)
        ],
        onResult: (r) => result = r);

    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save & continue'));
    await tester.pumpAndSettle();

    expect(
        result!['when'], matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$')));
  });

  testWidgets('a required date still reports a missing value', (tester) async {
    Record? result;
    await openForm(
        tester,
        const [
          CraftField('due', 'Due date', 'तारीख', required: true, date: true)
        ],
        onResult: (r) => result = r);

    await tester.tap(find.text('Save & continue'));
    await tester.pumpAndSettle();

    // The form stays open and reports what is missing.
    expect(find.text('Required'), findsOneWidget);
    expect(result, isNull);
  });

  testWidgets('a plain field is still typed by hand', (tester) async {
    Record? result;
    await openForm(tester, const [CraftField('note', 'Note', 'नोट')],
        onResult: (r) => result = r);

    await tester.enterText(find.byType(TextFormField), 'woven by hand');
    await tester.tap(find.text('Save & continue'));
    await tester.pumpAndSettle();

    expect(result!['note'], 'woven by hand');
  });
}
