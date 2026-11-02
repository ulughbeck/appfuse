import 'package:appfuse/appfuse.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

final _bothThemes = {
  Brightness.light: ThemeData.light(),
  Brightness.dark: ThemeData.dark(),
};

void main() {
  setUpAppFuseMocks();

  testWidgets('defaults to the system mode and saves a choice', (tester) async {
    final context = await pumpApp(tester, themes: _bothThemes);
    expect(context.fuse.state.themeMode, ThemeMode.system);

    await context.fuse.changeThemeMode(ThemeMode.dark);
    final prefs = SharedPreferencesAsync();
    expect(await prefs.getString('appfuse.settings.themeMode'), 'dark');
    expect(context.fuse.state.themeMode, ThemeMode.dark);
  });

  testWidgets('an unknown saved mode falls back to the default', (
    tester,
  ) async {
    seedSavedValues(<String, Object>{'appfuse.settings.themeMode': 'sepia'});
    final errors = <Object>[];
    final context = await pumpApp(
      tester,
      themes: _bothThemes,
      onError: (error, _) => errors.add(error),
    );

    expect(errors.single, isA<FormatException>());
    expect(context.fuse.state.themeMode, ThemeMode.system);
  });

  testWidgets('without a dark theme, dark becomes system', (tester) async {
    final context = await pumpApp(
      tester,
      themes: {Brightness.light: ThemeData.light()},
    );
    expect(context.fuse.state.themeMode, ThemeMode.system);

    await context.fuse.changeThemeMode(ThemeMode.dark);
    expect(context.fuse.state.themeMode, ThemeMode.system);
  });

  testWidgets('a dark choice without a dark theme applies when one is added', (
    tester,
  ) async {
    late BuildContext appContext;
    Widget scope(Map<Brightness, ThemeData> themes) => AppFuseScope(
      themes: themes,
      app: Builder(
        builder: (context) {
          appContext = context;
          return const SizedBox.expand();
        },
      ),
    );
    await tester.pumpWidget(scope({Brightness.light: ThemeData.light()}));
    await tester.pumpAndSettle();

    await appContext.fuse.changeThemeMode(ThemeMode.dark);
    final prefs = SharedPreferencesAsync();
    expect(await prefs.getString('appfuse.settings.themeMode'), 'dark');
    expect(appContext.fuse.state.themeMode, ThemeMode.system);

    await tester.pumpWidget(scope(_bothThemes));
    expect(appContext.fuse.state.themeMode, ThemeMode.dark);
  });

  testWidgets('a saved dark choice applies once a dark theme exists', (
    tester,
  ) async {
    seedSavedValues(<String, Object>{'appfuse.settings.themeMode': 'dark'});
    final lightOnly = await pumpApp(
      tester,
      themes: {Brightness.light: ThemeData.light()},
    );
    expect(lightOnly.fuse.state.themeMode, ThemeMode.system);

    await tester.pumpWidget(const SizedBox());
    final both = await pumpApp(tester, themes: _bothThemes);
    expect(both.fuse.state.themeMode, ThemeMode.dark);
  });

  testWidgets('a rebuild with new themes updates the state', (tester) async {
    late BuildContext appContext;
    Widget scope(Map<Brightness, ThemeData> themes) => AppFuseScope(
      themes: themes,
      app: Builder(
        builder: (context) {
          appContext = context;
          return const SizedBox.expand();
        },
      ),
    );
    await tester.pumpWidget(scope({Brightness.light: ThemeData.light()}));
    await tester.pumpAndSettle();
    expect(appContext.fuse.state.darkTheme, isNull);

    await tester.pumpWidget(scope(_bothThemes));
    expect(appContext.fuse.state.darkTheme, isNotNull);
  });

  group('dialog', () {
    testWidgets('reports a failed save and keeps the mode', (tester) async {
      final errors = <Object>[];
      final context = await pumpApp(
        tester,
        themes: _bothThemes,
        storage: MemoryStorage(failingKeys: {'appfuse.settings.themeMode'}),
        onError: (error, _) => errors.add(error),
        material: true,
      );

      selectThemeDialog(context).ignore();
      await tester.pumpAndSettle();
      await tester.tap(find.text('dark'));
      await tester.pumpAndSettle();

      expect(errors.single, isA<StateError>());
      expect(context.fuse.state.themeMode, ThemeMode.system);
    });

    testWidgets('with only a light theme, the light entry is selected', (
      tester,
    ) async {
      final context = await pumpApp(
        tester,
        themes: {Brightness.light: ThemeData.light()},
        material: true,
      );

      selectThemeDialog(context).ignore();
      await tester.pumpAndSettle();

      expect(find.byType(RadioListTile<ThemeMode>), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(RadioListTile<ThemeMode>)),
        isSemantics(isChecked: true),
      );
    });
  });

  testWidgets('ThemeIconButton names the current mode in its tooltip', (
    tester,
  ) async {
    await pumpApp(
      tester,
      themes: _bothThemes,
      material: true,
      child: const ThemeIconButton(),
    );
    expect(find.byTooltip('Current theme mode: system'), findsOneWidget);
  });
}
