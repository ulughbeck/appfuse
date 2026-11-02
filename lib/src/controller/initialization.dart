part of 'controller.dart';

mixin _InitializationMixin<T extends AppFuseInitialization> on _AppFuseBase<T> {
  /// The setup object that already got [AppFuseInitialization.dispose].
  AppFuseInitialization? _releasedSetup;

  /// The first launch is known only on the first run, because a run saves the launch date.
  bool? _isFirstLaunch;

  /// Creates the setup object, then runs the built-in steps and its steps.
  Future<void> _initialize() => _runInitialization(_startupSteps);

  List<MapEntry<String, InitializationStep>> _startupSteps() => [
    ..._builtInSteps.entries,
    ..._createSetupSteps(),
  ];

  /// Runs the startup again after it failed, with a new setup object.
  ///
  /// The old setup object gets [AppFuseInitialization.dispose]. The built-in
  /// steps and the steps of the new object run again. A new failure sets [AppFuseFailed] again
  /// and goes to [onError]. The returned future completes after the run, also
  /// after a failure.
  ///
  /// Runs after earlier writes. Fails with a [StateError] when the phase is not [AppFuseFailed].
  Future<void> retry() => _serial(() async {
    if (state.phase is! AppFuseFailed) {
      throw StateError('Cannot retry while AppFuse has no error');
    }
    _setState(state.copyWith(phase: const AppFuseStarting()));
    await _releaseSetup(_report);
    if (_disposed) return;
    await _runInitialization(_startupSteps);
  });

  /// Creates the setup object and returns its steps. Without a setup factory there are none.
  List<MapEntry<String, InitializationStep>> _createSetupSteps() {
    final setup = _createSetup?.call();
    _setup = setup;
    return [...?setup?.steps.entries];
  }

  /// Runs the steps that [build] returns, with progress and [initTimeout].
  ///
  /// [build] runs inside the error handling. Sets the phase to [AppFuseReady],
  /// or to [AppFuseFailed] after a failure, which is reported once. Returns the
  /// new phase.
  Future<AppFusePhase> _runInitialization(
    List<MapEntry<String, InitializationStep>> Function() build,
  ) async {
    var timedOut = false;
    try {
      final run = _runSteps(build(), () => timedOut);
      final timeout = initTimeout;
      await (timeout == null
          ? run
          : run.timeout(
              timeout,
              onTimeout: () {
                timedOut = true;
                throw TimeoutException('initialization timed out', timeout);
              },
            ));
      return _finish(const AppFuseReady());
    } on Object catch (error, stackTrace) {
      final phase = _finish(AppFuseFailed(error, stackTrace));
      _report(error, stackTrace);
      return phase;
    }
  }

  AppFusePhase _finish(AppFusePhase phase) {
    _setState(state.copyWith(phase: phase));
    return phase;
  }

  /// Calls [AppFuseInitialization.dispose] once on the current setup object.
  ///
  /// A failure goes to [onFailure]. It never throws.
  Future<void> _releaseSetup(
    void Function(Object error, StackTrace stackTrace)? onFailure,
  ) async {
    final setup = _setup;
    if (setup == null || identical(setup, _releasedSetup)) return;
    _releasedSetup = setup;
    try {
      await setup.dispose();
    } on Object catch (error, stackTrace) {
      onFailure?.call(error, stackTrace);
    }
  }

  Map<String, InitializationStep> get _builtInSteps => {
    if (_storage == null)
      'initialize AppFuseStorage': (_) async {
        _storage = await AppFuseShPrStorage.init();
      },
    'fetch meta data': (_) => _fetchAppMetaData(),
    'fetch and activate environment config': (_) => _fetchSavedConfig(),
    'fetch saved settings': (_) => _fetchSavedSettings(),
  };

  /// Runs the steps in order.
  ///
  /// A timeout does not stop the running step, so no later step starts once
  /// [isCancelled] returns `true` or the controller is disposed.
  Future<void> _runSteps(
    List<MapEntry<String, InitializationStep>> steps,
    bool Function() isCancelled,
  ) async {
    final stopwatch = Stopwatch()..start();

    _setState(state.copyWith(phase: const AppFuseStarting()));
    onProgress?.call('initialization started');
    for (final (index, MapEntry(key: name, value: step)) in steps.indexed) {
      if (isCancelled() || _disposed) return;
      final current = index + 1;
      final total = steps.length;
      final percent = current * 100 ~/ total;
      _setState(
        state.copyWith(
          phase: AppFuseStarting(
            AppFuseProgress(current: current, total: total, step: name),
          ),
        ),
      );
      onProgress?.call(
        'initialization | $current/$total ($percent%) | "$name"',
      );
      final task = developer.TimelineTask()..start('AppFuse: $name');
      try {
        await step(state);
      } on Object catch (error, stackTrace) {
        Error.throwWithStackTrace(
          AppFuseInitException(name, error),
          stackTrace,
        );
      } finally {
        task.finish();
      }
    }
    if (isCancelled() || _disposed) return;
    onProgress?.call('initialization finished in ${stopwatch.elapsed}');
  }

  /// Restores the custom settings, locale, and theme mode. A bad value falls back to its default.
  Future<void> _fetchSavedSettings() async {
    final customSettings = await _restore(
      AppFuseKeys.customSettings,
      _AppFuseBase._decodeSettings,
    );
    final userLocale = await _restore(AppFuseKeys.locale, _parseLocale);
    final themeMode = await _restore(
      AppFuseKeys.themeMode,
      (name) =>
          ThemeMode.values.asNameMap()[name] ??
          (throw FormatException('unknown theme mode', name)),
    );

    _themeChoice = themeMode ?? ThemeMode.system;
    _setState(
      _withEffectiveLocale(
        state.copyWith(
          customSettings: customSettings,
          userLocale: () => userLocale,
          themeMode: state.resolveThemeMode(_themeChoice),
        ),
      ),
    );
  }

  /// Loads and activates the previously saved or default configuration.
  Future<void> _fetchSavedConfig() async {
    final configs = state.configs;
    if (configs.isEmpty) return;
    final name = await _restore(AppFuseKeys.config, (name) => name);
    final config =
        configs.where((config) => config.name == name).firstOrNull ??
        configs.first;
    _setState(state.copyWith(config: await config.init()));
  }

  /// Gathers and stores application and device metadata.
  ///
  /// The app works without it, so a failure goes to [onError] and the app
  /// info stays empty. On web the app info is a network request, so it has a
  /// time limit.
  Future<void> _fetchAppMetaData() async {
    PackageInfo? info;
    try {
      info = await PackageInfo.fromPlatform().timeout(_kAppInfoTimeout);
    } on Object catch (error, stackTrace) {
      _report(error, stackTrace);
    }

    final appFirstLaunchTimestamp = await _restore(
      AppFuseKeys.firstLaunch,
      DateTime.parse,
    );
    final isFirstLaunch = _isFirstLaunch ??= appFirstLaunchTimestamp == null;
    final now = DateTime.now();
    if (appFirstLaunchTimestamp == null) {
      try {
        await _store.write(AppFuseKeys.firstLaunch, now.toIso8601String());
      } on Object catch (error, stackTrace) {
        // The app works without it, so this does not stop startup.
        _report(error, stackTrace);
      }
    }

    final metaData = AppMetaData(
      isWeb: kIsWeb,
      isRelease: kReleaseMode,
      isFirstLaunch: isFirstLaunch,
      appVersion: info?.version ?? '',
      appPackageName: info?.packageName ?? '',
      appBuildNumber: info?.buildNumber ?? '',
      appName: info?.appName ?? '',
      operatingSystem: defaultTargetPlatform.name,
      systemLocale: WidgetsBinding.instance.platformDispatcher.locale
          .toLanguageTag(),
      appFirstLaunchTimestamp: appFirstLaunchTimestamp ?? now,
      appLaunchedTimestamp: now,
    );

    _setState(state.copyWith(metaData: metaData));
  }
}
