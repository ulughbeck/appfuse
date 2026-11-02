import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../controller/controller.dart';
import '../../controller/storage.dart';
import '../../models/models.dart';
import 'banner.dart';
import 'vital_app.dart';

/// A top-level widget that initializes and provides app-wide dependencies, configurations, and settings to the entire widget tree.
///
/// [T] is the type of the setup object that [init] creates. Read it with [initOf].
class AppFuseScope<T extends AppFuseInitialization> extends StatefulWidget {
  const AppFuseScope({
    required this.app,
    super.key,
    this.placeholder = const SizedBox.shrink(),
    this.keepNativeSplash = true,
    this.initTimeout,
    this.storage,
    this.init,
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
  ///
  /// At startup it shows only when [keepNativeSplash] is `false`.
  final Widget placeholder;

  /// Keeps the native splash screen until the startup ends.
  ///
  /// When `true`, the scope defers the first frame until the startup is ready
  /// or failed. [placeholder] and [progressBuilder] then show only during later
  /// config switches and retries. When `false`, the first frame draws at once
  /// and they also show at startup.
  final bool keepNativeSplash;

  /// The maximum duration allowed for the initialization.
  ///
  /// `null` (default) waits until initialization completes. The limit uses
  /// wall-clock time, so it also runs while the OS suspends the app.
  final Duration? initTimeout;

  /// The storage implementation for persisting settings. Defaults to [AppFuseShPrStorage].
  final IAppFuseStorage? storage;

  /// Creates the object that defines the asynchronous initialization steps, for example `Dependencies.new`.
  ///
  /// Called at startup, after each config switch, and on a retry. AppFuse calls
  /// [AppFuseInitialization.dispose] on the old object before it creates a new one.
  /// Without [init], only the built-in steps run.
  final T Function()? init;

  /// A list of available environment configurations for the app.
  final List<BaseConfig>? configs;

  /// A map of themes available in the app, keyed by [Brightness].
  final Map<Brightness, ThemeData>? themes;

  /// A map of supported locales and their human-readable names.
  final Map<Locale, String>? supportedLanguages;

  /// The list of localization delegates for the app.
  final Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates;

  /// A builder for a custom widget to display initialization progress.
  ///
  /// [progress] is `null` before the first step. At startup it shows only when [keepNativeSplash] is `false`.
  final Widget Function(AppFuseProgress? progress)? progressBuilder;

  /// A builder for the widget shown when initialization fails.
  ///
  /// Call `retry` to run the startup again with a new setup object.
  final Widget Function(
    Object error,
    StackTrace? stackTrace,
    VoidCallback retry,
  )?
  errorBuilder;

  /// A callback that fires with progress messages during initialization.
  final void Function(String message)? onProgress;

  /// A callback that fires on each initialization error and failed write.
  final void Function(Object error, StackTrace stackTrace)? onError;

  @override
  State<AppFuseScope<T>> createState() => _AppFuseScopeState<T>();

  /// Retrieves the [AppFuseController] from the nearest [AppFuseScope].
  /// Does not cause the widget to rebuild when the state changes.
  static AppFuseController<AppFuseInitialization> controller(
    BuildContext context,
  ) => _InheritedAppFuseScope.of(context).controller;

  /// Retrieves the setup object that [init] created, for example `Dependencies`.
  ///
  /// [T] must be the type of the scope. Throws a [StateError] when the scope
  /// has another type or no [init].
  static T initOf<T extends AppFuseInitialization>(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_InheritedSetup<T>>()?.setup ??
      (throw StateError(
        'No setup of type $T found. Pass `init` with a $T to AppFuseScope<$T>.',
      ));

  /// Retrieves the current [AppFuseState] from the nearest [AppFuseScope].
  /// Does not cause the widget to rebuild when the state changes.
  static AppFuseState read(BuildContext context) =>
      _InheritedAppFuseScope.of(context).state;

  /// Subscribes to the [AppFuseState] from the nearest [AppFuseScope].
  ///
  /// The widget rebuilds when [aspect] changes, or on any change when [aspect] is `null`.
  static AppFuseState watch(BuildContext context, [AppFuseAspect? aspect]) =>
      _InheritedAppFuseScope.of(context, listen: true, aspect: aspect).state;
}

/// A part of [AppFuseState] that a widget can watch without rebuilding on other changes.
enum AppFuseAspect {
  config,
  locale,
  theme,
  settings,
  permissions,
  metaData;

  bool changed(AppFuseState old, AppFuseState next) => switch (this) {
    config =>
      old.config != next.config ||
          old.configRevision != next.configRevision ||
          !listEquals(old.configs, next.configs),
    locale =>
      old.locale != next.locale ||
          old.userLocale != next.userLocale ||
          !mapEquals(old.supportedLanguages, next.supportedLanguages) ||
          !listEquals(old.localizationsDelegates, next.localizationsDelegates),
    theme =>
      old.themeMode != next.themeMode || !mapEquals(old.themes, next.themes),
    settings => !mapEquals(old.customSettings, next.customSettings),
    permissions => !mapEquals(old.permissions, next.permissions),
    metaData => old.metaData != next.metaData,
  };
}

class _AppFuseScopeState<T extends AppFuseInitialization>
    extends State<AppFuseScope<T>> {
  late final AppFuseController<T> _controller;
  bool _isFirstFrameDeferred = false;

  @override
  void initState() {
    super.initState();
    if (widget.keepNativeSplash) {
      WidgetsBinding.instance.deferFirstFrame();
      _isFirstFrameDeferred = true;
    }
    _controller = AppFuseController<T>(
      setup: widget.init,
      initTimeout: widget.initTimeout,
      storage: widget.storage,
      configs: widget.configs,
      themes: widget.themes,
      supportedLanguages: widget.supportedLanguages,
      localizationsDelegates: widget.localizationsDelegates,
      onProgress:
          widget.onProgress ??
          (m) => developer.log(m, name: 'app-fuse', time: DateTime.now()),
      onError:
          widget.onError ??
          (e, s) => developer.log(
            '$e',
            name: 'app-fuse',
            time: DateTime.now(),
            error: e,
            stackTrace: s,
          ),
    );
    if (_isFirstFrameDeferred) _controller.addListener(_allowFirstFrame);
  }

  /// Allows the first frame once, when the startup is no longer running.
  void _allowFirstFrame() {
    if (!_isFirstFrameDeferred || _controller.state.phase is AppFuseStarting) {
      return;
    }
    _isFirstFrameDeferred = false;
    _controller.removeListener(_allowFirstFrame);
    WidgetsBinding.instance.allowFirstFrame();
  }

  /// Applies changed configs, themes, languages, and delegates. The other options apply only at startup.
  ///
  /// Compares by content, so values built inline in a rebuilding parent do not apply again.
  @override
  void didUpdateWidget(AppFuseScope<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    List<String>? names(List<BaseConfig>? configs) =>
        configs?.map((config) => config.name).toList();
    if (listEquals(names(widget.configs), names(oldWidget.configs)) &&
        mapEquals(widget.themes, oldWidget.themes) &&
        mapEquals(widget.supportedLanguages, oldWidget.supportedLanguages) &&
        listEquals(
          widget.localizationsDelegates?.toList(),
          oldWidget.localizationsDelegates?.toList(),
        )) {
      return;
    }
    _controller.updateOptions(
      configs: widget.configs,
      themes: widget.themes,
      supportedLanguages: widget.supportedLanguages,
      localizationsDelegates: widget.localizationsDelegates,
    );
  }

  @override
  void dispose() {
    if (_isFirstFrameDeferred) WidgetsBinding.instance.allowFirstFrame();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppFuseState>(
    valueListenable: _controller,
    builder: (context, state, _) => switch (state.phase) {
      AppFuseStarting(:final progress) => VitalApp(
        theme: _shellTheme(context, state),
        home: widget.progressBuilder?.call(progress) ?? widget.placeholder,
      ),
      AppFuseFailed(:final error, :final stackTrace) => VitalApp(
        theme: _shellTheme(context, state),
        home:
            widget.errorBuilder?.call(
              error,
              stackTrace,
              () => _controller.retry().ignore(),
            ) ??
            // The builder hides the error text in release builds.
            ErrorWidget.builder(
              FlutterErrorDetails(exception: error, stack: stackTrace),
            ),
      ),
      AppFuseReady() => _buildApp(state),
    },
  );

  /// The theme of the placeholder and error screens: dark when the effective mode is dark and a dark theme exists.
  ThemeData _shellTheme(BuildContext context, AppFuseState state) {
    final isDark = switch (state.themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };
    return (isDark ? state.darkTheme : null) ?? state.lightTheme;
  }

  Widget _buildApp(AppFuseState state) {
    final config = state.config;
    final setup = _controller.setup;
    final app = _InheritedAppFuseScope(
      controller: _controller,
      state: state,
      child: setup == null
          ? widget.app
          : _InheritedSetup<T>(setup: setup, child: widget.app),
    );
    if (config is EmptyConfig) return app;

    // A new revision remounts the app, so it reads the new config values.
    return KeyedSubtree(
      key: ValueKey(state.configRevision),
      child: config.showBanner
          ? Stack(
              alignment: Alignment.topLeft,
              children: [
                app,
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: ConfigBanner(name: config.name, color: config.color),
                ),
              ],
            )
          : app,
    );
  }
}

/// Provides the setup object of type [T] to the app.
///
/// The app mounts again after each new setup object, so it does not listen for changes.
class _InheritedSetup<T extends AppFuseInitialization> extends InheritedWidget {
  const _InheritedSetup({required this.setup, required super.child});

  final T setup;

  @override
  bool updateShouldNotify(_InheritedSetup<T> oldWidget) =>
      !identical(oldWidget.setup, setup);
}

/// Provides the [AppFuseState] and [AppFuseController] to the widget tree.
class _InheritedAppFuseScope extends InheritedModel<AppFuseAspect> {
  const _InheritedAppFuseScope({
    required this.state,
    required this.controller,
    required super.child,
  });

  /// The current state of the application.
  final AppFuseState state;

  /// The controller for managing the application's state.
  final AppFuseController<AppFuseInitialization> controller;

  static Never _notFoundInheritedWidgetOfExactType() => throw ArgumentError(
    'Out of scope, not found inherited widget '
        'a _InheritedAppFuseScope of the exact type',
    'out_of_scope',
  );

  /// The closest instance of this class that encloses the given context.
  static _InheritedAppFuseScope of(
    BuildContext context, {
    bool listen = false,
    AppFuseAspect? aspect,
  }) =>
      (listen
          ? InheritedModel.inheritFrom<_InheritedAppFuseScope>(
              context,
              aspect: aspect,
            )
          : context.getInheritedWidgetOfExactType<_InheritedAppFuseScope>()) ??
      _notFoundInheritedWidgetOfExactType();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<AppFuseState>('state', state));
  }

  @override
  bool updateShouldNotify(covariant _InheritedAppFuseScope oldWidget) =>
      !identical(oldWidget.state, state);

  @override
  bool updateShouldNotifyDependent(
    covariant _InheritedAppFuseScope oldWidget,
    Set<AppFuseAspect> dependencies,
  ) => dependencies.any((aspect) => aspect.changed(oldWidget.state, state));
}

/// An extension on [BuildContext] to provide easy access to AppFuse properties.
extension $AppFuseContext on BuildContext {
  /// Shortcut for accessing the [AppFuseController].
  AppFuseController<AppFuseInitialization> get fuse =>
      AppFuseScope.controller(this);

  /// The currently active [Locale]. Rebuilds only on locale changes.
  Locale get currentLocale =>
      AppFuseScope.watch(this, AppFuseAspect.locale).locale;

  /// The currently active [ThemeMode]. Rebuilds only on theme changes.
  ThemeMode get currentThemeMode =>
      AppFuseScope.watch(this, AppFuseAspect.theme).themeMode;
}
