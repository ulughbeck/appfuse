import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/models.dart';
import 'storage.dart';
import 'storage_keys.dart';

part 'config.dart';
part 'initialization.dart';
part 'locale.dart';
part 'permissions.dart';
part 'theme.dart';

const _kAppInfoTimeout = Duration(seconds: 5);

/// Copies decoded JSON so that every nested map and list cannot change.
Object? _freeze(Object? value) => switch (value) {
  final Map<String, Object?> map => _freezeMap(map),
  final List<Object?> list => List<Object?>.unmodifiable(list.map(_freeze)),
  _ => value,
};

Map<String, Object?> _freezeMap(Map<String, Object?> map) => Map.unmodifiable({
  for (final MapEntry(:key, :value) in map.entries) key: _freeze(value),
});

/// The state, callbacks, and storage helpers that each feature of [AppFuseController] uses.
///
/// Only the controller can change the state. [value] has no setter.
abstract class _AppFuseBase<T extends AppFuseInitialization>
    extends ChangeNotifier
    implements ValueListenable<AppFuseState> {
  _AppFuseBase(
    this._state, {
    required this.initTimeout,
    required this.onProgress,
    required this.onError,
    required IAppFuseStorage? storage,
    T Function()? setup,
  }) : _storage = storage,
       _createSetup = setup;

  /// Limits the initialization. `null` waits until it completes.
  final Duration? initTimeout;
  final void Function(String message)? onProgress;
  final void Function(Object error, StackTrace stackTrace)? onError;

  /// Creates the setup object at startup, after each config switch, and on a retry.
  final T Function()? _createSetup;

  AppFuseState _state;

  /// The current setup object. A config switch or a retry replaces it. `null` when the app gives no setup factory.
  T? get setup => _setup;
  T? _setup;

  /// Set by the first initialization step when the app gives no storage.
  IAppFuseStorage? _storage;
  IAppFuseStorage get _store =>
      _storage ?? (throw StateError('AppFuse storage is not ready'));

  bool _disposed = false;

  /// The theme mode the user picked. [AppFuseState.themeMode] holds it resolved against the themes.
  ThemeMode _themeChoice = ThemeMode.system;

  /// Completes after the last queued write.
  Future<void> _writes = Future.value();

  @override
  AppFuseState get value => _state;

  AppFuseState get state => _state;

  /// Ignored after [dispose], because async work can finish after its owner is gone.
  void _setState(AppFuseState newState) {
    if (_disposed || _state == newState) return;
    _state = newState;
    notifyListeners();
  }

  void _report(Object error, StackTrace stackTrace) {
    if (!_disposed) onError?.call(error, stackTrace);
  }

  /// Runs [action] after the previous writes complete, so saved values and the state stay in order.
  ///
  /// A failure goes to the returned future only.
  Future<R> _serial<R>(Future<R> Function() action) {
    final result = _writes.then((_) => action());
    _writes = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Like [_serial], and a failure also goes to [onError].
  Future<R> _queued<R>(Future<R> Function() action) => _serial(() async {
    try {
      return await action();
    } on Object catch (error, stackTrace) {
      _report(error, stackTrace);
      rethrow;
    }
  });

  /// Reads and decodes a saved value. A failure goes to [onError] and returns `null`, so startup continues.
  Future<R?> _restore<R extends Object>(
    String key,
    R? Function(String raw) decode,
  ) async {
    try {
      final raw = await _store.read(key);
      return raw == null ? null : decode(raw);
    } on Object catch (error, stackTrace) {
      _report(error, stackTrace);
      return null;
    }
  }

  /// Returns [state] with [AppFuseState.locale] resolved from the user choice or the device languages.
  AppFuseState _withEffectiveLocale(
    AppFuseState state, [
    List<Locale>? deviceLocales,
  ]) {
    final userLocale = state.userLocale;
    final locale = userLocale == null
        ? state.resolveLocales(
            deviceLocales ?? WidgetsBinding.instance.platformDispatcher.locales,
          )
        : state.resolveLocale(userLocale);
    return locale == state.locale ? state : state.copyWith(locale: locale);
  }

  static Map<String, Object?> _decodeSettings(String raw) => switch (jsonDecode(
    raw,
  )) {
    final Map<String, Object?> settings => _freezeMap(settings),
    _ => throw FormatException('custom settings are not a JSON object', raw),
  };

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Runs the app's startup, holds [AppFuseState], and saves the user's choices.
///
/// Writes that are saved and config switches run one after another. Permission requests do not wait for them.
///
/// [T] is the type of the setup object that [setup] creates.
class AppFuseController<T extends AppFuseInitialization> extends _AppFuseBase<T>
    with
        WidgetsBindingObserver,
        _InitializationMixin<T>,
        _ConfigMixin<T>,
        _LocaleMixin<T>,
        _ThemeMixin<T>,
        _PermissionMixin<T> {
  /// Starts the initialization and follows the device languages until [dispose].
  AppFuseController({
    super.initTimeout,
    super.onProgress,
    super.onError,
    super.setup,
    List<BaseConfig>? configs,
    Map<Brightness, ThemeData>? themes,
    Map<Locale, String>? supportedLanguages,
    Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates,
    super.storage,
  }) : super(
         AppFuseState.initial(
           configs: configs,
           themes: themes,
           supportedLanguages: supportedLanguages,
           localizationsDelegates: localizationsDelegates,
         ),
       ) {
    WidgetsFlutterBinding.ensureInitialized().addObserver(this);
    _initialize().ignore();
  }

  /// Replaces the options that can change after startup, for example on a rebuild of [AppFuseScope].
  ///
  /// A `null` value uses the default. Resolves the locale and theme mode again.
  ///
  /// The active config stays active while [configs] has a config with its
  /// name. Otherwise, after startup, this calls [activateConfig] with the first
  /// config, or with [EmptyConfig] when [configs] is empty. [onError] receives
  /// a failure of that switch.
  void updateOptions({
    List<BaseConfig>? configs,
    Map<Brightness, ThemeData>? themes,
    Map<Locale, String>? supportedLanguages,
    Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates,
  }) {
    // Uses the same defaults as at startup.
    final options = AppFuseState.initial(
      configs: configs,
      themes: themes,
      supportedLanguages: supportedLanguages,
      localizationsDelegates: localizationsDelegates,
    );
    final next = state.copyWith(
      configs: options.configs,
      themes: options.themes,
      supportedLanguages: options.supportedLanguages,
      localizationsDelegates: options.localizationsDelegates,
    );
    _setState(
      _withEffectiveLocale(
        next.copyWith(themeMode: next.resolveThemeMode(_themeChoice)),
      ),
    );
    _replaceMissingConfig();
  }

  /// Switches to another config when the active one is not in [AppFuseState.configs].
  void _replaceMissingConfig() {
    if (state.phase is! AppFuseReady) return;
    final active = state.config;
    final BaseConfig next;
    if (state.configs.isEmpty) {
      if (active is EmptyConfig) return;
      next = const EmptyConfig();
    } else if (state.configs.any((config) => config.name == active.name)) {
      return;
    } else {
      next = state.configs.first;
    }
    // activateConfig reports its failures to onError.
    activateConfig(next).ignore();
  }

  @override
  void didChangeLocales(List<Locale>? locales) =>
      _setState(_withEffectiveLocale(state, locales));

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Not awaited. A failure goes to onError directly, because _report is silent after dispose.
    _releaseSetup(onError).ignore();
    super.dispose();
  }
}
