import 'package:flutter/material.dart';

import 'foundation/scope.dart';
import 'utils/dialogs.dart';

/// Opens [selectLocaleDialog]. The tooltip names the current language.
class LocalizationIconButton extends StatelessWidget {
  const LocalizationIconButton({
    super.key,
    this.dialogTitle = 'Language',
    this.systemLabel = 'System',
    this.iconColor,
  });
  final String dialogTitle;

  /// The name of the dialog entry that follows the device languages.
  final String systemLabel;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(Icons.language),
    color: iconColor,
    tooltip:
        'Current language: ${AppFuseScope.watch(context, AppFuseAspect.locale).languageName}',
    onPressed: () => selectLocaleDialog(
      context,
      title: dialogTitle,
      systemLabel: systemLabel,
    ),
  );
}

/// Opens [selectThemeDialog]. The icon and tooltip show the current theme mode.
class ThemeIconButton extends StatelessWidget {
  const ThemeIconButton({
    super.key,
    this.dialogTitle = 'Theme',
    this.iconColor,
  });
  final String dialogTitle;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final mode = context.currentThemeMode;
    return IconButton(
      icon: Icon(switch (mode) {
        ThemeMode.light => Icons.sunny,
        ThemeMode.dark => Icons.nightlight_round,
        ThemeMode.system => Icons.brightness_auto,
      }),
      color: iconColor,
      tooltip: 'Current theme mode: ${mode.name}',
      onPressed: () => selectThemeDialog(context, title: dialogTitle),
    );
  }
}
