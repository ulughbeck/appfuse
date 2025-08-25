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
