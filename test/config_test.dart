import 'dart:convert';

import 'package:appfuse/appfuse.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// Runs one step that takes 10 seconds.
class _SlowStep with AppFuseInitialization {
  const _SlowStep();

  @override
  Map<String, InitializationStep> get steps => {
    'slow step': (_) => Future<void>.delayed(const Duration(seconds: 10)),
  };
}

const _host = ConfigKey<String>('HOST');

class _AssetConfig extends JsonAssetConfig {
  _AssetConfig() : super(name: 'ASSET', path: 'config.json');

  String get host => read(_host);
}

class _EnvConfig extends EnvironmentConfig {
  const _EnvConfig()
    : super(
        name: 'ENV',
        values: const {
          'HOST': 'example.com',
          'PORT': '8080',
          'DEBUG': 'TRUE',
          'RATIO': '0.5',
          'WHOLE': 1,
        },
      );
}

class _RemoteConfig extends JsonRemoteConfig {
  _RemoteConfig(http.Client client)
    : super(
        name: 'REMOTE',
        uri: 'https://example.com/config.json',
        client: client,
      );

  String get host => read(_host);
}

void main() {
  setUpAppFuseMocks();

  group('config banner', () {
    testWidgets('shown when showBanner is true', (tester) async {
      await pumpApp(tester, configs: const [TestConfig(showBanner: true)]);
      expect(find.byType(ConfigBanner), findsOneWidget);
    });

    testWidgets('absent when showBanner is false', (tester) async {
      await pumpApp(tester, configs: const [TestConfig()]);
      expect(find.byType(ConfigBanner), findsNothing);
    });

    testWidgets('lets taps reach the app', (tester) async {
      var taps = 0;
      await pumpApp(
        tester,
        configs: const [TestConfig(showBanner: true)],
        child: Align(
          alignment: Alignment.topLeft,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      );

      await tester.tapAt(const Offset(10, 10));
      expect(taps, 1);
    });
  });

  group('configs that change on rebuild', () {
    late BuildContext appContext;

    Widget scope(List<BaseConfig> configs) => AppFuseScope(
      configs: configs,
      app: Builder(
        builder: (context) {
          appContext = context;
          return const SizedBox.expand();
        },
      ),
    );

    testWidgets('a removed active config switches to the first config', (
      tester,
    ) async {
      await tester.pumpWidget(scope(const [TestConfig(name: 'A')]));
      await tester.pumpAndSettle();
      expect(appContext.fuse.state.config.name, 'A');

      await tester.pumpWidget(
        scope(const [TestConfig(name: 'B'), TestConfig(name: 'C')]),
      );
      await tester.pumpAndSettle();

      expect(appContext.fuse.state.config.name, 'B');
      expect(
        await SharedPreferencesAsync().getString('appfuse.settings.config'),
        'B',
      );
    });

    testWidgets('an active config that stays in the list is kept', (
      tester,
    ) async {
      await tester.pumpWidget(
        scope(const [TestConfig(name: 'A'), TestConfig(name: 'B')]),
      );
      await tester.pumpAndSettle();
      await appContext.fuse.activateConfig(const TestConfig(name: 'B'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        scope(const [TestConfig(name: 'C'), TestConfig(name: 'B')]),
      );
      await tester.pumpAndSettle();

      expect(appContext.fuse.state.config.name, 'B');
    });

    testWidgets('an empty list switches to EmptyConfig', (tester) async {
      await tester.pumpWidget(scope(const [TestConfig(name: 'A')]));
      await tester.pumpAndSettle();

      await tester.pumpWidget(scope(const []));
      await tester.pumpAndSettle();

      expect(appContext.fuse.state.config, isA<EmptyConfig>());
    });

    testWidgets('a failed switch goes to onError, not to the zone', (
      tester,
    ) async {
      final errors = <Object>[];
      Widget failing(List<BaseConfig> configs) => AppFuseScope(
        configs: configs,
        onError: (error, _) => errors.add(error),
        app: Builder(
          builder: (context) {
            appContext = context;
            return const SizedBox.expand();
          },
        ),
      );
      await tester.pumpWidget(failing(const [TestConfig(name: 'A')]));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        failing(const [SlowConfig(name: 'B', fails: true)]),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(errors.single, isA<StateError>());
      expect(appContext.fuse.state.config.name, 'A');
    });
  });

  group('activateConfig', () {
    testWidgets('a successful switch remounts the app subtree', (tester) async {
      const configA = TestConfig(name: 'A');
      const configB = TestConfig(name: 'B');
      var mounts = 0;
      final fuse = (await pumpApp(
        tester,
        configs: const [configA, configB],
        child: MountProbe(onMount: () => mounts++),
      )).fuse;
      expect(mounts, 1);

      await fuse.activateConfig(configB);
      await tester.pumpAndSettle();
      expect(mounts, 2);
      expect(fuse.state.config, same(configB));
      final prefs = SharedPreferencesAsync();
      expect(await prefs.getString('appfuse.settings.config'), 'B');
    });

    testWidgets('re-activating the same config remounts with fresh values', (
      tester,
    ) async {
      const config = TestConfig(name: 'A');
      var mounts = 0;
      final fuse = (await pumpApp(
        tester,
        configs: const [config],
        child: MountProbe(onMount: () => mounts++),
      )).fuse;

      await fuse.activateConfig(config);
      await tester.pumpAndSettle();
      expect(mounts, 2);
    });

    testWidgets('the placeholder shows during the switch', (tester) async {
      const slow = SlowConfig(name: 'SLOW');
      var mounts = 0;
      final fuse = (await pumpApp(
        tester,
        configs: const [
          TestConfig(name: 'A'),
          slow,
        ],
        child: MountProbe(onMount: () => mounts++),
      )).fuse;

      final switching = fuse.activateConfig(slow);
      // The first pump starts the queued switch, the second builds the placeholder.
      await tester.pump();
      await tester.pump();
      expect(find.text('app'), findsNothing);
      expect(fuse.state.phase, isA<AppFuseStarting>());

      await tester.pump(const Duration(seconds: 1));
      await switching;
      await tester.pumpAndSettle();
      expect(find.text('app'), findsOneWidget);
      expect(mounts, 2);
      expect(fuse.state.config, same(slow));
    });

    testWidgets('a switch runs the steps again with a new init object', (
      tester,
    ) async {
      const configA = TestConfig(name: 'A');
      const configB = TestConfig(name: 'B');
      final created = <RecordingInitialization>[];
      final fuse = (await pumpApp(
        tester,
        configs: const [configA, configB],
        init: recordingFactory(created),
      )).fuse;
      final [old] = created;
      expect(old.seenConfigs, ['A']);

      await fuse.activateConfig(configB);
      await tester.pumpAndSettle();

      expect(created, hasLength(2));
      expect(old.disposals, 1);
      expect(old.seenConfigs, ['A']);
      expect(created.last.seenConfigs, ['B']);
      expect(created.last.disposals, 0);
      expect(fuse.setup, same(created.last));
    });

    testWidgets('a failing dispose is reported and the switch continues', (
      tester,
    ) async {
      const configB = TestConfig(name: 'B');
      final errors = <Object>[];
      final created = <RecordingInitialization>[];
      final fuse = (await pumpApp(
        tester,
        configs: const [
          TestConfig(name: 'A'),
          configB,
        ],
        init: recordingFactory(created, disposeError: StateError('close')),
        onError: (error, _) => errors.add(error),
      )).fuse;

      await fuse.activateConfig(configB);
      await tester.pumpAndSettle();

      expect(errors, hasLength(1));
      expect(fuse.state.config, same(configB));
      expect(created.last.seenConfigs, ['B']);
    });

    testWidgets('a config that fails to load keeps the old setup', (
      tester,
    ) async {
      const config = TestConfig(name: 'A');
      const failing = SlowConfig(name: 'FAILING', fails: true);
      final errors = <Object>[];
      final created = <RecordingInitialization>[];
      var mounts = 0;
      final fuse = (await pumpApp(
        tester,
        configs: const [config, failing],
        init: recordingFactory(created),
        onError: (error, _) => errors.add(error),
        child: MountProbe(onMount: () => mounts++),
      )).fuse;

      final switching = expectLater(
        fuse.activateConfig(failing),
        throwsStateError,
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('app'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      await switching;
      await tester.pumpAndSettle();

      expect(errors, hasLength(1));
      expect(mounts, 2);
      expect(find.text('app'), findsOneWidget);
      expect(fuse.state.config, same(config));
      expect(created, hasLength(1));
      expect(created.single.disposals, 0);
      expect(fuse.setup, same(created.single));
    });

    testWidgets('a step that fails after a switch is final and not saved', (
      tester,
    ) async {
      const configB = TestConfig(name: 'B');
      final storage = MemoryStorage(values: {'appfuse.settings.config': 'A'});
      final errors = <Object>[];
      final fuse = (await pumpApp(
        tester,
        configs: const [
          TestConfig(name: 'A'),
          configB,
        ],
        storage: storage,
        init: recordingFactory([], failsFor: 'B'),
        onError: (error, _) => errors.add(error),
        child: MountProbe(onMount: () {}),
      )).fuse;

      await expectLater(
        fuse.activateConfig(configB),
        throwsA(isA<AppFuseInitException>()),
      );
      await tester.pumpAndSettle();

      expect(errors, [isA<AppFuseInitException>()]);
      expect(
        fuse.state.phase,
        isA<AppFuseFailed>().having(
          (phase) => phase.error,
          'error',
          isA<AppFuseInitException>(),
        ),
      );
      expect(find.text('app'), findsNothing);
      expect(storage.values['appfuse.settings.config'], 'A');
    });

    testWidgets('a failed save keeps the new config and fails the call', (
      tester,
    ) async {
      const configB = TestConfig(name: 'B');
      final errors = <Object>[];
      var mounts = 0;
      final fuse = (await pumpApp(
        tester,
        configs: const [
          TestConfig(name: 'A'),
          configB,
        ],
        storage: MemoryStorage(failingKeys: {'appfuse.settings.config'}),
        onError: (error, _) => errors.add(error),
        child: MountProbe(onMount: () => mounts++),
      )).fuse;

      await expectLater(fuse.activateConfig(configB), throwsStateError);
      await tester.pumpAndSettle();

      expect(errors, hasLength(1));
      expect(fuse.state.config, same(configB));
      expect(fuse.state.phase, isA<AppFuseReady>());
      expect(mounts, 2);
    });

    testWidgets('overlapping switches run in order and the last one wins', (
      tester,
    ) async {
      const slow = SlowConfig(name: 'SLOW');
      const fast = TestConfig(name: 'FAST');
      final storage = MemoryStorage();
      final created = <RecordingInitialization>[];
      final fuse = (await pumpApp(
        tester,
        configs: const [
          TestConfig(name: 'A'),
          slow,
          fast,
        ],
        storage: storage,
        init: recordingFactory(created),
      )).fuse;

      final first = fuse.activateConfig(slow);
      await tester.pump();
      final second = fuse.activateConfig(fast);
      await tester.pump(const Duration(seconds: 1));
      await Future.wait([first, second]);
      await tester.pumpAndSettle();

      expect(fuse.state.config, same(fast));
      expect(storage.values['appfuse.settings.config'], 'FAST');
      expect(created.map((init) => init.seenConfigs), [
        ['A'],
        ['SLOW'],
        ['FAST'],
      ]);
    });

    testWidgets('a theme change waits for a running switch', (tester) async {
      const slow = SlowConfig(name: 'SLOW');
      final fuse = (await pumpApp(
        tester,
        configs: const [
          TestConfig(name: 'A'),
          slow,
        ],
        themes: {
          Brightness.light: ThemeData.light(),
          Brightness.dark: ThemeData.dark(),
        },
      )).fuse;

      final switching = fuse.activateConfig(slow);
      var themeChanged = false;
      fuse.changeThemeMode(ThemeMode.dark).then((_) => themeChanged = true);
      await tester.pump();
      expect(themeChanged, isFalse);

      await tester.pump(const Duration(seconds: 1));
      await switching;
      await tester.pumpAndSettle();
      expect(themeChanged, isTrue);
      expect(fuse.state.themeMode, ThemeMode.dark);
    });

    testWidgets('fails with StateError while the controller initializes', (
      tester,
    ) async {
      final errors = <Object>[];
      final controller = AppFuseController(
        storage: MemoryStorage(),
        setup: () => const _SlowStep(),
        onError: (error, _) => errors.add(error),
      );
      addTearDown(controller.dispose);

      await expectLater(
        controller.activateConfig(const TestConfig()),
        throwsStateError,
      );
      expect(errors, isEmpty);
      await tester.pump(const Duration(seconds: 10));
    });
  });

  group('config types', () {
    testWidgets('JsonAssetConfig loads again on a second init', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        (message) async {
          final bytes = utf8.encode('{"HOST":"example.com"}');
          return ByteData.sublistView(bytes);
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMessageHandler(
          'flutter/assets',
          null,
        ),
      );

      final config = _AssetConfig();
      await tester.runAsync(config.init);
      await tester.runAsync(config.init);
      expect(config.host, 'example.com');
    });

    test('read returns typed values and parses strings', () {
      const config = _EnvConfig();
      expect(config.read(const ConfigKey<String>('HOST')), 'example.com');
      expect(config.read(const ConfigKey<int>('PORT')), 8080);
      expect(config.read(const ConfigKey<bool>('DEBUG')), isTrue);
      expect(config.read(const ConfigKey<double>('RATIO')), 0.5);
      expect(config.read(const ConfigKey<int>('WHOLE')), 1);
      expect(config.read(const ConfigKey<String>('WHOLE')), '1');
    });

    test('read throws for a missing key and a wrong type', () {
      const config = _EnvConfig();
      expect(
        () => config.read(const ConfigKey<String>('MISSING')),
        throwsA(isA<AppFuseConfigException>()),
      );
      expect(
        () => config.read(const ConfigKey<int>('DEBUG')),
        throwsA(isA<AppFuseConfigException>()),
      );
      expect(
        () => config.read(const ConfigKey<bool>('HOST')),
        throwsA(isA<AppFuseConfigException>()),
      );
    });

    test('JsonRemoteConfig loads values with the given client', () async {
      final config = _RemoteConfig(
        MockClient((request) async => http.Response('{"HOST":"a.dev"}', 200)),
      );
      await config.init();
      expect(config.host, 'a.dev');
    });

    test('JsonRemoteConfig fails on a non-2xx status', () async {
      final config = _RemoteConfig(
        MockClient((request) async => http.Response('', 400)),
      );
      await expectLater(config.init(), throwsA(isA<http.ClientException>()));
    });

    test('JsonRemoteConfig fails on an empty config', () async {
      final config = _RemoteConfig(
        MockClient((request) async => http.Response('{}', 200)),
      );
      await expectLater(config.init(), throwsA(isA<AppFuseConfigException>()));
    });
  });
}
