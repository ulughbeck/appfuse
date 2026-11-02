import 'package:appfuse/appfuse.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

final _languages = {
  Locale('en'): 'English',
  Locale('uz'): "O'zbek",
  Locale('ru'): 'Русский',
};

void main() {
  setUpAppFuseMocks();

  void setDeviceLocales(WidgetTester tester, List<Locale> locales) {
    tester.platformDispatcher.localesTestValue = locales;
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  }

  Future<BuildContext> pumpScope(
    WidgetTester tester, {
    bool material = false,
  }) =>
      pumpApp(tester, supportedLanguages: {..._languages}, material: material);

  testWidgets('matches the device language when the region differs', (
    tester,
  ) async {
    setDeviceLocales(tester, const [Locale('ru', 'RU')]);
    final context = await pumpScope(tester);
    expect(context.fuse.state.locale, const Locale('ru'));
    expect(context.fuse.state.userLocale, isNull);
  });

  testWidgets('uses the first supported device language', (tester) async {
    setDeviceLocales(tester, const [Locale('de', 'DE'), Locale('uz', 'UZ')]);
    final context = await pumpScope(tester);
    expect(context.fuse.state.locale, const Locale('uz'));
  });

  testWidgets('follows a device language change at runtime', (tester) async {
    setDeviceLocales(tester, const [Locale('ru', 'RU')]);
    final context = await pumpScope(tester);

    tester.platformDispatcher.localesTestValue = const [Locale('uz', 'UZ')];
    await tester.pump();
    expect(context.fuse.state.locale, const Locale('uz'));
  });

  testWidgets('a saved choice wins over a device language change', (
    tester,
  ) async {
    setDeviceLocales(tester, const [Locale('ru', 'RU')]);
    final context = await pumpScope(tester);
    await context.fuse.changeLocale(const Locale('en'));

    tester.platformDispatcher.localesTestValue = const [Locale('uz', 'UZ')];
    await tester.pump();
    expect(context.fuse.state.locale, const Locale('en'));
  });

  testWidgets('saves only an explicit choice', (tester) async {
    setDeviceLocales(tester, const [Locale('ru', 'RU')]);
    final context = await pumpScope(tester);
    final prefs = SharedPreferencesAsync();
    expect(await prefs.getString('appfuse.settings.locale'), isNull);

    await context.fuse.changeLocale(const Locale('uz'));
    expect(await prefs.getString('appfuse.settings.locale'), 'uz');
    expect(context.fuse.state.locale, const Locale('uz'));
    expect(context.fuse.state.userLocale, const Locale('uz'));
  });

  testWidgets('changeLocale(null) follows the device again', (tester) async {
    setDeviceLocales(tester, const [Locale('ru', 'RU')]);
    final context = await pumpScope(tester);
    await context.fuse.changeLocale(const Locale('uz'));

    await context.fuse.changeLocale(null);
    final prefs = SharedPreferencesAsync();
    expect(await prefs.containsKey('appfuse.settings.locale'), isFalse);
    expect(context.fuse.state.userLocale, isNull);
    expect(context.fuse.state.locale, const Locale('ru'));
  });

  testWidgets('a failed save keeps the locale and reports the error', (
    tester,
  ) async {
    final errors = <Object>[];
    final context = await pumpApp(
      tester,
      supportedLanguages: {..._languages},
      storage: MemoryStorage(failingKeys: {'appfuse.settings.locale'}),
      onError: (error, _) => errors.add(error),
    );

    await expectLater(
      context.fuse.changeLocale(const Locale('uz')),
      throwsStateError,
    );
    expect(errors.single, isA<StateError>());
    expect(context.fuse.state.locale, const Locale('en'));
    expect(context.fuse.state.userLocale, isNull);
  });

  testWidgets('a region of a supported language saves the language', (
    tester,
  ) async {
    final context = await pumpScope(tester);
    await context.fuse.changeLocale(const Locale('uz', 'UZ'));

    expect(context.fuse.state.userLocale, const Locale('uz'));
    expect(
      await SharedPreferencesAsync().getString('appfuse.settings.locale'),
      'uz',
    );
  });

  testWidgets('an unsupported language throws and changes nothing', (
    tester,
  ) async {
    final errors = <Object>[];
    final storage = MemoryStorage();
    final context = await pumpApp(
      tester,
      supportedLanguages: {..._languages},
      storage: storage,
      onError: (error, _) => errors.add(error),
    );
    final writes = storage.writes.length;

    expect(
      () => context.fuse.changeLocale(const Locale('xx')),
      throwsArgumentError,
    );
    await tester.pump();

    expect(storage.writes, hasLength(writes));
    expect(errors, isEmpty);
    expect(context.fuse.state.locale, const Locale('en'));
    expect(context.fuse.state.userLocale, isNull);
  });

  group('dialog', () {
    testWidgets('selects the device entry without a saved choice', (
      tester,
    ) async {
      final context = await pumpScope(tester, material: true);
      selectLocaleDialog(context).ignore();
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(
          find.widgetWithText(RadioListTile<Locale?>, 'System'),
        ),
        isSemantics(isChecked: true),
      );
    });

    testWidgets('a tap saves the language and closes the dialog', (
      tester,
    ) async {
      final context = await pumpScope(tester, material: true);
      selectLocaleDialog(context).ignore();
      await tester.pumpAndSettle();

      await tester.tap(find.text("O'zbek"));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(context.fuse.state.userLocale, const Locale('uz'));
    });
  });

  group('with scripts', () {
    const latin = Locale.fromSubtags(languageCode: 'uz', scriptCode: 'Latn');
    const cyrillic = Locale.fromSubtags(languageCode: 'uz', scriptCode: 'Cyrl');

    Future<BuildContext> pumpScriptScope(WidgetTester tester) => pumpApp(
      tester,
      supportedLanguages: {
        const Locale('en'): 'English',
        latin: "O'zbek",
        cyrillic: 'Ўзбек',
      },
    );

    testWidgets('matches the device script', (tester) async {
      setDeviceLocales(tester, const [
        Locale.fromSubtags(
          languageCode: 'uz',
          scriptCode: 'Cyrl',
          countryCode: 'UZ',
        ),
      ]);
      final context = await pumpScriptScope(tester);
      expect(context.fuse.state.locale, cyrillic);
    });

    testWidgets('keeps the script of a saved choice', (tester) async {
      final context = await pumpScriptScope(tester);
      await context.fuse.changeLocale(cyrillic);
      final prefs = SharedPreferencesAsync();
      expect(await prefs.getString('appfuse.settings.locale'), 'uz-Cyrl');

      await tester.pumpWidget(const SizedBox());
      final restarted = await pumpScriptScope(tester);
      expect(restarted.fuse.state.locale, cyrillic);
    });

    testWidgets('reads a choice saved in the older format', (tester) async {
      seedSavedValues(<String, Object>{'appfuse.settings.locale': 'uz_Cyrl'});

      final context = await pumpScriptScope(tester);
      expect(context.fuse.state.locale, cyrillic);
    });
  });
}
