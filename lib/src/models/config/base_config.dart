import 'package:flutter/widgets.dart';

/// An abstract base class for all environment configurations.
abstract class BaseConfig {
  BaseConfig({
    String name = 'BASE',
    this.color = const Color(0xFFCCCCCC),
    this.showBanner = false,
  }) : name = name.toUpperCase();

  /// The unique name of the configuration (e.g., "PROD", "TEST").
  final String name;

  /// The color used for the debug banner.
  final Color color;

  /// Whether to display the debug banner in the corner of the app.
  final bool showBanner;

  /// Asynchronously initializes the configuration, loading any required data.
  Future<BaseConfig> init();

  /// Retrieves a raw configuration value for a given [key].
  T getConfigValue<T extends Object?>([String? key]);
}
