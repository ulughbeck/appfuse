import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// An interface for a simple key-value storage system.
abstract interface class IFuseStorage {
  Future<bool> setValue<T>(String key, T value);
  Future<T?> getValue<T>(String key);
}

/// A default storage implementation using the `shared_preferences` package.
class FuseShPrStorage implements IFuseStorage {
  FuseShPrStorage._();

  static late SharedPreferences _prefs;

  static Future<FuseShPrStorage> init() async {
    _prefs = await SharedPreferences.getInstance();
    return FuseShPrStorage._();
  }

  @override
  Future<T?> getValue<T>(String key) async {
    final value = _prefs.get(key);

    if (value == null) return null;
    return switch (value) {
      bool b when T == bool => b as T,
      int i when T == int => i as T,
      double d when T == double => d as T,
      String s when T == String => s as T,
      String dt when T == DateTime => DateTime.parse(dt) as T,
      String m when T == Map => jsonDecode(m) as T,
      String m when T == (Map<String, Object?>) => jsonDecode(m) as T,
      String m when T == (Map<String, dynamic>) => jsonDecode(m) as T,
      List<String> list when T == (List<String>) => list as T,
      _ => throw UnsupportedError('Type $T is not supported by SharedPreferencesStorage'),
    };
  }

  @override
  Future<bool> setValue<T>(String key, T value) => switch (value) {
        bool b => _prefs.setBool(key, b),
        int i => _prefs.setInt(key, i),
        double d => _prefs.setDouble(key, d),
        String s => _prefs.setString(key, s),
        List<String> list => _prefs.setStringList(key, list),
        Map<String, Object?> map => _prefs.setString(key, jsonEncode(map)),
        DateTime dt => _prefs.setString(key, dt.toIso8601String()),
        _ => throw UnsupportedError('Type ${value.runtimeType} is not supported by SharedPreferencesStorage'),
      };
}
