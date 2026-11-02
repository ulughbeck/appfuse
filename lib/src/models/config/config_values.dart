import '../exceptions.dart';
import 'base_config.dart';

/// A config key whose value type is [T].
///
/// [T] is `String`, `int`, `double`, or `bool`. Declare keys once and read them with [ConfigValues.read].
extension type const ConfigKey<T extends Object>(String name) {}

/// Typed lookup over a map of config [values]. Numbers and booleans may also be stored as strings.
mixin ConfigValues on BaseConfig {
  Map<String, Object?> get values;

  @override
  T getConfigValue<T extends Object?>(String key) {
    final value = values[key];

    if (value is T) return value;
    if (value == null)
      throw AppFuseConfigException("Config key '$key' not found.");
    final valString = value.toString();
    final parsed = switch (T) {
      const (String) => valString,
      const (int) => int.tryParse(valString),
      const (double) => double.tryParse(valString),
      const (bool) => bool.tryParse(valString, caseSensitive: false),
      _ => null,
    };
    if (parsed is T) return parsed;
    throw AppFuseConfigException(
      "Config key '$key' has value '$valString' that is not a $T.",
    );
  }

  /// Returns the value of [key] as a [T].
  ///
  /// Throws an [AppFuseConfigException] when the key is missing or its value is not a [T].
  T read<T extends Object>(ConfigKey<T> key) => getConfigValue<T>(key.name);
}
