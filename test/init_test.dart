import 'dart:async';
import 'dart:ui';

import 'package:appfuse/appfuse.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Runs one step that takes [duration].
class _SlowInitialization with AppFuseInitialization {
  const _SlowInitialization(this.duration);

  final Duration duration;

  @override
  Map<String, InitializationStep> get steps => {
    'slow step': (_) => Future<void>.delayed(duration),
  };
}

/// A slow step, then a step that records whether it ran.
class _TwoStepInitialization with AppFuseInitialization {
  int slowRuns = 0;
  bool secondRan = false;

  @override
  Map<String, InitializationStep> get steps => {
    'slow step': (_) async {
      slowRuns++;
      await Future<void>.delayed(const Duration(seconds: 2));
    },
    'second step': (_) async => secondRan = true,
  };
}

class _FailingInitialization with AppFuseInitialization {
  @override
  Map<String, InitializationStep> get steps => {
    'open database': (_) async => throw StateError('disk full'),
  };
}

class _ShadowingInitialization with AppFuseInitialization {
  bool ran = false;

  @override
  Map<String, InitializationStep> get steps => {
    'fetch meta data': (_) async => ran = true,
  };
}

/// Fails its step when [fails] is `true`, and counts [dispose] calls.
class _FlakyInitialization with AppFuseInitialization {
  _FlakyInitialization({required this.fails});

  final bool fails;
  int disposals = 0;

  @override
  Map<String, InitializationStep> get steps => {
    'connect': (_) async {
      if (fails) throw StateError('offline');
    },
  };

  @override
  void dispose() => disposals++;
}

