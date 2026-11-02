# Changelog

## 0.0.3

- **Breaking**: smaller API: `AppFuseScope.read`, `watch(context, aspect)`, `controller`, `initOf<T>`, and `context.fuse`. `init:` takes a factory (`Dependencies.new`), `AppFuseState.phase` replaces `isProcessing`/`error`/`progress`, configs read values with a typed `ConfigKey<T>`, and `IAppFuseStorage` stores strings. `Header` and `SettingTile` are now `AppFuseSettingsHeader` and `AppFuseSettingTile`. Only `Permission`, `PermissionStatus`, and their getters are re-exported from `permission_handler`. Android needs `compileSdk = 37`, and there `checkPermissionStatus` no longer returns `permanentlyDenied`.
- **Changed**: a config switch is a soft restart that saves the choice only after the init steps succeed. The native splash stays until startup ends (`keepNativeSplash`). On macOS, Linux, and Fuchsia the permission helpers return `granted` instead of throwing.
- **Added**: `retry()` after an init error, `AppFuseAspect` for targeted rebuilds, the "System" language option, `removeCustomSetting`, `AppFuseInitialization.dispose()`, a permission recheck on app resume, DevTools timeline events, and inspector support for `AppFuseState`.
- **Fixed**: bad saved data and a failed or slow app info read no longer stop startup. Writes run in order, and a failed write keeps the current value. The state is unmodifiable. Theme choice, placeholder theming, the permission dialog, and a removed active config are handled correctly.
- **Dependencies**: removed `intl`, `flutter_localizations`, and `platform_info`. `permission_handler` ^13.0.2, `package_info_plus` ^10.2.2, `shared_preferences` ^2.5.6 (`SharedPreferencesWithCache`, saved values migrate once). Requires Dart 3.11 and Flutter 3.41.
- **Tests**: split by feature and expanded to 117 tests.

## 0.0.2

- **Fixed**: stale `MediaQuery` shadowing the live root one. `VitalApp` wrapped the entire app in a one-shot `MediaQueryData.fromView` snapshot with no metrics listener; since Flutter 3.10 the root `View` owns the live `MediaQuery` and `WidgetsApp` installs none of its own, so the app's metrics froze at startup values (symptom: app rendered with frozen/halved screen metrics when the platform corrected the window size after launch).
- **Changed**: when environment configs are active, the app is no longer wrapped in `VitalApp` at all — the app is a complete `MaterialApp` and needs no shell. The debug banner is overlaid via a `Stack`; config-change remount semantics are preserved with `KeyedSubtree`. `VitalApp` remains as the minimal shell for splash/error content only and no longer inserts a `MediaQuery`.
- **Changed**: migrated to `MediaQuery.sizeOf`, `ColorScheme.surface`, and `RadioGroup` (Radio `groupValue`/`onChanged` deprecated since Flutter 3.32).
- **Dependencies**: bumped `package_info_plus` `^9.0.0` → `^10.1.0`, `shared_preferences` `^2.5.4` → `^2.5.5`, and `permission_handler` `^12.0.1` → `^12.0.3`; SDK floor raised to `^3.10.0`.
- **Tests**: added regression coverage for MediaQuery liveness, banner visibility, and config switching.

## 0.0.1

- Initial release.
