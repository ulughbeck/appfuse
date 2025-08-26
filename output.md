---
FILE: lib/appfuse.dart
---
export 'package:permission_handler/permission_handler.dart';

export 'src/controller/controller.dart';
export 'src/controller/storage.dart';
export 'src/models/models.dart';
export 'src/widgets/widgets.dart';

---
FILE: lib/src/models/config/environment_config.dart
---
import 'dart:ui';

import 'base_config.dart';

/// A configuration that loads its values from compile-time environment variables passed via the `--dart-define` flag.
abstract class EnvironmentConfig extends BaseConfig {
  const EnvironmentConfig({
    super.name,
    super.color = const Color(0xFFCCCCCC),
    super.showBanner = false,
  });

  @override
  Future<EnvironmentConfig> init() async => this;

  @override
  T getConfigValue<T extends Object?>(String key) {
    if (T == String) return getString(key) as T;
    if (T == int) return getInt(key) as T;
    if (T == bool) return getBool(key) as T;
    if (T == double) return getDouble(key) as T;
    throw Exception(
      "Type $T is not supported by EnvironmentConfig. Only String, int, bool, and double are allowed.",
    );
  }

  bool getBool(String key, {bool defaultValue = false}) => bool.fromEnvironment(key, defaultValue: defaultValue);
  String getString(String key, {String defaultValue = ''}) => String.fromEnvironment(key, defaultValue: defaultValue);
  int getInt(String key, {int defaultValue = 0}) => int.fromEnvironment(key, defaultValue: defaultValue);
  double getDouble(String key, {double defaultValue = 0.0}) {
    final valueStr = String.fromEnvironment(key);
    return double.tryParse(valueStr) ?? defaultValue;
  }
}

---
FILE: lib/src/models/config/json_config.dart
---
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import 'base_config.dart';

// mixin for common JSON logic
mixin _JsonConfigMixin on BaseConfig {
  // The late final Map must be provided by the class using the mixin
  late final Map<String, Object?> _config;

  @override
  T getConfigValue<T extends Object?>(String key) {
    final value = _config[key];

    if (value is T) return value;
    if (value != null) {
      final valString = value.toString();
      if (T == String) return valString as T;
      if (T == int) {
        final parsed = int.tryParse(valString);
        if (parsed != null) return parsed as T;
        throw Exception("Failed to parse value '$valString' as int for key '$key'.");
      }
      if (T == double) {
        final parsed = double.tryParse(valString);
        if (parsed != null) return parsed as T;
        throw Exception("Failed to parse value '$valString' as double for key '$key'.");
      }
      if (T == bool) {
        return switch (valString.toLowerCase()) {
          'true' => true,
          'false' => false,
          _ => throw Exception("Config key '$key' has type ${value.runtimeType} but type $T was requested.")
        } as T;
      }
    }
    if (value == null) throw Exception("Config key '$key' not found.");
    throw Exception("Config key '$key' has type ${value.runtimeType} but type $T was requested.");
  }

  bool getBool(String key) => getConfigValue<bool>(key);
  String getString(String key) => getConfigValue<String>(key);
  int getInt(String key) => getConfigValue<int>(key);
  double getDouble(String key) => getConfigValue<double>(key);
}

/// A configuration that loads its values from a local JSON asset file.
abstract class JsonAssetConfig extends BaseConfig with _JsonConfigMixin {
  JsonAssetConfig({
    required String path,
    required super.name,
    super.color = const Color(0xFFCCCCCC),
    super.showBanner = false,
  }) : _path = path;

  final String _path;

  @override
  Future<JsonAssetConfig> init() async {
    _config = await _loadFromPath();
    return this;
  }

  Future<Map<String, Object?>> _loadFromPath() async {
    final result = await rootBundle.loadString(_path);
    final configJson = jsonDecode(result) as Map<String, Object?>;
    if (configJson.isEmpty) throw Exception("Config was empty");
    return configJson;
  }
}

/// The HTTP method to use for the network request.
enum HttpMethod { get, post }

/// A configuration that loads its values from a remote JSON endpoint.
abstract class JsonRemoteConfig extends BaseConfig with _JsonConfigMixin {
  JsonRemoteConfig({
    required String uri,
    required super.name,
    super.color = const Color(0xFFCCCCCC),
    super.showBanner = false,
    HttpMethod httpMethod = HttpMethod.get,
    Map<String, String>? headers,
  })  : _uri = uri,
        _httpMethod = httpMethod,
        _headers = headers;

  final String _uri;
  final HttpMethod _httpMethod;
  final Map<String, String>? _headers;

  @override
  Future<JsonRemoteConfig> init() async {
    _config = await _fetchFromNetwork();
    return this;
  }

  Future<Map<String, Object?>> _fetchFromNetwork() async {
    final uri = Uri.parse(_uri);
    final response = await (switch (_httpMethod) {
      HttpMethod.get => http.get(uri, headers: _headers),
      HttpMethod.post => http.post(uri, headers: _headers),
    });

    final configJson = jsonDecode(response.body) as Map<String, Object?>;
    if (configJson.isEmpty) throw Exception("Config was empty");
    return configJson;
  }
}

---
FILE: lib/src/models/config/base_config.dart
---
import 'package:flutter/widgets.dart';

/// An abstract base class for all environment configurations.
abstract class BaseConfig {
  const BaseConfig({
    this.name = 'BASE',
    this.color = const Color(0xFFCCCCCC),
    this.showBanner = false,
  });

  /// The unique name of the configuration (e.g., "PROD", "TEST").
  final String name;

  /// The color used for the debug banner.
  final Color color;

  /// Whether to display the debug banner in the corner of the app.
  final bool showBanner;

  /// Asynchronously initializes the configuration, loading any required data.
  Future<BaseConfig> init();

  /// Retrieves a raw configuration value for a given [key].
  T getConfigValue<T extends Object?>(String key);
}

class EmptyConfig extends BaseConfig {
  const EmptyConfig() : super(name: 'NONE', showBanner: false);

  @override
  Future<BaseConfig> init() async => this;

  @override
  T getConfigValue<T extends Object?>(String key) => throw Exception(
        "Configuration Error: You are trying to access the config key '$key', but no environment configurations were provided to AppFuseScope. Please provide a non-empty list to the `configs` parameter.",
      );
}

