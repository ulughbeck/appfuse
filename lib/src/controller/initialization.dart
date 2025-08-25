part of 'controller.dart';

const _kFirstLaunchTimeStamp = 'appfuse.settings.firstLaunch';

extension $Initialization on AppFuseController {
  /// Kicks off the entire application initialization process.
  Future<void> _initialiseApp() async {
    try {
      setState(state.startProcessing());
      setState(state.copyWith(
        supportedLocales: supportedLocales,
        localizationsDelegates: _localizationsDelegates,
      ));

      final dependencies = await _initialize(
        setup: _setupSteps,
        configs: _configs,
      ).timeout(initTimeout);

      setState(state.copyWith(
        dependencies: dependencies,
      ));
    } on Object catch (error, stackTrace) {
      _onError(error, stackTrace);
      rethrow;
    } finally {
      setState(state.stopProcessing());
    }
  }

  /// Initializes the app and prepares it for use.
  Future<AppFuseSetup> _initialize({
    required AppFuseSetup setup,
    required List<BaseConfig> configs,
  }) =>
      _$currentInitialization ??= Future<AppFuseSetup>(() async {
        late final WidgetsBinding binding;
        final stopwatch = Stopwatch()..start();

        try {
          binding = WidgetsFlutterBinding.ensureInitialized()..deferFirstFrame();
          await _catchExceptions();

          final initializationSteps = <String, InitializationStep>{
            if (_fuseStorage == null)
              'initialize FuseStorage': (_, __) async {
                _fuseStorage = await FuseShPrStorage.init();
              },
            'fetch meta data': (_, __) async {
              await _fetchAppMetaData();
            },
            'fetch and activate environment config': (_, __) async {
              if (configs.isNotEmpty) {
                await _fetchSavedConfig(configs);
              } else {
                setState(state.copyWith(config: EmptyConfig()));
              }
            },
            'fetch saved settings': (_, __) async {
              await _fetchSavedSettings();
            },
          }..addAll(setup.steps);

          _onProgress('initialization started');
          final totalSteps = initializationSteps.length;
          var currentStep = 0;
          for (final step in initializationSteps.entries) {
            try {
              currentStep++;
              final percent = (currentStep * 100 ~/ totalSteps).clamp(0, 100);
              _onProgress('initialization | $currentStep/$totalSteps ($percent%) | "${step.key}"');
              await step.value(state.config, setup);
            } on Object catch (error, stackTrace) {
              _onError('initialization failed at step "${step.key}": $error', stackTrace);
              Error.throwWithStackTrace('initialization failed at step "${step.key}": $error', stackTrace);
            }
          }

          return setup;
        } on Object catch (error, stackTrace) {
          _onError('failed to initialize app: $error', stackTrace);
          rethrow;
        } finally {
          stopwatch.stop();
          _onProgress('initialization finished in ${stopwatch.elapsed}');

          binding.addPostFrameCallback((_) {
            // Closes splash screen, and show the app layout.
            binding.allowFirstFrame();
            //final context = binding.renderViewElement;
          });
          _$currentInitialization = null;
        }
      });

  /// Loads saved user preferences like theme, locale, and custom settings from storage.
  Future<void> _fetchSavedSettings() async {
    final customSettings = await _fuseStorage!.getValue<Map<String, Object?>>(_kCustomSettings);
    await changeLocale();
    await changeThemeMode();

    setState(state.copyWith(
      customSettings: customSettings,
      lightTheme: _themes[Brightness.light] ?? ThemeData.light(),
      darkTheme: _themes[Brightness.dark],
    ));
  }

  /// Loads and activates the previously saved or default configuration.
  Future<void> _fetchSavedConfig(List<BaseConfig> configs) async {
    final name = await _fuseStorage!.getValue<String>(_kConfigSelected);
    final iterator = configs.where((config) => config.name == name);
    final enabledConfig = iterator.isNotEmpty ? iterator.first : configs.first;
    final configLoaded = await enabledConfig.init();
    setState(state.copyWith(configs: configs, config: configLoaded));
  }

  /// Gathers and stores application and device metadata.
  Future<void> _fetchAppMetaData() async {
    final info = await PackageInfo.fromPlatform();

    final appFirstLaunchTimestamp = await _fuseStorage!.getValue<DateTime>(_kFirstLaunchTimeStamp);
    final isFirstLaunch = appFirstLaunchTimestamp == null;
    if (isFirstLaunch) _fuseStorage!.setValue<DateTime>(_kFirstLaunchTimeStamp, DateTime.now()).ignore();

    final metaData = AppMetaData(
      isWeb: platform.js,
      isRelease: platform.buildMode.release,
      isFirstLaunch: isFirstLaunch,
      appVersion: info.version,
      appPackageName: info.packageName,
      appBuildNumber: info.buildNumber,
      appName: info.appName,
      operatingSystem: platform.operatingSystem.name,
      processorsCount: platform.numberOfProcessors,
      systemLocale: platform.locale,
      deviceVersion: platform.version,
      appFirstLaunchTimestamp: appFirstLaunchTimestamp ?? DateTime.now(),
      appLaunchedTimestamp: DateTime.now(),
    );

    setState(state.copyWith(metaData: metaData));
  }

  /// Sets up global error handlers to catch and log uncaught exceptions.
  Future<void> _catchExceptions() async {
    try {
      PlatformDispatcher.instance.onError = (error, stackTrace) {
        developer.log('$error',
            error: error, stackTrace: stackTrace, name: 'ROOT ERROR\r\n${Error.safeToString(error)}');
        return true;
      };

      final sourceFlutterError = FlutterError.onError;
      FlutterError.onError = (final details) {
        developer.log(
          '${details.exception}',
          error: details.exception,
          stackTrace: details.stack ?? StackTrace.current,
          name: 'FLUTTER ERROR\r\n$details',
        );
        sourceFlutterError?.call(details);
      };
    } on Object catch (error, stackTrace) {
      developer.log('$error', error: error, stackTrace: stackTrace);
    }
  }
}
