import 'package:shared_preferences/shared_preferences.dart';

import 'storage_keys.dart';

/// A key-value store for strings. AppFuse encodes every value it saves as a string.
///
/// [write] and [remove] must throw when they fail, so AppFuse keeps the old state.
abstract interface class IAppFuseStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

/// The default storage, backed by `SharedPreferencesWithCache`.
///
/// It reads and writes only the keys that AppFuse stores. Any other key throws
/// an [ArgumentError], so AppFuse cannot touch the other values of the app.
/// Reads come from a cache that [init] loads once.
///
/// [init] copies the `appfuse.` values of the legacy `SharedPreferences` API
/// once, so saved settings survive the switch to the new API.
class AppFuseShPrStorage implements IAppFuseStorage {
  AppFuseShPrStorage._(this._prefs);

  final SharedPreferencesWithCache _prefs;

  static const _prefix = 'appfuse.';

  /// Opens the storage after the one-time migration from the legacy API.
  ///
  /// The migration copies only string values with the `appfuse.` prefix, and
  /// it does not replace a value that the new storage already holds. It does
  /// not delete legacy values. Other keys of the app stay untouched.
  static Future<AppFuseShPrStorage> init() async {
    await _migrate();
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: AppFuseKeys.stored,
      ),
    );
    return AppFuseShPrStorage._(prefs);
  }

  // TODO(migration): Remove in 0.1.0. It moves values saved by 0.0.1 and 0.0.2
  // (legacy SharedPreferences) to the new store. Then also remove the call in
  // [init], AppFuseKeys.migration, and the migration tests in storage_test.dart.
  static Future<void> _migrate() async {
    final prefs = SharedPreferencesAsync();
    if (await prefs.containsKey(AppFuseKeys.migration)) return;
    final legacy = await SharedPreferences.getInstance();
    for (final key in legacy.getKeys().where(
      (key) => key.startsWith(_prefix),
    )) {
      if (legacy.get(key) case final String value
          when !await prefs.containsKey(key)) {
        await prefs.setString(key, value);
      }
    }
    await prefs.setBool(AppFuseKeys.migration, true);
  }

  /// Throws a [FormatException] when the stored value is not a string.
  @override
  Future<String?> read(String key) async {
    try {
      return _prefs.getString(key);
    } on TypeError {
      throw FormatException('"$key" does not hold a String');
    }
  }

  @override
  Future<void> write(String key, String value) =>
      _restoreCacheOnFailure(() => _prefs.setString(key, value));

  @override
  Future<void> remove(String key) =>
      _restoreCacheOnFailure(() => _prefs.remove(key));

  /// The cache changes before the platform write, so a failed write reloads it.
  Future<void> _restoreCacheOnFailure(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      try {
        await _prefs.reloadCache();
      } on Object {
        // The write error is the one to report.
      }
      rethrow;
    }
  }
}
