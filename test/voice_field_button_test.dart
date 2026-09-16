import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:craft_connect/features/commerce/presentation/craft_forms.dart';

/// Records the callback the button registers and lets a test speak into the field,
/// the way the platform recognizer would.
class FakeDictation implements CraftDictation {
  void Function(String words, bool isFinal)? _onResult;
  int starts = 0;
  int stops = 0;
  final List<String> locales = [];

  @override
  Future<bool> start(
      {required String localeId,
      void Function(String words, bool isFinal)? onResult}) async {
    starts++;
    locales.add(localeId);
    _onResult = onResult;
    return true;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  void say(String words, {bool isFinal = true}) => _onResult!(words, isFinal);
}

Future<FakeDictation> pumpMic(WidgetTester tester, TextEditingController controller,
    {String? initial}) async {
  if (initial != null) controller.text = initial;
  final dictation = FakeDictation();
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: VoiceFieldButton(controller: controller, dictation: dictation))));
  return dictation;
}

Future<void> pressMic(WidgetTester tester) async {
  await tester.tap(find.byType(IconButton));
  await tester.pumpAndSettle();
}

void main() {
  group('joinFieldDictation', () {
    test('continues existing text with a single space', () {
      expect(joinFieldDictation('handwoven basket', 'in bamboo'),
          'handwoven basket in bamboo');
    });

    test('does not double a space the field already ends with', () {
      expect(joinFieldDictation('handwoven basket ', 'in bamboo'),
          'handwoven basket in bamboo');
    });

    test('takes the whole utterance when the field is empty', () {
      expect(joinFieldDictation('', 'in bamboo'), 'in bamboo');
      expect(joinFieldDictation('   ', 'in bamboo'), 'in bamboo');
    });

    test('leaves typing alone while nothing has been recognised', () {
      expect(joinFieldDictation('typed by hand', ''), isNull);
      expect(joinFieldDictation('typed by hand', '   '), isNull);
    });
  });

  group('VoiceFieldButton dictation', () {
    testWidgets('a second press continues the text instead of replacing it',
        (tester) async {
      final controller = TextEditingController();
      final dictation = await pumpMic(tester, controller, initial: 'Handwoven basket');

      await pressMic(tester);
      dictation.say('made of bamboo');
      await tester.pumpAndSettle();
      expect(controller.text, 'Handwoven basket made of bamboo');

      // The reported bug: pressing mic again wiped the field.
      await pressMic(tester);
      dictation.say('from Assam');
      await tester.pumpAndSettle();
      expect(controller.text, 'Handwoven basket made of bamboo from Assam');
    });

    testWidgets('a continued session keeps the words an earlier one added',
        (tester) async {
      final controller = TextEditingController();
      final dictation = await pumpMic(tester, controller, initial: 'Clay pot');

      await pressMic(tester);
      dictation.say('from Jaipur');
      await tester.pumpAndSettle();
      await pressMic(tester);
      dictation.say('painted by hand');
      await tester.pumpAndSettle();
      await pressMic(tester);
      dictation.say('for daily use');
      await tester.pumpAndSettle();

      expect(controller.text, 'Clay pot from Jaipur painted by hand for daily use');
    });

    testWidgets('refined partial utterances do not duplicate the typed text',
        (tester) async {
      final controller = TextEditingController();
      final dictation = await pumpMic(tester, controller, initial: 'Clay pot');

      await pressMic(tester);
      dictation.say('terracotta', isFinal: false);
      await tester.pumpAndSettle();
      expect(controller.text, 'Clay pot terracotta');

      dictation.say('terracotta clay', isFinal: false);
      await tester.pumpAndSettle();
      expect(controller.text, 'Clay pot terracotta clay');

      dictation.say('terracotta clay pot');
      await tester.pumpAndSettle();
      expect(controller.text, 'Clay pot terracotta clay pot');
    });

    testWidgets('an empty utterance leaves the held text untouched', (tester) async {
      final controller = TextEditingController();
      final dictation = await pumpMic(tester, controller, initial: 'Chikankari kurta');

      await pressMic(tester);
      dictation.say('', isFinal: false);
      await tester.pumpAndSettle();
      expect(controller.text, 'Chikankari kurta');
    });

    testWidgets('dictation into an empty field still works', (tester) async {
      final controller = TextEditingController();
      final dictation = await pumpMic(tester, controller);

      await pressMic(tester);
      dictation.say('Handwoven bamboo basket');
      await tester.pumpAndSettle();
      expect(controller.text, 'Handwoven bamboo basket');
    });

    testWidgets('the caret lands at the end of the continued text', (tester) async {
      final controller = TextEditingController();
      final dictation = await pumpMic(tester, controller, initial: 'Clay pot');

      await pressMic(tester);
      dictation.say('from Jaipur');
      await tester.pumpAndSettle();
      expect(controller.selection.baseOffset, 'Clay pot from Jaipur'.length);
    });

    testWidgets('a final utterance stops the recognizer and a second press restarts it',
        (tester) async {
      final controller = TextEditingController();
      final dictation = await pumpMic(tester, controller, initial: 'Basket');

      await pressMic(tester);
      expect(dictation.starts, 1);
      dictation.say('woven');
      await tester.pumpAndSettle();

      await pressMic(tester);
      expect(dictation.starts, 2);
      dictation.say('in cane');
      await tester.pumpAndSettle();
      expect(controller.text, 'Basket woven in cane');
    });
  });
}
