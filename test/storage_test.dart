import 'package:appfuse/appfuse.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appfuse/src/controller/storage_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers.dart';

/// An in-memory platform whose string writes fail.
base class _FailingWrites extends InMemorySharedPreferencesAsync {
  _FailingWrites.withData(super.data) : super.withData();

  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) => throw StateError('write failed');
}

void main() {
  setUpAppFuseMocks();

  group('AppFuseShPrStorage', () {
    test('writes, reads, and removes strings', () async {
      final storage = await AppFuseShPrStorage.init();
      await storage.write(AppFuseKeys.locale, 'value');
      expect(await storage.read(AppFuseKeys.locale), 'value');
      expect(
        await SharedPreferencesAsync().getString(AppFuseKeys.locale),
        'value',
      );

      await storage.remove(AppFuseKeys.locale);
      expect(await storage.read(AppFuseKeys.locale), isNull);
      expect(
        await SharedPreferencesAsync().containsKey(AppFuseKeys.locale),
        isFalse,
      );
    });

    test('rejects a value that is not a string', () async {
      seedSavedValues(<String, Object>{AppFuseKeys.locale: 5});
      final storage = await AppFuseShPrStorage.init();
      await expectLater(
        storage.read(AppFuseKeys.locale),
        throwsFormatException,
      );
    });

    test('migrates values saved with the legacy API once', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'appfuse.settings.locale': 'uz',
      });
      final storage = await AppFuseShPrStorage.init();
      expect(await storage.read('appfuse.settings.locale'), 'uz');

      await storage.write('appfuse.settings.locale', 'ru');
      SharedPreferences.setMockInitialValues(<String, Object>{
        'appfuse.settings.locale': 'en',
      });
      final next = await AppFuseShPrStorage.init();
      expect(await next.read('appfuse.settings.locale'), 'ru');
    });

    test(
      'migrates only AppFuse keys and keeps values in the new store',
      () async {
        seedSavedValues(<String, Object>{'appfuse.settings.themeMode': 'dark'});
        SharedPreferences.setMockInitialValues(<String, Object>{
          'appfuse.settings.themeMode': 'light',
          'appfuse.settings.locale': 'uz',
          'app.token': 'secret',
        });
        final storage = await AppFuseShPrStorage.init();

        expect(await storage.read('appfuse.settings.themeMode'), 'dark');
        expect(await storage.read('appfuse.settings.locale'), 'uz');
        expect(
          await SharedPreferencesAsync().getKeys(),
          isNot(contains('app.token')),
        );
      },
    );

    test('cannot read or write a key outside the AppFuse keys', () async {
      seedSavedValues(<String, Object>{'app.token': 'secret'});
      final storage = await AppFuseShPrStorage.init();

      await expectLater(storage.read('app.token'), throwsArgumentError);
      await expectLater(storage.write('app.token', 'x'), throwsArgumentError);
      await expectLater(storage.remove('app.token'), throwsArgumentError);
      expect(await SharedPreferencesAsync().getString('app.token'), 'secret');
    });

    test('a failed write throws and the cache keeps the old value', () async {
      SharedPreferencesAsyncPlatform.instance = _FailingWrites.withData({
        AppFuseKeys.locale: 'uz',
      });
      final storage = await AppFuseShPrStorage.init();

      await expectLater(
        storage.write(AppFuseKeys.locale, 'ru'),
        throwsA(isA<StateError>()),
      );
      expect(await storage.read(AppFuseKeys.locale), 'uz');
    });
  });

  group('app storage', () {
    testWidgets('AppFuse leaves the keys of the app untouched', (tester) async {
      seedSavedValues(<String, Object>{'app.token': 'secret', 'app.count': 3});
      final context = await pumpApp(tester);
      await context.fuse.changeThemeMode(ThemeMode.dark);
      await context.fuse.setCustomSetting('a', 1);

      final prefs = SharedPreferencesAsync();
      expect(await prefs.getString('app.token'), 'secret');
      expect(await prefs.getInt('app.count'), 3);
      expect(await prefs.getString(AppFuseKeys.themeMode), 'dark');
    });
  });

  group('bad saved data', () {
    testWidgets('invalid JSON and a wrong type fall back and are reported', (
      tester,
    ) async {
      seedSavedValues(<String, Object>{
        'appfuse.settings.custom': '{not json',
        'appfuse.settings.locale': 5,
      });
      final errors = <Object>[];
      final context = await pumpApp(
        tester,
        onError: (error, _) => errors.add(error),
      );

      expect(context.fuse.state.phase, isA<AppFuseReady>());
      expect(errors, hasLength(2));
      expect(errors, everyElement(isFormatException));
      expect(context.fuse.state.customSettings, isEmpty);
      expect(context.fuse.state.userLocale, isNull);
    });

    testWidgets('startup restores a choice saved with the legacy API', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'appfuse.settings.locale': 'uz',
      });
      final context = await pumpApp(
        tester,
        supportedLanguages: {
          const Locale('en'): 'English',
          const Locale('uz'): "O'zbek",
        },
      );

      expect(context.fuse.state.userLocale, const Locale('uz'));
    });

    testWidgets('a failed first-launch write does not stop startup', (
      tester,
    ) async {
      final errors = <Object>[];
      final context = await pumpApp(
        tester,
        storage: MemoryStorage(failingKeys: {'appfuse.settings.firstLaunch'}),
        onError: (error, _) => errors.add(error),
      );

      expect(context.fuse.state.phase, isA<AppFuseReady>());
      expect(errors.single, isA<StateError>());
      expect(context.fuse.state.metaData.isFirstLaunch, isTrue);
    });

    testWidgets('keeps the saved first-launch date on the next launch', (
      tester,
    ) async {
      final storage = MemoryStorage();
      final first = await pumpApp(tester, storage: storage);
      final firstLaunch = first.fuse.state.metaData.appFirstLaunchTimestamp;

      await tester.pumpWidget(const SizedBox());
      final next = await pumpApp(tester, storage: storage);
      expect(next.fuse.state.metaData.isFirstLaunch, isFalse);
      expect(next.fuse.state.metaData.appFirstLaunchTimestamp, firstLaunch);
    });
  });
}
