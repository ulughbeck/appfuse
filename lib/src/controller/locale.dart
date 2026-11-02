part of 'controller.dart';

mixin _LocaleMixin<T extends AppFuseInitialization> on _AppFuseBase<T> {
  /// Changes the locale and saves it as the user's choice.
  ///
  /// The saved locale is the closest supported one, so `Locale('en', 'US')`
  /// saves `Locale('en')` when only `en` is supported. `null` removes the saved
  /// choice, and the app follows the device languages again.
  ///
  /// Throws an [ArgumentError] at once when no supported locale has the
  /// language of [locale]. Nothing is saved, the state does not change, and
  /// [onError] receives nothing. On a failed write the locale does not change,
  /// [onError] receives the error, and the returned future completes with it.
  Future<void> changeLocale(Locale? locale) {
    if (locale == null) {
      return _queued(() async {
        await _store.remove(AppFuseKeys.locale);
        _setState(_withEffectiveLocale(state.copyWith(userLocale: () => null)));
      });
    }
    final resolved = state.resolveLocale(locale);
    if (resolved.languageCode != locale.languageCode) {
      throw ArgumentError.value(locale, 'locale', 'is not supported');
    }
    return _queued(() async {
      await _store.write(AppFuseKeys.locale, resolved.toLanguageTag());
      _setState(
        _withEffectiveLocale(state.copyWith(userLocale: () => resolved)),
      );
    });
  }
}

/// Reads language tags like `zh-Hant-TW` and the older `zh_Hant_TW` format.
Locale? _parseLocale(String value) {
  if (value.isEmpty) return null;
  final [languageCode, ...subtags] = value.split(RegExp('[-_]'));
  return Locale.fromSubtags(
    languageCode: languageCode,
    scriptCode: subtags.where((subtag) => subtag.length == 4).firstOrNull,
    countryCode: subtags.where((subtag) => subtag.length != 4).firstOrNull,
  );
}