---
FILE: lib/src/models/meta_data.dart
---
import 'package:flutter/foundation.dart';

@immutable
class AppMetaData {
  const AppMetaData({
    required this.isWeb,
    required this.isRelease,
    required this.isFirstLaunch,
    required this.appVersion,
    required this.appBuildNumber,
    required this.appPackageName,
    required this.appName,
    required this.operatingSystem,
    required this.processorsCount,
    required this.systemLocale,
    required this.deviceVersion,
    required this.appLaunchedTimestamp,
    required this.appFirstLaunchTimestamp,
  });

  factory AppMetaData.none() => AppMetaData(
        isWeb: kIsWeb,
        isRelease: !kDebugMode,
        isFirstLaunch: true,
        appVersion: '',
        appBuildNumber: '',
        appPackageName: '',
        appName: '',
        operatingSystem: '',
        processorsCount: 0,
        systemLocale: '',
        deviceVersion: '',
        appLaunchedTimestamp: DateTime.now(),
        appFirstLaunchTimestamp: DateTime.now(),
      );

  /// Is web platform
  final bool isWeb;

  /// Is release build
  final bool isRelease;

  /// Is first run
  final bool isFirstLaunch;

  /// App version
  final String appVersion;

  /// App build timestamp
  final String appBuildNumber;

  /// Package name
  final String appPackageName;

  /// App name
  final String appName;

  /// Operating system
  final String operatingSystem;

  /// Processors count
  final int processorsCount;

  /// Locale
  final String systemLocale;

  /// Device representation
  final String deviceVersion;

  /// App launched timestamp
  final DateTime appLaunchedTimestamp;

  /// App first launched timestamp
  final DateTime appFirstLaunchTimestamp;

  /// Convert to headers
  Map<String, String> toHeaders() => <String, String>{
        'X-Meta-Is-Web': isWeb ? 'true' : 'false',
        'X-Meta-Is-Release': isRelease ? 'true' : 'false',
        'X-Meta-App-Version': appVersion,
        'X-Meta-App-Build-Number': appBuildNumber,
        'X-Meta-App-Package-Name': appPackageName,
        'X-Meta-App-Name': appName,
        'X-Meta-Operating-System': operatingSystem,
        'X-Meta-Processors-Count': processorsCount.toString(),
        'X-Meta-Device-Locale': systemLocale,
        'X-Meta-Device-Version': deviceVersion,
        'X-Meta-App-First-Launched-Timestamp': appFirstLaunchTimestamp.millisecondsSinceEpoch.toString(),
        'X-Meta-App-Launched-Timestamp': appLaunchedTimestamp.millisecondsSinceEpoch.toString(),
      };

  @override
  bool operator ==(covariant AppMetaData other) {
    if (identical(this, other)) return true;

    return other.isWeb == isWeb &&
        other.isRelease == isRelease &&
        other.isFirstLaunch == isFirstLaunch &&
        other.appVersion == appVersion &&
        other.appBuildNumber == appBuildNumber &&
        other.appPackageName == appPackageName &&
        other.appName == appName &&
        other.operatingSystem == operatingSystem &&
        other.processorsCount == processorsCount &&
        other.systemLocale == systemLocale &&
        other.deviceVersion == deviceVersion &&
        other.appLaunchedTimestamp == appLaunchedTimestamp &&
        other.appFirstLaunchTimestamp == appFirstLaunchTimestamp;
  }

  @override
  int get hashCode => Object.hash(
        isWeb,
        isRelease,
        isFirstLaunch,
        appVersion,
        appBuildNumber,
        appPackageName,
        appName,
        operatingSystem,
        processorsCount,
        systemLocale,
        deviceVersion,
        appLaunchedTimestamp,
        appFirstLaunchTimestamp,
      );
}

---
FILE: lib/src/models/setup.dart
---
import 'dart:async';

import 'package:appfuse/appfuse.dart';

/// A type definition for a single step in the app's initialization process.
typedef InitializationStep = Future<void> Function(AppFuseState state);

/// A mixin that defines the contract for providing app initialization steps.
///
/// Classes using this mixin must implement [steps] to define their async setup logic.
mixin AppFuseSetup {
  Map<String, InitializationStep> get steps;
}

/// A default, empty implementation of [AppFuseSetup]
class EmptyInitialization with AppFuseSetup {
  @override
  Map<String, InitializationStep> get steps => {};
}

---
FILE: lib/src/models/models.dart
---
export 'config/base_config.dart';
export 'config/environment_config.dart';
export 'config/json_config.dart';
export 'meta_data.dart';
export 'setup.dart';

