import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import 'base_config.dart';

// mixin for common JSON logic
mixin _JsonConfigMixin on BaseConfig {
  // The late final Map must be provided by the class using the mixin
  late final Map<String, Object?> _config;

  @override
  T getConfigValue<T extends Object?>(String key) {
    final value = _config[key];

    if (value is T) return value;
    if (value != null) {
      final valString = value.toString();
      if (T == String) return valString as T;
      if (T == int) {
        final parsed = int.tryParse(valString);
        if (parsed != null) return parsed as T;
        throw Exception("Failed to parse value '$valString' as int for key '$key'.");
      }
      if (T == double) {
        final parsed = double.tryParse(valString);
        if (parsed != null) return parsed as T;
        throw Exception("Failed to parse value '$valString' as double for key '$key'.");
      }
      if (T == bool) {
        return switch (valString.toLowerCase()) {
          'true' => true,
          'false' => false,
          _ => throw Exception("Config key '$key' has type ${value.runtimeType} but type $T was requested.")
        } as T;
      }
    }
    if (value == null) throw Exception("Config key '$key' not found.");
    throw Exception("Config key '$key' has type ${value.runtimeType} but type $T was requested.");
  }

  bool getBool(String key) => getConfigValue<bool>(key);
  String getString(String key) => getConfigValue<String>(key);
  int getInt(String key) => getConfigValue<int>(key);
  double getDouble(String key) => getConfigValue<double>(key);
}

/// A configuration that loads its values from a local JSON asset file.
abstract class JsonAssetConfig extends BaseConfig with _JsonConfigMixin {
  JsonAssetConfig({
    required String path,
    required super.name,
    super.color = const Color(0xFFCCCCCC),
    super.showBanner = false,
  }) : _path = path;

  final String _path;

  @override
  Future<JsonAssetConfig> init() async {
    _config = await _loadFromPath();
    return this;
  }

  Future<Map<String, Object?>> _loadFromPath() async {
    final result = await rootBundle.loadString(_path);
    final configJson = jsonDecode(result) as Map<String, Object?>;
    if (configJson.isEmpty) throw Exception("Config was empty");
    return configJson;
  }
}

/// The HTTP method to use for the network request.
enum HttpMethod { get, post }

/// A configuration that loads its values from a remote JSON endpoint.
abstract class JsonRemoteConfig extends BaseConfig with _JsonConfigMixin {
  JsonRemoteConfig({
    required String uri,
    required super.name,
    super.color = const Color(0xFFCCCCCC),
    super.showBanner = false,
    HttpMethod httpMethod = HttpMethod.get,
    Map<String, String>? headers,
  })  : _uri = uri,
        _httpMethod = httpMethod,
        _headers = headers;

  final String _uri;
  final HttpMethod _httpMethod;
  final Map<String, String>? _headers;

  @override
  Future<JsonRemoteConfig> init() async {
    _config = await _fetchFromNetwork();
    return this;
  }

  Future<Map<String, Object?>> _fetchFromNetwork() async {
    final uri = Uri.parse(_uri);
    final response = await (switch (_httpMethod) {
      HttpMethod.get => http.get(uri, headers: _headers),
      HttpMethod.post => http.post(uri, headers: _headers),
    });

    final configJson = jsonDecode(response.body) as Map<String, Object?>;
    if (configJson.isEmpty) throw Exception("Config was empty");
    return configJson;
  }
}
