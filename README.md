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
    init: Dependencies.new, // optional
    placeholder: const SplashScreen(),
    errorBuilder: (error, stackTrace, retry) => Text('Error: $error'),
    app: const App(),
  ),
);
```

## How it works

Main components:

- `AppFuseScope` is the root widget. It owns the controller, wires your inputs (configs, themes, init, etc.), and decides what to render during progress/error/success.
- `AppFuseController` is the core orchestrator. It runs initialization, manages persistence, exposes a `ValueListenable` state, and provides APIs for changing config/locale/theme or requesting permissions. Only the controller can change the state. Each feature (config, locale, theme, permissions, initialization) is a mixin in its own file, and all methods are instance methods, so you can override or mock them.
- `AppFuseState` is the immutable snapshot of everything AppFuse knows about your app (config, locale, theme, custom settings, permissions, metadata, and the startup `phase`). It can be accessed from anywhere in your app tree. The maps and lists in it cannot change. Changing them throws `UnsupportedError`.

```dart
final state = AppFuseScope.watch(context);
final config = AppFuseScope.read(context).getCurrentConfig<AppConfig>();
final controller = AppFuseScope.controller(context); // or context.fuse
```

`AppFuseScope.watch(context)` rebuilds on any change. `AppFuseScope.read(context)` never rebuilds. To rebuild only when one part changes, watch an aspect: `config`, `locale`, `theme`, `settings`, `permissions`, or `metaData`. `context.currentLocale` and `context.currentThemeMode` already do this.

```dart
final settings = AppFuseScope.watch(context, AppFuseAspect.settings).customSettings;
```

Configs, themes, supported languages, and localization delegates apply again when `AppFuseScope` rebuilds with new values. AppFuse compares configs by `name` and the other values by content, so values built inline in a rebuilding parent do not apply again. The active config stays active while the new `configs` list has a config with its name. If it has not, AppFuse calls `activateConfig` with the first config, or with `EmptyConfig` when the list is empty. This happens after startup only. A failed switch goes to `onError`. The other options apply only at startup.

## Initialization

`AppFuseController` orchestrates the full startup sequence:

1. Initializes AppFuseStorage.
2. Collects app metadata (operating system, app version, locale, etc.).
3. Loads the last-selected config (or falls back to the first available).
4. Restores persisted locale, theme, and custom settings.
5. Executes your `AppFuseInitialization` steps in order (DI).

The built-in steps and your steps have separate names, so a step of yours with a built-in name does not replace it. Initialization runs sequentially, reports progress, and accepts an optional `initTimeout` (default: none). After a timeout, the running step finishes, but no later step starts.

Bad saved data does not stop startup. When a saved value cannot be read or decoded, AppFuse uses the default, reports the error to `onError`, and continues. A failed first-launch write is reported the same way. The app info (version, build number, package name) is optional too. When it fails or takes longer than 5 seconds, AppFuse reports the error, keeps the app info empty, and continues.

`AppFuseState.phase` tells where startup is. It is a sealed type, so a `switch` on it is exhaustive:

```dart
final status = switch (AppFuseScope.watch(context).phase) {
  AppFuseStarting(:final progress) => 'Step ${progress?.current} of ${progress?.total}',
  AppFuseFailed(:final error) => 'Failed: $error',
  AppFuseReady() => 'Ready',
};
```

By default (`keepNativeSplash: true`), AppFuse defers the first Flutter frame, so the native splash stays until startup is ready or fails. Then `placeholder` and `progressBuilder` show only during a config switch or a retry. Set `keepNativeSplash: false` to close the native splash at the first frame and show them at startup too. `progressBuilder` gets the current `AppFuseProgress` (`current`, `total`, and `step`).

Each step is a `dart:developer` timeline event named `AppFuse: <step>`, so the DevTools performance view shows how long each step takes. `AppFuseState` is `Diagnosticable`, so the Flutter inspector shows it as the `state` property of the scope.

The placeholder, the progress widget, and the error widget have a `Theme` and a default text style. They use your dark theme when the theme mode is dark, or when it is system and the device is dark. Else they use your light theme. They have no `Navigator`.

If initialization fails, or `initTimeout` passes, the phase becomes `AppFuseFailed` with the error and stack trace. AppFuse calls `onError` once, and renders your `errorBuilder` (or `ErrorWidget.builder`, which hides the error text in release builds). A failed step arrives as `AppFuseInitException`, with the step name in `step` and the original error in `error`.

Call the `retry` callback of `errorBuilder`, or `context.fuse.retry()`, to run the startup again. AppFuse calls `dispose()` on the old setup object, creates a new one, and runs all steps again, built-in steps first. A built-in step that already succeeded, for example the storage step, does not run again. A new failure sets `AppFuseFailed` again. `retry()` in another phase fails with `StateError`.

```dart
AppFuseScope(
  errorBuilder: (error, stackTrace, retry) => Column(
    children: [
      Text('Startup failed: $error'),
      TextButton(onPressed: retry, child: const Text('Retry')),
    ],
  ),
  app: const App(),
);
```

AppFuse does not install global error handlers. Set `FlutterError.onError` and `PlatformDispatcher.instance.onError` in your app.

### Dependency initialization (DI)

Use `AppFuseInitialization` to wire up dependencies that must be ready before the UI starts. Create a class that owns your services and initialize them in steps. Pass a factory for the class to `AppFuseScope(init: ...)`, for example `Dependencies.new`. AppFuse calls the factory at startup, after each config switch, and on each retry. `AppFuseScope` takes the type of the factory result, so the object has its real type. Steps read their own fields through `this`. Widgets read the current instance with `AppFuseScope.initOf<Dependencies>(context)`. It throws a `StateError` when the type is not the type of the scope, or when the scope has no `init`. Without `init`, only the built-in steps run.

Override `dispose()` to release what the steps created, for example clients and connections. AppFuse calls it before a config switch or a retry creates a new instance, and when `AppFuseScope` is disposed.

Common candidates include Firebase, analytics, crash reporting, API clients, databases, and other services that must be ready before the UI loads.

```dart
class Dependencies with AppFuseInitialization {
  late final FirebaseApp firebase;
  late final Analytics analytics;
  late final Repository repository;