---
FILE: lib/src/controller/initialization.dart
---
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
              'initialize FuseStorage': (_) async {
                _fuseStorage = await FuseShPrStorage.init();
              },
            'fetch meta data': (_) async {
              await _fetchAppMetaData();
            },
            'fetch and activate environment config': (_) async {
              if (configs.isNotEmpty) {
                await _fetchSavedConfig(configs);
              } else {
                setState(state.copyWith(config: EmptyConfig()));
              }
            },
            'fetch saved settings': (_) async {
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
              await step.value(state);
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

---
FILE: lib/src/controller/storage.dart
---
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// An interface for a simple key-value storage system.
abstract interface class IFuseStorage {
  Future<bool> setValue<T>(String key, T value);
  Future<T?> getValue<T>(String key);
}

/// A default storage implementation using the `shared_preferences` package.
class FuseShPrStorage implements IFuseStorage {
  FuseShPrStorage._();

  static late SharedPreferences _prefs;

  static Future<FuseShPrStorage> init() async {
    _prefs = await SharedPreferences.getInstance();
    return FuseShPrStorage._();
  }

  @override
  Future<T?> getValue<T>(String key) async {
    final value = _prefs.get(key);

    if (value == null) return null;
    return switch (value) {
      bool b when T == bool => b as T,
      int i when T == int => i as T,
      double d when T == double => d as T,
      String s when T == String => s as T,
      String dt when T == DateTime => DateTime.parse(dt) as T,
      String m when T == Map => jsonDecode(m) as T,
      List<String> list when T == (List<String>) => list as T,
      _ => throw UnsupportedError('Type $T is not supported by SharedPreferencesStorage'),
    };
  }

  @override
  Future<bool> setValue<T>(String key, T value) => switch (value) {
        bool b => _prefs.setBool(key, b),
        int i => _prefs.setInt(key, i),
        double d => _prefs.setDouble(key, d),
        String s => _prefs.setString(key, s),
        List<String> list => _prefs.setStringList(key, list),
        Map<String, Object?> map => _prefs.setString(key, jsonEncode(map)),
        DateTime dt => _prefs.setString(key, dt.toIso8601String()),
        _ => throw UnsupportedError('Type ${value.runtimeType} is not supported by SharedPreferencesStorage'),
      };
}

---
FILE: lib/src/controller/config.dart
---
part of 'controller.dart';

const _kConfigSelected = 'appfuse.settings.config';
const _kCustomSettings = 'appfuse.settings.custom';

extension $ConfigSettings on AppFuseController {
  /// Activates the given [config], initializes it, and persists the choice.
  Future<void> activateConfig(BaseConfig config) => handle<void>(() async {
        try {
          setState(state.startProcessing());
          final configLoaded = await config.init();
          setState(state.copyWith(config: configLoaded));
          _fuseStorage!.setValue(_kConfigSelected, config.name).ignore();
        } on Object catch (error, stackTrace) {
          _onError(error, stackTrace);
        } finally {
          setState(state.stopProcessing());
        }
      });

  /// Sets a custom key-value pair in the settings and persists it.
  Future<void> setCustomSetting<T>(String key, T value) => handle<void>(() async {
        final customSettings = Map<String, Object?>.from(state.customSettings);
        customSettings[key] = value;
        setState(state.copyWith(customSettings: customSettings));
        _fuseStorage!.setValue<Map<String, Object?>>(_kCustomSettings, customSettings).ignore();
      });
}

---
FILE: lib/src/controller/controller.dart
---
import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl_standalone.dart' if (dart.library.html) 'package:intl/intl_browser.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:platform_info/platform_info.dart';

import '../models/models.dart';
import 'storage.dart';

part 'config.dart';
part 'initialization.dart';
part 'locale.dart';
part 'permissions.dart';
part 'theme.dart';

/// A base class for controllers that holds a single value and notifies listeners.
abstract class IController<S> extends ValueNotifier<S> {
  IController(super.value);

  final mutex = Mutex();

  S get state => value;

  Future<T> handle<T>(Future<T> Function() fn) => mutex.synchronize<T>(fn);

  void setState(S newState) => value = newState;
}

/// A simple mutex implementation using a queue of completers.
/// This allows for synchronizing access to a critical section of code,
/// ensuring that only one task can execute the critical section at a time.
class Mutex {
  /// Creates a new instance of the mutex.
  Mutex();

  /// Queue of completers representing tasks waiting for the mutex.
  final DoubleLinkedQueue<Completer<void>> _queue = DoubleLinkedQueue<Completer<void>>();

  /// Check if the mutex is currently locked.
  bool get isLocked => _queue.isNotEmpty;

  /// Returns the number of tasks waiting for the mutex.
  int get tasks => _queue.length;

  /// Locks the mutex and returns
  /// a future that completes when the lock is acquired.
  /// The returned function can be called to unlock the mutex,
  /// but it should only be called once and relatively expensive to call.
  Future<void> lock() {
    final previous = _queue.lastOrNull?.future ?? Future<void>.value();
    _queue.add(Completer<void>.sync());
    return previous;
  }

  /// Unlocks the mutex, allowing the next waiting task to proceed.
  void unlock() {
    if (_queue.isEmpty) {
      assert(false, 'Mutex unlock called when no tasks are waiting.');
      return;
    }
    final completer = _queue.removeFirst(); // Remove the current lock holder
    if (completer.isCompleted) {
      assert(false, 'Mutex unlock called when the completer is already completed.');
      return;
    }
    completer.complete();
  }

  /// Synchronizes the execution of a function, ensuring that only one
  /// task can execute the function at a time.
  Future<T> synchronize<T>(Future<T> Function() action) async {
    await lock();
    try {
      return await action();
    } finally {
      unlock();
    }
  }
}

/// The main controller that orchestrates the application's initialization and state.
class AppFuseController extends IController<AppFuseState> {
  AppFuseController({
    this.initTimeout = const Duration(minutes: 3),
    this.onProgress,
    this.onError,
    AppFuseSetup? setup,
    List<BaseConfig>? configs,
    Map<Brightness, ThemeData>? themes,
    Map<Locale, String>? supportedLanguages,
    Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates,
    IFuseStorage? storage,
  })  : _fuseStorage = storage,
        _setupSteps = setup ?? EmptyInitialization(),
        _configs = configs ?? const [],
        _localizationsDelegates = localizationsDelegates ?? const [],
        _supportedLanguages = supportedLanguages ?? {const Locale('en'): 'English'},
        _themes = themes ?? {Brightness.light: ThemeData.light()},
        super(AppFuseState.initial()) {
    _initialiseApp();
  }

  final Duration initTimeout;
  final void Function(String message)? onProgress;
  final void Function(Object error, StackTrace stackTrace)? onError;

  final List<BaseConfig> _configs;
  final AppFuseSetup _setupSteps;
  final Map<Brightness, ThemeData> _themes;
  final Map<Locale, String> _supportedLanguages;
  final Iterable<LocalizationsDelegate<dynamic>> _localizationsDelegates;

  /// Fuse Settings Storage
  IFuseStorage? _fuseStorage;

  /// Ephemerally initializes the app and prepares it for use.
  Future<AppFuseSetup>? _$currentInitialization;

  /// Reports a progress message to the state and the onProgress callback.
  void _onProgress(String message) {
    setState(state.copyWith(progressMessage: message));
    onProgress?.call(message);
  }

  /// Updates the state with error information and calls the onError callback.
  void _onError(Object error, StackTrace stackTrace) {
    setState(state.copyWith(
      error: error,
      stackTrace: stackTrace,
    ));
    setState(state.stopProcessing());
    onError?.call(error, stackTrace);
  }
}

/// An immutable class representing the entire state of the application.
@immutable
class AppFuseState {
  const AppFuseState({
    required this.metaData,
    required this.lightTheme,
    this.setup,
    this.config = const EmptyConfig(),
    this.configs,
    this.permissions = const <Permission, PermissionStatus>{},
    this.localizationsDelegates = const [],
    this.supportedLocales = const <Locale>[Locale('en')],
    this.customSettings = const <String, Object?>{},
    this.locale = const Locale('en'),
    this.themeMode = ThemeMode.system,
    this.darkTheme,
    this.isProcessing = false,
    this.progressMessage,
    this.error,
    this.stackTrace,
  });

  factory AppFuseState.initial() => AppFuseState(
        isProcessing: true,
        lightTheme: ThemeData.light(),
        metaData: AppMetaData.none(),
      );

  AppFuseState startProcessing() => copyWith(isProcessing: true);
  AppFuseState stopProcessing() => copyWith(isProcessing: false);

  final AppFuseSetup? setup;

  final BaseConfig config;
  final List<BaseConfig>? configs;
  T? getCurrentConfig<T extends BaseConfig>() {
    if (config is! T) return null;
    return config as T;
  }

  final Map<String, Object?> customSettings;
  T? getCustomSetting<T>(String key) {
    if (customSettings[key] == null) return null;
    if (customSettings[key] is! T) return null;
    return customSettings[key] as T;
  }

  final AppMetaData metaData;
  final Map<Permission, PermissionStatus> permissions;

  final Iterable<LocalizationsDelegate<dynamic>> localizationsDelegates;
  final Iterable<Locale> supportedLocales;
  final Locale locale;

  final ThemeMode themeMode;
  final ThemeData lightTheme;
  final ThemeData? darkTheme;

  final bool isProcessing;
  final String? progressMessage;
  final Object? error;
  final StackTrace? stackTrace;

  bool get hasError => error != null;

  AppFuseState copyWith({
    AppFuseSetup? dependencies,
    BaseConfig? config,
    List<BaseConfig>? configs,
    Map<String, Object?>? customSettings,
    AppMetaData? metaData,
    Map<Permission, PermissionStatus>? permissions,
    Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates,
    Iterable<Locale>? supportedLocales,
    Locale? locale,
    ThemeMode? themeMode,
    ThemeData? lightTheme,
    ThemeData? darkTheme,
    bool? isProcessing,
    String? progressMessage,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      AppFuseState(
        setup: dependencies ?? setup,
        config: config ?? this.config,
        configs: configs ?? this.configs,
        customSettings: customSettings ?? this.customSettings,
        metaData: metaData ?? this.metaData,
        permissions: permissions ?? this.permissions,
        localizationsDelegates: localizationsDelegates ?? this.localizationsDelegates,
        supportedLocales: supportedLocales ?? this.supportedLocales,
        locale: locale ?? this.locale,
        themeMode: themeMode ?? this.themeMode,
        lightTheme: lightTheme ?? this.lightTheme,
        darkTheme: darkTheme ?? this.darkTheme,
        isProcessing: isProcessing ?? this.isProcessing,
        progressMessage: progressMessage ?? this.progressMessage,
        error: error ?? this.error,
        stackTrace: stackTrace ?? this.stackTrace,
      );

  @override
  bool operator ==(covariant AppFuseState other) {
    if (identical(this, other)) return true;

    return other.setup == setup &&
        other.config == config &&
        listEquals(other.configs, configs) &&
        other.metaData == metaData &&
        mapEquals(other.permissions, permissions) &&
        mapEquals(other.customSettings, customSettings) &&
        other.localizationsDelegates == localizationsDelegates &&
        other.supportedLocales == supportedLocales &&
        other.locale == locale &&
        other.themeMode == themeMode &&
        other.lightTheme == lightTheme &&
        other.darkTheme == darkTheme &&
        other.isProcessing == isProcessing &&
        other.progressMessage == progressMessage &&
        other.error == error &&
        other.stackTrace == stackTrace;
  }

  @override
  int get hashCode => Object.hash(
        setup,
        config,
        configs,
        metaData,
        permissions,
        customSettings,
        localizationsDelegates,
        supportedLocales,
        locale,
        themeMode,
        lightTheme,
        darkTheme,
        isProcessing,
        progressMessage,
        error,
        stackTrace,
      );
}

---
FILE: lib/src/controller/locale.dart
---
part of 'controller.dart';

const _kLocaleSelected = 'appfuse.settings.locale';

extension $LocaleSetttings on AppFuseController {
  Map<Locale, String> get supportedLanguages => _supportedLanguages;
  Iterable<Locale> get supportedLocales => _supportedLanguages.keys;

  /// Changes the application's active locale and persists the choice.
  Future<void> changeLocale([Locale? newLocale]) => handle<void>(() async {
        var locale = newLocale;

        locale ??= await _loadSavedLocale();
        locale ??= await _getDeviceLocale();

        if (!_isLocaleSupported(locale!)) {
          locale = await _loadSavedLocale();
          locale ??= supportedLocales.first;
        }

        setState(state.copyWith(locale: locale));

        _fuseStorage!.setValue<String>(_kLocaleSelected, locale.toString()).ignore();
      });

  /// Checks if the given [locale] is present in the list of supported locales.
  bool _isLocaleSupported(Locale locale) => supportedLocales.contains(locale);

  /// Retrieves the device's current system locale.
  Future<Locale?> _getDeviceLocale() async {
    final deviceLocale = await findSystemLocale();
    return _localeFromString(deviceLocale);
  }

  /// Retrieves the saved locale from storage.
  Future<Locale?> _loadSavedLocale() async {
    final localeStr = await _fuseStorage!.getValue<String>(_kLocaleSelected);
    if (localeStr != null) return _localeFromString(localeStr);
    return null;
  }

  /// Parses a string (e.g., "en_US" or "en") into a [Locale] object.
  Locale? _localeFromString(String val) {
    if (val.isEmpty) return null;
    final localeList = val.split('_');
    return (localeList.length > 1) ? Locale(localeList.first, localeList.last) : Locale(localeList.first);
  }
}

---
FILE: lib/src/controller/permissions.dart
---
part of 'controller.dart';

extension $PermissionSettings on AppFuseController {
  List<Permission> get permissions => Permission.values;

  /// Checks the current status of a single [permission].
  Future<PermissionStatus> checkPermissionStatus(Permission permission) =>
      handle<PermissionStatus>(() => permission.status);

  /// Requests a single [permission] from the user.
  Future<PermissionStatus> requestPermission(Permission permission) =>
      handle<PermissionStatus>(() => permission.request());

  /// Opens the app's settings screen to allow the user to manually change permissions.
  Future<bool> openSettings() => openAppSettings();
}

---
FILE: lib/src/controller/theme.dart
---
part of 'controller.dart';

const _kThemeModeSelected = 'appfuse.settings.themeMode';

extension $ThemeModeSettings on AppFuseController {
  /// Changes the application's active theme mode and persists the choice.
  Future<void> changeThemeMode([ThemeMode? newMode]) => handle<void>(() async {
        var mode = newMode;

        mode ??= await _loadSavedThemeMode();

        if (!_isThemeModeSupported(mode)) {
          mode = await _loadSavedThemeMode();
          mode ??= ThemeMode.system;
        }

        setState(state.copyWith(themeMode: mode));

        /// saves [ThemeMode] preference
        _fuseStorage!.setValue<String>(_kThemeModeSelected, mode!.name).ignore();
      });

  /// Checks if the given [ThemeMode] is present in the list of supported locales.
  bool _isThemeModeSupported(ThemeMode? mode) {
    if (mode == null) return false;
    switch (mode) {
      case ThemeMode.light:
        return _themes[Brightness.light] != null;
      case ThemeMode.dark:
        return _themes[Brightness.dark] != null;
      case ThemeMode.system:
        return true;
    }
  }

  /// Retrieves the saved theme mode from storage.
  Future<ThemeMode?> _loadSavedThemeMode() async {
    final localeStr = await _fuseStorage!.getValue<String>(_kThemeModeSelected);
    if (localeStr != null) return _themeModeFromString(localeStr);
    return null;
  }

  /// Parses a string (e.g., "light") into a [ThemMode] object.
  ThemeMode? _themeModeFromString(String val) {
    if (val.isEmpty) return null;
    // Find by name, default to system if not found or on error
    return ThemeMode.values.firstWhere(
      (e) => e.name == val,
      orElse: () => ThemeMode.system,
    );
  }
}

---
FILE: lib/src/widgets/widgets.dart
---
export 'buttons.dart';
export 'foundation/scope.dart';
export 'utils/config.dart';
export 'utils/locale.dart';
export 'utils/permission.dart';
export 'utils/settings.dart';
export 'utils/theme.dart';

---
FILE: lib/src/widgets/buttons.dart
---
import 'package:appfuse/appfuse.dart';
import 'package:flutter/material.dart';

class LocalizationIconButton extends StatelessWidget {
  const LocalizationIconButton({
    super.key,
    this.dialogTitle = 'Language',
    this.iconColor,
  });
  final String dialogTitle;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onLongPress: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Current language ${context.currentLanguage}'),
            ),
          );
        },
        child: IconButton(
          icon: const Icon(Icons.language),
          color: iconColor,
          onPressed: () => selectLocaleDialog(context, title: dialogTitle),
        ),
      );
}

