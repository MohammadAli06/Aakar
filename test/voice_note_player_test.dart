import 'package:craft_connect/features/commerce/presentation/inquiry_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bubble's seconds come from the recorder's counter — carried through the
/// upload and stored on the message — not from playback, which used to leave a
/// fresh note reading `0s` until it was played.
Future<void> pumpPlayer(WidgetTester tester, String language, int? seconds) =>
    tester.pumpWidget(MaterialApp(
        locale: Locale(language),
        supportedLocales: const [Locale('en'), Locale('hi')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
            body: VoiceNotePlayer(
                seconds: seconds, load: () async => 'note.m4a'))));

void main() {
  testWidgets('a stored length is shown before the note is played',
      (tester) async {
    await pumpPlayer(tester, 'en', 12);

    expect(find.text('Voice note · 12s'), findsOneWidget);
  });

  testWidgets('the label follows the app language', (tester) async {
    await pumpPlayer(tester, 'hi', 5);

    expect(find.text('वॉइस नोट · 5s'), findsOneWidget);
  });

  testWidgets('a note with no stored length reports zero until it plays',
      (tester) async {
    await pumpPlayer(tester, 'en', null);

    expect(find.text('Voice note · 0s'), findsOneWidget);
  });
}
