import 'dart:convert';
import 'dart:ui';

import 'package:http/http.dart' as http;

import 'base_config.dart';

/// The HTTP method to use for the network request.
enum HttpMethod { get, post }

/// A configuration that loads its values from a remote JSON endpoint.
abstract class JsonRemoteConfig extends BaseConfig {
  JsonRemoteConfig({
    required String uri,
    required super.name,
    super.color = const Color(0xFFCCCCCC),
    super.showBanner = false,
    HttpMethod httpMethod = HttpMethod.get,
    Map<String, String>? headers,
    Map<String, Object?> config = const <String, Object?>{},
  })  : _uri = uri,
        _httpMethod = httpMethod,
        _headers = headers,
        _config = config;

  final String _uri;
  final HttpMethod _httpMethod;
  final Map<String, String>? _headers;

  Map<String, Object?> _config;

  @override
  Future<JsonRemoteConfig> init() async {
    try {
      _config = await _fetchFromNetwork();
      return this;
    } catch (_) {
      rethrow;
    }
  }

  Future<Map<String, Object?>> _fetchFromNetwork() async {
    try {
      final uri = Uri.parse(_uri);
      late final String response;
      switch (_httpMethod) {
        case HttpMethod.post:
          response = (await http.post(uri, headers: _headers)).body;
        case HttpMethod.get:
          response = (await http.get(uri, headers: _headers)).body;
      }

      final configJson = jsonDecode(response) as Map<String, Object?>;
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
