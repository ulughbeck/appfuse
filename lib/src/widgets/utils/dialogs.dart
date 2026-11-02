import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../foundation/scope.dart';

/// Shows the supported languages, with a first entry named [systemLabel] that follows the device languages.
Future<void> selectLocaleDialog(
  BuildContext context, {
  String title = 'Language',
  String systemLabel = 'System',
}) {
  final fuse = context.fuse;
  final state = fuse.state;
  return _selectDialog<Locale?>(
    context,
    title: title,
    selected: state.userLocale == null ? null : state.locale,
    choices: [
      _Choice(null, systemLabel),
      for (final MapEntry(key: locale, value: name)
          in state.supportedLanguages.entries)
        _Choice(locale, name),
    ],
    onSelected: fuse.changeLocale,
  );
}

/// Shows the theme modes the app supports. Without a dark theme, only light is shown and selected.
Future<void> selectThemeDialog(BuildContext context, {String title = 'Theme'}) {
  final fuse = context.fuse;
  final state = fuse.state;
  return _selectDialog<ThemeMode>(
    context,
    title: title,
    selected: state.darkTheme == null ? ThemeMode.light : state.themeMode,
    choices: [for (final mode in state.themeModes) _Choice(mode, mode.name)],
    onSelected: fuse.changeThemeMode,
  );
}

/// Shows the configs. A new choice restarts the app with the new config. Does nothing without configs.
Future<void> selectConfigDialog(
  BuildContext context, {
  String title = 'Config',
}) async {
  final fuse = context.fuse;
  final AppFuseState(:config, :configs) = fuse.state;
  if (config is EmptyConfig) return;
  return _selectDialog<String>(
    context,
    title: title,
    selected: config.name,
    choices: [
      for (final config in configs)
        _Choice(config.name, config.name, color: config.color),
    ],
    onSelected: (name) async {
      final config = configs.where((config) => config.name == name).first;
      await fuse.activateConfig(config);
    },
  );
}

@immutable
class _Choice<T> {
  const _Choice(this.value, this.label, {this.color});

  final T value;
  final String label;

  /// The radio color. `null` uses the theme.
  final Color? color;
}

/// Shows a radio entry for each choice. A tap closes the dialog, then calls [onSelected].
///
/// [onSelected] reports its own failure to `onError`, so its future is ignored.
Future<void> _selectDialog<T>(
  BuildContext context, {
  required String title,
  required T selected,
  required List<_Choice<T>> choices,
  required Future<void> Function(T value) onSelected,
}) => showDialog<void>(
  context: context,
  useRootNavigator: true,
  builder: (dialogContext) => AlertDialog(
    title: Text(title),
    scrollable: true,
    contentPadding: const EdgeInsets.symmetric(vertical: 16),
    content: RadioGroup<T>(
      groupValue: selected,
      onChanged: (value) {
        // `null` is a valid value only when T is nullable.
        if (value is! T) return;
        Navigator.of(dialogContext).pop();
        onSelected(value).ignore();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final choice in choices)
            RadioListTile<T>(
              value: choice.value,
              title: Text(choice.label),
              activeColor: choice.color,
            ),
        ],
      ),
    ),
  ),
);