class ThemeIconButton extends StatelessWidget {
  const ThemeIconButton({
    super.key,
    this.dialogTitle = 'Theme',
    this.iconColor,
  });
  final String dialogTitle;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final icon = switch (context.currentThemeMode) {
      ThemeMode.light => Icons.sunny,
      ThemeMode.dark => Icons.nightlight_round,
      ThemeMode.system => Icons.perm_device_info,
    };
    return GestureDetector(
      onLongPress: () {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Current theme mode ${context.currentThemeModeName}'),
          ),
        );
      },
      child: IconButton(
        icon: Icon(icon),
        color: iconColor,
        onPressed: () => selectThemeDialog(context, title: dialogTitle),
      ),
    );
  }
}

---
FILE: lib/src/widgets/foundation/banner.dart
---
import 'package:flutter/widgets.dart';

@immutable
class ConfigBanner extends StatelessWidget {
  const ConfigBanner({
    required this.name,
    required this.color,
    super.key,
    this.onPressed,
    this.onLongPressed,
  });
  final String name;
  final Color color;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPressed;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: onLongPressed,
        onTap: onPressed,
        child: SizedBox(
          height: 50,
          width: 50,
          child: Banner(
            location: BannerLocation.topStart,
            color: color,
            message: name,
            textDirection: Directionality.of(context),
            layoutDirection: Directionality.of(context),
          ),
        ),
      );
}