  static Dependencies of(BuildContext context) =>
      AppFuseScope.initOf<Dependencies>(context);

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

  @override
  void dispose() => repository.close();
}

void main() {
  runApp(
    AppFuseScope(
      init: Dependencies.new,
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
AppFuseScope.read(context).getCurrentConfig<T>()
```

AppFuse also persists the last-selected config and supports switching configs at runtime.

Any config implementation must have at minimum:

- a `name`
- optional banner settings (`color` and `showBanner`)
- `init()` to load/prepare config values
- `getConfigValue<T>(key)` to resolve a value by key

Built-in config types:

- `JsonAssetConfig`: loads values from a bundled JSON asset
- `JsonRemoteConfig`: fetches JSON from a remote endpoint. Fails on a non-2xx status or after `timeout` (default 30 seconds).
- `EnvironmentConfig`: holds compile-time values from `--dart-define`

Every built-in type reads values with `read` and a typed `ConfigKey<T>`. `T` is `String`, `int`, `double`, or `bool`. Numbers and booleans may also be stored as strings. Declare each key once and share it between configs:

```dart
abstract final class Keys {
  static const apiHost = ConfigKey<String>('API_HOST');
  static const analyticsEnabled = ConfigKey<bool>('ANALYTICS_ENABLED');
  static const debugEnabled = ConfigKey<bool>('DEBUG_ENABLED');
}
```

Calling `init()` again reloads the values.

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

  String get apiHost => read(Keys.apiHost);
  bool get analyticsEnabled => read(Keys.analyticsEnabled);
}

class TestConfig extends JsonAssetConfig {
  TestConfig()
      : super(
          name: 'test',
          path: 'assets/config/test.json',
          color: Colors.red,
          showBanner: true,
        );

  String get apiHost => read(Keys.apiHost);
  bool get analyticsEnabled => read(Keys.analyticsEnabled);
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

  String get apiHost => read(Keys.apiHost);
  bool get debugEnabled => read(Keys.debugEnabled);
}
```

### EnvironmentConfig example

```dart
class EnvConfig extends EnvironmentConfig {
  const EnvConfig()
      : super(
          name: 'env',
          showBanner: true,
          values: const {
            'API_HOST': String.fromEnvironment('API_HOST', defaultValue: 'https://api.example.com'),
            'DEBUG_ENABLED': bool.fromEnvironment('DEBUG_ENABLED'),
          },
        );

  String get apiHost => read(Keys.apiHost);
  bool get debugEnabled => read(Keys.debugEnabled);
}
```

Dart reads `--dart-define` values only in a constant expression, so declare them in the `const` `values` map.

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

AppFuse automatically persists the last-selected config and displays a `ConfigBanner` when `showBanner` is `true`. The banner does not block taps.

`activateConfig` does a soft restart, also when you select the active config again:

1. The app unmounts and the `placeholder` shows.
2. The config loads.
3. AppFuse calls `dispose()` on the old `AppFuseInitialization`, then creates a new one with the factory.
4. The new instance runs its steps again. They see the new config in `state`, so services use the new config.
5. The app mounts again.
6. AppFuse saves the choice.

Calls run one after another, after earlier saved writes. The last call ends active. A call while AppFuse is still initializing, or after an error, fails with `StateError`.

Failures go to `onError` once, and the returned future completes with the error:

- The config does not load: the old config and the old instance stay, and the app mounts again.
- A step fails: the phase becomes `AppFuseFailed`, as at startup, and `retry` runs the startup again. AppFuse does not save the choice, so the next launch uses the previous config.
- The save fails: the new config stays active for this session.

```dart
context.fuse.activateConfig(ProdConfig());
```

A missing key or a value of the wrong type throws `AppFuseConfigException`. `JsonRemoteConfig` takes an optional `http.Client` as `client`, for example to reuse a connection or to test with `MockClient`.

## Localization & theme management

Provide a `Map<Locale, String>` for language names, `LocalizationsDelegate`s for translations, and `ThemeData` entries keyed by `Brightness`. AppFuse follows the device languages, also when they change while the app runs, until the user picks one with `changeLocale`. Then it persists that choice in `AppFuseState.userLocale`. `changeLocale(null)` removes the choice and follows the device again. `changeLocale` saves the closest supported locale, so `Locale('en', 'US')` saves `Locale('en')` when you support `en`. It throws `ArgumentError` when no supported locale has the language, for example `Locale('xx')`. Nothing is saved then. It matches the device languages in order of preference with the same rules as `MaterialApp`: full match, language and script, language and country, then language. A `ru_RU` device gets `Locale('ru')`, and a `uz-Cyrl-UZ` device gets `uz_Cyrl` when you support both Uzbek scripts. The theme mode is saved the same way, with `ThemeMode.system` as the default. Read them anywhere with `context.currentLocale` and `context.currentThemeMode`. Change them with `context.fuse`. The light theme is optional and defaults to `ThemeData.light()`. Without a dark theme, `ThemeMode.dark` resolves to `ThemeMode.system`, and the theme picker shows and selects only light. AppFuse saves the choice as given, so a dark choice applies when you add a dark theme. If you provide a dark theme too, `ThemeMode.dark` and `ThemeMode.system` become available.

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
        supportedLocales: AppFuseScope.read(context).supportedLocales,
        localizationsDelegates: AppFuseScope.read(context).localizationsDelegates,
        themeMode: context.currentThemeMode,
        theme: AppFuseScope.read(context).lightTheme,
        darkTheme: AppFuseScope.read(context).darkTheme,
        home: const HomeScreen(),
      );
}
```

To change locale or theme mode at runtime use `changeLocale` and `changeThemeMode`:

```dart
final localeName = AppFuseScope.watch(context, AppFuseAspect.locale).languageName;
context.fuse.changeLocale(const Locale('es'));
context.fuse.changeLocale(null); // follow the device again
// context.fuse.changeLocale(const Locale('xx')) throws ArgumentError: not supported
context.fuse.changeThemeMode(ThemeMode.dark);
```

If the save fails, the value does not change, `onError` receives the error, and the returned future completes with it. An unsupported language is a programming error, so `changeLocale` throws `ArgumentError` at once and `onError` receives nothing.

Helper widgets:

- `LocalizationIconButton` / `ThemeIconButton`
- `selectLocaleDialog` / `selectThemeDialog`

The buttons show the current language or theme mode in their tooltip. The language dialog starts with a "System" entry that follows the device.

Each helper takes its text as parameters with English defaults:

```dart
selectLocaleDialog(context, title: 'Til', systemLabel: 'Qurilma tili');
const LocalizationIconButton(dialogTitle: 'Til', systemLabel: 'Qurilma tili');
const ThemeIconButton(dialogTitle: 'Mavzu');
```

## Permission handling

AppFuse re-exports only `Permission`, `PermissionStatus`, and the status getters of `permission_handler` 13, and exposes controller helpers. An app that calls `permission_handler` directly, for example `Permission.camera.request()` or `ServiceStatus`, adds `permission_handler` to its own `pubspec.yaml`. On Android, the app must set `compileSdk = 37` (or higher) in `android/app/build.gradle(.kts)`. Also on Android, `Permission.status` and `checkPermissionStatus` no longer return `permanentlyDenied`. Only a request returns it. `permission_handler` supports Android, iOS, web, and Windows. It has no code for macOS, Linux, and Fuchsia, so its calls throw `MissingPluginException` there. On those platforms the AppFuse helpers do not call it. `checkPermissionStatus` and `requestPermission` store and return `PermissionStatus.granted`, `openSettings` returns `false`, and `askPermissionDialog` returns `true` without a dialog.

Each permission needs native setup. On iOS, add the `GCC_PREPROCESSOR_DEFINITIONS` macros of `permission_handler` to the `post_install` block of your `Podfile`, one `PERMISSION_*=1` macro for each permission the app uses, and add the matching `Info.plist` usage text. Without its macro, a permission reports denied and its request shows no prompt. On Android, add the matching `<uses-permission>` entries to `AndroidManifest.xml`. See the [permission_handler setup guide](https://pub.dev/packages/permission_handler) for the macros and entries of each permission.

```dart
await context.fuse.checkPermissionStatus(Permission.camera);
await context.fuse.requestPermission(Permission.photos);
await context.fuse.openSettings();
```

Each check or request stores the result in `AppFuseState.permissions`. Watch `AppFuseAspect.permissions` to rebuild when it changes. When the app resumes, for example after the user changes a permission in the OS settings, AppFuse checks the stored permissions again and updates the changed ones. A permission request does not block settings writes, so the app can change the theme while an OS prompt is open. When a check, a request, or `openSettings` fails, `onError` receives the error and the returned future completes with it. `openSettings` returns `false` when the settings did not open. It always does on web.

Use `askPermissionDialog` for a ready-made rationale flow. It returns `true` when the permission is granted, limited, or provisional. The user can close it with "Not now" or a tap outside. When a request returns permanently denied, the dialog changes to a view that opens the OS settings, and it closes only when the OS settings open. On web they never open, so the settings view stays until the user taps "Not now". While a request or the settings call runs, the buttons are off, so a double tap starts one request. When a check or request fails, the dialog closes (or is not shown) and returns `false`. Pass `titleText` and `reasonText` to set the dialog copy, `goToSettingsText` for the settings view, and `okBtnText`, `cancelBtnText`, and `goToSettingsBtnText` for the buttons.

## Storage & persistence

By default AppFuse uses `AppFuseShPrStorage`, an `IAppFuseStorage` implementation backed by `SharedPreferencesWithCache`. It loads its values once at startup and reads them from memory. Its allow list holds only the AppFuse keys, so AppFuse cannot read or write other keys of your app. On Android it uses the DataStore Preferences backend. The other platforms use their usual stores. `IAppFuseStorage` stores strings only. AppFuse encodes each value itself: names and language tags as strings, the first-launch date as ISO-8601, and custom settings as JSON.

Earlier versions used the legacy `SharedPreferences` API. On the first start, before the first read, `AppFuseShPrStorage` copies the legacy values with the `appfuse.` prefix to the new store, so saved settings stay. It does not replace a value that the new store already holds, and it does not delete legacy values. Other keys of your app stay untouched. The key `appfuse.migration.sharedPreferencesAsync` marks the migration as done. A read of a key that holds a value other than a string throws `FormatException`.

Settings writes run one after another and complete before the state changes. `setCustomSetting` stores all custom settings as one JSON map, so each value must be JSON-encodable. The state holds the decoded value, with maps and lists that cannot change, so a value reads the same before and after a restart. A value that equals the saved one writes nothing and does not rebuild `AppFuseAspect.settings` watchers. For example, a `List<String>` reads back as a `List<Object?>`. `removeCustomSetting` removes a key. The returned future completes with an error when the value cannot be encoded or the write fails, `onError` receives it, and the state then does not change.

```dart
await context.fuse.setCustomSetting('onboarding', true);
final done = AppFuseScope.read(context).getCustomSetting<bool>('onboarding');
await context.fuse.removeCustomSetting('onboarding');
```

To supply your own storage, implement the three methods. `write` and `remove` must throw when they fail:

```dart
class MyStorage implements IAppFuseStorage {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {
    // Persist value...
  }

  @override
  Future<void> remove(String key) async {
    // Remove value...
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
- `ConfigSettings` shows the active config and a hook for custom widgets. It hides the config row when there are no configs
- `AppFuseSettingsHeader` and `AppFuseSettingTile` are the title and the row that `ConfigSettings` uses. Use them for your own entries
- `selectConfigDialog` renders config radio buttons and restarts the app with the new config
- `ConfigBanner` overlays the active config name/color when enabled. Use it directly with optional `onPressed`/`onLongPressed`; without them it lets taps through

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
2. DI implementation with `AppFuseInitialization`, read with `AppFuseScope.initOf<Dependencies>(context)`.
3. Theme/locale wiring passed into `AppFuseScope`.
4. A `MaterialApp` that uses `currentLocale`, `currentThemeMode`, and `AppFuseScope.read`.
5. An `errorBuilder` with a retry button, and the language, theme, and debug menu buttons.
