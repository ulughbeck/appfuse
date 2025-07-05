part of 'controller.dart';

const _kConfigSelected = 'appfuse.settings.config';
const _kCustomSettings = 'appfuse.settings.custom';

extension $ConfigSettings on AppFuseController {
  /// Loads and activates the previously saved or default configuration.
  Future<void> _fetchSavedConfig(List<BaseConfig> configs) async {
    final name = await _storage!.getValue<String>(_kConfigSelected);
    final iterator = configs.where((config) => config.name == name);
    final enabledConfig = iterator.isNotEmpty ? iterator.first : configs.first;
    final configLoaded = await enabledConfig.init();
    setState(state.copyWith(configs: configs, config: configLoaded));
  }

  /// Activates the given [config], initializes it, and persists the choice.
  Future<void> activateConfig(BaseConfig config) async {
    try {
      setState(state.copyWith(isInitializing: true));
      final configLoaded = await config.init();
      setState(state.copyWith(isInitializing: false, config: configLoaded));
      _storage!.setValue(_kConfigSelected, config.name).ignore();
    } on Object catch (error, stackTrace) {
      _onError(error, stackTrace);
    }
  }

  /// Sets a custom key-value pair in the settings and persists it.
  Future<void> setCustomSetting<T>(String key, T value) async {
    final customSettings = Map<String, Object?>.from(state.customSettings);
    customSettings[key] = value;
    setState(state.copyWith(customSettings: customSettings));
    _storage!.setValue<Map<String, Object?>>(_kCustomSettings, customSettings).ignore();
  }
}
