import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;

import 'base_config.dart';

/// A configuration that loads its values from a local JSON asset file.
abstract class JsonAssetConfig extends BaseConfig {
  JsonAssetConfig({
    required String path,
    required super.name,
    super.color = const Color(0xFFCCCCCC),
    super.showBanner = false,
    Map<String, Object?> config = const <String, Object?>{},
  })  : _path = path,
        _config = config;

  final String _path;
  Map<String, Object?> _config;

  @override
  Future<JsonAssetConfig> init() async {
    try {
      _config = await _loadFromPath();
      return this;
    } catch (_) {
      rethrow;
    }
  }

  Future<Map<String, Object?>> _loadFromPath() async {
    try {
      final configJson = jsonDecode(
        await rootBundle.loadString(_path),
      ) as Map<String, Object?>;

      if (configJson.isEmpty) throw Exception('Config was empty');
      return configJson;
    } catch (_) {
      rethrow;
    }
  }

  @override
  R getConfigValue<R extends Object?>([String? key]) {
    if (key == null) throw Exception('key must be provided');

    try {
      return _config[key] as R;
    } catch (_) {
      rethrow;
    }
  }

  bool getBool(String key) => getConfigValue<bool>(key);
  String getString(String key) => getConfigValue<String>(key);
  int getInt(String key) => getConfigValue<int>(key);
  double getDouble(String key) => getConfigValue<double>(key);
}
