import 'package:appfuse/appfuse.dart';
import 'package:flutter/material.dart';

class LocalizationIconButton extends StatelessWidget {
  const LocalizationIconButton({
    super.key,
    this.dialogTitle = 'Language',
    this.iconColor,
  });
  final String dialogTitle;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onLongPress: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Current language ${context.currentLanguage}'),
            ),
          );
        },
        child: IconButton(
          icon: const Icon(Icons.language),
          color: iconColor,
          onPressed: () => selectLocaleDialog(context, title: dialogTitle),
        ),
      );
}

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
    final icon = switch (context.currentThemeMode) {
      ThemeMode.light => Icons.sunny,
      ThemeMode.dark => Icons.nightlight_round,
      ThemeMode.system => Icons.perm_device_info,
    };
    return GestureDetector(
      onLongPress: () {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Current theme mode ${context.currentThemeModeName}'),
          ),
        );
      },
      child: IconButton(
        icon: Icon(icon),
        color: iconColor,
        onPressed: () => selectThemeDialog(context, title: dialogTitle),
      ),
    );
  }
}