---
FILE: lib/src/widgets/foundation/scope.dart
---
import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../../controller/controller.dart';
import '../../controller/storage.dart';
import '../../models/models.dart';
import 'banner.dart';
import 'vital_app.dart';

/// A top-level widget that initializes and provides app-wide dependencies, configurations, and settings to the entire widget tree.
class AppFuseScope extends StatefulWidget {
  const AppFuseScope({
    required this.app,
    super.key,
    this.placeholder = const SizedBox.shrink(),
    this.initTimeout = const Duration(minutes: 3),
    this.storage,
    this.setup,
    this.configs,
    this.themes,
    this.supportedLanguages,
    this.localizationsDelegates,
    this.errorBuilder,
    this.progressBuilder,
    this.onProgress,
    this.onError,
  });

  /// The root widget of the application, displayed after initialization.
  final Widget app;

  /// A widget to display while the app is initializing.
  final Widget placeholder;

  /// The maximum duration allowed for the entire initialization process.
  final Duration initTimeout;

  /// The storage implementation for persisting settings. Defaults to [FuseShPrStorage].
  final IFuseStorage? storage;

  /// The class that defines the asynchronous initialization steps.
  final AppFuseSetup? setup;

  /// A list of available environment configurations for the app.
  final List<BaseConfig>? configs;

  /// A map of themes available in the app, keyed by [Brightness].
  final Map<Brightness, ThemeData>? themes;

  /// A map of supported locales and their human-readable names.
  final Map<Locale, String>? supportedLanguages;

  /// The list of localization delegates for the app.
  final Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates;

  /// A builder for a custom widget to display initialization progress.
  final Widget Function(String message)? progressBuilder;

  /// A builder for a custom widget to display when an error occurs.
  final Widget Function(Object error, StackTrace? stackTrace)? errorBuilder;

