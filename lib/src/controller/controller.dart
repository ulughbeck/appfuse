import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl_standalone.dart' if (dart.library.html) 'package:intl/intl_browser.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:platform_info/platform_info.dart';

import '../models/models.dart';
import 'storage.dart';

part 'config.dart';
part 'initialization.dart';
part 'locale.dart';
part 'permissions.dart';
part 'state.dart';
part 'theme.dart';

/// A base class for controllers that holds a single value and notifies listeners.
abstract class IController<S> extends ValueNotifier<S> {
  IController(super.value);

  S get state => value;

  void setState(S newState) => value = newState;
}

/// The main controller that orchestrates the application's initialization and state.
class AppFuseController extends IController<AppFuseState> {
  AppFuseController({
    this.initTimeout = const Duration(minutes: 8),
    this.onProgress,
    this.onError,
    AppFuseInitialization? initData,
    List<BaseConfig>? configs,
    Map<Brightness, ThemeData>? themes,
    Map<Locale, String>? supportedLanguages,
    Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates,
    IFuseStorage? storage,
  })  : _storage = storage,
        _initData = initData ?? EmptyInitialization(),
        _configs = configs ?? const [],
        _localizationsDelegates = localizationsDelegates ?? const [],
        _supportedLanguages = supportedLanguages ?? {const Locale('en'): 'English'},
        _themes = themes ?? {Brightness.light: ThemeData.light()},
        super(AppFuseState.initialising()) {
    _initialiseApp();
  }

  final Duration initTimeout;
  final void Function(String message)? onProgress;
  final void Function(Object error, StackTrace stackTrace)? onError;

  final List<BaseConfig> _configs;
  final AppFuseInitialization _initData;
  final Map<Brightness, ThemeData> _themes;
  final Map<Locale, String> _supportedLanguages;
  final Iterable<LocalizationsDelegate<dynamic>> _localizationsDelegates;

  /// Fuse Settings Storage
  IFuseStorage? _storage;

  /// Ephemerally initializes the app and prepares it for use.
  Future<AppFuseInitialization>? _$currentInitialization;
}
