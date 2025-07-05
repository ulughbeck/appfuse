part of 'controller.dart';

/// An immutable class representing the entire state of the application.
@immutable
class AppFuseState {
  const AppFuseState({
    required this.metaData,
    required this.lightTheme,
    this.dependencies,
    this.config,
    this.configs,
    this.permissions = const <Permission, PermissionStatus>{},
    this.localizationsDelegates = const [],
    this.supportedLocales = const <Locale>[Locale('en', 'US')],
    this.customSettings = const <String, Object?>{},
    this.locale = const Locale('en', 'US'),
    this.themeMode = ThemeMode.system,
    this.darkTheme,
    this.isInitializing = false,
    this.initProgressMessage,
    this.error,
    this.stackTrace,
  });

  factory AppFuseState.initialising() => AppFuseState(
        isInitializing: true,
        lightTheme: ThemeData.light(),
        metaData: AppMetaData.none(),
      );

  final AppFuseInitialization? dependencies;

  final BaseConfig? config;
  final List<BaseConfig>? configs;
  T? getCurrentConfig<T extends BaseConfig>() {
    if (config == null) return null;
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

  final bool isInitializing;
  final String? initProgressMessage;
  final Object? error;
  final StackTrace? stackTrace;

  bool get hasError => error != null;

  AppFuseState copyWith({
    AppFuseInitialization? dependencies,
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
    bool? isInitializing,
    String? initProgressMessage,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      AppFuseState(
        dependencies: dependencies ?? this.dependencies,
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
        isInitializing: isInitializing ?? this.isInitializing,
        initProgressMessage: initProgressMessage ?? this.initProgressMessage,
        error: error ?? this.error,
        stackTrace: stackTrace ?? this.stackTrace,
      );

  @override
  bool operator ==(covariant AppFuseState other) {
    if (identical(this, other)) return true;

    return other.dependencies == dependencies &&
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
        other.isInitializing == isInitializing &&
        other.initProgressMessage == initProgressMessage &&
        other.error == error &&
        other.stackTrace == stackTrace;
  }

  @override
  int get hashCode =>
      dependencies.hashCode ^
      config.hashCode ^
      configs.hashCode ^
      metaData.hashCode ^
      permissions.hashCode ^
      customSettings.hashCode ^
      localizationsDelegates.hashCode ^
      supportedLocales.hashCode ^
      locale.hashCode ^
      themeMode.hashCode ^
      lightTheme.hashCode ^
      darkTheme.hashCode ^
      isInitializing.hashCode ^
      initProgressMessage.hashCode ^
      error.hashCode ^
      stackTrace.hashCode;
}
