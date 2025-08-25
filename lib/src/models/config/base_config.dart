import 'package:flutter/widgets.dart';

/// An abstract base class for all environment configurations.
abstract class BaseConfig {
  const BaseConfig({
    this.name = 'BASE',
    this.color = const Color(0xFFCCCCCC),
    this.showBanner = false,
  });

  /// The unique name of the configuration (e.g., "PROD", "TEST").
  final String name;

  /// The color used for the debug banner.
  final Color color;

  /// Whether to display the debug banner in the corner of the app.
  final bool showBanner;

  /// Asynchronously initializes the configuration, loading any required data.
  Future<BaseConfig> init();

  /// Retrieves a raw configuration value for a given [key].
  T getConfigValue<T extends Object?>(String key);
}

class EmptyConfig extends BaseConfig {
  const EmptyConfig() : super(name: 'NONE', showBanner: false);

  @override
  Future<BaseConfig> init() async => this;

  @override
  T getConfigValue<T extends Object?>(String key) => throw Exception(
        "Configuration Error: You are trying to access the config key '$key', but no environment configurations were provided to AppFuseScope. Please provide a non-empty list to the `configs` parameter.",
      );
}
