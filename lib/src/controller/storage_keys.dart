/// The keys that AppFuse stores. The default storage can access no other key.
abstract final class AppFuseKeys {
  static const config = 'appfuse.settings.config';
  static const customSettings = 'appfuse.settings.custom';
  static const locale = 'appfuse.settings.locale';
  static const themeMode = 'appfuse.settings.themeMode';
  static const firstLaunch = 'appfuse.settings.firstLaunch';

  /// Marks the migration from the legacy `SharedPreferences` API as done.
  static const migration = 'appfuse.migration.sharedPreferencesAsync';

  /// The keys that the storage reads and writes.
  static const stored = {
    config,
    customSettings,
    locale,
    themeMode,
    firstLaunch,
  };
}
