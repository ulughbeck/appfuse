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
    AppFuseInitialization? setup,
    List<BaseConfig>? configs,
    Map<Brightness, ThemeData>? themes,
    Map<Locale, String>? supportedLanguages,
    Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates,
    IAppFuseStorage? storage,
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
  final AppFuseInitialization _setupSteps;
  final Map<Brightness, ThemeData> _themes;
  final Map<Locale, String> _supportedLanguages;
  final Iterable<LocalizationsDelegate<dynamic>> _localizationsDelegates;

  /// Fuse Settings Storage
  IAppFuseStorage? _fuseStorage;

  /// Ephemerally initializes the app and prepares it for use.
  Future<AppFuseInitialization>? _$currentInitialization;

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
    this.init,
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

  final AppFuseInitialization? init;

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
    AppFuseInitialization? setup,
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
        init: setup ?? init,
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

    return other.init == init &&
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
        init,
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
