part of 'controller.dart';

const _kLocaleSelected = 'appfuse.settings.locale';

extension $LocaleSetttings on AppFuseController {
  Map<Locale, String> get supportedLanguages => _supportedLanguages;
  Iterable<Locale> get supportedLocales => _supportedLanguages.keys;

  /// Changes the application's active locale and persists the choice.
  Future<void> changeLocale([Locale? newLocale]) => handle<void>(() async {
        var locale = newLocale;

        locale ??= await _loadSavedLocale();
        locale ??= await _getDeviceLocale();

        if (!_isLocaleSupported(locale!)) {
          locale = await _loadSavedLocale();
          locale ??= supportedLocales.first;
        }

        setState(state.copyWith(locale: locale));

        _fuseStorage!.setValue<String>(_kLocaleSelected, locale.toString()).ignore();
      });

  /// Checks if the given [locale] is present in the list of supported locales.
  bool _isLocaleSupported(Locale locale) => supportedLocales.contains(locale);

  /// Retrieves the device's current system locale.
  Future<Locale?> _getDeviceLocale() async {
    final deviceLocale = await findSystemLocale();
    return _localeFromString(deviceLocale);
  }

  /// Retrieves the saved locale from storage.
  Future<Locale?> _loadSavedLocale() async {
    final localeStr = await _fuseStorage!.getValue<String>(_kLocaleSelected);
    if (localeStr != null) return _localeFromString(localeStr);
    return null;
  }

  /// Parses a string (e.g., "en_US" or "en") into a [Locale] object.
  Locale? _localeFromString(String val) {
    if (val.isEmpty) return null;
    final localeList = val.split('_');
    return (localeList.length > 1) ? Locale(localeList.first, localeList.last) : Locale(localeList.first);
  }
}
