part of 'controller.dart';

const _kFirstLaunchTimeStamp = 'appfuse.settings.firstLaunch';

extension $Initialization on AppFuseController {
  /// Kicks off the entire application initialization process.
  Future<void> _initialiseApp() async {
    try {
      setState(state.copyWith(
        isInitializing: true,
        supportedLocales: supportedLocales,
        localizationsDelegates: _localizationsDelegates,
      ));
      final initData = _initData;

      final dependencies = await _initialize(
        initData: initData,
        configs: _configs,
        onProgress: onProgress,
        onError: onError,
      ).timeout(initTimeout);

      setState(state.copyWith(
        isInitializing: false,
        dependencies: dependencies,
      ));
    } on Object catch (error, stackTrace) {
      _onError(error, stackTrace);
      rethrow;
    }
  }

  /// Initializes the app and prepares it for use.
  Future<AppFuseInitialization> _initialize({
    required AppFuseInitialization initData,
    required List<BaseConfig> configs,
    void Function(String message)? onProgress,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) =>
      _$currentInitialization ??= Future<AppFuseInitialization>(() async {
        late final WidgetsBinding binding;
        final stopwatch = Stopwatch()..start();

        try {
          binding = WidgetsFlutterBinding.ensureInitialized()..deferFirstFrame();
          await _catchExceptions();

          final initializationSteps = <String, InitializationStep>{
            if (_storage == null)
              'Initialize Fuse Storage': (_) async {
                _storage = await $SharedPreferencesStorage.getInstance();
              },
            'Fetch Meta Data': (_) async {
              await _fetchAppMetaData();
            },
            'Check Permissions': (_) async {
              await _checkPermissions();
            },
            'Fetch Saved Settings': (_) async {
              await _fetchSavedSettings();
            },
            if (configs.isNotEmpty)
              'Fetch and Activate Environment Config': (_) async {
                await _fetchSavedConfig(configs);
              },
          }..addAll(initData.initialisationSteps);

          _onProgress('Initialization started');
          final totalSteps = initializationSteps.length;
          var currentStep = 0;
          for (final step in initializationSteps.entries) {
            try {
              currentStep++;
              final percent = (currentStep * 100 ~/ totalSteps).clamp(0, 100);
              _onProgress('Initialization | $currentStep/$totalSteps ($percent%) | "${step.key}"');
              await step.value(initData);
            } on Object catch (error, stackTrace) {
              _onError('Initialization failed at step "${step.key}": $error', stackTrace);
              Error.throwWithStackTrace('Initialization failed at step "${step.key}": $error', stackTrace);
            }
          }

          return initData;
        } on Object catch (error, stackTrace) {
          _onError('Failed to initialize app: $error', stackTrace);
          rethrow;
        } finally {
          stopwatch.stop();
          _onProgress('Initialization finished in ${stopwatch.elapsed}');

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
    final customSettings = await _storage!.getValue<Map<String, Object?>>(_kCustomSettings);
    await changeLocale();
    await changeThemeMode();

    setState(state.copyWith(
      customSettings: customSettings,
      lightTheme: _themes[Brightness.light] ?? ThemeData.light(),
      darkTheme: _themes[Brightness.dark],
    ));
  }

  /// Gathers and stores application and device metadata.
  Future<void> _fetchAppMetaData() async {
    final info = await PackageInfo.fromPlatform();

    final appFirstLaunchTimestamp = await _storage!.getValue<DateTime>(_kFirstLaunchTimeStamp);
    final isFirstLaunch = appFirstLaunchTimestamp == null;
    if (isFirstLaunch) _storage!.setValue<DateTime>(_kFirstLaunchTimeStamp, DateTime.now()).ignore();

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

  /// Reports a progress message to the state and the onProgress callback.
  void _onProgress(String message) {
    setState(state.copyWith(initProgressMessage: message));
    onProgress?.call(message);
  }

  /// Updates the state with error information and calls the onError callback.
  void _onError(Object error, StackTrace stackTrace) {
    setState(state.copyWith(
      isInitializing: false,
      error: error,
      stackTrace: stackTrace,
    ));
    onError?.call(error, stackTrace);
  }

  /// Sets up global error handlers to catch and log uncaught exceptions.
  Future<void> _catchExceptions() async {
    try {
      PlatformDispatcher.instance.onError = (error, stackTrace) {
        log('$error', error: error, stackTrace: stackTrace, name: 'ROOT ERROR\r\n${Error.safeToString(error)}');
        return true;
      };

      final sourceFlutterError = FlutterError.onError;
      FlutterError.onError = (final details) {
        log(
          '${details.exception}',
          error: details.exception,
          stackTrace: details.stack ?? StackTrace.current,
          name: 'FLUTTER ERROR\r\n$details',
        );
        sourceFlutterError?.call(details);
      };
    } on Object catch (error, stackTrace) {
      log('$error', error: error, stackTrace: stackTrace);
    }
  }
}
