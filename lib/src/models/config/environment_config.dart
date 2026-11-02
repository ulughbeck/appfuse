import 'dart:ui';

import 'base_config.dart';
import 'config_values.dart';

/// A configuration with compile-time values passed via the `--dart-define` flag.
///
/// Dart reads `--dart-define` values only in a constant expression, so the
/// subclass must declare them as `const` [values]:
///
/// ```dart
/// class EnvConfig extends EnvironmentConfig {
///   const EnvConfig()
///       : super(name: 'env', values: const {
///           'API_HOST': String.fromEnvironment('API_HOST', defaultValue: 'https://api.example.com'),
///         });
/// }
/// ```
abstract class EnvironmentConfig extends BaseConfig with ConfigValues {
  const EnvironmentConfig({
    required this.values,
    super.name,
    super.color = const Color(0xFFCCCCCC),
    super.showBanner = false,
  });

  @override
  final Map<String, Object?> values;

  @override
  Future<EnvironmentConfig> init() async => this;
}
