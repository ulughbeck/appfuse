part of 'controller.dart';

mixin _ThemeMixin<T extends AppFuseInitialization> on _AppFuseBase<T> {
  /// Changes the theme mode and saves it as the user's choice.
  ///
  /// The choice is saved as given. Without a dark theme, [AppFuseState.themeMode]
  /// shows [ThemeMode.dark] as [ThemeMode.system] until a dark theme is added.
  /// On a failed write the theme mode does not change, [onError] receives the
  /// error, and the returned future completes with it.
  Future<void> changeThemeMode(ThemeMode newMode) => _queued(() async {
    await _store.write(AppFuseKeys.themeMode, newMode.name);
    _themeChoice = newMode;
    _setState(state.copyWith(themeMode: state.resolveThemeMode(newMode)));
  });
}
