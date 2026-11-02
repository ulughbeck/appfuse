import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'config/base_config.dart';
import 'meta_data.dart';

/// The position of the running initialization step.
@immutable
class AppFuseProgress {
  const AppFuseProgress({
    required this.current,
    required this.total,
    required this.step,
  });

  /// The number of the running step, from 1 to [total].
  final int current;

  /// The number of steps in this run.
  final int total;

  /// The name of the running step.
  final String step;

  @override
  bool operator ==(Object other) =>
      other is AppFuseProgress &&
      other.current == current &&
      other.total == total &&
      other.step == step;

  @override
  int get hashCode => Object.hash(current, total, step);

  @override
  String toString() => 'AppFuseProgress($current/$total, "$step")';
}

/// Where the startup of the app is.
sealed class AppFusePhase {
  const AppFusePhase();
}

/// The startup steps run. [progress] is `null` before the first step of a run.
final class AppFuseStarting extends AppFusePhase {
  const AppFuseStarting([this.progress]);

  final AppFuseProgress? progress;

  @override
  bool operator ==(Object other) =>
      other is AppFuseStarting && other.progress == progress;

  @override
  int get hashCode => Object.hash(AppFuseStarting, progress);

  @override
  String toString() => 'AppFuseStarting($progress)';
}

/// A startup step failed or [AppFuseScope.initTimeout] passed. Call `retry` to run the startup again.
final class AppFuseFailed extends AppFusePhase {
  const AppFuseFailed(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;

  @override
  bool operator ==(Object other) =>
      other is AppFuseFailed &&
      other.error == error &&
      other.stackTrace == stackTrace;

  @override
  int get hashCode => Object.hash(error, stackTrace);

  @override
  String toString() => 'AppFuseFailed($error)';
}

/// The startup finished and the app runs.
final class AppFuseReady extends AppFusePhase {
  const AppFuseReady();

  @override
  String toString() => 'AppFuseReady()';
}

/// An immutable snapshot of everything AppFuse knows about the app.
@immutable
class AppFuseState with Diagnosticable {
  const AppFuseState({
    required this.metaData,
    required this.locale,
    required this.supportedLanguages,
    this.config = const EmptyConfig(),
    this.configRevision = 0,
    this.configs = const [],
    this.permissions = const <Permission, PermissionStatus>{},
    this.localizationsDelegates = const [],
    this.customSettings = const <String, Object?>{},
    this.userLocale,
    this.themeMode = ThemeMode.system,
    this.themes = const {},
    this.phase = const AppFuseStarting(),
  });

  /// The state before initialization. A `null` or empty [supportedLanguages] uses English.
  ///
  /// The collections are copies that cannot change, so the state changes only through the controller.
  factory AppFuseState.initial({
    List<BaseConfig>? configs,
    Map<Brightness, ThemeData>? themes,
    Map<Locale, String>? supportedLanguages,
    Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates,
  }) {
    final languages = supportedLanguages == null || supportedLanguages.isEmpty
        ? _defaultLanguages
        : Map<Locale, String>.unmodifiable(supportedLanguages);
    return AppFuseState(
      metaData: AppMetaData.none(),
      locale: languages.keys.first,
      configs: List.unmodifiable(configs ?? const []),
      themes: Map.unmodifiable(themes ?? const {}),
      supportedLanguages: languages,
      localizationsDelegates: List.unmodifiable(
        localizationsDelegates ?? const [],
      ),
    );
  }

  static final _defaultLanguages = Map<Locale, String>.unmodifiable({
    const Locale('en'): 'English',
  });

  final BaseConfig config;

  /// Increases on each [AppFuseController.activateConfig] that loads its config, so the app remounts with fresh config values.
  final int configRevision;
  final List<BaseConfig> configs;

  final Map<String, Object?> customSettings;

  final AppMetaData metaData;

  /// The last known status of each permission checked or requested through the controller.
  final Map<Permission, PermissionStatus> permissions;

  final List<LocalizationsDelegate<dynamic>> localizationsDelegates;
  final Map<Locale, String> supportedLanguages;

  /// The language the user picked. `null` follows the device languages.
  final Locale? userLocale;