void main() {
  setUpAppFuseMocks();

  group('initTimeout', () {
    testWidgets('waits for slow initialization by default', (tester) async {
      await tester.pumpWidget(
        AppFuseScope(
          init: () => const _SlowInitialization(Duration(minutes: 10)),
          errorBuilder: (error, _, _) =>
              Text('$error', textDirection: TextDirection.ltr),
          app: const Text('app', textDirection: TextDirection.ltr),
        ),
      );
      await tester.pump(const Duration(minutes: 10));
      await tester.pumpAndSettle();
      expect(find.text('app'), findsOneWidget);
    });

    testWidgets('no later step starts after the timeout', (tester) async {
      final init = _TwoStepInitialization();
      final errors = <Object>[];
      await tester.pumpWidget(
        AppFuseScope(
          init: () => init,
          initTimeout: const Duration(seconds: 1),
          onError: (error, _) => errors.add(error),
          app: const SizedBox.expand(),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(errors.single, isA<TimeoutException>());
      expect(init.secondRan, isFalse);
    });
  });

  group('initialization errors', () {
    testWidgets(
      'a failed step reports one typed error and does not throw into the zone',
      (tester) async {
        final errors = <Object>[];
        Object? shownError;
        await tester.pumpWidget(
          AppFuseScope(
            init: _FailingInitialization.new,
            onError: (error, _) => errors.add(error),
            errorBuilder: (error, _, _) {
              shownError = error;
              return const SizedBox.shrink();
            },
            app: const SizedBox.expand(),
          ),
        );
        await tester.pumpAndSettle();

        expect(errors, hasLength(1));
        expect(shownError, isA<AppFuseInitException>());
        final exception = shownError! as AppFuseInitException;
        expect(exception.step, 'open database');
        expect(exception.error, isA<StateError>());
      },
    );

    testWidgets('the default error UI goes through ErrorWidget.builder', (
      tester,
    ) async {
      final builder = ErrorWidget.builder;
      ErrorWidget.builder = (details) => const Text('hidden error');

      await tester.pumpWidget(
        AppFuseScope(
          init: _FailingInitialization.new,
          onError: (_, _) {},
          app: const SizedBox.expand(),
        ),
      );
      await tester.pumpAndSettle();

      final shown = find.text('hidden error').evaluate().length;
      // The test binding checks that the builder is restored before tear-down.
      ErrorWidget.builder = builder;
      expect(shown, 1);
    });

    testWidgets('does not replace global error handlers', (tester) async {
      final platformOnError = PlatformDispatcher.instance.onError;
      final flutterOnError = FlutterError.onError;
      await tester.pumpWidget(const AppFuseScope(app: SizedBox.expand()));
      await tester.pumpAndSettle();

      expect(PlatformDispatcher.instance.onError, same(platformOnError));
      expect(FlutterError.onError, same(flutterOnError));
    });
  });

  testWidgets('an app step with a built-in name does not replace it', (
    tester,
  ) async {
    final init = _ShadowingInitialization();
    final context = await pumpApp(tester, init: () => init);

    expect(init.ran, isTrue);
    expect(context.fuse.state.metaData.appName, 'appfuse_test');
  });

  testWidgets('initOf returns the init instance', (tester) async {
    final init = _ShadowingInitialization();
    final context = await pumpApp(tester, init: () => init);
    expect(AppFuseScope.initOf<_ShadowingInitialization>(context), same(init));
  });

  testWidgets('initOf throws a StateError for another type or without init', (
    tester,
  ) async {
    final withoutInit = await pumpApp(tester);
    expect(
      () => AppFuseScope.initOf<_ShadowingInitialization>(withoutInit),
      throwsStateError,
    );

    await tester.pumpWidget(const SizedBox());
    final withInit = await pumpApp(tester, init: _ShadowingInitialization.new);
    expect(
      () => AppFuseScope.initOf<_FailingInitialization>(withInit),
      throwsStateError,
    );
  });

  group('retry', () {
    /// Pumps a scope whose first init object fails and later ones succeed.
    Future<({List<_FlakyInitialization> created, VoidCallback retry})>
    pumpFlaky(
      WidgetTester tester, {
      IAppFuseStorage? storage,
      required ValueSetter<BuildContext> onApp,
    }) async {
      final created = <_FlakyInitialization>[];
      late VoidCallback retry;
      await tester.pumpWidget(
        AppFuseScope(
          storage: storage,
          init: () {
            final init = _FlakyInitialization(fails: created.isEmpty);
            created.add(init);
            return init;
          },
          onError: (_, _) {},
          errorBuilder: (error, _, onRetry) {
            retry = onRetry;
            return const Text('failed', textDirection: TextDirection.ltr);
          },
          app: Builder(
            builder: (context) {
              onApp(context);
              return const Text('app', textDirection: TextDirection.ltr);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('failed'), findsOneWidget);
      return (created: created, retry: () => retry());
    }

    testWidgets('shows the app with a new init object', (tester) async {
      late BuildContext appContext;
      final (:created, :retry) = await pumpFlaky(
        tester,
        onApp: (context) => appContext = context,
      );
      expect(created.single.disposals, 0);

      retry();
      await tester.pumpAndSettle();

      expect(find.text('app'), findsOneWidget);
      expect(created, hasLength(2));
      expect(created.first.disposals, 1);
      expect(created.last.disposals, 0);
      expect(
        AppFuseScope.initOf<_FlakyInitialization>(appContext),
        created.last,
      );
      expect(AppFuseScope.read(appContext).phase, isA<AppFuseReady>());
    });

    testWidgets('runs the built-in steps again', (tester) async {
      late BuildContext appContext;
      final storage = MemoryStorage(
        values: {'appfuse.settings.custom': '{"visits":3}'},
      );
      final (:created, :retry) = await pumpFlaky(
        tester,
        storage: storage,
        onApp: (context) => appContext = context,
      );

      retry();
      await tester.pumpAndSettle();

      final state = AppFuseScope.read(appContext);
      expect(state.metaData.appName, 'appfuse_test');
      expect(state.metaData.isFirstLaunch, isTrue);
      expect(state.customSettings, {'visits': 3});
    });

    testWidgets('a second failure shows the error again', (tester) async {
      final errors = <Object>[];
      var attempts = 0;
      late VoidCallback retry;
      await tester.pumpWidget(
        AppFuseScope(
          init: () => _FlakyInitialization(fails: ++attempts < 3),
          onError: (error, _) => errors.add(error),
          errorBuilder: (error, _, onRetry) {
            retry = onRetry;
            return const Text('failed', textDirection: TextDirection.ltr);
          },
          app: const Text('app', textDirection: TextDirection.ltr),
        ),
      );
      await tester.pumpAndSettle();

      retry();
      await tester.pumpAndSettle();
      expect(find.text('failed'), findsOneWidget);
      expect(errors, hasLength(2));

      retry();
      await tester.pumpAndSettle();
      expect(find.text('app'), findsOneWidget);
      expect(errors, hasLength(2));
    });

    testWidgets('fails with a StateError outside the error state', (
      tester,
    ) async {
      final context = await pumpApp(tester);
      await expectLater(context.fuse.retry(), throwsStateError);
      expect(context.fuse.state.phase, isA<AppFuseReady>());
    });
  });

  testWidgets('dispose during initialization reports nothing', (tester) async {
    final init = _TwoStepInitialization();
    final errors = <Object>[];
    await tester.pumpWidget(
      AppFuseScope(
        init: () => init,
        onError: (error, _) => errors.add(error),
        app: const SizedBox.expand(),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));

    expect(tester.takeException(), isNull);
    expect(errors, isEmpty);
    expect(init.secondRan, isFalse);
  });

  group('dispose', () {
    testWidgets('disposing the scope disposes the init object once', (
      tester,
    ) async {
      final created = <RecordingInitialization>[];
      await pumpApp(tester, init: recordingFactory(created));
      expect(created.single.disposals, 0);

      await tester.pumpWidget(const SizedBox());
      expect(created.single.disposals, 1);
    });

    testWidgets('a failing dispose goes to onError and not into the zone', (
      tester,
    ) async {
      final errors = <Object>[];
      await pumpApp(
        tester,
        init: recordingFactory([], disposeError: StateError('close failed')),
        onError: (error, _) => errors.add(error),
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(errors, [isA<StateError>()]);
    });
  });
}
