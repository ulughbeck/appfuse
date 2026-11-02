import 'dart:async';

import 'package:appfuse/appfuse.dart';
import 'package:appfuse/src/widgets/foundation/vital_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Reports the size it observes via [MediaQuery.sizeOf] on every build.
class _SizeProbe extends StatelessWidget {
  const _SizeProbe({required this.onSize});

  final ValueSetter<Size> onSize;

  @override
  Widget build(BuildContext context) {
    onSize(MediaQuery.sizeOf(context));
    return const SizedBox.expand();
  }
}

/// Runs one step that waits for [gate], and fails when [fails] is `true`.
class _GatedStep with AppFuseInitialization {
  _GatedStep({this.fails = false});

  final gate = Completer<void>();
  final bool fails;

  @override
  Map<String, InitializationStep> get steps => {
    'gated step': (_) async {
      await gate.future;
      if (fails) throw StateError('step failed');
    },
  };
}

/// Runs one step that takes one second.
class _SlowStep with AppFuseInitialization {
  const _SlowStep();

  @override
  Map<String, InitializationStep> get steps => {
    'slow step': (_) => Future<void>.delayed(const Duration(seconds: 1)),
  };
}

void main() {
  setUpAppFuseMocks();

  Future<void> resizeView(
    WidgetTester tester,
    Size physicalSize,
    double devicePixelRatio,
  ) async {
    tester.view.physicalSize = physicalSize;
    tester.view.devicePixelRatio = devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pump();
  }

  group('MediaQuery liveness', () {
    testWidgets('config branch: app sees updated metrics after a view change', (
      tester,
    ) async {
      Size? seenSize;
      await pumpApp(
        tester,
        configs: const [TestConfig()],
        child: _SizeProbe(onSize: (size) => seenSize = size),
      );
      expect(
        seenSize,
        isNotNull,
        reason: 'initialization must complete and build the app',
      );

      await resizeView(tester, const Size(400, 600), 1);
      expect(
        seenSize,
        const Size(400, 600),
        reason: 'app must observe live view metrics, not a startup snapshot',
      );
    });

    testWidgets(
      'no-configs branch: app sees updated metrics after a view change',
      (tester) async {
        Size? seenSize;
        await pumpApp(
          tester,
          child: _SizeProbe(onSize: (size) => seenSize = size),
        );
        expect(seenSize, isNotNull);

        await resizeView(tester, const Size(400, 600), 1);
        expect(seenSize, const Size(400, 600));
      },
    );

    testWidgets(
      'VitalApp (splash/error shell): home sees updated metrics after a view change',
      (tester) async {
        Size? seenSize;
        await tester.pumpWidget(
          VitalApp(
            theme: ThemeData.light(),
            home: _SizeProbe(onSize: (size) => seenSize = size),
          ),
        );
        expect(seenSize, isNotNull);

        await resizeView(tester, const Size(400, 600), 1);
        expect(seenSize, const Size(400, 600));
      },
    );
  });

  testWidgets('progressBuilder gets the running step', (tester) async {
    final seen = <AppFuseProgress?>[];
    await tester.pumpWidget(
      AppFuseScope(
        keepNativeSplash: false,
        storage: MemoryStorage(),
        init: () => const _SlowStep(),
        progressBuilder: (progress) {
          seen.add(progress);
          return const SizedBox();
        },
        app: const SizedBox.expand(),
      ),
    );
    await tester.pump();

    // Three built-in steps and one step of the app.
    expect(
      seen.last,
      const AppFuseProgress(current: 4, total: 4, step: 'slow step'),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('reports progress for each step', (tester) async {
    final messages = <String>[];
    await tester.pumpWidget(
      AppFuseScope(onProgress: messages.add, app: const SizedBox.expand()),
    );
    await tester.pumpAndSettle();

    expect(messages.first, 'initialization started');
    expect(messages, contains(contains('"fetch saved settings"')));
    expect(messages.last, startsWith('initialization finished'));
  });

  testWidgets('a rebuild with equal inline options keeps the state', (
    tester,
  ) async {
    late BuildContext appContext;
    Widget scope() => AppFuseScope(
      // New instances on each build, as in a parent that builds them inline.
      // ignore: prefer_const_constructors
      configs: [TestConfig()],
      supportedLanguages: {const Locale('en'): 'English'},
      themes: {Brightness.light: ThemeData.light()},
      localizationsDelegates: [DefaultWidgetsLocalizations.delegate],
      app: Builder(
        builder: (context) {
          appContext = context;
          return const SizedBox.expand();
        },
      ),
    );
    await tester.pumpWidget(scope());
    await tester.pumpAndSettle();
    final before = AppFuseScope.read(appContext);

    await tester.pumpWidget(scope());
    expect(AppFuseScope.read(appContext), same(before));
  });

  testWidgets('a changed option notifies only the widgets that watch it', (
    tester,
  ) async {
    var themeBuilds = 0;
    var localeBuilds = 0;
    // The same app instance on each build, so only notifications rebuild it.
    final app = Column(
      children: [
        Expanded(
          child: AspectProbe(
            aspect: AppFuseAspect.theme,
            onBuild: () => themeBuilds++,
          ),
        ),
        Expanded(
          child: AspectProbe(
            aspect: AppFuseAspect.locale,
            onBuild: () => localeBuilds++,
          ),
        ),
      ],
    );
    Widget scope(Map<Locale, String> languages) => AppFuseScope(
      supportedLanguages: languages,
      themes: {Brightness.light: ThemeData.light()},
      app: app,
    );
    await tester.pumpWidget(scope({const Locale('en'): 'English'}));
    await tester.pumpAndSettle();
    final (themeBefore, localeBefore) = (themeBuilds, localeBuilds);

    await tester.pumpWidget(
      scope({const Locale('en'): 'English', const Locale('uz'): "O'zbek"}),
    );

    expect(themeBuilds, themeBefore);
    expect(localeBuilds, localeBefore + 1);
  });

  group('keepNativeSplash', () {
    Future<_GatedStep> pumpGated(
      WidgetTester tester, {
      bool fails = false,
      bool keepNativeSplash = true,
    }) async {
      final init = _GatedStep(fails: fails);
      await tester.pumpWidget(
        AppFuseScope(
          keepNativeSplash: keepNativeSplash,
          storage: MemoryStorage(),
          init: () => init,
          onError: (_, _) {},
          errorBuilder: (_, _, _) => const SizedBox(),
          app: const SizedBox.expand(),
        ),
      );
      return init;
    }

    testWidgets('defers frames until the startup is ready', (tester) async {
      final init = await pumpGated(tester);
      expect(tester.binding.sendFramesToEngine, isFalse);

      init.gate.complete();
      await tester.pumpAndSettle();
      expect(tester.binding.sendFramesToEngine, isTrue);
    });

    testWidgets('allows frames when the startup fails', (tester) async {
      final init = await pumpGated(tester, fails: true);
      expect(tester.binding.sendFramesToEngine, isFalse);

      init.gate.complete();
      await tester.pumpAndSettle();
      expect(tester.binding.sendFramesToEngine, isTrue);
    });

    testWidgets('allows frames when the scope is removed during startup', (
      tester,
    ) async {
      await pumpGated(tester);
      expect(tester.binding.sendFramesToEngine, isFalse);

      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.sendFramesToEngine, isTrue);
    });

    testWidgets('does not defer frames when false', (tester) async {
      await pumpGated(tester, keepNativeSplash: false);
      expect(tester.binding.sendFramesToEngine, isTrue);
    });
  });

  group('state', () {
    testWidgets('describes the config and locale for the inspector', (
      tester,
    ) async {
      final context = await pumpApp(
        tester,
        configs: const [TestConfig(name: 'staging')],
        supportedLanguages: {const Locale('uz'): "O'zbek"},
      );
      final description = AppFuseScope.read(context).toDiagnosticsNode();
      expect(
        description.toStringDeep(),
        allOf(contains('staging'), contains('uz'), contains('phase')),
      );
    });
  });

  group('placeholder theme', () {
    final themes = {
      Brightness.light: ThemeData.light(),
      Brightness.dark: ThemeData.dark(),
    };

    /// Returns the theme that the placeholder sees.
    Future<ThemeData> placeholderTheme(
      WidgetTester tester, {
      required Brightness platform,
      required Map<Brightness, ThemeData> themes,
      Map<String, String> saved = const {},
    }) async {
      tester.platformDispatcher.platformBrightnessTestValue = platform;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      late ThemeData seen;
      await tester.pumpWidget(
        AppFuseScope(
          keepNativeSplash: false,
          themes: themes,
          storage: MemoryStorage(values: saved),
          init: () => const _SlowStep(),
          placeholder: Builder(
            builder: (context) {
              seen = Theme.of(context);
              return const SizedBox();
            },
          ),
          app: const SizedBox.expand(),
        ),
      );
      await tester.pump();
      final theme = seen;
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      return theme;
    }

    testWidgets('follows a dark system', (tester) async {
      final theme = await placeholderTheme(
        tester,
        platform: Brightness.dark,
        themes: themes,
      );
      expect(theme.brightness, Brightness.dark);
    });

    testWidgets('uses the saved mode over the system', (tester) async {
      final theme = await placeholderTheme(
        tester,
        platform: Brightness.dark,
        themes: themes,
        saved: {'appfuse.settings.themeMode': 'light'},
      );
      expect(theme.brightness, Brightness.light);
    });

    testWidgets('uses the light theme without a dark theme', (tester) async {
      final theme = await placeholderTheme(
        tester,
        platform: Brightness.dark,
        themes: {Brightness.light: ThemeData.light()},
      );
      expect(theme.brightness, Brightness.light);
    });
  });
}
