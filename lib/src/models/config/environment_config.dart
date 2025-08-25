import 'dart:ui';

import 'base_config.dart';

/// A configuration that loads its values from compile-time environment variables passed via the `--dart-define` flag.
abstract class EnvironmentConfig extends BaseConfig {
  const EnvironmentConfig({
    super.name,
    super.color = const Color(0xFFCCCCCC),
    super.showBanner = false,
  });

  @override
  Future<EnvironmentConfig> init() async => this;

  @override
  T getConfigValue<T extends Object?>(String key) {
    if (T == String) return getString(key) as T;
    if (T == int) return getInt(key) as T;
    if (T == bool) return getBool(key) as T;
    if (T == double) return getDouble(key) as T;
    throw Exception(
      "Type $T is not supported by EnvironmentConfig. Only String, int, bool, and double are allowed.",
    );
  }

  bool getBool(String key, {bool defaultValue = false}) => bool.fromEnvironment(key, defaultValue: defaultValue);
  String getString(String key, {String defaultValue = ''}) => String.fromEnvironment(key, defaultValue: defaultValue);
  int getInt(String key, {int defaultValue = 0}) => int.fromEnvironment(key, defaultValue: defaultValue);
  double getDouble(String key, {double defaultValue = 0.0}) {
    final valueStr = String.fromEnvironment(key);
    return double.tryParse(valueStr) ?? defaultValue;
  }
}