  /// A callback that fires with progress messages during initialization.
  final void Function(String message)? onProgress;

  /// A callback that fires when an error occurs during initialization.
  final void Function(Object error, StackTrace stackTrace)? onError;

  @override
  State<AppFuseScope> createState() => _AppFuseScopeState();

  /// Retrieves the [AppFuseController] from the nearest [AppFuseScope].
  /// Does not cause the widget to rebuild when the state changes.
  static AppFuseController controller(BuildContext context) =>
      _InheritedAppFuseScope.of(context, listen: false).controller;

  /// Retrieves the current [AppFuseState] from the nearest [AppFuseScope].
  static AppFuseState of(BuildContext context, {bool listen = false}) =>
      _InheritedAppFuseScope.of(context, listen: listen).state;

  /// Retrieves the current [AppFuseState] from the nearest [AppFuseScope].
  /// Does not cause the widget to rebuild when the state changes.
  static AppFuseState read(BuildContext context) => _InheritedAppFuseScope.of(context, listen: false).state;

  /// Subscribes to the [AppFuseState] from the nearest [AppFuseScope].
  /// Causes the widget to rebuild when the state changes.
  static AppFuseState watch(BuildContext context) => _InheritedAppFuseScope.of(context, listen: true).state;
}

class _AppFuseScopeState extends State<AppFuseScope> {
  late AppFuseController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AppFuseController(
      setup: widget.setup,
      initTimeout: widget.initTimeout,
      storage: widget.storage,
      configs: widget.configs,
      supportedLanguages: widget.supportedLanguages,
      localizationsDelegates: widget.localizationsDelegates,
      themes: widget.themes,
      onProgress: widget.onProgress ?? (m) => developer.log(m, name: 'app-fuse', time: DateTime.now()),
      onError: widget.onError ??
          (e, s) => developer.log('$e', name: 'app-fuse', time: DateTime.now(), error: e, stackTrace: s),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The currently selected configuration.
  BaseConfig? _selectedConfig;

  /// A unique key that forces the widget tree to rebuild when the config changes.
  UniqueKey? _key;

  /// Generates a new [UniqueKey] only when the configuration changes.
  UniqueKey _getKey(BaseConfig config) {
    if (_selectedConfig?.name == config.name) return _key ??= UniqueKey();
    _selectedConfig = config;
    return _key = UniqueKey();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppFuseState>(
        valueListenable: _controller,
        builder: (context, state, _) {
          if (state.isProcessing) {
            return VitalApp(
              home: widget.progressBuilder?.call(state.progressMessage ?? '') ?? widget.placeholder,
            );
          }

          if (state.hasError) {
            return VitalApp(
              home: widget.errorBuilder?.call(
                    state.error!,
                    state.stackTrace,
                  ) ??
                  ErrorWidget(state.error!),
            );
          }

          final currentConfig = state.config;
          if (currentConfig is EmptyConfig) {
            return _InheritedAppFuseScope(
              controller: _controller,
              state: state,
              child: widget.app,
            );
          }

          _key = _getKey(currentConfig);
          return VitalApp(
            key: _key,
            home: Stack(
              children: [
                _InheritedAppFuseScope(
                  state: state,
                  controller: _controller,
                  child: widget.app,
                ),
                if (currentConfig.showBanner)
                  Align(
                    alignment: Alignment.topLeft,
                    child: ConfigBanner(
                      name: currentConfig.name,
                      color: currentConfig.color,
                      onPressed: () {},
                      onLongPressed: () {},
                    ),
                  ),
              ],
            ),
          );
        },
      );
}

/// An inherited widget that provides the [AppFuseState] and [AppFuseController] to the widget tree.
class _InheritedAppFuseScope extends InheritedWidget {
  const _InheritedAppFuseScope({
    required this.state,
    required this.controller,
    required super.child,
  });

  /// The current state of the application.
  final AppFuseState state;

  /// The controller for managing the application's state.
  final AppFuseController controller;

  /// The state from the closest instance of this class that encloses the given context, if any.
  static _InheritedAppFuseScope? maybeOf(BuildContext context, {bool listen = true}) => listen
      ? context.dependOnInheritedWidgetOfExactType<_InheritedAppFuseScope>()
      : context.getInheritedWidgetOfExactType<_InheritedAppFuseScope>();

  static Never _notFoundInheritedWidgetOfExactType() => throw ArgumentError(
        'Out of scope, not found inherited widget '
            'a _InheritedAppFuseScope of the exact type',
        'out_of_scope',
      );

  /// The state from the closest instance of this class that encloses the given context.
  static _InheritedAppFuseScope of(BuildContext context, {bool listen = true}) =>
      maybeOf(context, listen: listen) ?? _notFoundInheritedWidgetOfExactType();

  @override
  bool updateShouldNotify(covariant _InheritedAppFuseScope oldWidget) => !identical(oldWidget.state, state);
}

/// An extension on [BuildContext] to provide easy access to AppFuse properties.
extension $AppFuseContext on BuildContext {
  /// Shortcut for accessing the [AppFuseController].
  AppFuseController get fuse => AppFuseScope.controller(this);

  /// Shortcut for reading the current [AppFuseState] without listening for changes.
  AppFuseState get readSettings => AppFuseScope.read(this);

  /// Shortcut for watching the current [AppFuseState] for changes.
  AppFuseState get watchSettings => AppFuseScope.watch(this);

  /// The currently active [Locale].
  Locale get currentLocale => watchSettings.locale;

  /// The language tag for the current locale (e.g., "en-US").
  String get currentLanguage => currentLocale.toLanguageTag();

  /// The human-readable name of the current language (e.g., "English").
  String get currentLanguageName => supportedLanguages[currentLocale]!;

  /// The language code for the current locale (e.g., "en").
  String get currentLanguageCode => currentLocale.languageCode;

  /// An iterable of all supported locales.
  Iterable<Locale> get supportedLocales => fuse.supportedLocales;

  /// A map of all supported locales and their names.
  Map<Locale, String> get supportedLanguages => fuse.supportedLanguages;

  /// Changes the application's active locale.
  Future<void> changeAppLocale(Locale locale) => fuse.changeLocale(locale);

  /// An iterable of all supported themes.
  Iterable<ThemeMode> get supportedThemes {
    final result = [ThemeMode.light];
    if (fuse.state.darkTheme != null) result.addAll([ThemeMode.dark, ThemeMode.system]);
    return result;
  }

  /// The currently active [ThemeMode].
  ThemeMode get currentThemeMode => watchSettings.themeMode;

  /// The name of the current theme mode (e.g., "dark").
  String get currentThemeModeName => currentThemeMode.name;

  /// Changes the application's active theme mode.
  Future<void> changeAppThemeMode(ThemeMode themeMode) => fuse.changeThemeMode(themeMode);

  /// Changes the application's active config. Will reload whole app
  Future<void> changeConfig(BaseConfig config) => fuse.activateConfig(config);
}

---
FILE: lib/src/widgets/foundation/vital_app.dart
---
import 'package:flutter/widgets.dart';

/// Bare Minimum [Widget] to be used as a root widget for `runApp()` function
@immutable
class VitalApp extends StatelessWidget {
  /// creates [VitalApp]
  const VitalApp({required this.home, super.key});

  /// [Widget] to be displayed
  final Widget home;

  @override
  Widget build(BuildContext context) => MediaQuery(
        data: MediaQueryData.fromView(View.of(context)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Color(0x00000000),
              fontFamily: 'Roboto',
              fontSize: 14,
            ),
            child: home,
          ),
        ),
      );
}

