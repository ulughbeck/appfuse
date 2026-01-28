# AppFuse 🧨

AppFuse is an opinionated orchestration layer for Flutter apps. It coordinates app initialization, environment configuration, localization/theme handling, permissions, and persistent settings behind a single scope.

## Features

- [Initialization pipeline](#initialization)
- [Environment configurations](#environment-configurations)
- [Locale and theme management](#localization--theme-management)
- [Permission helpers with rationale dialog](#permission-handling)
- [Persistent settings storage](#storage--persistence)
- [Debug / Config UI](#debug--config-utilities)

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  appfuse: <version>
```

## Get started

Wrap your entire application tree with `AppFuseScope`. Supply configs, themes, supported languages, localization delegates, initialization steps, a placeholder widget, and your main app widget. All of the features are optional. Add only what you need; you can start with just `app` and incrementally enable configs, themes, localization, permissions, or init steps later.

```dart
runApp(
  AppFuseScope(
    configs: <BaseConfig>[],
    themes: <Brightness, ThemeData>{
      Brightness.light: ThemeData.light(),
      Brightness.dark: ThemeData.dark(),
    },
    supportedLanguages: <Locale, String>{
      const Locale('en'): 'English',
    },
    localizationsDelegates: <LocalizationsDelegate<dynamic>>[],
    init: EmptyInitialization(),
    placeholder: const SplashScreen(),
    errorBuilder: (error, stackTrace) => Text('Error: $error'),
    app: const App(),
  ),
);
```

## How it works

Main components:

- `AppFuseScope` is the root widget. It owns the controller, wires your inputs (configs, themes, init, etc.), and decides what to render during progress/error/success.
- `AppFuseController` is the core orchestrator. It runs initialization, manages persistence, exposes a `ValueListenable` state, and provides APIs for changing config/locale/theme or requesting permissions. Most features are implemented as extensions on `AppFuseController` (config, locale, theme, permissions, initialization), keeping the core controller small while still offering a single entry point for the API.
- `AppFuseState` is the immutable snapshot of everything AppFuse knows about your app (config, locale, theme, metadata, progress/error). It can be accessed from anywhere in your app tree.

```dart
final state = context.watchFuseState;
final config = context.readFuseState.getCurrentConfig<AppConfig>();
```

## Initialization

`AppFuseController` orchestrates the full startup sequence:

1. Initializes AppFuseStorage.
2. Collects app metadata (platform, app version, locale, etc.).
3. Loads the last-selected config (or falls back to the first available).
4. Restores persisted locale, theme, and custom settings.
5. Executes your `AppFuseInitialization` steps in order (DI).

Initialization runs sequentially, reports progress, and uses a single shared timeout (default: 3 minutes).

While initialization is running, AppFuse renders your `placeholder` (or a custom `progressBuilder`). If initialization fails, it renders your `errorBuilder` (or falls back to `ErrorWidget`).

### Dependency initialization (DI)

Use `AppFuseInitialization` to wire up dependencies that must be ready before the UI starts. Create a class that owns your services, initialize them in steps, and pass the instance to `AppFuseScope(init: ...)`. That instance is then accessible anywhere in the widget tree.

Common candidates include Firebase, analytics, crash reporting, API clients, databases, and other services that must be ready before the UI loads.

```dart
class Dependencies with AppFuseInitialization {
  late final FirebaseApp firebase;
  late final Analytics analytics;
  late final Repository repository;

  static Dependencies of(BuildContext context) =>
      AppFuseScope.of(context, listen: false).init as Dependencies;

  @override
  Map<String, InitializationStep> get steps => {
        'init firebase': (_) async {
          firebase = await Firebase.initializeApp();
        },
        'init analytics': (_) async {
          analytics = Analytics();
        },
        'init repository': (state) async {
          final config = state.getCurrentConfig<AppConfig>()!;
          repository = Repository(config.apiHost);
        },
      };
}

void main() {
  runApp(
    AppFuseScope(
      init: Dependencies(),
      placeholder: const SplashScreen(),
      app: const App(),
    ),
  );
}
```

Access dependencies from anywhere:

```dart
final deps = Dependencies.of(context);
deps.analytics.logEvent('app_open');
```

## Environment configurations

Environment configurations let you keep environment-specific values (API base URLs, feature flags, service keys, etc.) out of your widgets. Each environment is represented by a `BaseConfig` subclass with typed getters.

Provide a list of configs to AppFuseScope. AppFuse initializes the active config during startup, then you can retrieve it anywhere via:

```dart
context.readFuseState.getCurrentConfig<T>()
```

AppFuse also persists the last-selected config and supports switching configs at runtime.

Any config implementation must have at minimum:

- a `name`
- optional banner settings (`color` and `showBanner`)
- `init()` to load/prepare config values
- `getConfigValue<T>(key)` to resolve a value by key

Built-in config types:

- `JsonAssetConfig` — loads values from a bundled JSON asset
- `JsonRemoteConfig` — fetches JSON from a remote endpoint
- `EnvironmentConfig` — reads compile-time values from `--dart-define`

### JsonAssetConfig example

```dart
class ProdConfig extends JsonAssetConfig {
  ProdConfig()
      : super(
          name: 'prod',
          path: 'assets/config/prod.json',
          color: Colors.green,
          showBanner: true,
        );

  String get apiHost => getString('API_HOST');
  bool get analyticsEnabled => getBool('ANALYTICS_ENABLED');
}

class TestConfig extends JsonAssetConfig {
  TestConfig()
      : super(
          name: 'test',
          path: 'assets/config/test.json',
          color: Colors.red,
          showBanner: true,
        );

  String get apiHost => getString('API_HOST');
  bool get analyticsEnabled => getBool('ANALYTICS_ENABLED');
}
```

### JsonRemoteConfig example

```dart
class RemoteConfig extends JsonRemoteConfig {
  RemoteConfig()
      : super(
          name: 'remote',
          uri: 'https://example.com/config.json',
          httpMethod: HttpMethod.get,
          headers: {'Authorization': 'Bearer <token>'},
        );

  String get apiHost => getString('API_HOST');
  bool get debugEnabled => getBool('DEBUG_ENABLED');
}
```

### EnvironmentConfig example

```dart
class EnvConfig extends EnvironmentConfig {
  const EnvConfig() : super(name: 'env', showBanner: true);

  String get apiHost => getString('API_HOST', defaultValue: 'https://api.example.com');
  bool get debugEnabled => getBool('DEBUG_ENABLED');
}
```

Run with:

```sh
flutter run --dart-define=API_HOST=https://api.example.com --dart-define=DEBUG_ENABLED=true
```

Use configs in your scope:

```dart
void main() {
  runApp(
    AppFuseScope(
      configs: [ProdConfig(), TestConfig(), RemoteConfig(), EnvConfig()],
      placeholder: const SplashScreen(),
      app: const App(),
    ),
  );
}
```

AppFuse automatically persists the last-selected config, displays a `ConfigBanner` when `showBanner` is `true`, and rebuilds the app when `activateConfig` is called.

```dart
context.fuse.activateConfig(BaseConfig());
context.changeConfig(BaseConfig());
```

## Localization & theme management

Provide a `Map<Locale, String>` for language names, `LocalizationsDelegate`s for translations, and `ThemeData` entries keyed by `Brightness`. AppFuse tracks the last selected locale and theme mode, persists them, and exposes helpers on `BuildContext` so you can read or change them anywhere. When you provide only a light theme, the theme picker exposes only `ThemeMode.light`. If you provide a dark theme too, `ThemeMode.dark` and `ThemeMode.system` become available.

Typical `MaterialApp` wiring:

```dart
runApp(
  AppFuseScope(
    themes: <Brightness, ThemeData>{
      Brightness.light: ThemeData.light(),
      Brightness.dark: ThemeData.dark(),
    },
    supportedLanguages: <Locale, String>{
      const Locale('en'): 'English',
    },
    localizationsDelegates: <LocalizationsDelegate<dynamic>>[],
    placeholder: const SplashScreen(),
    app: const App(),
  ),
);

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        locale: context.currentLocale,
        supportedLocales: context.readFuseState.supportedLocales,
        localizationsDelegates: context.readFuseState.localizationsDelegates,
        themeMode: context.watchFuseState.themeMode,
        theme: context.readFuseState.lightTheme,
        darkTheme: context.readFuseState.darkTheme,
        home: const HomeScreen(),
      );
}
```

To change locale or theme mode at runtime use `changeAppLocale` and `changeAppThemeMode`:

```dart
final localeName = context.currentLanguageName;
context.changeAppLocale(const Locale('es'));
context.changeAppThemeMode(ThemeMode.dark);
```

Helper widgets:

- `LocalizationIconButton` / `ThemeIconButton`
- `selectLocaleDialog` / `selectThemeDialog`

`LocalizationIconButton` and `ThemeIconButton` also support a long-press hint that shows the currently selected language or theme mode.

## Permission handling

AppFuse re-exports `permission_handler` and exposes controller helpers:

```dart
await context.fuse.checkPermissionStatus(Permission.camera);
await context.fuse.requestPermission(Permission.photos);
await context.fuse.openSettings();
```

Use `askPermissionDialog` for a ready-made rationale flow that handles denied/permanently denied states and optionally opens OS settings.

## Storage & persistence

By default AppFuse uses `AppFuseShPrStorage`, an `IAppFuseStorage` implementation backed by `SharedPreferences`. It serializes primitives, `DateTime`, and `Map<String, Object?>`.

To supply your own storage:

```dart
class MyStorage implements IAppFuseStorage {
  @override
  Future<bool> setValue<T>(String key, T value) async {
    // Persist value...
    return true;
  }

  @override
  Future<T?> getValue<T>(String key) async {
    // Read value...
    return null;
  }
}

void main() {
  runApp(
    AppFuseScope(
      storage: MyStorage(),
      placeholder: const SplashScreen(),
      app: const App(),
    ),
  );
}
```

## Debug / Config utilities

Use the built-in debug UI helpers for QA or internal builds. They are optional and can be mixed with your own widgets.

- `showAppFuseMenu` renders a sheet or dialog depending on screen size
- `ConfigSettings` shows the active config and a hook for custom widgets
- `selectConfigDialog` renders config radio buttons and reloads the app
- `ConfigBanner` overlays the active config name/color when enabled

Example of a simple debug trigger:

```dart
IconButton(
  icon: const Icon(Icons.tune),
  onPressed: () => showAppFuseMenu(
    context,
    children: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: const Text('Switch config'),
          onTap: () => selectConfigDialog(context),
        ),
      ],
    ),
  ),
);
```

## Example app

See `example/lib/main.dart` for a runnable reference that shows:

1. Environment configs with JSON asset files.
2. DI implementation with `AppFuseInitialization`.
3. Theme/locale wiring passed into `AppFuseScope`.
4. A `MaterialApp` that reads `watchSettings`/`readSettings`.
