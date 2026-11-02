import 'package:flutter/widgets.dart';

import '../exceptions.dart';

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

/// The active config when `AppFuseScope` has no configs. It has no values.
class EmptyConfig extends BaseConfig {
  const EmptyConfig() : super(name: 'NONE', showBanner: false);

  @override
  Future<BaseConfig> init() async => this;

  @override
  T getConfigValue<T extends Object?>(
    String key,
  ) => throw AppFuseConfigException(
    "Config key '$key' not found: AppFuseScope has no configs. Pass a non-empty list to `configs`.",
  );
}