---
FILE: lib/src/widgets/utils/permission.dart
---
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../controller/controller.dart';
import '../foundation/scope.dart';

Future<bool> askPermissionDialog({
  required BuildContext context,
  required Permission permission,
  String goToSettingsText = 'You can go to app settings and enable permissions there.',
  String goToSettingsBtnText = 'Open Settings',
  String? reasonText,
}) async {
  final status = await context.fuse.checkPermissionStatus(permission);
  if (status == PermissionStatus.granted) return true;

  String permissionName(Permission permission) {
    final name = permission.toString().replaceAll('Permission.', '');
    if (name.contains('location')) return 'Location';
    return name[0].toUpperCase() + name.substring(1);
  }

  final reason = reasonText ?? 'App needs permission for accessing ${permissionName(permission)} to work further.';

  final result = await showDialog<PermissionStatus>(
    barrierDismissible: false,
    context: context,
    builder: (context) => _AskPermissionDialog(
      permission: permission,
      status: status,
      reasonText: reason,
      goToSettingsText: goToSettingsText,
      goToSettingsBtnText: goToSettingsBtnText,
    ),
  );

  return result == PermissionStatus.granted;
}

class _AskPermissionDialog extends StatelessWidget {
  const _AskPermissionDialog({
    required this.permission,
    required this.status,
    required this.reasonText,
    required this.goToSettingsText,
    required this.goToSettingsBtnText,
  });
  final Permission permission;
  final PermissionStatus status;
  final String reasonText;
  final String goToSettingsText;
  final String goToSettingsBtnText;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final secondaryColor = Theme.of(context).textTheme.titleLarge?.color ?? Colors.black;

    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 10),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 20),
            Icon(Icons.device_unknown, size: 50, color: secondaryColor),
            const SizedBox(height: 20),
            _AskPermissionDialogText(
              reasonText,
              isTitle: true,
              color: secondaryColor,
            ),
            const SizedBox(height: 20),
            _AskPermissionDialogText(
              reasonText,
              color: secondaryColor,
            ),
            if (status == PermissionStatus.permanentlyDenied)
              _AskPermissionDialogText(
                goToSettingsText,
                color: secondaryColor,
              ),
            const SizedBox(height: 20),
            Container(
              width: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                color: secondaryColor.withAlpha(50),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: <Widget>[
                  if (status != PermissionStatus.permanentlyDenied)
                    _AskPermissionDialogButton(
                      'OK',
                      color: primaryColor,
                      onTap: () => _requestPermission(context),
                    )
                  else
                    _AskPermissionDialogButton(
                      goToSettingsBtnText,
                      color: primaryColor,
                      onTap: () => _openSettings(context),
                    )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestPermission(BuildContext context) async {
    final result = await context.fuse.requestPermission(permission);
    if (!context.mounted) return;
    Navigator.of(context).pop(result);
  }

  Future<void> _openSettings(BuildContext context) async {
    final result = await context.fuse.openSettings();
    if (!context.mounted) return;
    if (result) Navigator.of(context).pop();
  }
}

class _AskPermissionDialogText extends StatelessWidget {
  const _AskPermissionDialogText(
    this.text, {
    required this.color,
    this.isTitle = false,
  });
  final String text;
  final bool isTitle;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontSize: isTitle ? 20.0 : 16.0,
                fontWeight: isTitle ? FontWeight.bold : FontWeight.normal,
              ),
          textAlign: TextAlign.center,
        ),
      );
}

class _AskPermissionDialogButton extends StatelessWidget {
  const _AskPermissionDialogButton(
    this.name, {
    required this.onTap,
    required this.color,
  });
  final String name;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 13),
        onPressed: onTap,
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: Text(
            name,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      );
}

---
FILE: lib/src/widgets/utils/config.dart
---
import 'package:appfuse/appfuse.dart';
import 'package:flutter/material.dart';

Future<void> selectConfigDialog(
  BuildContext context, {
  String title = 'Config',
}) async {
  final configs = context.fuse.state.configs;
  final selectedConfig = context.fuse.state.config;
  if (configs == null) return;
  if (selectedConfig is EmptyConfig) return;

  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: configs
            .map(
              (config) => _ConfigRadioButton(
                selectedConfig: selectedConfig,
                config: config,
                onChanged: (config) {
                  if (config != null) context.changeConfig(config);
                  Navigator.of(context).pop();
                },
              ),
            )
            .toList(),
      ),
    ),
  );
}

@immutable
class _ConfigRadioButton extends StatelessWidget {
  const _ConfigRadioButton({
    required this.selectedConfig,
    required this.config,
    required this.onChanged,
  });
  final BaseConfig selectedConfig;
  final BaseConfig config;
  final ValueChanged<BaseConfig?> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(config.name),
        leading: Radio<String>(
          activeColor: config.color,
          value: config.name,
          groupValue: selectedConfig.name,
          onChanged: (value) {
            onChanged.call(config);
          },
        ),
        onTap: () => onChanged.call(config),
      );
}

