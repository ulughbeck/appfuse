part of 'controller.dart';

mixin _ConfigMixin<T extends AppFuseInitialization>
    on _AppFuseBase<T>, _InitializationMixin<T> {
  /// Switches to [config] with a soft restart, and saves the choice after it succeeds.
  ///
  /// The app unmounts and the placeholder shows. [config] loads, the old init
  /// object gets [AppFuseInitialization.dispose], and a new one runs its steps
  /// again, so services use the new config. Then the app mounts again.
  ///
  /// Calls run one after another, after earlier writes. The last call ends
  /// active. A call fails with a [StateError] when the controller is still
  /// initializing or has failed. Failures:
  /// * [config] fails to load: the old config and setup object stay active,
  ///   [onError] receives the error, and the returned future completes with it.
  /// * A step fails: [AppFuseState.phase] is [AppFuseFailed], as at startup. [retry] runs
  ///   the startup again. The choice is not saved, so the next launch uses the
  ///   previous config.
  /// * The save fails: the new config stays active for this session.
  Future<void> activateConfig(BaseConfig config) => _serial(() async {
    if (state.phase is! AppFuseReady) {
      throw StateError('Cannot switch the config while AppFuse is not ready');
    }
    _setState(state.copyWith(phase: const AppFuseStarting()));

    final BaseConfig loaded;
    try {
      loaded = await config.init();
    } on Object catch (error, stackTrace) {
      _report(error, stackTrace);
      _setState(state.copyWith(phase: const AppFuseReady()));
      rethrow;
    }
    if (_disposed) return;

    await _releaseSetup(_report);
    if (_disposed) return;

    final phase = await _runInitialization(() {
      final steps = _createSetupSteps();
      _setState(
        state.copyWith(
          config: loaded,
          configRevision: state.configRevision + 1,
        ),
      );
      return steps;
    });
    if (_disposed) return;
    // The runner already reported the failure.
    if (phase case AppFuseFailed(:final error, :final stackTrace)) {
      Error.throwWithStackTrace(error, stackTrace);
    }

    try {
      await _store.write(AppFuseKeys.config, loaded.name);
    } on Object catch (error, stackTrace) {
      _report(error, stackTrace);
      rethrow;
    }
  });

  /// Saves a custom setting. All custom settings are saved as one JSON map.
  ///
  /// [value] must be JSON-encodable. The state then holds the decoded value, so
  /// it is the same before and after a restart. When the value cannot be
  /// encoded or the write fails, the state does not change, [onError] receives
  /// the error, and the returned future completes with it. A value equal to the
  /// saved one writes nothing and does not change the state.
  Future<void> setCustomSetting(String key, Object? value) =>
      _queued(() => _saveCustomSettings({...state.customSettings, key: value}));

  /// Removes a custom setting. Fails the same way as [setCustomSetting].
  Future<void> removeCustomSetting(String key) => _queued(() async {
    if (!state.customSettings.containsKey(key)) return;
    await _saveCustomSettings({...state.customSettings}..remove(key));
  });

  /// Does nothing when [settings] encode to the saved settings, so a watcher does not rebuild.
  Future<void> _saveCustomSettings(Map<String, Object?> settings) async {
    final encoded = jsonEncode(settings);
    if (encoded == jsonEncode(state.customSettings)) return;
    await _store.write(AppFuseKeys.customSettings, encoded);
    _setState(
      state.copyWith(customSettings: _AppFuseBase._decodeSettings(encoded)),
    );
  }
}
