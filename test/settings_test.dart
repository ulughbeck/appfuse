import 'dart:convert';

import 'package:appfuse/appfuse.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  setUpAppFuseMocks();

  testWidgets('setCustomSetting rejects a value JSON cannot encode', (
    tester,
  ) async {
    final context = await pumpApp(tester, onError: (_, _) {});

    await expectLater(
      context.fuse.setCustomSetting('date', DateTime(2026)),
      throwsA(isA<JsonUnsupportedObjectError>()),
    );
    expect(context.fuse.state.getCustomSetting<Object>('date'), isNull);
  });

  testWidgets('a value reads the same before and after a restart', (
    tester,
  ) async {
    final storage = MemoryStorage();
    final context = await pumpApp(tester, storage: storage);
    await context.fuse.setCustomSetting('tags', <String>['a']);
    final inSession = context.fuse.state.customSettings['tags'];

    await tester.pumpWidget(const SizedBox());
    final restarted = await pumpApp(tester, storage: storage);
    final restored = restarted.fuse.state.customSettings['tags'];

    expect(restored, inSession);
    expect(restored.runtimeType, inSession.runtimeType);
    expect(restarted.fuse.state.getCustomSetting<List<Object?>>('tags'), ['a']);
  });

  testWidgets('removeCustomSetting removes the saved value', (tester) async {
    final storage = MemoryStorage();
    final context = await pumpApp(tester, storage: storage);
    await context.fuse.setCustomSetting('onboarding', true);
    await context.fuse.setCustomSetting('visits', 3);

    await context.fuse.removeCustomSetting('onboarding');
    expect(context.fuse.state.customSettings, {'visits': 3});

    await tester.pumpWidget(const SizedBox());
    final restarted = await pumpApp(tester, storage: storage);
    expect(restarted.fuse.state.customSettings, {'visits': 3});
  });

  testWidgets(
    'a custom setting does not rebuild widgets that watch the locale',
    (tester) async {
      var localeBuilds = 0;
      var settingsBuilds = 0;
      final context = await pumpApp(
        tester,
        child: Column(
          children: [
            Expanded(
              child: AspectProbe(
                aspect: AppFuseAspect.locale,
                onBuild: () => localeBuilds++,
              ),
            ),
            Expanded(
              child: AspectProbe(
                aspect: AppFuseAspect.settings,
                onBuild: () => settingsBuilds++,
              ),
            ),
          ],
        ),
      );
      final (localeBefore, settingsBefore) = (localeBuilds, settingsBuilds);

      await context.fuse.setCustomSetting('onboarding', true);
      await tester.pump();

      expect(localeBuilds, localeBefore);
      expect(settingsBuilds, settingsBefore + 1);
    },
  );

  testWidgets('the state cannot be changed from outside', (tester) async {
    final storage = MemoryStorage(
      values: {'appfuse.settings.custom': '{"nested":{"tags":["a",["b"]]}}'},
    );
    final context = await pumpApp(tester, storage: storage);
    await context.fuse.setCustomSetting('list', [1]);
    final state = context.fuse.state;

    void expectFrozen(Map<String, Object?> settings) {
      expect(() => settings['x'] = 1, throwsUnsupportedError);
    }

    expectFrozen(state.customSettings);
    final nested = state.getCustomSetting<Map<String, Object?>>('nested')!;
    expectFrozen(nested);
    final tags = nested['tags']! as List<Object?>;
    expect(() => tags.add('c'), throwsUnsupportedError);
    expect(() => (tags[1]! as List<Object?>).add('c'), throwsUnsupportedError);
    expect(
      () => state.getCustomSetting<List<Object?>>('list')!.add(2),
      throwsUnsupportedError,
    );
    expect(
      () => state.supportedLanguages[const Locale('uz')] = "O'zbek",
      throwsUnsupportedError,
    );
    expect(() => state.configs.add(const TestConfig()), throwsUnsupportedError);
  });

  testWidgets('setting an equal value does not write or rebuild', (
    tester,
  ) async {
    final storage = MemoryStorage();
    var builds = 0;
    final context = await pumpApp(
      tester,
      storage: storage,
      child: AspectProbe(
        aspect: AppFuseAspect.settings,
        onBuild: () => builds++,
      ),
    );
    Future<void> save(String tag) async {
      await context.fuse.setCustomSetting('profile', {
        'tags': [tag],
        'age': 3,
      });
      await tester.pump();
    }

    await save('a');
    final (buildsBefore, writesBefore) = (builds, storage.writes.length);

    await save('a');
    expect(builds, buildsBefore);
    expect(storage.writes, hasLength(writesBefore));

    await save('b');
    expect(builds, buildsBefore + 1);
    expect(storage.writes, hasLength(writesBefore + 1));
  });
}