  /// The effective locale: [userLocale] or the device languages, resolved against [supportedLocales].
  final Locale locale;

  final ThemeMode themeMode;
  final Map<Brightness, ThemeData> themes;

  /// Where the startup is: running, failed, or finished.
  final AppFusePhase phase;

  Iterable<Locale> get supportedLocales => supportedLanguages.keys;

  /// The name of [locale] in [supportedLanguages], or its language tag.
  String get languageName =>
      supportedLanguages[locale] ?? locale.toLanguageTag();

  ThemeData get lightTheme => themes[Brightness.light] ?? _defaultLightTheme;
  static final _defaultLightTheme = ThemeData.light();
  ThemeData? get darkTheme => themes[Brightness.dark];

  /// The theme modes the app offers: only light without a dark theme.
  List<ThemeMode> get themeModes => darkTheme == null
      ? const [ThemeMode.light]
      : const [ThemeMode.light, ThemeMode.dark, ThemeMode.system];

  T? getCurrentConfig<T extends BaseConfig>() {
    final current = config;
    return current is T ? current : null;
  }

  T? getCustomSetting<T>(String key) {
    final value = customSettings[key];
    return value is T ? value : null;
  }

  /// Returns the supported locale closest to [locale].
  Locale resolveLocale(Locale locale) => resolveLocales([locale]);

  /// Returns the supported locale closest to [preferred], in order of preference.
  ///
  /// Uses the same matching as [MaterialApp]: full match, language and script,
  /// language and country, language, country, then the first supported locale.
  Locale resolveLocales(List<Locale> preferred) =>
      basicLocaleListResolution(preferred, supportedLocales);

  /// Returns [mode], or [ThemeMode.system] for [ThemeMode.dark] when there is no dark theme.
  ThemeMode resolveThemeMode(ThemeMode mode) => switch (mode) {
    ThemeMode.dark when darkTheme == null => ThemeMode.system,
    _ => mode,
  };

  /// [userLocale] takes a [ValueGetter], so a caller can set it to `null`.
  AppFuseState copyWith({
    BaseConfig? config,
    int? configRevision,
    List<BaseConfig>? configs,
    Map<String, Object?>? customSettings,
    AppMetaData? metaData,
    Map<Permission, PermissionStatus>? permissions,
    List<LocalizationsDelegate<dynamic>>? localizationsDelegates,
    Map<Locale, String>? supportedLanguages,
    ValueGetter<Locale?>? userLocale,
    Locale? locale,
    ThemeMode? themeMode,
    Map<Brightness, ThemeData>? themes,
    AppFusePhase? phase,
  }) => AppFuseState(
    config: config ?? this.config,
    configRevision: configRevision ?? this.configRevision,
    configs: configs ?? this.configs,
    customSettings: customSettings ?? this.customSettings,
    metaData: metaData ?? this.metaData,
    permissions: permissions ?? this.permissions,
    localizationsDelegates:
        localizationsDelegates ?? this.localizationsDelegates,
    supportedLanguages: supportedLanguages ?? this.supportedLanguages,
    userLocale: userLocale == null ? this.userLocale : userLocale(),
    locale: locale ?? this.locale,
    themeMode: themeMode ?? this.themeMode,
    themes: themes ?? this.themes,
    phase: phase ?? this.phase,
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<AppFusePhase>('phase', phase))
      ..add(StringProperty('config', config.name))
      ..add(IntProperty('configs', configs.length))
      ..add(DiagnosticsProperty<Locale>('locale', locale))
      ..add(DiagnosticsProperty<Locale>('userLocale', userLocale))
      ..add(EnumProperty<ThemeMode>('themeMode', themeMode))
      ..add(IterableProperty<Brightness>('themes', themes.keys))
      ..add(IterableProperty<Locale>('supportedLanguages', supportedLocales))
      ..add(
        DiagnosticsProperty<Map<String, Object?>>(
          'customSettings',
          customSettings,
        ),
      )
      ..add(
        DiagnosticsProperty<Map<Permission, PermissionStatus>>(
          'permissions',
          permissions,
        ),
      )
      ..add(StringProperty('appName', metaData.appName))
      ..add(StringProperty('appVersion', metaData.appVersion));
  }
}
