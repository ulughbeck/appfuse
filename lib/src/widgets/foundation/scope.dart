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
