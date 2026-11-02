import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../exceptions.dart';
import 'base_config.dart';
import 'config_values.dart';

Map<String, Object?> _decodeConfig(String source) =>
    switch (jsonDecode(source)) {
      Map<String, Object?> config when config.isNotEmpty => config,
      Map<String, Object?>() => throw const AppFuseConfigException(
        'Config was empty.',
      ),
      _ => throw const AppFuseConfigException('Config is not a JSON object.'),
    };

/// A configuration that loads its values from a local JSON asset file.
abstract class JsonAssetConfig extends BaseConfig with ConfigValues {
  JsonAssetConfig({
    required String path,
    required super.name,
    super.color = const Color(0xFFCCCCCC),
    super.showBanner = false,
  }) : _path = path;

  final String _path;

  Map<String, Object?> _values = const {};

  @override
  Map<String, Object?> get values => _values;

  /// Loads the asset. Calling it again reloads the values.
  @override
  Future<JsonAssetConfig> init() async {
    _values = _decodeConfig(await rootBundle.loadString(_path));
    return this;
  }
}

/// The HTTP method to use for the network request.
enum HttpMethod { get, post }

/// A configuration that loads its values from a remote JSON endpoint.
abstract class JsonRemoteConfig extends BaseConfig with ConfigValues {
  /// Sends the request with [client] when given. Else each request uses a new client that closes after it.
  JsonRemoteConfig({
    required String uri,
    required super.name,
    super.color = const Color(0xFFCCCCCC),
    super.showBanner = false,
    HttpMethod httpMethod = HttpMethod.get,
    Map<String, String>? headers,
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  }) : _uri = uri,
       _httpMethod = httpMethod,
       _headers = headers,
       _client = client;

  final String _uri;
  final HttpMethod _httpMethod;
  final Map<String, String>? _headers;
  final http.Client? _client;

  /// Limits the request. Startup has no limit of its own, so this keeps a
  /// stalled server from holding the app on the placeholder.
  final Duration timeout;

  Map<String, Object?> _values = const {};

  @override
  Map<String, Object?> get values => _values;

  /// Fetches the config. Calling it again reloads the values.
  @override
  Future<JsonRemoteConfig> init() async {
    final uri = Uri.parse(_uri);
    final client = _client ?? http.Client();
    try {
      final response = await switch (_httpMethod) {
        HttpMethod.get => client.get(uri, headers: _headers),
        HttpMethod.post => client.post(uri, headers: _headers),
      }.timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw http.ClientException(
          'Config request failed with status ${response.statusCode}',
          uri,
        );
      }
      _values = _decodeConfig(response.body);
    } finally {
      if (_client == null) client.close();
    }
    return this;
  }
}
