part of 'controller.dart';

const _kConfigSelected = 'appfuse.settings.config';
const _kCustomSettings = 'appfuse.settings.custom';

extension $ConfigSettings on AppFuseController {
  /// Activates the given [config], initializes it, and persists the choice.
  Future<void> activateConfig(BaseConfig config) => handle<void>(() async {
        try {
          setState(state.startProcessing());
          final configLoaded = await config.init();
          setState(state.copyWith(config: configLoaded));
          _fuseStorage!.setValue(_kConfigSelected, config.name).ignore();
        } on Object catch (error, stackTrace) {
          _onError(error, stackTrace);
        } finally {
          setState(state.stopProcessing());
        }
      });

  /// Sets a custom key-value pair in the settings and persists it.
  Future<void> setCustomSetting<T>(String key, T value) => handle<void>(() async {
        final customSettings = Map<String, Object?>.from(state.customSettings);
        customSettings[key] = value;
        setState(state.copyWith(customSettings: customSettings));
        _fuseStorage!.setValue<Map<String, Object?>>(_kCustomSettings, customSettings).ignore();
      });
}
