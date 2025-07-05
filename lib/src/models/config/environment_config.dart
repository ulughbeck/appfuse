import 'dart:ui';

import 'base_config.dart';

/// A configuration that loads its values from compile-time environment variables passed via the `--dart-define` flag.
abstract class EnvironmentConfig extends BaseConfig {
  EnvironmentConfig({
    super.name,
    super.color = const Color(0xFFCCCCCC),
    super.showBanner = false,
  });

  @override
  Future<EnvironmentConfig> init() async => this;

  @override
  R getConfigValue<R extends Object?>([String? key]) {
    if (key == null) throw ArgumentError.notNull('key');

    if (R == String) return getString(key) as R;
    if (R == int) return getInt(key) as R;
    if (R == bool) return getBool(key) as R;
    if (R == double) return getDouble(key) as R;

    throw UnsupportedError(
      'Type $R is not supported by EnvironmentConfig. '
      'Only String, int, bool, and double are allowed.',
    );
  }

  bool getBool(String key) => bool.fromEnvironment(key);
  String getString(String key, {String defaultValue = ''}) => String.fromEnvironment(key, defaultValue: defaultValue);
  int getInt(String key, {int defaultValue = 0}) => int.fromEnvironment(key, defaultValue: defaultValue);
  double getDouble(String key, {double defaultValue = 0.0}) {
    final valueStr = String.fromEnvironment(key);
    return double.tryParse(valueStr) ?? defaultValue;
  }
}