---
FILE: lib/src/widgets/utils/locale.dart
---
import 'package:appfuse/appfuse.dart';
import 'package:flutter/material.dart';

Future<void> selectLocaleDialog(
  BuildContext context, {
  String title = 'Language',
}) =>
    showDialog<void>(
      useRootNavigator: true,
      barrierColor: Theme.of(context).textTheme.bodyLarge?.color?.withAlpha(124),
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: context.supportedLanguages.keys
              .map(
                (locale) => _AppLocaleRadioButton(
                  title: context.supportedLanguages[locale]!,
                  value: locale,
                  onChanged: (locale) {
                    context.changeAppLocale(locale!);
                    Navigator.of(context).pop();
                  },
                ),
              )
              .toList(),
        ),
      ),
    );

class _AppLocaleRadioButton extends StatelessWidget {
  const _AppLocaleRadioButton({
    required this.title,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final Locale value;
  final void Function(Locale?)? onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        leading: Radio<Locale>(
          activeColor: Theme.of(context).colorScheme.primary,
          value: value,
          groupValue: context.currentLocale,
          onChanged: onChanged,
        ),
        onTap: () => onChanged?.call(value),
      );
}

---
FILE: lib/src/widgets/utils/theme.dart
---
import 'package:appfuse/appfuse.dart';
import 'package:flutter/material.dart';

Future<void> selectThemeDialog(
  BuildContext context, {
  String title = 'Theme',
}) =>
    showDialog<void>(
      useRootNavigator: true,
      barrierColor: Theme.of(context).textTheme.bodyLarge?.color?.withAlpha(124),
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: context.supportedThemes
              .map(
                (theme) => _AppThemeRadioButton(
                  themeMode: theme,
                  onChanged: (locale) {
                    context.changeAppThemeMode(theme);
                    Navigator.of(context).pop();
                  },
                ),
              )
              .toList(),
        ),
      ),
    );

class _AppThemeRadioButton extends StatelessWidget {
  const _AppThemeRadioButton({
    required this.themeMode,
    required this.onChanged,
  });
  final ThemeMode themeMode;
  final void Function(ThemeMode?)? onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(
          themeMode.name,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        leading: Radio<ThemeMode>(
          activeColor: Theme.of(context).colorScheme.primary,
          value: themeMode,
          groupValue: context.currentThemeMode,
          onChanged: onChanged,
        ),
        onTap: () => onChanged?.call(themeMode),
      );
}

---
FILE: lib/src/widgets/utils/settings.dart
---
import 'package:appfuse/appfuse.dart';
import 'package:flutter/material.dart';

void showAppFuseMenu(
  BuildContext context, {
  Widget? children,
  VoidCallback? onClose,
  Color? backgroundColor,
}) {
  if (MediaQuery.of(context).size.width > 750) {
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (context) => ConfigSettings.dialog(
        children: children,
        onClose: () {
          onClose?.call();
          Navigator.of(context, rootNavigator: true).pop();
        },
      ),
    );
  } else {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      builder: (context) => ConfigSettings.sheet(
        onClose: onClose,
        children: children,
      ),
    );
  }
}

enum RenderMode { sheet, dialog }

@immutable
class ConfigSettings extends StatelessWidget {
  const ConfigSettings._({
    required this.mode,
    super.key,
    this.children,
    this.onClose,
  });

  factory ConfigSettings.sheet({
    Key? key,
    VoidCallback? onClose,
    Widget? children,
  }) =>
      ConfigSettings._(
        key: key,
        onClose: onClose,
        mode: RenderMode.sheet,
        children: children,
      );

  factory ConfigSettings.dialog({
    Key? key,
    VoidCallback? onClose,
    Widget? children,
  }) =>
      ConfigSettings._(
        key: key,
        onClose: onClose,
        mode: RenderMode.dialog,
        children: children,
      );

  final Widget? children;
  final VoidCallback? onClose;
  final RenderMode mode;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppFuseState>(
        valueListenable: context.fuse,
        builder: (context, state, _) {
          if (state.isProcessing) return const _SettingsLoader();

          switch (mode) {
            case RenderMode.sheet:
              return _SettingsBody(
                onClose: onClose,
                fuseState: state,
                mode: mode,
                children: children,
              );

            case RenderMode.dialog:
              return Dialog(
                insetPadding: const EdgeInsets.only(top: 35, left: 35, right: 35),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: _SettingsBody(
                    onClose: onClose,
                    fuseState: state,
                    mode: mode,
                    children: children,
                  ),
                ),
              );
          }
        },
      );
}

@immutable
class _SettingsBody extends StatelessWidget {
  const _SettingsBody({
    required this.fuseState,
    required this.mode,
    this.onClose,
    this.children,
  });
  final VoidCallback? onClose;
  final Widget? children;
  final AppFuseState fuseState;
  final RenderMode mode;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Header(onClose: onClose),
          const SizedBox(height: 20),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height - 80,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (children != null) ...[
                      children!,
                      const Divider(thickness: 1),
                    ],
                    if (fuseState.config is! EmptyConfig)
                      SettingTile(
                        icon: Icons.cloud_rounded,
                        label: 'Config',
                        value: fuseState.config.name,
                        onPressed: () => selectConfigDialog(context),
                      ),
                    const Divider(),
                    if (mode == RenderMode.sheet) const SizedBox(height: 50) else const SizedBox(height: 10)
                  ],
                ),
              ),
            ),
          ),
        ],
      );
}

@immutable
class Header extends StatelessWidget {
  const Header({
    super.key,
    this.onClose,
  });
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          const Align(
            alignment: Alignment.center,
            child: Text(
              'Config Debug',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
          if (onClose != null) ...[
            Positioned(
              top: 0,
              left: 10,
              child: InkWell(
                onTap: onClose,
                customBorder: const CircleBorder(),
                child: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ],
      );
}

@immutable
class _SettingsLoader extends StatelessWidget {
  const _SettingsLoader();

  @override
  Widget build(BuildContext context) => const Center(child: Text('...'));
}

@immutable
class SettingTile extends StatelessWidget {
  const SettingTile({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
    this.onPressed,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 16,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
}

